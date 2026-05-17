import Cocoa
import FlutterMacOS
import os.log

private extension OSLog {
    static let alembicAccounts: OSLog = OSLog(
        subsystem: "art.arcane.alembic.spike",
        category: "accounts"
    )
}

struct AccountItem: Identifiable, Hashable {
    let id: String
    let name: String
    let login: String?
    let tokenType: String
    let tokenDescription: String
    let createdAtMs: Int64
}

final class AccountsBridgeState: ObservableObject {
    @Published var accounts: [AccountItem] = []
    @Published var primaryAccountId: String? = nil
    @Published var lastUpdateMs: Int64 = 0
    @Published var lastError: String? = nil

    var hasAccounts: Bool { !accounts.isEmpty }
    var primaryAccount: AccountItem? {
        guard let id: String = primaryAccountId else { return nil }
        return accounts.first(where: { $0.id == id })
    }
}

final class AlembicAccountsBridge: NSObject {
    static let shared: AlembicAccountsBridge = AlembicAccountsBridge()

    let state: AccountsBridgeState = AccountsBridgeState()
    private var channel: FlutterMethodChannel?

    private override init() {
        super.init()
    }

    struct AddResult {
        let ok: Bool
        let accountId: String?
        let login: String?
        let error: String?
    }

    struct OperationResult {
        let ok: Bool
        let error: String?
    }

    func attach(messenger: FlutterBinaryMessenger) {
        let channel: FlutterMethodChannel = FlutterMethodChannel(
            name: "alembic.spike.accounts",
            binaryMessenger: messenger
        )
        self.channel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
        os_log("AlembicAccountsBridge attached", log: .alembicAccounts, type: .info)
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "info",
            tag: "swift.accounts",
            message: "Accounts bridge attached"
        )
        requestSnapshot()
    }

    func requestSnapshot() {
        channel?.invokeMethod("getAll", arguments: nil) { result in
            DispatchQueue.main.async {
                if let map: [String: Any] = result as? [String: Any] {
                    AlembicAccountsBridge.shared.ingest(map: map)
                }
            }
        }
    }

    func addAccount(token: String, name: String, completion: @escaping (AddResult) -> Void) {
        let arguments: [String: Any] = [
            "token": token,
            "name": name,
        ]
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "info",
            tag: "swift.accounts",
            message: "Adding account name=\"\(name)\" tokenLen=\(token.count)"
        )
        channel?.invokeMethod("add", arguments: arguments) { result in
            DispatchQueue.main.async {
                completion(AlembicAccountsBridge.parseAddResult(raw: result))
            }
        }
    }

    func removeAccount(accountId: String, completion: @escaping (OperationResult) -> Void) {
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "info",
            tag: "swift.accounts",
            message: "Removing account \(accountId)"
        )
        channel?.invokeMethod("remove", arguments: ["accountId": accountId]) { result in
            DispatchQueue.main.async {
                completion(AlembicAccountsBridge.parseOperationResult(raw: result))
            }
        }
    }

    func renameAccount(accountId: String, name: String, completion: @escaping (OperationResult) -> Void) {
        let arguments: [String: Any] = [
            "accountId": accountId,
            "name": name,
        ]
        channel?.invokeMethod("rename", arguments: arguments) { result in
            DispatchQueue.main.async {
                completion(AlembicAccountsBridge.parseOperationResult(raw: result))
            }
        }
    }

    func setPrimary(accountId: String, completion: @escaping (OperationResult) -> Void) {
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "info",
            tag: "swift.accounts",
            message: "Set primary -> \(accountId)"
        )
        channel?.invokeMethod("setPrimary", arguments: ["accountId": accountId]) { result in
            DispatchQueue.main.async {
                completion(AlembicAccountsBridge.parseOperationResult(raw: result))
            }
        }
    }

    func reorder(accountIds: [String], completion: @escaping (OperationResult) -> Void) {
        channel?.invokeMethod("reorder", arguments: ["order": accountIds]) { result in
            DispatchQueue.main.async {
                completion(AlembicAccountsBridge.parseOperationResult(raw: result))
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
        let rawAccounts: [[String: Any]] = (map["accounts"] as? [[String: Any]]) ?? []
        let primaryAccountId: String? = map["primaryAccountId"] as? String
        let items: [AccountItem] = rawAccounts.compactMap { raw in
            guard let id: String = raw["id"] as? String,
                  let name: String = raw["name"] as? String else {
                return nil
            }
            let login: String? = raw["login"] as? String
            let tokenType: String = (raw["tokenType"] as? String) ?? "Unknown"
            let tokenDescription: String = (raw["tokenDescription"] as? String) ?? tokenType
            let createdAtMs: Int64 = AlembicAccountsBridge.intValue(from: raw["createdAtMs"])
            return AccountItem(
                id: id,
                name: name,
                login: login,
                tokenType: tokenType,
                tokenDescription: tokenDescription,
                createdAtMs: createdAtMs
            )
        }
        let nowMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000)

        AlembicDiagnosticsBridge.shared.recordNative(
            level: "trace",
            tag: "swift.accounts",
            message: "ingest accounts=\(items.count) primary=\(primaryAccountId ?? "nil")"
        )

        DispatchQueue.main.async { [weak self] in
            guard let self: AlembicAccountsBridge = self else { return }
            self.state.accounts = items
            self.state.primaryAccountId = primaryAccountId
            self.state.lastUpdateMs = nowMillis
        }
    }

    private static func parseAddResult(raw: Any?) -> AddResult {
        if let flutterError: FlutterError = raw as? FlutterError {
            return AddResult(
                ok: false,
                accountId: nil,
                login: nil,
                error: flutterError.message ?? "Add account failed."
            )
        }
        guard let map: [String: Any] = raw as? [String: Any] else {
            return AddResult(
                ok: false,
                accountId: nil,
                login: nil,
                error: "Add account failed: no response from Dart."
            )
        }
        let ok: Bool = (map["ok"] as? Bool) ?? false
        let accountId: String? = map["accountId"] as? String
        let login: String? = map["login"] as? String
        let error: String? = map["error"] as? String
        return AddResult(ok: ok, accountId: accountId, login: login, error: error)
    }

    private static func parseOperationResult(raw: Any?) -> OperationResult {
        if let flutterError: FlutterError = raw as? FlutterError {
            return OperationResult(
                ok: false,
                error: flutterError.message ?? "Operation failed."
            )
        }
        guard let map: [String: Any] = raw as? [String: Any] else {
            return OperationResult(
                ok: false,
                error: "Operation failed: no response from Dart."
            )
        }
        let ok: Bool = (map["ok"] as? Bool) ?? false
        let error: String? = map["error"] as? String
        return OperationResult(ok: ok, error: error)
    }

    private static func intValue(from raw: Any?) -> Int64 {
        if let v: Int64 = raw as? Int64 { return v }
        if let v: Int = raw as? Int { return Int64(v) }
        if let v: NSNumber = raw as? NSNumber { return v.int64Value }
        return 0
    }
}
