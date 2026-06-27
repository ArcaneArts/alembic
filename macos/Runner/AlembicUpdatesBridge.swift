import Cocoa
import FlutterMacOS
import SwiftUI
import os.log

private extension OSLog {
    static let alembicUpdates: OSLog = OSLog(
        subsystem: "art.arcane.alembic.spike",
        category: "updates"
    )
}

/// Shared styling for the non-intrusive "update available" indicator.
enum AlembicUpdateStyle {
    /// Warm amber used for the update dot. The theme has no warning token, so
    /// this is defined once and reused on the gear badge and the settings row.
    static let dot: Color = Color(red: 0.96, green: 0.77, blue: 0.13)
    static let dotSize: CGFloat = 7
}

/// The amber "update available" dot, reused on the gear badge, the settings
/// sidebar row, and the Updates pane status line.
struct AlembicUpdateDot: View {
    var size: CGFloat = AlembicUpdateStyle.dotSize
    var bordered: Bool = false

    var body: some View {
        Circle()
            .fill(AlembicUpdateStyle.dot)
            .frame(width: size, height: size)
            .overlay {
                if bordered {
                    Circle().strokeBorder(Color.black.opacity(0.18), lineWidth: 0.5)
                }
            }
    }
}

/// Mirrors the Dart `UpdateSnapshot` pushed over `alembic.spike.updates`.
final class UpdatesBridgeState: ObservableObject {
    @Published var status: String = "idle"
    @Published var updateAvailable: Bool = false
    @Published var autoCheckEnabled: Bool = true
    @Published var currentVersion: String = ""
    @Published var latestVersion: String? = nil
    @Published var lastCheckedMs: Int64 = 0
    @Published var downloadProgress: Double = 0
    @Published var errorMessage: String? = nil
    @Published var releaseUrl: String = ""

    var isChecking: Bool { status == "checking" }
    var isDownloading: Bool { status == "downloading" }
    var isBusy: Bool { isChecking || isDownloading }
}

/// Native counterpart of `UpdateChannelBridge`. Surfaces update state to the
/// SwiftUI layer and forwards user actions (check / install / toggle) to Dart.
final class AlembicUpdatesBridge: NSObject {
    static let shared: AlembicUpdatesBridge = AlembicUpdatesBridge()

    let state: UpdatesBridgeState = UpdatesBridgeState()
    private var channel: FlutterMethodChannel?

    private override init() {
        super.init()
    }

    struct OperationResult {
        let ok: Bool
        let error: String?
    }

    func attach(messenger: FlutterBinaryMessenger) {
        let channel: FlutterMethodChannel = FlutterMethodChannel(
            name: "alembic.spike.updates",
            binaryMessenger: messenger
        )
        self.channel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
        os_log("AlembicUpdatesBridge attached", log: .alembicUpdates, type: .info)
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "info",
            tag: "swift.updates",
            message: "Updates bridge attached"
        )
        requestSnapshot()
    }

    func requestSnapshot() {
        channel?.invokeMethod("getState", arguments: nil) { result in
            DispatchQueue.main.async {
                if let map: [String: Any] = result as? [String: Any] {
                    AlembicUpdatesBridge.shared.ingest(map: map)
                }
            }
        }
    }

    func setAutoCheck(_ enabled: Bool, completion: @escaping (OperationResult) -> Void) {
        channel?.invokeMethod("setAutoCheck", arguments: ["enabled": enabled]) { result in
            DispatchQueue.main.async {
                completion(AlembicUpdatesBridge.parseOperationResult(raw: result))
            }
        }
    }

    func checkNow(completion: @escaping (OperationResult) -> Void) {
        channel?.invokeMethod("checkNow", arguments: nil) { result in
            DispatchQueue.main.async {
                completion(AlembicUpdatesBridge.parseOperationResult(raw: result))
            }
        }
    }

    /// Asks Dart to download + verify + launch the update helper. On success the
    /// app must terminate so the detached helper can swap the bundle.
    func install(completion: @escaping (OperationResult) -> Void) {
        channel?.invokeMethod("install", arguments: nil) { result in
            DispatchQueue.main.async {
                completion(AlembicUpdatesBridge.parseOperationResult(raw: result))
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
        let status: String = (map["status"] as? String) ?? "idle"
        let updateAvailable: Bool = (map["updateAvailable"] as? Bool) ?? false
        let autoCheckEnabled: Bool = (map["autoCheckEnabled"] as? Bool) ?? true
        let currentVersion: String = (map["currentVersion"] as? String) ?? ""
        let latestVersion: String? = map["latestVersion"] as? String
        let lastCheckedMs: Int64 = AlembicUpdatesBridge.intValue(from: map["lastCheckedMs"])
        let downloadProgress: Double = AlembicUpdatesBridge.doubleValue(from: map["downloadProgress"])
        let errorMessage: String? = map["errorMessage"] as? String
        let releaseUrl: String = (map["releaseUrl"] as? String) ?? ""

        AlembicDiagnosticsBridge.shared.recordNative(
            level: "trace",
            tag: "swift.updates",
            message: "ingest status=\(status) available=\(updateAvailable) latest=\(latestVersion ?? "nil")"
        )

        DispatchQueue.main.async { [weak self] in
            guard let self: AlembicUpdatesBridge = self else { return }
            self.state.status = status
            self.state.updateAvailable = updateAvailable
            self.state.autoCheckEnabled = autoCheckEnabled
            self.state.currentVersion = currentVersion
            self.state.latestVersion = latestVersion
            self.state.lastCheckedMs = lastCheckedMs
            self.state.downloadProgress = downloadProgress
            self.state.errorMessage = errorMessage
            self.state.releaseUrl = releaseUrl
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

    private static func intValue(from raw: Any?) -> Int64 {
        if let v: Int64 = raw as? Int64 { return v }
        if let v: Int = raw as? Int { return Int64(v) }
        if let v: NSNumber = raw as? NSNumber { return v.int64Value }
        return 0
    }

    private static func doubleValue(from raw: Any?) -> Double {
        if let v: Double = raw as? Double { return v }
        if let v: NSNumber = raw as? NSNumber { return v.doubleValue }
        return 0
    }
}
