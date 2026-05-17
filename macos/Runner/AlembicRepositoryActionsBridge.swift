import Cocoa
import FlutterMacOS
import os.log

private extension OSLog {
    static let alembicRepoActions: OSLog = OSLog(
        subsystem: "art.arcane.alembic.spike",
        category: "repository_actions"
    )
}

final class AlembicRepositoryActionsBridge: NSObject {
    static let shared: AlembicRepositoryActionsBridge = AlembicRepositoryActionsBridge()

    private var channel: FlutterMethodChannel?

    private override init() {
        super.init()
    }

    func attach(messenger: FlutterBinaryMessenger) {
        let channel: FlutterMethodChannel = FlutterMethodChannel(
            name: "alembic.spike.repositories.actions",
            binaryMessenger: messenger
        )
        self.channel = channel
        os_log("AlembicRepositoryActionsBridge attached", log: .alembicRepoActions, type: .info)
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "info",
            tag: "swift.actions",
            message: "Repository actions bridge attached"
        )
    }

    struct ActionResult {
        let ok: Bool
        let state: String?
        let fullName: String?
        let error: String?
    }

    struct RepositoryDetail {
        let ok: Bool
        let fullName: String
        let repoPath: String
        let archivePath: String
        let archiveMasterPath: String
        let state: String
        let daysUntilArchival: Int
        let lastOpenMs: Int64?
        let latestFileModificationMs: Int64?
        let accountId: String?
        let accountLogin: String?
        let archiveMasterFullName: String?
        let archiveMasterLastCheckedMs: Int64?
        let archiveMasterLastPulledMs: Int64?
        let archiveMasterLastCommitHash: String?
        let archiveMasterLastErrorMessage: String?
        let error: String?
    }

    func clone(fullName: String, accountId: String? = nil, completion: @escaping (ActionResult) -> Void) {
        invoke(method: "clone", fullName: fullName, accountId: accountId, completion: completion)
    }

    func pull(fullName: String, accountId: String? = nil, completion: @escaping (ActionResult) -> Void) {
        invoke(method: "pull", fullName: fullName, accountId: accountId, completion: completion)
    }

    func open(fullName: String, accountId: String? = nil, completion: @escaping (ActionResult) -> Void) {
        invoke(method: "open", fullName: fullName, accountId: accountId, completion: completion)
    }

    func openInFinder(fullName: String, completion: @escaping (ActionResult) -> Void) {
        invoke(method: "openInFinder", fullName: fullName, accountId: nil, completion: completion)
    }

    func archive(fullName: String, completion: @escaping (ActionResult) -> Void) {
        invoke(method: "archive", fullName: fullName, accountId: nil, completion: completion)
    }

    func unarchive(fullName: String, accountId: String? = nil, completion: @escaping (ActionResult) -> Void) {
        invoke(method: "unarchive", fullName: fullName, accountId: accountId, completion: completion)
    }

    func updateArchive(fullName: String, accountId: String? = nil, completion: @escaping (ActionResult) -> Void) {
        invoke(method: "updateArchive", fullName: fullName, accountId: accountId, completion: completion)
    }

    func archiveFromCloud(fullName: String, accountId: String? = nil, completion: @escaping (ActionResult) -> Void) {
        invoke(method: "archiveFromCloud", fullName: fullName, accountId: accountId, completion: completion)
    }

    func delete(fullName: String, completion: @escaping (ActionResult) -> Void) {
        invoke(method: "delete", fullName: fullName, accountId: nil, completion: completion)
    }

    func deleteArchive(fullName: String, completion: @escaping (ActionResult) -> Void) {
        invoke(method: "deleteArchive", fullName: fullName, accountId: nil, completion: completion)
    }

    func fork(fullName: String, accountId: String? = nil, completion: @escaping (ActionResult) -> Void) {
        invoke(method: "fork", fullName: fullName, accountId: accountId, completion: completion)
    }

    func enrollArchiveMaster(fullName: String, accountId: String? = nil, completion: @escaping (ActionResult) -> Void) {
        invoke(method: "enrollArchiveMaster", fullName: fullName, accountId: accountId, completion: completion)
    }

    func unenrollArchiveMaster(fullName: String, completion: @escaping (ActionResult) -> Void) {
        invoke(method: "unenrollArchiveMaster", fullName: fullName, accountId: nil, completion: completion)
    }

    func refreshArchiveMaster(fullName: String, accountId: String? = nil, completion: @escaping (ActionResult) -> Void) {
        invoke(method: "refreshArchiveMaster", fullName: fullName, accountId: accountId, completion: completion)
    }

    func promoteArchiveMaster(fullName: String, accountId: String? = nil, completion: @escaping (ActionResult) -> Void) {
        invoke(method: "promoteArchiveMaster", fullName: fullName, accountId: accountId, completion: completion)
    }

    func getDetail(fullName: String, completion: @escaping (RepositoryDetail) -> Void) {
        let arguments: [String: Any] = ["fullName": fullName]
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "trace",
            tag: "swift.actions",
            message: "getDetail -> \(fullName)"
        )
        channel?.invokeMethod("getDetail", arguments: arguments) { result in
            DispatchQueue.main.async {
                completion(AlembicRepositoryActionsBridge.parseDetail(raw: result, fullName: fullName))
            }
        }
    }

    private func invoke(
        method: String,
        fullName: String,
        accountId: String?,
        completion: @escaping (ActionResult) -> Void
    ) {
        var arguments: [String: Any] = ["fullName": fullName]
        if let accountId: String = accountId, !accountId.isEmpty {
            arguments["accountId"] = accountId
        }
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "info",
            tag: "swift.actions",
            message: "\(method) -> \(fullName)"
        )
        channel?.invokeMethod(method, arguments: arguments) { result in
            DispatchQueue.main.async {
                completion(AlembicRepositoryActionsBridge.parseResult(raw: result))
            }
        }
    }

    private static func parseResult(raw: Any?) -> ActionResult {
        if let flutterError: FlutterError = raw as? FlutterError {
            return ActionResult(
                ok: false,
                state: nil,
                fullName: nil,
                error: flutterError.message ?? "Action failed."
            )
        }
        guard let map: [String: Any] = raw as? [String: Any] else {
            return ActionResult(
                ok: false,
                state: nil,
                fullName: nil,
                error: "Action failed: no response from Dart."
            )
        }
        let ok: Bool = (map["ok"] as? Bool) ?? false
        let state: String? = map["state"] as? String
        let fullName: String? = map["fullName"] as? String
        let error: String? = map["error"] as? String
        return ActionResult(ok: ok, state: state, fullName: fullName, error: error)
    }

    private static func parseDetail(raw: Any?, fullName: String) -> RepositoryDetail {
        if let flutterError: FlutterError = raw as? FlutterError {
            return RepositoryDetail(
                ok: false,
                fullName: fullName,
                repoPath: "",
                archivePath: "",
                archiveMasterPath: "",
                state: "cloud",
                daysUntilArchival: 0,
                lastOpenMs: nil,
                latestFileModificationMs: nil,
                accountId: nil,
                accountLogin: nil,
                archiveMasterFullName: nil,
                archiveMasterLastCheckedMs: nil,
                archiveMasterLastPulledMs: nil,
                archiveMasterLastCommitHash: nil,
                archiveMasterLastErrorMessage: nil,
                error: flutterError.message ?? "Failed to load repository detail."
            )
        }
        guard let map: [String: Any] = raw as? [String: Any] else {
            return RepositoryDetail(
                ok: false,
                fullName: fullName,
                repoPath: "",
                archivePath: "",
                archiveMasterPath: "",
                state: "cloud",
                daysUntilArchival: 0,
                lastOpenMs: nil,
                latestFileModificationMs: nil,
                accountId: nil,
                accountLogin: nil,
                archiveMasterFullName: nil,
                archiveMasterLastCheckedMs: nil,
                archiveMasterLastPulledMs: nil,
                archiveMasterLastCommitHash: nil,
                archiveMasterLastErrorMessage: nil,
                error: "Failed to load repository detail: no response from Dart."
            )
        }
        let ok: Bool = (map["ok"] as? Bool) ?? false
        let archiveMaster: [String: Any]? = map["archiveMaster"] as? [String: Any]
        return RepositoryDetail(
            ok: ok,
            fullName: (map["fullName"] as? String) ?? fullName,
            repoPath: (map["repoPath"] as? String) ?? "",
            archivePath: (map["archivePath"] as? String) ?? "",
            archiveMasterPath: (map["archiveMasterPath"] as? String) ?? "",
            state: (map["state"] as? String) ?? "cloud",
            daysUntilArchival: Int(AlembicRepositoryActionsBridge.intValue(from: map["daysUntilArchival"])),
            lastOpenMs: AlembicRepositoryActionsBridge.optionalIntValue(from: map["lastOpenMs"]),
            latestFileModificationMs: AlembicRepositoryActionsBridge.optionalIntValue(from: map["latestFileModificationMs"]),
            accountId: map["accountId"] as? String,
            accountLogin: map["accountLogin"] as? String,
            archiveMasterFullName: archiveMaster?["fullName"] as? String,
            archiveMasterLastCheckedMs: AlembicRepositoryActionsBridge.optionalIntValue(from: archiveMaster?["lastCheckedMs"]),
            archiveMasterLastPulledMs: AlembicRepositoryActionsBridge.optionalIntValue(from: archiveMaster?["lastPulledMs"]),
            archiveMasterLastCommitHash: archiveMaster?["lastCommitHash"] as? String,
            archiveMasterLastErrorMessage: archiveMaster?["lastErrorMessage"] as? String,
            error: map["error"] as? String
        )
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
