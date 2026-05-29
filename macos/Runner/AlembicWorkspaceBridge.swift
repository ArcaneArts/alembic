import AppKit
import FlutterMacOS
import Foundation

final class WorkspaceBridgeState: ObservableObject {
    @Published var workspacePath: String = ""
    @Published var workspaceExists: Bool = false
    @Published var isScanning: Bool = false
    @Published var scanProgress: String = ""
    @Published var lastScanResult: ScanOutcome? = nil
    @Published var lastError: String? = nil

    struct ScanOutcome {
        let rootPath: String
        let totalGitRepos: Int
        let gitHubRepos: Int
        let durationMs: Int
        let directoriesVisited: Int
        let repos: [DiscoveredRepoView]
        let warnings: [String]
    }

    struct DiscoveredRepoView: Identifiable {
        let id: String
        let absolutePath: String
        let relativePath: String
        let remoteUrl: String?
        let ownerLogin: String?
        let repoName: String?
        let slug: String?
        let isGitHub: Bool
        let defaultBranch: String?
    }
}

@MainActor
final class AlembicWorkspaceBridge {
    static let shared: AlembicWorkspaceBridge = AlembicWorkspaceBridge()

    let state: WorkspaceBridgeState = WorkspaceBridgeState()
    private var channel: FlutterMethodChannel?
    private weak var hostWindow: NSWindow?

    private init() {}

