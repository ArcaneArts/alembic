import Cocoa
import FlutterMacOS
import os.log

private extension OSLog {
    static let alembicSettings: OSLog = OSLog(
        subsystem: "art.arcane.alembic.spike",
        category: "settings"
    )
}

struct ApplicationToolItem: Identifiable, Hashable {
    let id: String
    let name: String
    let displayName: String
    let help: String?
}

struct GitToolItem: Identifiable, Hashable {
    let id: String
    let name: String
    let displayName: String
}

struct PlatformInfo: Hashable {
    let isMacOS: Bool
    let isWindows: Bool
    let pathSeparator: String
}

struct RepoConfigDto: Hashable {
    let editorTool: String?
    let gitTool: String?
    let openDirectory: String?
    let lastOpenMs: Int64?
    let accountId: String?
}

final class SettingsBridgeState: ObservableObject {
    @Published var workspaceDirectory: String = ""
    @Published var archiveDirectory: String = ""
    @Published var archiveMasterDirectory: String = ""
    @Published var defaultWorkspaceDirectory: String = ""
    @Published var defaultArchiveDirectory: String = ""
    @Published var defaultArchiveMasterDirectory: String = ""
    @Published var archiveEnabled: Bool = true
    @Published var daysToArchive: Int = 7
    @Published var archiveMasterIntervalMinutes: Int = 60
    @Published var editorTool: String? = nil
    @Published var gitTool: String? = nil
    @Published var autolaunch: Bool = true
    @Published var configPath: String = ""
    @Published var supportedEditorTools: [ApplicationToolItem] = []
    @Published var supportedGitTools: [GitToolItem] = []
    @Published var platform: PlatformInfo = PlatformInfo(isMacOS: true, isWindows: false, pathSeparator: "/")
    @Published var lastUpdateMs: Int64 = 0
}

final class AlembicSettingsBridge: NSObject {
    static let shared: AlembicSettingsBridge = AlembicSettingsBridge()

    let state: SettingsBridgeState = SettingsBridgeState()
    private var channel: FlutterMethodChannel?

    private override init() {
        super.init()
    }

    struct OperationResult {
        let ok: Bool
        let error: String?
    }

    struct RepoConfigResult {
        let ok: Bool
        let fullName: String?
        let config: RepoConfigDto?
        let error: String?
    }

