import Cocoa
import FlutterMacOS
import LaunchAtLogin
import SwiftUI

final class AlembicHostingView<Content: View>: NSHostingView<Content> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    return true
  }

  override var mouseDownCanMoveWindow: Bool {
    return false
  }
}

final class AlembicHostingController<Content: View>: NSHostingController<Content> {
  override func loadView() {
    view = AlembicHostingView(rootView: rootView)
  }
}

class MainFlutterWindow: NSWindow {
  private let hostCornerRadius: CGFloat = 22
  private var backdropView: AlembicGlassBackdrop?
  private var flutterEngine: FlutterEngine?

  override var canBecomeKey: Bool {
    return true
  }

  override var canBecomeMain: Bool {
    return true
  }

  override func awakeFromNib() {
    self.orderOut(nil)

    self.isReleasedWhenClosed = false
    self.hidesOnDeactivate = false
    self.level = .floating
    self.collectionBehavior.insert(.moveToActiveSpace)
    self.collectionBehavior.insert(.fullScreenAuxiliary)
    self.collectionBehavior.insert(.transient)
    self.isOpaque = false
    self.backgroundColor = NSColor.clear
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.styleMask.remove(.titled)
    self.styleMask.remove(.closable)
    self.styleMask.remove(.miniaturizable)
    if #available(macOS 11.0, *) {
      self.titlebarSeparatorStyle = .none
    }
    self.hasShadow = false
    self.isMovable = false
    self.isMovableByWindowBackground = false
    self.contentMinSize = NSSize(width: 960, height: 620)
    _hideTrafficLights()

    self.contentView?.wantsLayer = true
    self.contentView?.layer?.backgroundColor = NSColor.clear.cgColor

    _installNativeUi()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(_windowDidResize),
      name: NSWindow.didResizeNotification,
      object: self
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(_windowResetPositionRequested),
      name: AlembicWindowPreferences.resetPositionNotification,
      object: nil
    )
    _applyHostMask()

    super.awakeFromNib()
    self.orderOut(nil)
    DispatchQueue.main.async {
      self._hideTrafficLights()
      self.orderOut(nil)
    }
  }

  override func close() {
    AlembicTrayController.shared.hideWindow()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    flutterEngine?.shutDownEngine()
    flutterEngine = nil
  }

  private func _installNativeUi() {
    NSLog("[Alembic] Launching native SwiftUI UI with headless Flutter engine")

    let engine: FlutterEngine = FlutterEngine(name: "alembic", project: nil)
    let started: Bool = engine.run(withEntrypoint: nil)
    if !started {
      NSLog("[Alembic] FlutterEngine.run() returned false")
    }
    RegisterGeneratedPlugins(registry: engine)
    flutterEngine = engine

    let messenger: FlutterBinaryMessenger = engine.binaryMessenger

    let rootView: AlembicSpikeRootView = AlembicSpikeRootView(
      state: AlembicSpikeBridge.shared.state,
      repositoryState: AlembicRepositoryListBridge.shared.state,
      diagnosticsState: AlembicDiagnosticsBridge.shared.state,
      workspaceState: AlembicWorkspaceBridge.shared.state,
      workState: AlembicRepositoryWorkBridge.shared.state,
      settingsState: AlembicSettingsBridge.shared.state,
      accountsState: AlembicAccountsBridge.shared.state,
      onRepositoryRefresh: {
        AlembicRepositoryListBridge.shared.refresh()
      },
      onRepositoryRetry: {
        AlembicRepositoryListBridge.shared.retry()
      },
      onRepositoryOpen: { url in
        AlembicRepositoryListBridge.shared.openInBrowser(url)
      }
    )

    let hostingController: AlembicHostingController<AlembicSpikeRootView> = AlembicHostingController(rootView: rootView)
    hostingController.view.wantsLayer = true
    hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor

    self.contentViewController = hostingController

    if let rootContent: NSView = self.contentView {
      let backdrop: AlembicGlassBackdrop = AlembicGlassBackdrop(
        frame: rootContent.bounds,
        cornerRadius: hostCornerRadius
      )
      rootContent.addSubview(backdrop, positioned: .below, relativeTo: nil)
      backdropView = backdrop
    }

    _attachBridges(messenger: messenger)
  }

  private func _attachBridges(messenger: FlutterBinaryMessenger) {
    AlembicDiagnosticsBridge.shared.attach(messenger: messenger)
    AlembicSpikeBridge.shared.attach(messenger: messenger)
    AlembicRepositoryListBridge.shared.attach(messenger: messenger)
    AlembicWorkspaceBridge.shared.attach(messenger: messenger)
    AlembicWorkspaceBridge.shared.setHostWindow(self)
    AlembicRepositoryActionsBridge.shared.attach(messenger: messenger)
    AlembicRepositoryWorkBridge.shared.attach(messenger: messenger)
    AlembicAccountsBridge.shared.attach(messenger: messenger)
    AlembicSettingsBridge.shared.attach(messenger: messenger)
    AlembicUpdatesBridge.shared.attach(messenger: messenger)
    AlembicWindowBridge.shared.attach(
      window: self,
      backdrop: backdropView,
      binaryMessenger: messenger
    )
    AlembicModalsBridge.shared.attach(
      window: self,
      binaryMessenger: messenger
    )
    AlembicMenusBridge.shared.attach(
      window: self,
      binaryMessenger: messenger
    )

    FlutterMethodChannel(
      name: "launch_at_startup",
      binaryMessenger: messenger
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
      binaryMessenger: messenger
    )
    AlembicTrayController.shared.attach(window: self, channel: trayChannel)
    trayChannel.setMethodCallHandler { (_ call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "init":
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
  }

  @objc private func _windowDidResize(_ notification: Notification) {
    _applyHostMask()
  }

  @objc private func _windowResetPositionRequested(_ notification: Notification) {
    AlembicTrayController.shared.repositionAtDefault()
  }

  private func _applyHostMask() {
    if let frameView: NSView = self.contentView?.superview {
      frameView.wantsLayer = true
      frameView.layer?.cornerRadius = hostCornerRadius
      frameView.layer?.masksToBounds = true
      frameView.layer?.borderWidth = 0
    }
  }

  private func _hideTrafficLights() {
    let buttonTypes: [NSWindow.ButtonType] = [
      .closeButton,
      .miniaturizeButton,
      .zoomButton,
    ]
    for buttonType: NSWindow.ButtonType in buttonTypes {
      if let button: NSButton = self.standardWindowButton(buttonType) {
        button.isHidden = true
        button.isEnabled = false
        button.alphaValue = 0
      }
    }
  }
}
