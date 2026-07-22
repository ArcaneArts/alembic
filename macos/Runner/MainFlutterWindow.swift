import Cocoa
import FlutterMacOS
import LaunchAtLogin

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    self.orderOut(nil)
    let flutterViewController: FlutterViewController = FlutterViewController()
    let windowFrame: NSRect = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

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
          if let enabled: Bool = arguments["setEnabledValue"] as? Bool {
            LaunchAtLogin.isEnabled = enabled
          }
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
}
