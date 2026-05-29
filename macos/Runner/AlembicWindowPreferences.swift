import AppKit
import Foundation
import SwiftUI

final class AlembicWindowPreferences: ObservableObject {
    static let shared: AlembicWindowPreferences = AlembicWindowPreferences()
    static let pinDefaultsKey: String = "alembic.window.pin"
    static let movableDefaultsKey: String = "alembic.window.movable"
    static let resetPositionNotification: Notification.Name = Notification.Name("alembic.window.resetPosition")
    static let windowDragNotification: Notification.Name = Notification.Name("alembic.window.drag")

    @Published private(set) var pinWindow: Bool
    @Published private(set) var movableWindow: Bool

    private init() {
        let defaults: UserDefaults = UserDefaults.standard
        if defaults.object(forKey: AlembicWindowPreferences.pinDefaultsKey) == nil {
            self.pinWindow = false
        } else {
            self.pinWindow = defaults.bool(forKey: AlembicWindowPreferences.pinDefaultsKey)
        }
        if defaults.object(forKey: AlembicWindowPreferences.movableDefaultsKey) == nil {
            self.movableWindow = false
        } else {
            self.movableWindow = defaults.bool(forKey: AlembicWindowPreferences.movableDefaultsKey)
        }
    }

    func setPinWindow(_ value: Bool) {
        guard value != pinWindow else {
            return
        }
        pinWindow = value
        UserDefaults.standard.set(value, forKey: AlembicWindowPreferences.pinDefaultsKey)
    }

    func setMovableWindow(_ value: Bool) {
        guard value != movableWindow else {
            return
        }
        movableWindow = value
        UserDefaults.standard.set(value, forKey: AlembicWindowPreferences.movableDefaultsKey)
    }

    func requestResetPosition() {
        NotificationCenter.default.post(name: AlembicWindowPreferences.resetPositionNotification, object: nil)
    }

    static func dragMainWindow(by translation: CGSize, fromStart startOrigin: CGPoint) {
        guard let window: NSWindow = NSApplication.shared.windows.first(where: { $0 is MainFlutterWindow }) else {
            return
        }
        let newOrigin: CGPoint = CGPoint(
            x: startOrigin.x + translation.width,
            y: startOrigin.y - translation.height
        )
        window.setFrameOrigin(newOrigin)
    }

    static func currentMainWindowOrigin() -> CGPoint? {
        return NSApplication.shared.windows.first(where: { $0 is MainFlutterWindow })?.frame.origin
    }
}
