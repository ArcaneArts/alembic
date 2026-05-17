import Cocoa
import FlutterMacOS
import os.log

private extension OSLog {
    static let alembicMenus: OSLog = OSLog(
        subsystem: "art.arcane.alembic.menus",
        category: "bridge"
    )
}

final class AlembicMenusBridge: NSObject {
    static let shared: AlembicMenusBridge = AlembicMenusBridge()

    private weak var hostWindow: NSWindow?
    private var channel: FlutterMethodChannel?
    private var pendingSelection: String?

    private override init() {
        super.init()
    }

    func attach(window: NSWindow, binaryMessenger: FlutterBinaryMessenger) {
        self.hostWindow = window
        let channel: FlutterMethodChannel = FlutterMethodChannel(
            name: "alembic_menus",
            binaryMessenger: binaryMessenger
        )
        self.channel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
        os_log(
            "AlembicMenusBridge attached",
            log: .alembicMenus,
            type: .info
        )
    }

    private func handle(
        call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        switch call.method {
        case "showContextMenu":
            ensureMainThread {
                self.showContextMenu(arguments: call.arguments, result: result)
            }
        case "setApplicationMenu":
            ensureMainThread {
                self.setApplicationMenu(arguments: call.arguments)
                result(nil)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func ensureMainThread(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    private func showContextMenu(
        arguments: Any?,
        result: @escaping FlutterResult
    ) {
        let map: [String: Any] = (arguments as? [String: Any]) ?? [:]
        let items: [[String: Any]] = (map["items"] as? [[String: Any]]) ?? []
        let originMap: [String: Any]? = map["origin"] as? [String: Any]
        let menu: NSMenu = buildMenu(from: items)

        AlembicWindowBridge.shared.suspendHideOnBlur()
        pendingSelection = nil

        let host: NSView? = hostWindow?.contentView
        let displayed: Bool
        if let origin: NSPoint = parseOrigin(originMap), let host: NSView = host {
            displayed = menu.popUp(positioning: nil, at: origin, in: host)
        } else if let host: NSView = host {
            let center: NSPoint = NSPoint(
                x: host.bounds.midX,
                y: host.bounds.midY
            )
            displayed = menu.popUp(positioning: nil, at: center, in: host)
        } else if let event: NSEvent = NSApp.currentEvent {
            NSMenu.popUpContextMenu(
                menu,
                with: event,
                for: NSApp.keyWindow?.contentView ?? NSView()
            )
            displayed = pendingSelection != nil
        } else {
            displayed = menu.popUp(positioning: nil, at: NSPoint.zero, in: nil)
        }

        AlembicWindowBridge.shared.resumeHideOnBlur(ensureVisible: false)
        let selected: String? = displayed ? pendingSelection : nil
        pendingSelection = nil
        result(selected)
    }

    private func parseOrigin(_ map: [String: Any]?) -> NSPoint? {
        guard let map: [String: Any] = map else {
            return nil
        }
        let x: Double? = map["x"] as? Double
        let y: Double? = map["y"] as? Double
        guard let x: Double = x, let y: Double = y else {
            return nil
        }
        return NSPoint(x: x, y: y)
    }

    private func setApplicationMenu(arguments: Any?) {
        let map: [String: Any] = (arguments as? [String: Any]) ?? [:]
        let items: [[String: Any]] = (map["items"] as? [[String: Any]]) ?? []
        if items.isEmpty {
            NSApp.mainMenu = nil
            return
        }
        let menu: NSMenu = buildAppMenu(from: items)
        NSApp.mainMenu = menu
    }

    private func buildMenu(from items: [[String: Any]]) -> NSMenu {
        let menu: NSMenu = NSMenu()
        for entry: [String: Any] in items {
            if let item: NSMenuItem = buildMenuItem(from: entry) {
                menu.addItem(item)
            }
        }
        return menu
    }

    private func buildAppMenu(from items: [[String: Any]]) -> NSMenu {
        let mainMenu: NSMenu = NSMenu()
        let hasTopLevelMenus: Bool = items.contains { (entry: [String: Any]) -> Bool in
            let kind: String = (entry["kind"] as? String) ?? "command"
            return kind == "submenu"
        }
        if hasTopLevelMenus {
            for entry: [String: Any] in items {
                let kind: String = (entry["kind"] as? String) ?? "command"
                if kind == "separator" {
                    continue
                }
                let label: String = (entry["label"] as? String) ?? ""
                let topItem: NSMenuItem = NSMenuItem(
                    title: label,
                    action: nil,
                    keyEquivalent: ""
                )
                let submenu: NSMenu = NSMenu(title: label)
                if kind == "submenu",
                   let children: [[String: Any]] = entry["children"] as? [[String: Any]] {
                    for child: [String: Any] in children {
                        if let childItem: NSMenuItem = buildMenuItem(from: child, appMenuRoot: true) {
                            submenu.addItem(childItem)
                        }
                    }
                } else if let item: NSMenuItem = buildMenuItem(from: entry, appMenuRoot: true) {
                    submenu.addItem(item)
                }
                topItem.submenu = submenu
                mainMenu.addItem(topItem)
            }
            return mainMenu
        }
        let appMenuContainer: NSMenuItem = NSMenuItem()
        let appMenu: NSMenu = NSMenu()
        appMenuContainer.submenu = appMenu
        mainMenu.addItem(appMenuContainer)
        for entry: [String: Any] in items {
            if let item: NSMenuItem = buildMenuItem(from: entry, appMenuRoot: true) {
                appMenu.addItem(item)
            }
        }
        return mainMenu
    }

    private func buildMenuItem(
        from entry: [String: Any],
        appMenuRoot: Bool = false
    ) -> NSMenuItem? {
        let kind: String = (entry["kind"] as? String) ?? "command"
        if kind == "separator" {
            return NSMenuItem.separator()
        }
        let id: String = (entry["id"] as? String) ?? ""
        let label: String = (entry["label"] as? String) ?? ""
        let enabled: Bool = (entry["enabled"] as? Bool) ?? true
        let checked: Bool = (entry["checked"] as? Bool) ?? false
        let keyEquivalent: String = (entry["keyEquivalent"] as? String) ?? ""

        let item: NSMenuItem = NSMenuItem(
            title: label,
            action: nil,
            keyEquivalent: keyEquivalent
        )
        item.isEnabled = enabled
        item.state = checked ? NSControl.StateValue.on : NSControl.StateValue.off
        item.representedObject = appMenuRoot ? "app:\(id)" : id
        if let modifiers: [String] = entry["modifiers"] as? [String] {
            item.keyEquivalentModifierMask = parseModifiers(modifiers)
        }
        if let sfSymbol: String = entry["sfSymbol"] as? String,
           !sfSymbol.isEmpty,
           #available(macOS 11.0, *),
           let image: NSImage = NSImage(
               systemSymbolName: sfSymbol,
               accessibilityDescription: label
           ) {
            item.image = image
        }
        if kind == "submenu",
           let children: [[String: Any]] = entry["children"] as? [[String: Any]] {
            let submenu: NSMenu = NSMenu(title: label)
            for child: [String: Any] in children {
                if let childItem: NSMenuItem = buildMenuItem(
                    from: child,
                    appMenuRoot: appMenuRoot
                ) {
                    submenu.addItem(childItem)
                }
            }
            item.submenu = submenu
        } else {
            item.target = self
            item.action = #selector(handleMenuItemSelection(_:))
        }
        return item
    }

    private func parseModifiers(_ modifiers: [String]) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        for modifier: String in modifiers {
            switch modifier.lowercased() {
            case "cmd", "command":
                flags.insert(NSEvent.ModifierFlags.command)
            case "shift":
                flags.insert(NSEvent.ModifierFlags.shift)
            case "option", "alt":
                flags.insert(NSEvent.ModifierFlags.option)
            case "control", "ctrl":
                flags.insert(NSEvent.ModifierFlags.control)
            default:
                break
            }
        }
        return flags
    }

    @objc private func handleMenuItemSelection(_ sender: NSMenuItem) {
        let rawId: String = (sender.representedObject as? String) ?? ""
        if rawId.hasPrefix("app:") {
            let cleanId: String = String(rawId.dropFirst(4))
            os_log(
                "application menu selected: %{public}@",
                log: .alembicMenus,
                type: .info,
                cleanId
            )
            invokeAppMenuItem(id: cleanId)
            return
        }
        pendingSelection = rawId.isEmpty ? nil : rawId
        os_log(
            "context menu selected: %{public}@",
            log: .alembicMenus,
            type: .info,
            rawId
        )
    }

    private func invokeAppMenuItem(id: String) {
        channel?.invokeMethod(
            "onApplicationMenuItemSelected",
            arguments: ["id": id]
        )
    }
}
