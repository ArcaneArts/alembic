import Cocoa
import FlutterMacOS
import os.log

private extension OSLog {
    static let alembicRepoWork: OSLog = OSLog(
        subsystem: "art.arcane.alembic.spike",
        category: "repository_work"
    )
}

struct RepositoryWorkEntry: Identifiable, Hashable {
    let id: String
    let fullName: String
    let kind: String
    let message: String
    let progress: Double?
}

struct ArchiveMasterRepoStateDto: Hashable {
    let fullName: String
    let lastCheckedMs: Int64?
    let lastPulledMs: Int64?
    let lastCommitHash: String?
    let lastErrorMessage: String?
}

final class RepositoryWorkBridgeState: ObservableObject {
    @Published var activeRepositories: Set<String> = []
    @Published var archivedRepositories: Set<String> = []
    @Published var syncingRepositories: Set<String> = []
    @Published var workEntries: [RepositoryWorkEntry] = []
    @Published var archiveMasterStates: [String: ArchiveMasterRepoStateDto] = [:]
    @Published var lastUpdateMs: Int64 = 0

    func isActive(_ fullName: String) -> Bool {
        return activeRepositories.contains(fullName.lowercased())
    }

    func isArchived(_ fullName: String) -> Bool {
        return archivedRepositories.contains(fullName.lowercased())
    }

    func isSyncing(_ fullName: String) -> Bool {
        return syncingRepositories.contains(fullName.lowercased())
    }

    func workForRepo(_ fullName: String) -> [RepositoryWorkEntry] {
        let key: String = fullName.lowercased()
        return workEntries.filter { $0.fullName.lowercased() == key }
    }

    func archiveMasterState(for fullName: String) -> ArchiveMasterRepoStateDto? {
        return archiveMasterStates[fullName.lowercased()]
    }
}

final class AlembicRepositoryWorkBridge: NSObject {
    static let shared: AlembicRepositoryWorkBridge = AlembicRepositoryWorkBridge()

    let state: RepositoryWorkBridgeState = RepositoryWorkBridgeState()
    private var channel: FlutterMethodChannel?

    private override init() {
        super.init()
    }

    func attach(messenger: FlutterBinaryMessenger) {
        let channel: FlutterMethodChannel = FlutterMethodChannel(
            name: "alembic.spike.repositories.work",
            binaryMessenger: messenger
        )
        self.channel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
        os_log("AlembicRepositoryWorkBridge attached", log: .alembicRepoWork, type: .info)
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "info",
            tag: "swift.work",
            message: "Repository work bridge attached"
        )
        requestSnapshot()
    }

    func requestSnapshot() {
        channel?.invokeMethod("getSnapshot", arguments: nil) { result in
            DispatchQueue.main.async {
                if let map: [String: Any] = result as? [String: Any] {
                    AlembicRepositoryWorkBridge.shared.ingest(map: map)
                }
            }
        }
    }

    func rescan() {
        channel?.invokeMethod("rescan", arguments: nil) { result in
            DispatchQueue.main.async {
                if let map: [String: Any] = result as? [String: Any] {
                    AlembicRepositoryWorkBridge.shared.ingest(map: map)
                }
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
        let active: [String] = (map["activeRepositories"] as? [String]) ?? []
        let archived: [String] = (map["archivedRepositories"] as? [String]) ?? []
        let syncing: [String] = (map["syncingRepositories"] as? [String]) ?? []
        let workEntriesRaw: [[String: Any]] = (map["workEntries"] as? [[String: Any]]) ?? []
        let masterStatesRaw: [[String: Any]] = (map["archiveMasterStates"] as? [[String: Any]]) ?? []

        let workEntries: [RepositoryWorkEntry] = workEntriesRaw.compactMap { raw in
            guard let fullName: String = raw["fullName"] as? String else { return nil }
            let kind: String = (raw["kind"] as? String) ?? "generic"
            let message: String = (raw["message"] as? String) ?? ""
            let progress: Double? = raw["progress"] as? Double
            let id: String = "\(fullName.lowercased())|\(kind)|\(message)"
            return RepositoryWorkEntry(
                id: id,
                fullName: fullName,
                kind: kind,
                message: message,
                progress: progress
            )
        }

        var masterStates: [String: ArchiveMasterRepoStateDto] = [:]
        for raw in masterStatesRaw {
            guard let fullName: String = raw["fullName"] as? String else { continue }
            let state: ArchiveMasterRepoStateDto = ArchiveMasterRepoStateDto(
                fullName: fullName,
                lastCheckedMs: AlembicRepositoryWorkBridge.optionalIntValue(from: raw["lastCheckedMs"]),
                lastPulledMs: AlembicRepositoryWorkBridge.optionalIntValue(from: raw["lastPulledMs"]),
                lastCommitHash: raw["lastCommitHash"] as? String,
                lastErrorMessage: raw["lastErrorMessage"] as? String
            )
            masterStates[fullName.lowercased()] = state
        }

        let nowMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000)

        AlembicDiagnosticsBridge.shared.recordNative(
            level: "trace",
            tag: "swift.work",
            message: "ingest active=\(active.count) archived=\(archived.count) syncing=\(syncing.count) work=\(workEntries.count) masters=\(masterStates.count)"
        )

        DispatchQueue.main.async { [weak self] in
            guard let self: AlembicRepositoryWorkBridge = self else { return }
            self.state.activeRepositories = Set(active.map { $0.lowercased() })
            self.state.archivedRepositories = Set(archived.map { $0.lowercased() })
            self.state.syncingRepositories = Set(syncing.map { $0.lowercased() })
            self.state.workEntries = workEntries
            self.state.archiveMasterStates = masterStates
            self.state.lastUpdateMs = nowMillis
        }
    }

    private static func optionalIntValue(from raw: Any?) -> Int64? {
        if let v: Int64 = raw as? Int64 { return v }
        if let v: Int = raw as? Int { return Int64(v) }
        if let v: NSNumber = raw as? NSNumber { return v.int64Value }
        return nil
    }
}
