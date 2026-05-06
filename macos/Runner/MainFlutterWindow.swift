import Cocoa
import FlutterMacOS
import LaunchAtLogin

class MainFlutterWindow: NSWindow {
  private let hostCornerRadius: CGFloat = 14
  private var hostGlassView: NSVisualEffectView?

  override func awakeFromNib() {
    self.orderOut(nil)
    let flutterViewController: FlutterViewController = FlutterViewController()
    let windowFrame: NSRect = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.appearance = NSAppearance(named: .aqua)

    self.isOpaque = false
    self.backgroundColor = NSColor.clear
    flutterViewController.backgroundColor = NSColor.clear
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    if #available(macOS 11.0, *) {
      self.titlebarSeparatorStyle = .none
    }
    self.hasShadow = false
    self.isMovableByWindowBackground = false

    self.contentView?.wantsLayer = true
    self.contentView?.layer?.backgroundColor = NSColor.clear.cgColor

    flutterViewController.view.wantsLayer = true
    flutterViewController.view.layer?.backgroundColor = NSColor.clear.cgColor

    if let flutterRootView: NSView = self.contentView {
      let glassView: NSVisualEffectView = NSVisualEffectView(frame: flutterRootView.bounds)
      glassView.autoresizingMask = [.width, .height]
      glassView.material = .underWindowBackground
      glassView.blendingMode = .behindWindow
      glassView.state = .active
      glassView.isEmphasized = false
      glassView.appearance = NSAppearance(named: .aqua)
      glassView.alphaValue = 1.0
      glassView.wantsLayer = true
      glassView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.10).cgColor
      glassView.layer?.cornerRadius = hostCornerRadius
      glassView.layer?.masksToBounds = true
      flutterRootView.addSubview(glassView, positioned: .below, relativeTo: nil)
      hostGlassView = glassView
    }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(_windowDidResize),
      name: NSWindow.didResizeNotification,
      object: self
    )
    _applyHostMask()

    FlutterMethodChannel(
      name: "launch_at_startup",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    .setMethodCallHandler { (_ call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "launchAtStartupIsEnabled":
        result(LaunchAtLogin.isEnabled)
      case "launchAtStartupSetEnabled":
        if let arguments: [String: Any] = call.arguments as? [String: Any] {
          LaunchAtLogin.isEnabled = arguments["setEnabledValue"] as! Bool
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let trayChannel: FlutterMethodChannel = FlutterMethodChannel(
      name: "alembic_tray",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    AlembicTrayController.shared.attach(window: self, channel: trayChannel)
    trayChannel.setMethodCallHandler { (_ call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "init":
        AlembicTrayController.shared.install()
        result(nil)
      case "dispose":
        AlembicTrayController.shared.dispose()
        result(nil)
      case "getBounds":
        result(AlembicTrayController.shared.bounds())
      case "setTooltip":
        let arguments: [String: Any]? = call.arguments as? [String: Any]
        let tooltip: String = (arguments?["tooltip"] as? String) ?? "Alembic"
        AlembicTrayController.shared.setTooltip(tooltip)
        result(nil)
      case "setActivationPolicy":
        let arguments: [String: Any]? = call.arguments as? [String: Any]
        let mode: String = (arguments?["mode"] as? String) ?? "accessory"
        AlembicTrayController.shared.setActivationPolicy(mode)
        result(nil)
      case "dumpFullDebug":
        result(AlembicTrayController.shared.dumpFullDebug())
      case "recreate":
        let arguments: [String: Any]? = call.arguments as? [String: Any]
        let activate: Bool = (arguments?["activate"] as? Bool) ?? true
        AlembicTrayController.shared.recreate(activate: activate)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
    self.orderOut(nil)
    DispatchQueue.main.async {
      self.orderOut(nil)
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func _windowDidResize(_ notification: Notification) {
    _applyHostMask()
  }

  private func _applyHostMask() {
    guard let rootView: NSView = self.contentView else {
      return
    }

    if let frameView: NSView = self.contentView?.superview {
      frameView.wantsLayer = true
      frameView.layer?.cornerRadius = hostCornerRadius
      frameView.layer?.masksToBounds = true
      frameView.layer?.borderWidth = 0
    }

    rootView.wantsLayer = true
    rootView.layer?.cornerRadius = hostCornerRadius
    rootView.layer?.masksToBounds = true
    rootView.layer?.borderWidth = 0

    if let hostGlassView: NSVisualEffectView = hostGlassView {
      hostGlassView.layer?.cornerRadius = hostCornerRadius
      hostGlassView.layer?.masksToBounds = true
      hostGlassView.layer?.borderWidth = 0
    }
  }
}
