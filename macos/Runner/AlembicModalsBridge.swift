import Cocoa
import FlutterMacOS
import SwiftUI
import os.log

private extension OSLog {
    static let alembicModals: OSLog = OSLog(
        subsystem: "art.arcane.alembic.modals",
        category: "bridge"
    )
}

final class AlembicModalsBridge: NSObject {
    static let shared: AlembicModalsBridge = AlembicModalsBridge()

    private weak var hostWindow: NSWindow?
    private var channel: FlutterMethodChannel?

    private override init() {
        super.init()
    }

    func attach(window: NSWindow, binaryMessenger: FlutterBinaryMessenger) {
        self.hostWindow = window
        let channel: FlutterMethodChannel = FlutterMethodChannel(
            name: "alembic_modals",
            binaryMessenger: binaryMessenger
        )
        self.channel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
        os_log(
            "AlembicModalsBridge attached",
            log: .alembicModals,
            type: .info
        )
    }

    private func handle(
        call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        switch call.method {
        case "showInfo":
            ensureMainThread {
                self.showInfo(arguments: call.arguments, result: result)
            }
        case "showConfirm":
            ensureMainThread {
                self.showConfirm(arguments: call.arguments, result: result)
            }
        case "showInput":
            ensureMainThread {
                self.showInput(arguments: call.arguments, result: result)
            }
        case "showCustom":
            ensureMainThread {
                self.showCustom(arguments: call.arguments, result: result)
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

    private func showInfo(arguments: Any?, result: @escaping FlutterResult) {
        let map: [String: Any] = (arguments as? [String: Any]) ?? [:]
        let title: String = (map["title"] as? String) ?? ""
        let message: String = (map["message"] as? String) ?? ""
        let closeLabel: String = (map["closeLabel"] as? String) ?? "Close"
        let style: String = (map["style"] as? String) ?? "sheet"

        guard let host: NSWindow = hostWindow else {
            performStandaloneAlert(
                style: NSAlert.Style.informational,
                title: title,
                message: message,
                buttons: [closeLabel]
            )
            result(nil)
            return
        }

        AlembicWindowBridge.shared.suspendHideOnBlur()
        let alert: NSAlert = makeAlert(
            style: NSAlert.Style.informational,
            title: title,
            message: message,
            buttons: [closeLabel]
        )
        let useSheet: Bool = (style == "sheet" || style == "popover")
            && host.isVisible
        if useSheet {
            alert.beginSheetModal(for: host) { _ in
                AlembicWindowBridge.shared.resumeHideOnBlur(ensureVisible: false)
                result(nil)
            }
        } else {
            alert.runModal()
            AlembicWindowBridge.shared.resumeHideOnBlur(ensureVisible: false)
            result(nil)
        }
    }

    private func showConfirm(arguments: Any?, result: @escaping FlutterResult) {
        let map: [String: Any] = (arguments as? [String: Any]) ?? [:]
        let title: String = (map["title"] as? String) ?? ""
        let description: String = (map["description"] as? String) ?? ""
        let confirmLabel: String = (map["confirmLabel"] as? String) ?? "Continue"
        let cancelLabel: String = (map["cancelLabel"] as? String) ?? "Cancel"
        let destructive: Bool = (map["destructive"] as? Bool) ?? false
        let style: String = (map["style"] as? String) ?? "sheet"

        AlembicWindowBridge.shared.suspendHideOnBlur()
        let alertStyle: NSAlert.Style = destructive
            ? NSAlert.Style.critical
            : NSAlert.Style.warning
        let alert: NSAlert = makeAlert(
            style: alertStyle,
            title: title,
            message: description,
            buttons: [confirmLabel, cancelLabel]
        )
        if destructive, #available(macOS 11.0, *) {
            alert.buttons.first?.hasDestructiveAction = true
        }

        let host: NSWindow? = hostWindow
        let useSheet: Bool = (style == "sheet" || style == "popover")
            && host?.isVisible == true

        if useSheet, let host: NSWindow = host {
            alert.beginSheetModal(for: host) { response in
                let confirmed: Bool = response == NSApplication.ModalResponse.alertFirstButtonReturn
                AlembicWindowBridge.shared.resumeHideOnBlur(ensureVisible: false)
                result(confirmed)
            }
        } else {
            let response: NSApplication.ModalResponse = alert.runModal()
            let confirmed: Bool = response == NSApplication.ModalResponse.alertFirstButtonReturn
            AlembicWindowBridge.shared.resumeHideOnBlur(ensureVisible: false)
            result(confirmed)
        }
    }

    private func showInput(arguments: Any?, result: @escaping FlutterResult) {
        let map: [String: Any] = (arguments as? [String: Any]) ?? [:]
        let title: String = (map["title"] as? String) ?? ""
        let description: String = (map["description"] as? String) ?? ""
        let placeholder: String = (map["placeholder"] as? String) ?? ""
        let confirmLabel: String = (map["confirmLabel"] as? String) ?? "Save"
        let cancelLabel: String = (map["cancelLabel"] as? String) ?? "Cancel"
        let initialValue: String = (map["initialValue"] as? String) ?? ""
        let secure: Bool = (map["secure"] as? Bool) ?? false
        let multiline: Bool = (map["multiline"] as? Bool) ?? false
        let style: String = (map["style"] as? String) ?? "sheet"

        AlembicWindowBridge.shared.suspendHideOnBlur()
        let alert: NSAlert = makeAlert(
            style: NSAlert.Style.informational,
            title: title,
            message: description,
            buttons: [confirmLabel, cancelLabel]
        )
        let accessory: NSView = makeInputAccessory(
            placeholder: placeholder,
            initialValue: initialValue,
            secure: secure,
            multiline: multiline
        )
        alert.accessoryView = accessory
        alert.window.initialFirstResponder = accessory.subviews.first

        let host: NSWindow? = hostWindow
        let useSheet: Bool = (style == "sheet" || style == "popover")
            && host?.isVisible == true

        if useSheet, let host: NSWindow = host {
            alert.beginSheetModal(for: host) { [weak self] response in
                let value: String? = self?.extractInputValue(from: accessory)
                AlembicWindowBridge.shared.resumeHideOnBlur(ensureVisible: false)
                result(response == NSApplication.ModalResponse.alertFirstButtonReturn ? value : nil)
            }
        } else {
            let response: NSApplication.ModalResponse = alert.runModal()
            let value: String? = extractInputValue(from: accessory)
            AlembicWindowBridge.shared.resumeHideOnBlur(ensureVisible: false)
            result(response == NSApplication.ModalResponse.alertFirstButtonReturn ? value : nil)
        }
    }

    private func showCustom(arguments: Any?, result: @escaping FlutterResult) {
        let map: [String: Any] = (arguments as? [String: Any]) ?? [:]
        let title: String = (map["title"] as? String) ?? ""
        let description: String? = map["description"] as? String
        let fields: [[String: Any]] = (map["fields"] as? [[String: Any]]) ?? []
        let buttons: [[String: Any]] = (map["buttons"] as? [[String: Any]]) ?? []
        let style: String = (map["style"] as? String) ?? "sheet"

        AlembicWindowBridge.shared.suspendHideOnBlur()
        let alert: NSAlert = NSAlert()
        alert.messageText = title
        alert.informativeText = description ?? ""
        alert.alertStyle = NSAlert.Style.informational

        var buttonOrder: [String] = []
        if buttons.isEmpty {
            alert.addButton(withTitle: "OK")
            buttonOrder.append("__ok__")
        } else {
            for entry: [String: Any] in buttons {
                let label: String = (entry["label"] as? String) ?? "Button"
                let id: String = (entry["id"] as? String) ?? label
                let role: String = (entry["role"] as? String) ?? "normal"
                let button: NSButton = alert.addButton(withTitle: label)
                buttonOrder.append(id)
                if role == "destructive", #available(macOS 11.0, *) {
                    button.hasDestructiveAction = true
                }
                if (entry["isDefault"] as? Bool) == true {
                    alert.window.defaultButtonCell = button.cell as? NSButtonCell
                }
            }
        }

        var fieldViews: [(String, NSView)] = []
        if !fields.isEmpty {
            let stack: NSStackView = NSStackView()
            stack.orientation = NSUserInterfaceLayoutOrientation.vertical
            stack.alignment = NSLayoutConstraint.Attribute.leading
            stack.spacing = 6
            stack.translatesAutoresizingMaskIntoConstraints = false
            for entry: [String: Any] in fields {
                let id: String = (entry["id"] as? String) ?? "field"
                let placeholder: String = (entry["placeholder"] as? String) ?? ""
                let initialValue: String = (entry["initialValue"] as? String) ?? ""
                let secure: Bool = (entry["secure"] as? Bool) ?? false
                let multiline: Bool = (entry["multiline"] as? Bool) ?? false
                let view: NSView = makeFieldView(
                    placeholder: placeholder,
                    initialValue: initialValue,
                    secure: secure,
                    multiline: multiline
                )
                stack.addArrangedSubview(view)
                fieldViews.append((id, view))
            }
            let wrapper: NSView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 0))
            wrapper.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
                stack.topAnchor.constraint(equalTo: wrapper.topAnchor),
                stack.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            ])
            wrapper.frame = NSRect(
                x: 0,
                y: 0,
                width: 320,
                height: CGFloat(fields.count) * 32
            )
            alert.accessoryView = wrapper
            alert.window.initialFirstResponder = fieldViews.first?.1
        }

        let host: NSWindow? = hostWindow
        let useSheet: Bool = (style == "sheet" || style == "popover")
            && host?.isVisible == true

        let resolveResult: (NSApplication.ModalResponse) -> Any? = { response in
            let index: Int = Int(response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue)
            let buttonId: String?
            if index >= 0 && index < buttonOrder.count {
                buttonId = buttonOrder[index]
            } else {
                buttonId = nil
            }
            var values: [String: String] = [:]
            for (id, view): (String, NSView) in fieldViews {
                if let value: String = self.extractValueFromField(view: view) {
                    values[id] = value
                }
            }
            return [
                "buttonId": buttonId as Any,
                "cancelled": buttonId == nil,
                "values": values,
            ]
        }

        if useSheet, let host: NSWindow = host {
            alert.beginSheetModal(for: host) { response in
                AlembicWindowBridge.shared.resumeHideOnBlur(ensureVisible: false)
                result(resolveResult(response))
            }
        } else {
            let response: NSApplication.ModalResponse = alert.runModal()
            AlembicWindowBridge.shared.resumeHideOnBlur(ensureVisible: false)
            result(resolveResult(response))
        }
    }

    private func makeAlert(
        style: NSAlert.Style,
        title: String,
        message: String,
        buttons: [String]
    ) -> NSAlert {
        let alert: NSAlert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        for label: String in buttons {
            alert.addButton(withTitle: label)
        }
        return alert
    }

    private func performStandaloneAlert(
        style: NSAlert.Style,
        title: String,
        message: String,
        buttons: [String]
    ) {
        let alert: NSAlert = makeAlert(
            style: style,
            title: title,
            message: message,
            buttons: buttons
        )
        alert.runModal()
    }

    private func makeInputAccessory(
        placeholder: String,
        initialValue: String,
        secure: Bool,
        multiline: Bool
    ) -> NSView {
        return makeFieldView(
            placeholder: placeholder,
            initialValue: initialValue,
            secure: secure,
            multiline: multiline,
            width: 320
        )
    }

    private func makeFieldView(
        placeholder: String,
        initialValue: String,
        secure: Bool,
        multiline: Bool,
        width: CGFloat = 280
    ) -> NSView {
        let height: CGFloat = multiline ? 80 : 24
        let frame: NSRect = NSRect(x: 0, y: 0, width: width, height: height)
        if multiline {
            let scroll: NSScrollView = NSScrollView(frame: frame)
            scroll.borderType = NSBorderType.bezelBorder
            scroll.hasVerticalScroller = true
            let text: NSTextView = NSTextView(frame: NSRect(
                x: 0,
                y: 0,
                width: width,
                height: height
            ))
            text.isRichText = false
            text.isAutomaticQuoteSubstitutionEnabled = false
            text.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            text.string = initialValue
            scroll.documentView = text
            scroll.identifier = NSUserInterfaceItemIdentifier("alembic.field.multiline")
            return scroll
        }
        if secure {
            let field: NSSecureTextField = NSSecureTextField(frame: frame)
            field.placeholderString = placeholder
            field.stringValue = initialValue
            field.identifier = NSUserInterfaceItemIdentifier("alembic.field.secure")
            return field
        }
        let field: NSTextField = NSTextField(frame: frame)
        field.placeholderString = placeholder
        field.stringValue = initialValue
        field.identifier = NSUserInterfaceItemIdentifier("alembic.field.text")
        return field
    }

    private func extractInputValue(from view: NSView) -> String? {
        return extractValueFromField(view: view)
    }

    private func extractValueFromField(view: NSView) -> String? {
        if let scroll: NSScrollView = view as? NSScrollView,
           let text: NSTextView = scroll.documentView as? NSTextView {
            return text.string
        }
        if let field: NSTextField = view as? NSTextField {
            return field.stringValue
        }
        return nil
    }
}
