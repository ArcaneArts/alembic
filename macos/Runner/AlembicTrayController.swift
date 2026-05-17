import Cocoa
import FlutterMacOS
import os.log

private extension OSLog {
    static let alembicTray: OSLog = OSLog(
        subsystem: "art.arcane.alembic.tray",
        category: "status-item"
    )
}

final class AlembicTrayController: NSObject {
    static let shared: AlembicTrayController = AlembicTrayController()
    static let openSettingsNotification: Notification.Name = Notification.Name("AlembicTrayOpenSettings")
    static let openImportNotification: Notification.Name = Notification.Name("AlembicTrayOpenImport")

    private static let autosaveNameString: String = "AlembicMenuBarItemV5"
    private static let autosaveName: NSStatusItem.AutosaveName = NSStatusItem.AutosaveName(
        AlembicTrayController.autosaveNameString
    )

    private var statusItem: NSStatusItem?
    private weak var window: NSWindow?
    private weak var eventChannel: FlutterMethodChannel?
    private var appResignObserver: NSObjectProtocol?
    private var windowResignObserver: NSObjectProtocol?
    private var suppressHideUntil: Date = Date.distantPast
    private let isVerbose: Bool = ProcessInfo.processInfo.environment["ALEMBIC_TRAY_VERBOSE"] == "1"