    func attach(messenger: FlutterBinaryMessenger) {
        let channel: FlutterMethodChannel = FlutterMethodChannel(
            name: "alembic.spike.workspace",
            binaryMessenger: messenger
        )
        self.channel = channel
        channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard let strongSelf: AlembicWorkspaceBridge = self else {
                result(FlutterMethodNotImplemented)
                return
            }
            strongSelf.handle(call: call, result: result)
        }
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "info",
            tag: "swift.workspace",
            message: "AlembicWorkspaceBridge attached"
        )
        loadInitialState()
    }

    func setHostWindow(_ window: NSWindow?) {
        self.hostWindow = window
    }

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "trace",
            tag: "swift.workspace",
            message: "Channel call: \(call.method)"
        )
        switch call.method {
        case "state":
            ingestState(call.arguments)
            result(nil)
        case "scanProgress":
            ingestScanProgress(call.arguments)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func loadInitialState() {
        channel?.invokeMethod("getWorkspacePath", arguments: nil) { [weak self] (response: Any?) in
            guard let strongSelf: AlembicWorkspaceBridge = self else { return }
            DispatchQueue.main.async {
                strongSelf.ingestState(response)
            }
        }
    }

    private func ingestState(_ arguments: Any?) {
        guard let map: [String: Any] = arguments as? [String: Any] else { return }
        let workspacePath: String = (map["workspacePath"] as? String) ?? ""
        let exists: Bool = (map["exists"] as? Bool) ?? false
        state.workspacePath = workspacePath
        state.workspaceExists = exists
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "trace",
            tag: "swift.workspace",
            message: "ingest state workspacePath=\(workspacePath) exists=\(exists)"
        )
    }

    private func ingestScanProgress(_ arguments: Any?) {
        guard let map: [String: Any] = arguments as? [String: Any] else { return }
        let visited: Int = (map["directoriesVisited"] as? Int) ?? 0
        let git: Int = (map["gitReposFound"] as? Int) ?? 0
        let github: Int = (map["gitHubReposFound"] as? Int) ?? 0
        let current: String = (map["currentPath"] as? String) ?? ""
        state.scanProgress = "Scanning... \(visited) dirs, \(git) git repos (\(github) GitHub) - \(URL(fileURLWithPath: current).lastPathComponent)"
    }

    func presentFolderPicker(completion: @escaping (String?) -> Void) {
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "info",
            tag: "swift.workspace",
            message: "Presenting folder picker"
        )
        let panel: NSOpenPanel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = "Choose Workspace Folder"
        panel.message = "Select a folder containing your existing git repositories. Alembic will scan for repos with the structure OWNER/REPO/.git"
        panel.prompt = "Choose"

        let activeWindow: NSWindow? = self.hostWindow ?? NSApp.keyWindow

        let handler: (NSApplication.ModalResponse) -> Void = { response in
            if response == .OK, let url: URL = panel.urls.first {
                let path: String = url.path
                AlembicDiagnosticsBridge.shared.recordNative(
                    level: "success",
                    tag: "swift.workspace",
                    message: "User chose folder: \(path)"
                )
                completion(path)
            } else {
                AlembicDiagnosticsBridge.shared.recordNative(
                    level: "info",
                    tag: "swift.workspace",
                    message: "Folder picker cancelled"
                )
                completion(nil)
            }
        }

        if let window: NSWindow = activeWindow {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            panel.begin { response in handler(response) }
        }
    }

    func scanDirectory(_ path: String, completion: @escaping (WorkspaceBridgeState.ScanOutcome?, String?) -> Void) {
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "info",
            tag: "swift.workspace",
            message: "Requesting scan of \(path)"
        )
        state.isScanning = true
        state.scanProgress = "Starting scan..."
        state.lastError = nil

        channel?.invokeMethod(
            "scanDirectory",
            arguments: ["path": path, "maxDepth": 4]
        ) { [weak self] (response: Any?) in
            guard let strongSelf: AlembicWorkspaceBridge = self else {
                completion(nil, "Bridge released")
                return
            }
            DispatchQueue.main.async {
                strongSelf.state.isScanning = false
                strongSelf.state.scanProgress = ""

                guard let map: [String: Any] = response as? [String: Any] else {
                    let errorMessage: String = "Invalid response from Dart"
                    strongSelf.state.lastError = errorMessage
                    AlembicDiagnosticsBridge.shared.recordNative(
                        level: "error",
                        tag: "swift.workspace",
                        message: "Scan response invalid"
                    )
                    completion(nil, errorMessage)
                    return
                }
                if let ok: Bool = map["ok"] as? Bool, ok == false {
                    let errorMessage: String = (map["error"] as? String) ?? "Unknown scan error"
                    strongSelf.state.lastError = errorMessage
                    AlembicDiagnosticsBridge.shared.recordNative(
                        level: "error",
                        tag: "swift.workspace",
                        message: "Scan failed: \(errorMessage)"
                    )
                    completion(nil, errorMessage)
                    return
                }
                guard let resultMap: [String: Any] = map["result"] as? [String: Any] else {
                    let errorMessage: String = "Missing result in scan response"
                    strongSelf.state.lastError = errorMessage
                    completion(nil, errorMessage)
                    return
                }
                let outcome: WorkspaceBridgeState.ScanOutcome = strongSelf.parseScanOutcome(resultMap)
                strongSelf.state.lastScanResult = outcome
                AlembicDiagnosticsBridge.shared.recordNative(
                    level: "success",
                    tag: "swift.workspace",
                    message: "Scan complete: \(outcome.totalGitRepos) git, \(outcome.gitHubRepos) GitHub, \(outcome.durationMs)ms"
                )
                completion(outcome, nil)
            }
        }
    }

    func cloneFromUrl(url: String, completion: @escaping (Bool, String?) -> Void) {
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "info",
            tag: "swift.workspace",
            message: "Cloning from URL: \(url)"
        )
        channel?.invokeMethod(
            "cloneFromUrl",
            arguments: ["url": url]
        ) { (response: Any?) in
            DispatchQueue.main.async {
                guard let map: [String: Any] = response as? [String: Any] else {
                    completion(false, "Invalid response")
                    return
                }
                let ok: Bool = (map["ok"] as? Bool) ?? false
                let errorMessage: String? = map["error"] as? String
                if ok {
                    AlembicDiagnosticsBridge.shared.recordNative(
                        level: "success",
                        tag: "swift.workspace",
                        message: "Clone succeeded"
                    )
                } else {
                    AlembicDiagnosticsBridge.shared.recordNative(
                        level: "error",
                        tag: "swift.workspace",
                        message: "Clone failed: \(errorMessage ?? "unknown")"
                    )
                }
                completion(ok, errorMessage)
            }
        }
    }

    func importDiscovered(rootPath: String, selectedSlugs: [String], completion: @escaping (Bool, String?) -> Void) {
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "info",
            tag: "swift.workspace",
            message: "Importing \(selectedSlugs.count) repos from \(rootPath)"
        )
        channel?.invokeMethod(
            "importDiscovered",
            arguments: [
                "rootPath": rootPath,
                "selectedSlugs": selectedSlugs,
            ]
        ) { (response: Any?) in
            DispatchQueue.main.async {
                guard let map: [String: Any] = response as? [String: Any] else {
                    completion(false, "Invalid response")
                    return
                }
                let ok: Bool = (map["ok"] as? Bool) ?? false
                let errorMessage: String? = map["error"] as? String
                if ok {
                    AlembicDiagnosticsBridge.shared.recordNative(
                        level: "success",
                        tag: "swift.workspace",
                        message: "Import succeeded"
                    )
                } else {
                    AlembicDiagnosticsBridge.shared.recordNative(
                        level: "error",
                        tag: "swift.workspace",
                        message: "Import failed: \(errorMessage ?? "unknown")"
                    )
                }
                completion(ok, errorMessage)
            }
        }
    }

    private func parseScanOutcome(_ map: [String: Any]) -> WorkspaceBridgeState.ScanOutcome {
        let rootPath: String = (map["rootPath"] as? String) ?? ""
        let totalGitRepos: Int = (map["totalGitRepos"] as? Int) ?? 0
        let gitHubRepos: Int = (map["gitHubRepos"] as? Int) ?? 0
        let directoriesVisited: Int = (map["directoriesVisited"] as? Int) ?? 0
        let durationMs: Int = (map["durationMs"] as? Int) ?? 0
        let warnings: [String] = (map["warnings"] as? [String]) ?? []
        let rawRepos: [[String: Any]] = (map["repos"] as? [[String: Any]]) ?? []
        let repos: [WorkspaceBridgeState.DiscoveredRepoView] = rawRepos.map { entry in
            WorkspaceBridgeState.DiscoveredRepoView(
                id: (entry["absolutePath"] as? String) ?? UUID().uuidString,
                absolutePath: (entry["absolutePath"] as? String) ?? "",
                relativePath: (entry["relativePath"] as? String) ?? "",
                remoteUrl: entry["remoteUrl"] as? String,
                ownerLogin: entry["ownerLogin"] as? String,
                repoName: entry["repoName"] as? String,
                slug: entry["slug"] as? String,
                isGitHub: (entry["isGitHub"] as? Bool) ?? false,
                defaultBranch: entry["defaultBranch"] as? String
            )
        }
        return WorkspaceBridgeState.ScanOutcome(
            rootPath: rootPath,
            totalGitRepos: totalGitRepos,
            gitHubRepos: gitHubRepos,
            durationMs: durationMs,
            directoriesVisited: directoriesVisited,
            repos: repos,
            warnings: warnings
        )
    }
}
