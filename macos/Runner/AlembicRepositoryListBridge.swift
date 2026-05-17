import Cocoa
import FlutterMacOS
import SwiftUI
import os.log

private extension OSLog {
    static let alembicRepoBridge: OSLog = OSLog(
        subsystem: "art.arcane.alembic.spike",
        category: "repositories"
    )
}

struct RepositoryItem: Identifiable, Hashable {
    let id: String
    let fullName: String
    let owner: String
    let name: String
    let description: String
    let defaultBranch: String
    let isPrivate: Bool
    let isFork: Bool
    let isArchived: Bool
    let htmlUrl: String
    let starCount: Int
    let forkCount: Int
    let language: String?
    let updatedAtMillis: Int64
}

final class RepositoryListBridgeState: ObservableObject {
    @Published var status: String = "idle"
    @Published var phase: String = "awaiting_first_refresh"
    @Published var accountLogin: String = ""
    @Published var repositories: [RepositoryItem] = []
    @Published var errorMessage: String = ""
    @Published var errorCode: String = ""
    @Published var lastRefreshMillis: Int64 = 0
    @Published var fetchedCount: Int = 0
    @Published var attempt: Int = 0
    @Published var requestStartedMillis: Int64 = 0
    @Published var requestDurationMillis: Int64 = 0
    @Published var ingestionCount: Int = 0
    @Published var lastIngestionMillis: Int64 = 0
    @Published var pageNumber: Int = 0
    @Published var pagesCompleted: Int = 0
    @Published var lastHttpStatus: Int = 0
    @Published var lastResponseBytes: Int = 0
    @Published var lastResponseDurationMillis: Int = 0
    @Published var rateLimitRemaining: Int = -1
    @Published var rateLimitLimit: Int = -1
    @Published var rateLimitResetMillis: Int64 = 0
    @Published var endpoint: String = ""
    @Published var diagnosticTail: String = ""

    var isLoading: Bool { status == "loading" }
    var isReady: Bool { status == "ready" }
    var hasError: Bool { status == "error" && !errorMessage.isEmpty }
    var hasNoAccount: Bool { status == "noAccount" }
    var isEmpty: Bool { status == "empty" }
}

final class AlembicRepositoryListBridge: NSObject {
    static let shared: AlembicRepositoryListBridge = AlembicRepositoryListBridge()

    let state: RepositoryListBridgeState = RepositoryListBridgeState()
    private var channel: FlutterMethodChannel?

    private override init() {
        super.init()
    }