    private override init() {
        super.init()
        appResignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] _ in
            self?.hideAfterOutsideClick()
        }
    }

    deinit {
        if let observer: NSObjectProtocol = appResignObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer: NSObjectProtocol = windowResignObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func attach(window: NSWindow, channel: FlutterMethodChannel) {
        self.window = window
        self.eventChannel = channel
        if let observer: NSObjectProtocol = windowResignObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        windowResignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: OperationQueue.main
        ) { [weak self] _ in
            self?.hideAfterOutsideClick()
        }
        verbose("attach: window attached")
    }

    func install() {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.install()
            }
            return
        }
        if statusItem != nil {
            verbose("install: already installed")
            return
        }

        UserDefaults.standard.set(
            true,
            forKey: "NSStatusItem Visible \(AlembicTrayController.autosaveNameString)"
        )

        let item: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = AlembicTrayController.autosaveName
        item.behavior = []
        item.isVisible = true
        statusItem = item

        guard let button: NSStatusBarButton = item.button else {
            log("install: NSStatusItem created but AppKit returned no button")
            return
        }

        button.image = makeIcon()
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = "Alembic"
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp])

        if isVerbose {
            logStatusItem("install")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                self.logStatusItem("install +0.75s")
            }
        }
    }

    func dispose() {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.dispose()
            }
            return
        }
        if let item: NSStatusItem = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
        log("dispose: removed status item")
    }

    func recreate(activate: Bool) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.recreate(activate: activate)
            }
            return
        }
        dispose()
        if activate {
            NSApp.activate(ignoringOtherApps: true)
        }
        install()
    }

    func setTooltip(_ tooltip: String) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.setTooltip(tooltip)
            }
            return
        }
        statusItem?.button?.toolTip = tooltip
        verbose("setTooltip: \(tooltip)")
    }

    func bounds() -> [String: Double]? {
        guard let frame: NSRect = statusItem?.button?.window?.frame,
              let screen: NSScreen = statusItem?.button?.window?.screen else {
            return nil
        }
        let screenFrame: NSRect = screen.frame
        return [
            "x": Double(frame.origin.x),
            "y": Double(screenFrame.origin.y + screenFrame.height - frame.origin.y - frame.height),
            "width": Double(frame.width),
            "height": Double(frame.height),
        ]
    }

    func dumpFullDebug() -> [String: Any] {
        let frame: String = statusItem?.button?.window.map { NSStringFromRect($0.frame) } ?? "<nil>"
        let screen: String = statusItem?.button?.window?.screen?.localizedName ?? "<nil>"
        return [
            "bundleIdentifier": Bundle.main.bundleIdentifier ?? "<nil>",
            "activationPolicy": NSApp.activationPolicy().rawValue,
            "statusItemPresent": statusItem != nil,
            "statusItemVisible": statusItem?.isVisible ?? false,
            "statusItemAutosaveName": statusItem?.autosaveName ?? "<nil>",
            "buttonWindowFrame": frame,
            "buttonWindowScreen": screen,
            "menuBarAllowHint": "macOS 26: System Settings > Menu Bar > Allow in the Menu Bar > Alembic must be enabled",
        ]
    }

    func showWindow() {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.showWindow()
            }
            return
        }
        guard let window: NSWindow = window else {
            log("showWindow: tray clicked before window attached")
            return
        }
        suppressHideUntil = Date().addingTimeInterval(0.35)
        ensureUsableWindowSize(window)
        positionWindowNearStatusItem(window)
        window.alphaValue = 1.0
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        verbose("showWindow: visible=\(window.isVisible) key=\(window.isKeyWindow) frame=\(NSStringFromRect(window.frame))")
    }

    func hideWindow() {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.hideWindow()
            }
            return
        }
        guard let window: NSWindow = window else {
            return
        }
        window.orderOut(nil)
        window.alphaValue = 1.0
        verbose("hideWindow: hidden")
    }

    private func hideAfterOutsideClick() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.hideIfUnfocused()
        }
    }

    private func hideIfUnfocused() {
        guard let window: NSWindow = window, window.isVisible else {
            return
        }
        if Date() < suppressHideUntil {
            return
        }
        if AlembicWindowBridge.shared.isHideOnBlurSuspended || window.attachedSheet != nil || NSApp.modalWindow != nil {
            return
        }
        if NSApp.isActive && window.isKeyWindow {
            return
        }
        hideWindow()
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        eventChannel?.invokeMethod("onLeftClick", arguments: nil)
        showWindow()
    }

    private func makeIcon() -> NSImage {
        if #available(macOS 11.0, *) {
            if let symbol: NSImage = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "Alembic") {
                let configuration: NSImage.SymbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15.0, weight: .bold)
                let configured: NSImage = symbol.withSymbolConfiguration(configuration) ?? symbol
                configured.isTemplate = true
                return configured
            }
        }
        if let asset: NSImage = NSImage(named: NSImage.Name("AlembicTray")) {
            asset.size = NSSize(width: 18.0, height: 18.0)
            asset.isTemplate = true
            return asset
        }
        let image: NSImage = NSImage(size: NSSize(width: 18.0, height: 18.0))
        image.lockFocus()
        NSString(string: "A").draw(
            in: NSRect(x: 4.0, y: 1.0, width: 14.0, height: 16.0),
            withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 13.0, weight: .bold),
                .foregroundColor: NSColor.labelColor,
            ]
        )
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func ensureUsableWindowSize(_ window: NSWindow) {
        if window.frame.width >= 760.0 && window.frame.height >= 560.0 {
            return
        }
        var frame: NSRect = window.frame
        frame.size = NSSize(width: 960.0, height: 720.0)
        window.setFrame(frame, display: false)
    }

    private func positionWindowNearStatusItem(_ window: NSWindow) {
        guard let screen: NSScreen = statusItem?.button?.window?.screen ?? NSScreen.main ?? NSScreen.screens.first else {
            return
        }
        let anchor: NSRect = statusItem?.button?.window?.frame ?? screen.visibleFrame
        let visibleFrame: NSRect = screen.visibleFrame
        let windowSize: NSSize = window.frame.size
        var originX: CGFloat = anchor.midX - (windowSize.width / 2.0)
        originX = max(visibleFrame.minX + 8.0, min(originX, visibleFrame.maxX - windowSize.width - 8.0))
        let originY: CGFloat = visibleFrame.maxY - windowSize.height - 8.0
        window.setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    private func logStatusItem(_ prefix: String) {
        let frame: String = statusItem?.button?.window.map { NSStringFromRect($0.frame) } ?? "<nil>"
        let screen: String = statusItem?.button?.window?.screen?.localizedName ?? "<nil>"
        let visible: String = statusItem?.isVisible == true ? "yes" : "no"
        let hint: String = "If invisible on macOS 26, enable Alembic in System Settings > Menu Bar > Allow in the Menu Bar."
        log("\(prefix): NSStatusItem visible=\(visible) frame=\(frame) screen=\(screen) autosave=\(AlembicTrayController.autosaveNameString). \(hint)")
    }

    private func verbose(_ message: String) {
        if isVerbose {
            log(message)
        }
    }

    private func log(_ message: String) {
        os_log(.info, log: .alembicTray, "%{public}@", message)
        eventChannel?.invokeMethod("onLog", arguments: ["level": "info", "message": message])
        FileHandle.standardError.write(Data(("[alembic-tray] " + message + "\n").utf8))
    }
}
