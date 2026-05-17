import Cocoa
import FlutterMacOS
import SwiftUI
import os.log

private extension OSLog {
    static let alembicDiagnosticsBridge: OSLog = OSLog(
        subsystem: "art.arcane.alembic.spike",
        category: "diagnostics"
    )
}

struct AlembicLogEntry: Identifiable, Hashable {
    let id: UInt64
    let timestampMillis: Int64
    let level: String
    let tag: String
    let message: String

    var date: Date {
        return Date(timeIntervalSince1970: TimeInterval(timestampMillis) / 1000.0)
    }
}

final class AlembicDiagnosticsState: ObservableObject {
    static let bufferLimit: Int = 500

    @Published private(set) var entries: [AlembicLogEntry] = []
    @Published var errorCount: Int = 0
    @Published var warnCount: Int = 0
    @Published var totalCount: Int = 0
    @Published var lastUpdatedMillis: Int64 = 0

    func append(entry: AlembicLogEntry) {
        var next: [AlembicLogEntry] = entries
        next.append(entry)
        if next.count > AlembicDiagnosticsState.bufferLimit {
            next.removeFirst(next.count - AlembicDiagnosticsState.bufferLimit)
        }
        entries = next
        totalCount += 1
        if entry.level == "error" {
            errorCount += 1
        } else if entry.level == "warn" {
            warnCount += 1
        }
        lastUpdatedMillis = entry.timestampMillis
    }

    func reset() {
        entries = []
        errorCount = 0
        warnCount = 0
        totalCount = 0
        lastUpdatedMillis = 0
    }
}

final class AlembicDiagnosticsBridge: NSObject {
    static let shared: AlembicDiagnosticsBridge = AlembicDiagnosticsBridge()
    private static let consoleDateFormatter: ISO8601DateFormatter = {
        let formatter: ISO8601DateFormatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
        ]
        return formatter
    }()

    let state: AlembicDiagnosticsState = AlembicDiagnosticsState()
    private var channel: FlutterMethodChannel?
    private var entrySeq: UInt64 = 0
    private let traceEnabled: Bool = ProcessInfo.processInfo.environment["ALEMBIC_DIAGNOSTICS_TRACE"] == "1" ||
        ProcessInfo.processInfo.environment["ALEMBIC_DIAGNOSTICS_STDOUT"] == "1"
    private let consoleVerbose: Bool = ProcessInfo.processInfo.environment["ALEMBIC_DIAGNOSTICS_STDOUT"] == "1"

    private override init() {
        super.init()
    }

    func attach(messenger: FlutterBinaryMessenger) {
        let channel: FlutterMethodChannel = FlutterMethodChannel(
            name: "alembic.spike.diagnostics",
            binaryMessenger: messenger
        )
        self.channel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
        os_log(
            "AlembicDiagnosticsBridge attached",
            log: .alembicDiagnosticsBridge,
            type: .info
        )
        recordNative(
            level: "info",
            tag: "swift",
            message: "Diagnostics bridge attached"
        )
    }

    func requestSnapshot() {
        guard let channel: FlutterMethodChannel = self.channel else { return }
        channel.invokeMethod("requestSnapshot", arguments: nil) { [weak self] raw in
            guard let map: [String: Any] = raw as? [String: Any] else { return }
            guard let entries: [[String: Any]] = map["entries"] as? [[String: Any]] else {
                return
            }
            DispatchQueue.main.async {
                guard let self: AlembicDiagnosticsBridge = self else { return }
                self.state.reset()
                for raw in entries {
                    if let parsed: AlembicLogEntry = self.parse(map: raw) {
                        self.state.append(entry: parsed)
                    }
                }
            }
        }
    }

    func recordNative(level: String, tag: String, message: String) {
        if level == "trace" && !traceEnabled {
            return
        }
        let now: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
        let entry: AlembicLogEntry = makeEntry(
            timestampMillis: now,
            level: level,
            tag: tag,
            message: message
        )
        os_log(
            "[swift][%{public}@] %{public}@",
            log: .alembicDiagnosticsBridge,
            type: osType(for: level),
            tag,
            message
        )
        if shouldWriteConsole(level: level) {
            let stamp: String = AlembicDiagnosticsBridge.consoleDateFormatter.string(from: entry.date)
            FileHandle.standardError.write(Data(("alembic.swift [\(stamp)] [\(level)] [\(tag)] \(message)\n").utf8))
        }
        DispatchQueue.main.async { [weak self] in
            self?.state.append(entry: entry)
        }
    }

    private func handle(
        call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        switch call.method {
        case "log":
            let map: [String: Any] = (call.arguments as? [String: Any]) ?? [:]
            ingestLog(map: map)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func ingestLog(map: [String: Any]) {
        guard let entry: AlembicLogEntry = parse(map: map) else { return }
        os_log(
            "[dart][%{public}@] %{public}@",
            log: .alembicDiagnosticsBridge,
            type: osType(for: entry.level),
            entry.tag,
            entry.message
        )
        DispatchQueue.main.async { [weak self] in
            self?.state.append(entry: entry)
        }
    }

    private func parse(map: [String: Any]) -> AlembicLogEntry? {
        let timestampMillis: Int64 = AlembicDiagnosticsBridge.intValue(from: map["timestampMillis"])
        let level: String = (map["level"] as? String) ?? "info"
        let tag: String = (map["tag"] as? String) ?? "?"
        let message: String = (map["message"] as? String) ?? ""
        return makeEntry(
            timestampMillis: timestampMillis,
            level: level,
            tag: tag,
            message: message
        )
    }

    private func makeEntry(
        timestampMillis: Int64,
        level: String,
        tag: String,
        message: String
    ) -> AlembicLogEntry {
        entrySeq &+= 1
        return AlembicLogEntry(
            id: entrySeq,
            timestampMillis: timestampMillis,
            level: level,
            tag: tag,
            message: message
        )
    }

    private func shouldWriteConsole(level: String) -> Bool {
        return consoleVerbose || level == "error" || level == "warn"
    }

    private func osType(for level: String) -> OSLogType {
        switch level {
        case "error":
            return .error
        case "warn":
            return .default
        case "success":
            return .info
        case "trace":
            return .debug
        default:
            return .info
        }
    }

    private static func intValue(from raw: Any?) -> Int64 {
        if let v: Int64 = raw as? Int64 { return v }
        if let v: Int = raw as? Int { return Int64(v) }
        if let v: NSNumber = raw as? NSNumber { return v.int64Value }
        return 0
    }
}
