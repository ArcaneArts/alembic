import Cocoa
import FlutterMacOS
import SwiftUI
import os.log

private extension OSLog {
    static let alembicSpike: OSLog = OSLog(
        subsystem: "art.arcane.alembic.spike",
        category: "bridge"
    )
}

final class SpikeAppState: ObservableObject {
    @Published var heartbeat: Int = 0
    @Published var lastEpoch: Int64 = 0
    @Published var status: String = "starting"
    @Published var ready: Bool = false
    @Published var pid: String = ""
    @Published var dartVersion: String = ""
    @Published var lastEchoResult: String = ""
    @Published var lastEchoError: String = ""
    @Published var configPath: String = ""
    @Published var migrationAttempted: Bool = false
    @Published var migrationSourcePath: String? = nil
    @Published var migrationCopiedFiles: [String] = []
    @Published var migrationSkippedFiles: [String] = []
    @Published var migrationSearchedPaths: [String] = []
    @Published var hiveEntries: Int = 0
    @Published var accountCount: Int = 0
    @Published var primaryAccountLogin: String? = nil
    @Published var trayScreenName: String = ""
    @Published var trayScreenIsMain: Bool = true
    @Published var mainScreenName: String = ""
    @Published var allScreenNames: [String] = []

    func updateTrayLocation(
        trayScreenName: String,
        trayScreenIsMain: Bool,
        mainScreenName: String,
        allScreenNames: [String]
    ) {
        self.trayScreenName = trayScreenName
        self.trayScreenIsMain = trayScreenIsMain
        self.mainScreenName = mainScreenName
        self.allScreenNames = allScreenNames
    }

    func ingestState(
        tick: Int,
        status: String,
        epochMillis: Int64,
        dartVersion: String,
        pid: String,
        configPath: String,
        migrationAttempted: Bool,
        migrationSourcePath: String?,
        migrationCopiedFiles: [String],
        migrationSkippedFiles: [String],
        migrationSearchedPaths: [String],
        hiveEntries: Int,
        accountCount: Int,
        primaryAccountLogin: String?
    ) {
        self.heartbeat = tick
        self.status = status
        self.lastEpoch = epochMillis
        self.dartVersion = dartVersion
        self.pid = pid
        self.ready = status == "ready"
        self.configPath = configPath
        self.migrationAttempted = migrationAttempted
        self.migrationSourcePath = migrationSourcePath
        self.migrationCopiedFiles = migrationCopiedFiles
        self.migrationSkippedFiles = migrationSkippedFiles
        self.migrationSearchedPaths = migrationSearchedPaths
        self.hiveEntries = hiveEntries
        self.accountCount = accountCount
        self.primaryAccountLogin = primaryAccountLogin
    }

    func ingestEcho(value: String) {
        self.lastEchoResult = value
        self.lastEchoError = ""
    }

    func ingestEchoFailure(reason: String) {
        self.lastEchoResult = ""
        self.lastEchoError = reason
    }
}

final class AlembicSpikeBridge: NSObject {
    static let shared: AlembicSpikeBridge = AlembicSpikeBridge()

    let state: SpikeAppState = SpikeAppState()
    private var channel: FlutterMethodChannel?

    private override init() {
        super.init()
    }