    func attach(messenger: FlutterBinaryMessenger) {
        let channel: FlutterMethodChannel = FlutterMethodChannel(
            name: "alembic.spike.settings",
            binaryMessenger: messenger
        )
        self.channel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
        os_log("AlembicSettingsBridge attached", log: .alembicSettings, type: .info)
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "info",
            tag: "swift.settings",
            message: "Settings bridge attached"
        )
        requestSnapshot()
    }

    func requestSnapshot() {
        channel?.invokeMethod("getAll", arguments: nil) { result in
            DispatchQueue.main.async {
                if let map: [String: Any] = result as? [String: Any] {
                    AlembicSettingsBridge.shared.ingest(map: map)
                }
            }
        }
    }

    func setGeneral(autolaunch: Bool?, completion: @escaping (OperationResult) -> Void) {
        var arguments: [String: Any] = [:]
        if let v: Bool = autolaunch {
            arguments["autolaunch"] = v
        }
        channel?.invokeMethod("setGeneral", arguments: arguments) { result in
            DispatchQueue.main.async {
                completion(AlembicSettingsBridge.parseOperationResult(raw: result))
            }
        }
    }

    func setWorkspace(
        workspaceDirectory: String?,
        archiveDirectory: String?,
        archiveMasterDirectory: String?,
        archiveEnabled: Bool?,
        daysToArchive: Int?,
        completion: @escaping (OperationResult) -> Void
    ) {
        var arguments: [String: Any] = [:]
        if let v: String = workspaceDirectory, !v.isEmpty { arguments["workspaceDirectory"] = v }
        if let v: String = archiveDirectory, !v.isEmpty { arguments["archiveDirectory"] = v }
        if let v: String = archiveMasterDirectory, !v.isEmpty { arguments["archiveMasterDirectory"] = v }
        if let v: Bool = archiveEnabled { arguments["archiveEnabled"] = v }
        if let v: Int = daysToArchive, v > 0 { arguments["daysToArchive"] = v }
        channel?.invokeMethod("setWorkspace", arguments: arguments) { result in
            DispatchQueue.main.async {
                completion(AlembicSettingsBridge.parseOperationResult(raw: result))
            }
        }
    }

    func setTools(editorTool: String?, gitTool: String?, completion: @escaping (OperationResult) -> Void) {
        var arguments: [String: Any] = [:]
        if let v: String = editorTool { arguments["editorTool"] = v }
        if let v: String = gitTool { arguments["gitTool"] = v }
        channel?.invokeMethod("setTools", arguments: arguments) { result in
            DispatchQueue.main.async {
                completion(AlembicSettingsBridge.parseOperationResult(raw: result))
            }
        }
    }

    func setArchiveMaster(intervalMinutes: Int, completion: @escaping (OperationResult) -> Void) {
        let arguments: [String: Any] = ["archiveMasterIntervalMinutes": intervalMinutes]
        channel?.invokeMethod("setArchiveMaster", arguments: arguments) { result in
            DispatchQueue.main.async {
                completion(AlembicSettingsBridge.parseOperationResult(raw: result))
            }
        }
    }

    func getRepoConfig(fullName: String, completion: @escaping (RepoConfigResult) -> Void) {
        channel?.invokeMethod("getRepoConfig", arguments: ["fullName": fullName]) { result in
            DispatchQueue.main.async {
                completion(AlembicSettingsBridge.parseRepoConfigResult(raw: result))
            }
        }
    }

    func setRepoConfig(
        fullName: String,
        editorTool: String?,
        gitTool: String?,
        openDirectory: String?,
        accountId: String?,
        clearEditor: Bool = false,
        clearGit: Bool = false,
        clearAccount: Bool = false,
        completion: @escaping (RepoConfigResult) -> Void
    ) {
        var arguments: [String: Any] = ["fullName": fullName]
        if clearEditor {
            arguments["clearEditor"] = true
        } else if let v: String = editorTool {
            arguments["editorTool"] = v
        }
        if clearGit {
            arguments["clearGit"] = true
        } else if let v: String = gitTool {
            arguments["gitTool"] = v
        }
        if clearAccount {
            arguments["clearAccount"] = true
        } else if let v: String = accountId {
            arguments["accountId"] = v
        }
        if let v: String = openDirectory {
            arguments["openDirectory"] = v
        }
        channel?.invokeMethod("setRepoConfig", arguments: arguments) { result in
            DispatchQueue.main.async {
                completion(AlembicSettingsBridge.parseRepoConfigResult(raw: result))
            }
        }
    }

    func revealDataFolder(completion: @escaping (OperationResult) -> Void) {
        channel?.invokeMethod("revealDataFolder", arguments: nil) { result in
            DispatchQueue.main.async {
                completion(AlembicSettingsBridge.parseOperationResult(raw: result))
            }
        }
    }

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "state":
            let map: [String: Any] = (call.arguments as? [String: Any]) ?? [:]
            ingest(map: map)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func ingest(map: [String: Any]) {
        let workspaceDirectory: String = (map["workspaceDirectory"] as? String) ?? ""
        let archiveDirectory: String = (map["archiveDirectory"] as? String) ?? ""
        let archiveMasterDirectory: String = (map["archiveMasterDirectory"] as? String) ?? ""
        let defaultWorkspaceDirectory: String = (map["defaultWorkspaceDirectory"] as? String) ?? ""
        let defaultArchiveDirectory: String = (map["defaultArchiveDirectory"] as? String) ?? ""
        let defaultArchiveMasterDirectory: String = (map["defaultArchiveMasterDirectory"] as? String) ?? ""
        let archiveEnabled: Bool = (map["archiveEnabled"] as? Bool) ?? true
        let daysToArchive: Int = Int(AlembicSettingsBridge.intValue(from: map["daysToArchive"]))
        let archiveMasterIntervalMinutes: Int = Int(AlembicSettingsBridge.intValue(from: map["archiveMasterIntervalMinutes"]))
        let editorTool: String? = map["editorTool"] as? String
        let gitTool: String? = map["gitTool"] as? String
        let autolaunch: Bool = (map["autolaunch"] as? Bool) ?? true
        let configPath: String = (map["configPath"] as? String) ?? ""

        let rawEditors: [[String: Any]] = (map["supportedEditorTools"] as? [[String: Any]]) ?? []
        let editorTools: [ApplicationToolItem] = rawEditors.compactMap { raw in
            guard let name: String = raw["name"] as? String,
                  let displayName: String = raw["displayName"] as? String else {
                return nil
            }
            let help: String? = raw["help"] as? String
            return ApplicationToolItem(id: name, name: name, displayName: displayName, help: help)
        }

        let rawGit: [[String: Any]] = (map["supportedGitTools"] as? [[String: Any]]) ?? []
        let gitTools: [GitToolItem] = rawGit.compactMap { raw in
            guard let name: String = raw["name"] as? String,
                  let displayName: String = raw["displayName"] as? String else {
                return nil
            }
            return GitToolItem(id: name, name: name, displayName: displayName)
        }

        let platformMap: [String: Any] = (map["platform"] as? [String: Any]) ?? [:]
        let platform: PlatformInfo = PlatformInfo(
            isMacOS: (platformMap["isMacOS"] as? Bool) ?? true,
            isWindows: (platformMap["isWindows"] as? Bool) ?? false,
            pathSeparator: (platformMap["pathSeparator"] as? String) ?? "/"
        )

        let nowMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000)

        AlembicDiagnosticsBridge.shared.recordNative(
            level: "trace",
            tag: "swift.settings",
            message: "ingest workspace=\(workspaceDirectory) editor=\(editorTool ?? "nil") git=\(gitTool ?? "nil") days=\(daysToArchive)"
        )

        DispatchQueue.main.async { [weak self] in
            guard let self: AlembicSettingsBridge = self else { return }
            self.state.workspaceDirectory = workspaceDirectory
            self.state.archiveDirectory = archiveDirectory
            self.state.archiveMasterDirectory = archiveMasterDirectory
            self.state.defaultWorkspaceDirectory = defaultWorkspaceDirectory
            self.state.defaultArchiveDirectory = defaultArchiveDirectory
            self.state.defaultArchiveMasterDirectory = defaultArchiveMasterDirectory
            self.state.archiveEnabled = archiveEnabled
            self.state.daysToArchive = daysToArchive > 0 ? daysToArchive : 7
            self.state.archiveMasterIntervalMinutes = archiveMasterIntervalMinutes > 0 ? archiveMasterIntervalMinutes : 60
            self.state.editorTool = editorTool
            self.state.gitTool = gitTool
            self.state.autolaunch = autolaunch
            self.state.configPath = configPath
            self.state.supportedEditorTools = editorTools
            self.state.supportedGitTools = gitTools
            self.state.platform = platform
            self.state.lastUpdateMs = nowMillis
        }
    }

    private static func parseOperationResult(raw: Any?) -> OperationResult {
        if let flutterError: FlutterError = raw as? FlutterError {
            return OperationResult(ok: false, error: flutterError.message ?? "Operation failed.")
        }
        guard let map: [String: Any] = raw as? [String: Any] else {
            return OperationResult(ok: false, error: "Operation failed: no response from Dart.")
        }
        let ok: Bool = (map["ok"] as? Bool) ?? false
        let error: String? = map["error"] as? String
        return OperationResult(ok: ok, error: error)
    }

    private static func parseRepoConfigResult(raw: Any?) -> RepoConfigResult {
        if let flutterError: FlutterError = raw as? FlutterError {
            return RepoConfigResult(
                ok: false,
                fullName: nil,
                config: nil,
                error: flutterError.message ?? "Operation failed."
            )
        }
        guard let map: [String: Any] = raw as? [String: Any] else {
            return RepoConfigResult(
                ok: false,
                fullName: nil,
                config: nil,
                error: "Operation failed: no response from Dart."
            )
        }
        let ok: Bool = (map["ok"] as? Bool) ?? false
        let fullName: String? = map["fullName"] as? String
        let error: String? = map["error"] as? String
        let configMap: [String: Any]? = map["config"] as? [String: Any]
        let config: RepoConfigDto? = configMap.map { c in
            RepoConfigDto(
                editorTool: c["editorTool"] as? String,
                gitTool: c["gitTool"] as? String,
                openDirectory: c["openDirectory"] as? String,
                lastOpenMs: AlembicSettingsBridge.optionalIntValue(from: c["lastOpenMs"]),
                accountId: c["accountId"] as? String
            )
        }
        return RepoConfigResult(ok: ok, fullName: fullName, config: config, error: error)
    }

    private static func intValue(from raw: Any?) -> Int64 {
        if let v: Int64 = raw as? Int64 { return v }
        if let v: Int = raw as? Int { return Int64(v) }
        if let v: NSNumber = raw as? NSNumber { return v.int64Value }
        return 0
    }

    private static func optionalIntValue(from raw: Any?) -> Int64? {
        if let v: Int64 = raw as? Int64 { return v }
        if let v: Int = raw as? Int { return Int64(v) }
        if let v: NSNumber = raw as? NSNumber { return v.int64Value }
        return nil
    }
}