    func attach(messenger: FlutterBinaryMessenger) {
        let channel: FlutterMethodChannel = FlutterMethodChannel(
            name: "alembic.spike.repositories",
            binaryMessenger: messenger
        )
        self.channel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
        os_log("AlembicRepositoryListBridge attached", log: .alembicRepoBridge, type: .info)
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "info",
            tag: "swift.repo",
            message: "Repository list bridge attached"
        )
    }

    func refresh() {
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "info",
            tag: "swift.repo",
            message: "User requested refresh"
        )
        channel?.invokeMethod("refresh", arguments: nil)
    }

    func retry() {
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "info",
            tag: "swift.repo",
            message: "User requested retry"
        )
        channel?.invokeMethod("retry", arguments: nil)
    }

    func openInBrowser(_ url: String) {
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "info",
            tag: "swift.repo",
            message: "User requested open in browser: \(url)"
        )
        channel?.invokeMethod("openInBrowser", arguments: ["url": url])
    }

    func signInWithToken(
        token: String,
        name: String,
        completion: @escaping (SignInResult) -> Void
    ) {
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "info",
            tag: "swift.repo",
            message: "Submitting token (length=\(token.count), name=\"\(name)\")"
        )
        let arguments: [String: Any] = [
            "token": token,
            "name": name,
        ]
        channel?.invokeMethod("signInWithToken", arguments: arguments) { result in
            DispatchQueue.main.async {
                completion(AlembicRepositoryListBridge.parseSignInResult(raw: result))
            }
        }
    }

    func signOut(
        accountId: String,
        completion: @escaping (Bool) -> Void
    ) {
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "info",
            tag: "swift.repo",
            message: "Sign out requested for account \(accountId)"
        )
        let arguments: [String: Any] = ["accountId": accountId]
        channel?.invokeMethod("signOut", arguments: arguments) { result in
            DispatchQueue.main.async {
                let map: [String: Any]? = result as? [String: Any]
                let ok: Bool = (map?["ok"] as? Bool) ?? false
                completion(ok)
            }
        }
    }

    struct SignInResult {
        let ok: Bool
        let login: String?
        let accountId: String?
        let errorMessage: String?
    }

    private static func parseSignInResult(raw: Any?) -> SignInResult {
        if let flutterError: FlutterError = raw as? FlutterError {
            return SignInResult(
                ok: false,
                login: nil,
                accountId: nil,
                errorMessage: flutterError.message ?? "Sign-in failed."
            )
        }
        guard let map: [String: Any] = raw as? [String: Any] else {
            return SignInResult(
                ok: false,
                login: nil,
                accountId: nil,
                errorMessage: "Sign-in failed: no response from Dart."
            )
        }
        let ok: Bool = (map["ok"] as? Bool) ?? false
        let login: String? = map["login"] as? String
        let accountId: String? = map["accountId"] as? String
        let errorMessage: String? = map["error"] as? String
        return SignInResult(
            ok: ok,
            login: login,
            accountId: accountId,
            errorMessage: errorMessage
        )
    }

    private func handle(
        call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        switch call.method {
        case "state":
            let map: [String: Any] = (call.arguments as? [String: Any]) ?? [:]
            ingestState(map: map)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func ingestState(map: [String: Any]) {
        let status: String = (map["status"] as? String) ?? "idle"
        let phase: String = (map["phase"] as? String) ?? "unknown"
        let accountLogin: String = (map["accountLogin"] as? String) ?? ""
        let errorMessage: String = (map["errorMessage"] as? String) ?? ""
        let errorCode: String = (map["errorCode"] as? String) ?? ""
        let lastRefresh: Int64 = AlembicRepositoryListBridge.intValue(from: map["lastRefreshMillis"])
        let fetched: Int = Int(AlembicRepositoryListBridge.intValue(from: map["fetchedCount"]))
        let attempt: Int = Int(AlembicRepositoryListBridge.intValue(from: map["attempt"]))
        let requestStarted: Int64 = AlembicRepositoryListBridge.intValue(from: map["requestStartedMillis"])
        let requestDuration: Int64 = AlembicRepositoryListBridge.intValue(from: map["requestDurationMillis"])
        let pageNumber: Int = Int(AlembicRepositoryListBridge.intValue(from: map["pageNumber"]))
        let pagesCompleted: Int = Int(AlembicRepositoryListBridge.intValue(from: map["pagesCompleted"]))
        let lastHttpStatus: Int = Int(AlembicRepositoryListBridge.intValue(from: map["lastHttpStatus"]))
        let lastResponseBytes: Int = Int(AlembicRepositoryListBridge.intValue(from: map["lastResponseBytes"]))
        let lastResponseDurationMillis: Int = Int(AlembicRepositoryListBridge.intValue(from: map["lastResponseDurationMillis"]))
        let rateLimitRemaining: Int = Int(AlembicRepositoryListBridge.intValue(from: map["rateLimitRemaining"]))
        let rateLimitLimit: Int = Int(AlembicRepositoryListBridge.intValue(from: map["rateLimitLimit"]))
        let rateLimitResetMillis: Int64 = AlembicRepositoryListBridge.intValue(from: map["rateLimitResetMillis"])
        let endpoint: String = (map["endpoint"] as? String) ?? ""
        let diagnosticTail: String = (map["diagnosticTail"] as? String) ?? ""
        let rawRepos: [[String: Any]] = (map["repositories"] as? [[String: Any]]) ?? []
        let items: [RepositoryItem] = rawRepos.compactMap(AlembicRepositoryListBridge.toItem)
        let nowMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000)

        AlembicDiagnosticsBridge.shared.recordNative(
            level: status == "error" ? "error" : "trace",
            tag: "swift.repo.state",
            message: "ingest status=\(status) phase=\(phase) page=\(pageNumber)/\(pagesCompleted) fetched=\(fetched) http=\(lastHttpStatus) bytes=\(lastResponseBytes) pageMs=\(lastResponseDurationMillis) ratelimit=\(rateLimitRemaining)/\(rateLimitLimit) attempt=\(attempt) duration=\(requestDuration)ms repos=\(items.count) tail=\"\(diagnosticTail)\""
        )
        DispatchQueue.main.async { [weak self] in
            guard let self: AlembicRepositoryListBridge = self else { return }
            self.state.status = status
            self.state.phase = phase
            self.state.accountLogin = accountLogin
            self.state.errorMessage = errorMessage
            self.state.errorCode = errorCode
            self.state.lastRefreshMillis = lastRefresh
            self.state.repositories = items
            self.state.fetchedCount = fetched
            self.state.attempt = attempt
            self.state.requestStartedMillis = requestStarted
            self.state.requestDurationMillis = requestDuration
            self.state.pageNumber = pageNumber
            self.state.pagesCompleted = pagesCompleted
            self.state.lastHttpStatus = lastHttpStatus
            self.state.lastResponseBytes = lastResponseBytes
            self.state.lastResponseDurationMillis = lastResponseDurationMillis
            self.state.rateLimitRemaining = rateLimitRemaining
            self.state.rateLimitLimit = rateLimitLimit
            self.state.rateLimitResetMillis = rateLimitResetMillis
            self.state.endpoint = endpoint
            self.state.diagnosticTail = diagnosticTail
            self.state.ingestionCount += 1
            self.state.lastIngestionMillis = nowMillis
        }
    }

    private static func toItem(map: [String: Any]) -> RepositoryItem? {
        guard let fullName: String = map["fullName"] as? String else { return nil }
        let owner: String = (map["owner"] as? String) ?? ""
        let name: String = (map["name"] as? String) ?? ""
        let description: String = (map["description"] as? String) ?? ""
        let defaultBranch: String = (map["defaultBranch"] as? String) ?? "main"
        let isPrivate: Bool = (map["isPrivate"] as? Bool) ?? false
        let isFork: Bool = (map["isFork"] as? Bool) ?? false
        let isArchived: Bool = (map["isArchived"] as? Bool) ?? false
        let htmlUrl: String = (map["htmlUrl"] as? String) ?? ""
        let starCount: Int = (map["starCount"] as? Int) ?? 0
        let forkCount: Int = (map["forkCount"] as? Int) ?? 0
        let language: String? = map["language"] as? String
        let updatedAtMillis: Int64 = AlembicRepositoryListBridge.intValue(from: map["updatedAtMillis"])
        return RepositoryItem(
            id: fullName.lowercased(),
            fullName: fullName,
            owner: owner,
            name: name,
            description: description,
            defaultBranch: defaultBranch,
            isPrivate: isPrivate,
            isFork: isFork,
            isArchived: isArchived,
            htmlUrl: htmlUrl,
            starCount: starCount,
            forkCount: forkCount,
            language: (language?.isEmpty == false) ? language : nil,
            updatedAtMillis: updatedAtMillis
        )
    }

    private static func intValue(from raw: Any?) -> Int64 {
        if let v: Int64 = raw as? Int64 { return v }
        if let v: Int = raw as? Int { return Int64(v) }
        if let v: NSNumber = raw as? NSNumber { return v.int64Value }
        return 0
    }
}