    func attach(messenger: FlutterBinaryMessenger) {
        let channel: FlutterMethodChannel = FlutterMethodChannel(
            name: "alembic.spike",
            binaryMessenger: messenger
        )
        self.channel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
        os_log("AlembicSpikeBridge attached", log: .alembicSpike, type: .info)
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "info",
            tag: "swift.app",
            message: "App bridge attached on alembic.spike"
        )
    }

    func sendEcho(value: String) {
        AlembicDiagnosticsBridge.shared.recordNative(
            level: "info",
            tag: "swift.app",
            message: "Echo invoked with value=\(value)"
        )
        channel?.invokeMethod("echo", arguments: ["value": value]) { [weak self] result in
            DispatchQueue.main.async {
                if let map: [String: Any] = result as? [String: Any] {
                    let description: String = AlembicSpikeBridge.describeEcho(map: map)
                    self?.state.ingestEcho(value: description)
                    AlembicDiagnosticsBridge.shared.recordNative(
                        level: "success",
                        tag: "swift.app",
                        message: "Echo response: \(description)"
                    )
                } else if let error: FlutterError = result as? FlutterError {
                    self?.state.ingestEchoFailure(reason: error.message ?? "unknown")
                    AlembicDiagnosticsBridge.shared.recordNative(
                        level: "error",
                        tag: "swift.app",
                        message: "Echo failed: \(error.message ?? "unknown")"
                    )
                } else {
                    self?.state.ingestEchoFailure(reason: "no response")
                    AlembicDiagnosticsBridge.shared.recordNative(
                        level: "warn",
                        tag: "swift.app",
                        message: "Echo returned no response"
                    )
                }
            }
        }
    }

    private static func describeEcho(map: [String: Any]) -> String {
        let echoedFrom: String = (map["echoedFrom"] as? String) ?? "?"
        let value: Any = map["value"] ?? "<nil>"
        let tick: Int = (map["tick"] as? Int) ?? 0
        return "from \(echoedFrom) at tick \(tick): \(value)"
    }

    func setStatus(_ status: String) {
        channel?.invokeMethod("setStatus", arguments: ["status": status])
    }

    private func handle(
        call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        switch call.method {
        case "state":
            let map: [String: Any] = (call.arguments as? [String: Any]) ?? [:]
            let tick: Int = (map["tick"] as? Int) ?? 0
            let status: String = (map["status"] as? String) ?? "unknown"
            let epoch: Int64 = AlembicSpikeBridge.intValue(from: map["epochMillis"])
            let dartVersion: String = (map["dartVersion"] as? String) ?? ""
            let pid: String = (map["pid"] as? String) ?? ""
            let configPath: String = (map["configPath"] as? String) ?? ""
            let migrationAttempted: Bool = (map["migrationAttempted"] as? Bool) ?? false
            let migrationSourcePath: String? = map["migrationSourcePath"] as? String
            let migrationCopiedFiles: [String] = (map["migrationCopiedFiles"] as? [String]) ?? []
            let migrationSkippedFiles: [String] = (map["migrationSkippedFiles"] as? [String]) ?? []
            let migrationSearchedPaths: [String] = (map["migrationSearchedPaths"] as? [String]) ?? []
            let hiveEntries: Int = (map["hiveEntries"] as? Int) ?? 0
            let accountCount: Int = (map["accountCount"] as? Int) ?? 0
            let primaryAccountLogin: String? = map["primaryAccountLogin"] as? String

            if tick == 0 || tick == 1 {
                AlembicDiagnosticsBridge.shared.recordNative(
                    level: "info",
                    tag: "swift.app.state",
                    message: "ingest tick=\(tick) status=\(status) configPath=\(configPath) hiveEntries=\(hiveEntries) accounts=\(accountCount) primaryLogin=\(primaryAccountLogin ?? "<nil>") migration: attempted=\(migrationAttempted) source=\(migrationSourcePath ?? "<nil>") copied=\(migrationCopiedFiles.count) skipped=\(migrationSkippedFiles.count) searched=\(migrationSearchedPaths.count)"
                )
            }
            DispatchQueue.main.async { [weak self] in
                self?.state.ingestState(
                    tick: tick,
                    status: status,
                    epochMillis: epoch,
                    dartVersion: dartVersion,
                    pid: pid,
                    configPath: configPath,
                    migrationAttempted: migrationAttempted,
                    migrationSourcePath: migrationSourcePath,
                    migrationCopiedFiles: migrationCopiedFiles,
                    migrationSkippedFiles: migrationSkippedFiles,
                    migrationSearchedPaths: migrationSearchedPaths,
                    hiveEntries: hiveEntries,
                    accountCount: accountCount,
                    primaryAccountLogin: primaryAccountLogin
                )
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private static func intValue(from raw: Any?) -> Int64 {
        if let v: Int64 = raw as? Int64 {
            return v
        }
        if let v: Int = raw as? Int {
            return Int64(v)
        }
        if let v: NSNumber = raw as? NSNumber {
            return v.int64Value
        }
        return 0
    }
}
