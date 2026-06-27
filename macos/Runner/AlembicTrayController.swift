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
        button.sendAction(on: [.leftMouseDown, .rightMouseDown])

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
        let prepareBeforeOpen: Bool = !window.isVisible
        ensureUsableWindowSize(window)
        positionWindowAtTopRight(window)
        window.alphaValue = 1.0
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]
        if prepareBeforeOpen {
            AlembicGlassLegibilityController.shared.prepareForWindowOpen(window) { [weak self, weak window] in
                guard let self: AlembicTrayController = self,
                      let window: NSWindow = window else {
                    return
                }
                self.finishShowWindow(window)
            }
            return
        }
        AlembicGlassLegibilityController.shared.refresh()
        finishShowWindow(window)
    }

    private func finishShowWindow(_ window: NSWindow) {
        suppressHideUntil = Date().addingTimeInterval(0.35)
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

    private func showWindowThen(_ block: @escaping () -> Void) {
        showWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            block()
        }
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
        if AlembicWindowPreferences.shared.pinWindow {
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

    func repositionAtDefault() {
        guard let window: NSWindow = window else {
            return
        }
        positionWindowAtTopRight(window)
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        if shouldShowStatusMenu {
            showStatusMenu(from: sender)
            return
        }
        eventChannel?.invokeMethod("onLeftClick", arguments: nil)
        if AlembicWindowPreferences.shared.pinWindow,
           let window: NSWindow = window,
           window.isVisible {
            hideWindow()
            return
        }
        showWindow()
    }

    private var shouldShowStatusMenu: Bool {
        guard let event: NSEvent = NSApp.currentEvent else {
            return false
        }
        return event.type == .rightMouseDown
            || event.type == .rightMouseUp
            || event.modifierFlags.contains(.control)
    }

    private func showStatusMenu(from button: NSStatusBarButton) {
        let menu: NSMenu = NSMenu(title: "Alembic")
        menu.autoenablesItems = false
        suppressHideUntil = Date().addingTimeInterval(0.35)
        menu.addItem(statusMenuItem(
            title: "Show Alembic",
            symbol: "rectangle.on.rectangle",
            action: #selector(handleShowWindowMenuItem(_:))
        ))
        menu.addItem(statusMenuItem(
            title: "Hide Window",
            symbol: "rectangle.compress.vertical",
            action: #selector(handleHideWindowMenuItem(_:)),
            enabled: window?.isVisible == true
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(statusMenuItem(
            title: "Refresh Repositories",
            symbol: "arrow.clockwise",
            action: #selector(handleRefreshMenuItem(_:))
        ))
        menu.addItem(statusMenuItem(
            title: "Import Repositories...",
            symbol: "square.and.arrow.down",
            action: #selector(handleImportMenuItem(_:))
        ))
        menu.addItem(statusMenuItem(
            title: "Settings...",
            symbol: "gearshape",
            action: #selector(handleSettingsMenuItem(_:))
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(statusMenuItem(
            title: "Restart Alembic",
            symbol: "restart",
            action: #selector(handleRestartMenuItem(_:))
        ))
        menu.addItem(statusMenuItem(
            title: "Quit Alembic",
            symbol: "power",
            action: #selector(handleQuitMenuItem(_:))
        ))
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0.0, y: button.bounds.minY - 4.0),
            in: button
        )
    }

    private func statusMenuItem(
        title: String,
        symbol: String,
        action: Selector,
        enabled: Bool = true
    ) -> NSMenuItem {
        let item: NSMenuItem = NSMenuItem(
            title: title,
            action: action,
            keyEquivalent: ""
        )
        item.target = self
        item.isEnabled = enabled
        if #available(macOS 11.0, *),
           let image: NSImage = NSImage(systemSymbolName: symbol, accessibilityDescription: title) {
            item.image = image
        }
        return item
    }

    @objc private func handleShowWindowMenuItem(_ sender: NSMenuItem) {
        eventChannel?.invokeMethod("onMenuAction", arguments: ["action": "show"])
        showWindow()
    }

    @objc private func handleHideWindowMenuItem(_ sender: NSMenuItem) {
        eventChannel?.invokeMethod("onMenuAction", arguments: ["action": "hide"])
        hideWindow()
    }

    @objc private func handleRefreshMenuItem(_ sender: NSMenuItem) {
        eventChannel?.invokeMethod("onMenuAction", arguments: ["action": "refresh"])
        AlembicRepositoryListBridge.shared.refresh()
    }

    @objc private func handleImportMenuItem(_ sender: NSMenuItem) {
        eventChannel?.invokeMethod("onMenuAction", arguments: ["action": "import"])
        showWindowThen {
            NotificationCenter.default.post(name: AlembicTrayController.openImportNotification, object: nil)
        }
    }

    @objc private func handleSettingsMenuItem(_ sender: NSMenuItem) {
        eventChannel?.invokeMethod("onMenuAction", arguments: ["action": "settings"])
        showWindowThen {
            NotificationCenter.default.post(name: AlembicTrayController.openSettingsNotification, object: nil)
        }
    }

    @objc private func handleRestartMenuItem(_ sender: NSMenuItem) {
        eventChannel?.invokeMethod("onMenuAction", arguments: ["action": "restart"])
        restartApplication()
    }

    @objc private func handleQuitMenuItem(_ sender: NSMenuItem) {
        eventChannel?.invokeMethod("onMenuAction", arguments: ["action": "quit"])
        NSApp.terminate(nil)
    }

    private func restartApplication() {
        let bundlePath: String = Bundle.main.bundlePath
        let process: Process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", bundlePath]
        do {
            try process.run()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                NSApp.terminate(nil)
            }
        } catch {
            log("restart: failed to relaunch \(bundlePath): \(error.localizedDescription)")
        }
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
        guard let screen: NSScreen = statusItem?.button?.window?.screen ?? window.screen ?? NSScreen.main ?? NSScreen.screens.first else {
            return
        }
        let visibleFrame: NSRect = screen.visibleFrame
        let maximumWidth: CGFloat = max(920.0, visibleFrame.width - 24.0)
        let maximumHeight: CGFloat = max(600.0, visibleFrame.height - 24.0)
        let minimumWidth: CGFloat = min(1080.0, maximumWidth)
        let minimumHeight: CGFloat = min(680.0, maximumHeight)
        var frame: NSRect = window.frame
        let width: CGFloat = min(max(frame.width, minimumWidth), maximumWidth)
        let height: CGFloat = min(max(frame.height, minimumHeight), maximumHeight)
        if abs(frame.width - width) < 1.0 && abs(frame.height - height) < 1.0 {
            return
        }
        frame.size = NSSize(width: width, height: height)
        window.setFrame(frame, display: false)
    }

    private func positionWindowAtTopRight(_ window: NSWindow) {
        guard let screen: NSScreen = statusItem?.button?.window?.screen ?? NSScreen.main ?? NSScreen.screens.first else {
            return
        }
        let visibleFrame: NSRect = screen.visibleFrame
        let windowSize: NSSize = window.frame.size
        let originX: CGFloat = visibleFrame.maxX - windowSize.width - 8.0
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
