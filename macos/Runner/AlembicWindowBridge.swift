import Cocoa
import FlutterMacOS
import os.log

private extension OSLog {
    static let alembicWindow: OSLog = OSLog(
        subsystem: "art.arcane.alembic.window",
        category: "bridge"
    )
}

final class AlembicWindowBridge: NSObject {
    static let shared: AlembicWindowBridge = AlembicWindowBridge()

    private weak var window: NSWindow?
    private weak var backdrop: AlembicGlassBackdrop?
    private var channel: FlutterMethodChannel?
    private var hideOnBlurSuspendCount: Int = 0
    private var themeTokens: [String: Any] = [:]
    private var appearanceObservation: NSKeyValueObservation?

    private override init() {
        super.init()
    }

    func attach(
        window: NSWindow,
        backdrop: AlembicGlassBackdrop?,
        binaryMessenger: FlutterBinaryMessenger
    ) {
        self.window = window
        self.backdrop = backdrop
        let channel: FlutterMethodChannel = FlutterMethodChannel(
            name: "alembic_window",
            binaryMessenger: binaryMessenger
        )
        self.channel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
        startObservingAppearance()
        DispatchQueue.main.async { [weak self] in
            self?.dispatchInitialThemeBrightness()
        }
        os_log(
            "AlembicWindowBridge attached",
            log: .alembicWindow,
            type: .info
        )
    }

    var isHideOnBlurSuspended: Bool {
        return hideOnBlurSuspendCount > 0
    }

    func suspendHideOnBlur() {
        hideOnBlurSuspendCount += 1
        os_log(
            "suspendHideOnBlur: count=%d",
            log: .alembicWindow,
            type: .info,
            hideOnBlurSuspendCount
        )
        channel?.invokeMethod(
            "onHideOnBlurSuspended",
            arguments: ["count": hideOnBlurSuspendCount]
        )
    }

    func resumeHideOnBlur(ensureVisible: Bool) {
        if hideOnBlurSuspendCount > 0 {
            hideOnBlurSuspendCount -= 1
        }
        os_log(
            "resumeHideOnBlur: count=%d ensureVisible=%@",
            log: .alembicWindow,
            type: .info,
            hideOnBlurSuspendCount,
            ensureVisible ? "yes" : "no"
        )
        channel?.invokeMethod(
            "onHideOnBlurResumed",
            arguments: [
                "count": hideOnBlurSuspendCount,
                "ensureVisible": ensureVisible,
            ]
        )
    }

    func themeToken(forKey key: String) -> Any? {
        return themeTokens[key]
    }

