import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var alembicActivity: NSObjectProtocol?

  override func applicationWillFinishLaunching(_ notification: Notification) {
    AlembicTrayController.shared.install()
    NSApp.disableRelaunchOnLogin()
    alembicActivity = ProcessInfo.processInfo.beginActivity(
      options: [.automaticTerminationDisabled],
      reason: "Alembic menu bar"
    )
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    AlembicTrayController.shared.install()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