    private func handle(
        call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        switch call.method {
        case "detectMaterial":
            result(detectMaterialWire())
        case "setMaterial":
            applyMaterial(arguments: call.arguments)
            result(nil)
        case "pushThemeTokens":
            ingestThemeTokens(arguments: call.arguments)
            result(nil)
        case "suspendHideOnBlur":
            suspendHideOnBlur()
            result(nil)
        case "resumeHideOnBlur":
            let arguments: [String: Any]? = call.arguments as? [String: Any]
            let ensureVisible: Bool = (arguments?["ensureVisible"] as? Bool) ?? false
            resumeHideOnBlur(ensureVisible: ensureVisible)
            result(nil)
        case "dumpDiagnostics":
            result(buildDiagnostics())
        case "showAboutPanel":
            showAboutPanel(arguments: call.arguments)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func detectMaterialWire() -> String {
        let current: AlembicMaterial = backdrop?.material ?? AlembicMaterial.detect()
        switch current {
        case .liquidGlass:
            return "liquid_glass"
        case .vibrancy:
            return "vibrancy"
        case .solid:
            return "solid"
        }
    }

    private func applyMaterial(arguments: Any?) {
        let map: [String: Any]? = arguments as? [String: Any]
        let wire: String = (map?["material"] as? String) ?? "vibrancy"
        let resolved: AlembicMaterial = parseMaterial(wire: wire)
        backdrop?.setMaterial(resolved)
        os_log(
            "applyMaterial: requested=%{public}@ resolved=%{public}@",
            log: .alembicWindow,
            type: .info,
            wire,
            resolved.rawValue
        )
    }

    private func parseMaterial(wire: String) -> AlembicMaterial {
        switch wire {
        case "liquid_glass":
            return AlembicMaterial.detect() == .liquidGlass
                ? .liquidGlass
                : .vibrancy
        case "vibrancy":
            return .vibrancy
        case "solid":
            return .solid
        case "mica", "mica_alt", "acrylic", "acrylic_legacy":
            return .vibrancy
        case "unknown":
            return AlembicMaterial.detect()
        default:
            return AlembicMaterial.detect()
        }
    }

    private func ingestThemeTokens(arguments: Any?) {
        guard let map: [String: Any] = arguments as? [String: Any] else {
            return
        }
        if let tokens: [String: Any] = map["tokens"] as? [String: Any] {
            themeTokens = tokens
            os_log(
                "pushThemeTokens: stored %d keys",
                log: .alembicWindow,
                type: .info,
                tokens.count
            )
            return
        }
        themeTokens = map
        os_log(
            "pushThemeTokens: stored %d keys (flat)",
            log: .alembicWindow,
            type: .info,
            themeTokens.count
        )
    }

    private func buildDiagnostics() -> [String: Any] {
        var output: [String: Any] = [:]
        output["macosVersion"] = ProcessInfo.processInfo.operatingSystemVersionString
        output["material"] = detectMaterialWire()
        output["hideOnBlurSuspendCount"] = hideOnBlurSuspendCount
        output["themeTokenCount"] = themeTokens.count
        if let window: NSWindow = window {
            output["window.frame"] = NSStringFromRect(window.frame)
            output["window.isVisible"] = window.isVisible
            output["window.isKey"] = window.isKeyWindow
            output["window.appearance"] = window.effectiveAppearance.name.rawValue
        }
        return output
    }

    private func startObservingAppearance() {
        guard let window: NSWindow = window else {
            return
        }
        appearanceObservation = window.observe(
            \.effectiveAppearance,
            options: [.initial, .new]
        ) { [weak self] _, _ in
            self?.dispatchInitialThemeBrightness()
        }
    }

    private func dispatchInitialThemeBrightness() {
        guard let window: NSWindow = window else {
            return
        }
        let appearanceName: NSAppearance.Name = window.effectiveAppearance.name
        let isDark: Bool = appearanceName == .darkAqua
            || appearanceName == .vibrantDark
            || appearanceName == .accessibilityHighContrastDarkAqua
            || appearanceName == .accessibilityHighContrastVibrantDark
        channel?.invokeMethod(
            "onThemeChanged",
            arguments: [
                "theme": isDark ? "dark" : "light",
                "raw": appearanceName.rawValue,
            ]
        )
    }

    private func showAboutPanel(arguments: Any?) {
        let map: [String: Any] = (arguments as? [String: Any]) ?? [:]
        var options: [NSApplication.AboutPanelOptionKey: Any] = [:]
        if let appName: String = map["appName"] as? String, !appName.isEmpty {
            options[NSApplication.AboutPanelOptionKey.applicationName] = appName
        }
        if let version: String = map["version"] as? String, !version.isEmpty {
            options[NSApplication.AboutPanelOptionKey.applicationVersion] = version
        }
        if let build: String = map["build"] as? String, !build.isEmpty {
            options[NSApplication.AboutPanelOptionKey.version] = build
        }
        if let copyright: String = map["copyright"] as? String, !copyright.isEmpty {
            let attributed: NSAttributedString = NSAttributedString(
                string: copyright,
                attributes: [
                    NSAttributedString.Key.font: NSFont.systemFont(
                        ofSize: NSFont.smallSystemFontSize
                    ),
                    NSAttributedString.Key.foregroundColor: NSColor.secondaryLabelColor,
                ]
            )
            options[NSApplication.AboutPanelOptionKey.credits] = attributed
        }
        if let creditsHtml: String = map["creditsHtml"] as? String,
           let data: Data = creditsHtml.data(using: String.Encoding.utf8) {
            let attributed: NSAttributedString? = try? NSAttributedString(
                data: data,
                options: [
                    NSAttributedString.DocumentReadingOptionKey.documentType:
                        NSAttributedString.DocumentType.html,
                ],
                documentAttributes: nil
            )
            if let attributed: NSAttributedString = attributed {
                options[NSApplication.AboutPanelOptionKey.credits] = attributed
            }
        }
        suspendHideOnBlur()
        NSApp.activate(ignoringOtherApps: true)
        if options.isEmpty {
            NSApp.orderFrontStandardAboutPanel(nil)
        } else {
            NSApp.orderFrontStandardAboutPanel(options: options)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.resumeHideOnBlur(ensureVisible: false)
        }
    }
}
