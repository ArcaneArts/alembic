# macOS Tray / Menu Bar Lifecycle Redesign

## Objective

Make the Alembic macOS menu bar (status bar) icon appear reliably on every launch and behave like a polished tray-first app: the status item shows up immediately, left-click toggles the window near the icon, right-click opens a context menu, and the lifecycle is deterministic with no scheduled re-assertions or race conditions.

## Background and Diagnosis

The current macOS implementation lives in two places:

- `macos/Runner/MainFlutterWindow.swift:138-264` defines `AlembicMenuBar.shared` as the `NSStatusItem` host.
- `macos/Runner/AppDelegate.swift:1-30` calls `AlembicMenuBar.shared.install()` in `applicationDidFinishLaunching` and then `scheduleLaunchReassertions()` to repeatedly re-install on a timer.

The Dart side at `lib/util/window.dart:159-191` short-circuits `initSystemTray()` for macOS and falls back to native code, with `lib/platform/macos_menu_bar.dart:1-30` only providing a `getBounds` accessor through the `alembic_menu_bar` method channel.

The status item never reliably appears in the macOS menu bar. Confirmed and suspected root causes:

1. **Lifecycle is split across two Swift files in the wrong order.** `MainFlutterWindow.awakeFromNib` calls `alembicMenuBar.configure(window: self)` at `macos/Runner/MainFlutterWindow.swift:79`, which then calls `refresh()` while `statusItem` is still `nil`. The actual install runs later in `applicationDidFinishLaunching`. The configure → install → refresh ordering is fragile and not deterministic across debug vs release vs cold-launch.
2. **Repeated `setActivationPolicy(.accessory)` calls.** `applicationWillFinishLaunching`, `applicationDidFinishLaunching`, and four delayed closures in `scheduleLaunchReassertions` all call `setActivationPolicy(.accessory)`. Apple documents that toggling activation policy after launch can cause status items to flicker or be lost. The scheduled re-assertions are a band-aid that masks the underlying timing bug rather than fixing it.
3. **SF Symbol sizing without `SymbolConfiguration`.** `iconImage()` at `macos/Runner/MainFlutterWindow.swift:223-242` does `symbol.size = NSSize(width: 18, height: 18)` on a system symbol. SF Symbols are vector glyphs whose size is normally derived from font metrics; setting `.size` directly produces inconsistent rendering and can render at zero size on some systems, leaving an empty button.
4. **`statusItem.menu` is set unconditionally.** `refresh()` does `statusItem.menu = makeMenu()` at `macos/Runner/MainFlutterWindow.swift:180`. Once a menu is attached to a status item, ANY click (left or right) pops the menu. There is no left-click-to-toggle-window UX path available in the current code.
5. **Bounds calculation uses `NSScreen.main` instead of the menu-bar screen.** `bounds()` at `macos/Runner/MainFlutterWindow.swift:201-212` inverts y against `NSScreen.main`, but on multi-display setups the menu bar is on the screen the user has chosen as the menu-bar screen, which may not be `.main`. This produces wrong window placement on multi-monitor rigs and makes the popup window land off-screen, which can be misread as "the icon is not there" because clicking does nothing visible.
6. **`ArcaneWindow.onClose` quits Alembic on macOS.** `arcane_desktop-2.1.0/lib/arcane_desktop.dart:87` resolves `AWM.tray != null ? hide() : destroy().then((_) => exit(0))`. Because `lib/main.dart:41-43` only assigns `AWM.tray` on non-macOS platforms, a macOS close-button click destroys the window and exits the process. Even with a native menu bar this means hitting the red dot quits the app, defeating the tray-first model. Independent from the icon-not-showing bug but must be fixed in this redesign.
7. **`tray_manager` plugin is still registered on macOS.** `macos/Flutter/GeneratedPluginRegistrant.swift:31` registers `TrayManagerPlugin` even though Dart never calls into it on macOS. The plugin only allocates state lazily on first call, so this is mostly inert; we will leave the plugin registered (Dart still uses it on Windows) but make sure no macOS code path tries to invoke it.
8. **No diagnostic logging.** There is no way to tell at runtime whether `install()` ran, whether the button got an image, or whether the status item was reaped. Adding `os_log` instrumentation early in this redesign will turn the next round of debugging into a one-shot read.
9. **Bundle identifier is the Flutter scaffolding default `com.example.alembic`** at `macos/Runner/Configs/AppInfo.xcconfig:11`. macOS persists Login Items and `LSUIElement` behavior per bundle ID. Stale state under the default ID can cause unexpected behavior on some systems. Out of scope for the bug fix itself, but tracked here for a follow-up.

## Architecture Target

A single-source-of-truth Swift controller `AlembicTrayController` in its own file:

- Owns the `NSStatusItem` for the entire app lifetime.
- Installs exactly once during `applicationDidFinishLaunching`, guarded by main-thread enforcement.
- Sets `NSApp.setActivationPolicy(.accessory)` exactly once, only in `applicationWillFinishLaunching`.
- Loads the icon via a robust waterfall: bundle PNG resource (`tray.png` copied into `Contents/Resources`) → SF Symbol with `SymbolConfiguration` → drawn `NSImage` fallback. Always template-rendered so macOS handles light/dark.
- Drives click behavior through the button's `target`/`action` rather than `statusItem.menu`, allowing left-click → toggle window, right-click → open context menu.
- Bridges to Dart via `MethodChannel` named `alembic_tray` with explicit verbs and named callbacks instead of bounds-only reads.
- Returns bounds in Flutter global coordinates using the screen the status button actually resides on.
- Tears down cleanly when the app enters window mode (`WINDOW_MODE` flag) and switches the activation policy back to `.regular` if the user opts out at runtime.

The Dart side consolidates into `lib/platform/macos_tray_service.dart` (replaces `lib/platform/macos_menu_bar.dart`) and exposes `MacOSTrayService.instance` with `init`, `dispose`, `setTooltip`, `getBounds`, plus a stream of tray events. `lib/util/window.dart` switches the macOS branch in `initSystemTray()` to call this service. The hide-on-blur listener and window positioning logic stay in `WindowUtil`.

`AWM.tray` is set to a non-null sentinel value on macOS so `ArcaneWindow.onClose` falls into the hide-instead-of-quit branch. We achieve this without modifying the third-party `arcane_desktop` package by assigning the existing global `trayManager` reference even on macOS; on macOS, no Dart code calls into `trayManager`, so the assignment is functionally a flag and harmless.

## Execution Status

### Phase 1 — Native Tray Controller Skeleton

- [x] Create `macos/Runner/AlembicTrayController.swift` with a singleton `AlembicTrayController.shared`.
- [x] Define stored properties: `private var statusItem: NSStatusItem?`, `private weak var window: NSWindow?`, `private var eventChannel: FlutterMethodChannel?`, `private var isInstalled: Bool = false`.
- [x] Add a private `init()` and a `static let shared = AlembicTrayController()`.
- [x] Add `os_log` subsystem `art.arcane.alembic.tray` and category `lifecycle`.
- [x] Add `func attach(window: NSWindow, channel: FlutterMethodChannel)` that stores the references and logs.
- [x] Add `func install()` that creates `statusItem` if `isInstalled == false`, with `length: NSStatusItem.variableLength`, sets `isVisible = true`, sets `behavior = []`, configures icon and click handlers, then logs install success.
- [x] Add `func dispose()` that nils out the status item via `NSStatusBar.system.removeStatusItem(_:)`, sets `isInstalled = false`, and logs.
- [x] Remove `AlembicMenuBar` class from `macos/Runner/MainFlutterWindow.swift:138-264` after callers are migrated.
- [x] Verify `swift build` (via `flutter build macos --debug`) succeeds.

### Phase 2 — Deterministic Lifecycle Wiring

- [x] In `macos/Runner/AppDelegate.swift:8-15`, keep `applicationWillFinishLaunching` to: set `.accessory` once, call `disableRelaunchOnLogin()`, begin the activity token. Do not install the tray here.
- [x] In `macos/Runner/AppDelegate.swift:17-21`, replace `applicationDidFinishLaunching` body with a single call to `AlembicTrayController.shared.install()` after a guard that confirms `Thread.isMainThread`.
- [x] Delete `scheduleLaunchReassertions` invocation and method.
- [x] Delete the redundant `NSApp.setActivationPolicy(.accessory)` call inside `applicationDidFinishLaunching`.
- [x] Move `AlembicTrayController.shared.attach(window:channel:)` into `MainFlutterWindow.awakeFromNib` immediately after the `FlutterMethodChannel(name: "alembic_tray", ...)` is created, replacing the existing `alembicMenuBar.configure(window: self)` and `alembic_menu_bar` channel block at `macos/Runner/MainFlutterWindow.swift:79-94`.
- [x] Verify by running `flutter run -d macos` that the status item appears within 250 ms of launch with no scheduled re-assertions in the codebase.

### Phase 3 — Icon Loading Waterfall

- [x] Add an Xcode build phase or `Bundle Resources` reference so `assets/tray.png` is copied into `alembic.app/Contents/Resources/tray.png` at build time. Update `macos/Runner.xcodeproj/project.pbxproj` to reference the asset (do this through Xcode's GUI in `Build Phases → Copy Bundle Resources` if pbxproj editing is fragile, or use a Run Script phase that copies from `${SRCROOT}/../assets/tray.png` to `${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/tray.png`).
- [x] Add a private `func loadIconImage() -> NSImage` to `AlembicTrayController` that:
  - Tries `Bundle.main.image(forResource: NSImage.Name("tray"))`, sets `isTemplate = true`, returns it if non-nil.
  - Falls back to `NSImage(systemSymbolName: "shippingbox.fill", accessibilityDescription: "Alembic")` with `withSymbolConfiguration(.init(pointSize: 14, weight: .medium))`, `isTemplate = true`.
  - Final fallback: a manually-drawn 18×18 monogram `NSImage` using `NSGraphicsContext` and `NSAttributedString.draw`, `isTemplate = true`.
- [x] In `install()`, set `button.image = loadIconImage()`, `button.imagePosition = .imageOnly`, `button.imageScaling = .scaleProportionallyDown`, `button.toolTip = "Alembic"`.
- [x] Verify each fallback path manually by temporarily renaming `tray.png` and the SF Symbol name in a scratch branch (do not commit the rename).

### Phase 4 — Click Behavior Split

- [x] In `install()`, set `statusItem.menu = nil` (do not attach a menu to the item itself).
- [x] Set `button.target = self`, `button.action = #selector(handleStatusItemClick(_:))`.
- [x] Set `button.sendAction(on: [.leftMouseUp, .rightMouseUp])`.
- [x] Implement `@objc private func handleStatusItemClick(_ sender: NSStatusBarButton)`:
  - Read `NSApp.currentEvent`.
  - For `.rightMouseUp` or for `.leftMouseUp` with `event.modifierFlags.contains(.control)`, call `popUpContextMenu()`.
  - For `.leftMouseUp` with no modifier, send `onLeftClick` over the `alembic_tray` channel and let Dart handle window toggle.
- [x] Implement `private func popUpContextMenu()` that builds an `NSMenu` with `Show Alembic`, `Hide Alembic`, separator, `Open Settings`, `Check for Updates`, separator, `Quit Alembic`, attaches it to `statusItem.menu`, calls `statusItem.button?.performClick(nil)` to display, then sets `statusItem.menu = nil` again so the next bare left-click stays a click. Log each menu pop.
- [x] Wire menu item targets to private `@objc` selectors that send `onMenuItem` events with a `key` argument over the channel.

### Phase 5 — Method Channel `alembic_tray`

- [x] Replace channel name `alembic_menu_bar` in `macos/Runner/MainFlutterWindow.swift:80-94` with `alembic_tray`.
- [x] Implement these inbound (Dart → Swift) methods inside the channel handler:
  - `init` → `AlembicTrayController.shared.install()`, returns `nil`.
  - `dispose` → `AlembicTrayController.shared.dispose()`, returns `nil`.
  - `getBounds` → returns `[String: Double]?` using the new screen-aware bounds calculation from Phase 7.
  - `setTooltip` → updates `button.toolTip` from `arguments["tooltip"] as? String`.
  - `setActivationPolicy` → `arguments["mode"]` of `"accessory"` or `"regular"` toggles `NSApp.setActivationPolicy(_:)`.
- [x] Implement these outbound (Swift → Dart) invocations:
  - `onLeftClick` (no payload).
  - `onMenuItem` with `{ "key": String }` payload.
- [x] Delete `lib/platform/macos_menu_bar.dart` after the new service replaces it.
- [x] Create `lib/platform/macos_tray_service.dart` exposing `MacOSTrayService.instance` with:
  - `Future<void> init()` invokes `init`.
  - `Future<void> dispose()` invokes `dispose`.
  - `Future<Rect?> getBounds()` invokes `getBounds` and converts the map to `Rect`.
  - `Future<void> setTooltip(String tooltip)`.
  - `Future<void> setActivationPolicy(String mode)`.
  - `Stream<MacOSTrayEvent> events` exposed via `BehaviorSubject` from `rxdart`, with subtypes `MacOSTrayLeftClick` and `MacOSTrayMenuItem(key)`.
- [x] Update `lib/util/window.dart:159-191` so the macOS branch calls `MacOSTrayService.instance.init()` and subscribes to events, mapping `onLeftClick` to `WindowUtil.show()` and `onMenuItem` keys (`show`, `hide`, `settings`, `update`, `exit`) to the appropriate handlers.
- [x] Update the macOS `_positionNearTray` call in `lib/util/window.dart:320-352` to use `MacOSTrayService.instance.getBounds()` instead of `MacOSMenuBar.getBounds()`.

### Phase 6 — `AWM.tray` Sentinel for macOS

- [x] Update `lib/main.dart:41-43` to set `AWM.tray = trayManager` for both Windows and macOS so that `ArcaneWindow.onClose` resolves to `windowManager.hide()` on macOS.
- [x] Verify `WindowUtil.hide()` is the correct implementation called when the close button is pressed; if `arcane_desktop` calls `windowManager.hide()` directly, follow up with a `setSkipTaskbar`/policy adjustment so macOS does not animate the window away with a dock-bounce.
- [x] Confirm that on Windows nothing changes (the assignment was already there).

### Phase 7 — Multi-Display Bounds Calculation

- [x] Replace the body of `bounds()` in `AlembicTrayController` with logic that resolves the screen as `statusItem?.button?.window?.screen ?? NSScreen.screens.first ?? NSScreen.main`.
- [x] Compute the screen frame in the Cocoa global coordinate space (`screen.frame`) and invert the button frame's y as `screen.frame.maxY - frame.maxY` to translate to Flutter's top-left global space.
- [x] Return `[ "x": frame.minX, "y": flippedY, "width": frame.width, "height": frame.height ]` as `[String: Double]`.
- [~] Re-test `_positionForTrayBounds` in `lib/util/window.dart:435-478` on a multi-monitor setup.

### Phase 8 — Window Mode Bypass

- [x] In `lib/util/window.dart:159-191`, when `windowMode == true`, skip `MacOSTrayService.instance.init()` AND call `MacOSTrayService.instance.setActivationPolicy("regular")` so the user gets a normal dockable app.
- [x] In `AlembicTrayController.install()`, add an early return logging path for "already installed" so the call is idempotent.
- [~] Add a manual smoke test: create the marker file `~/Documents/Alembic/WINDOW_MODE`, relaunch, and verify Alembic shows in the dock and behaves like a regular Cocoa app with no menu bar item.

### Phase 9 — Diagnostic Logging

- [x] Add `os_log(.info, log: .alembicTray, "%{public}@", message)` at install start, install success, install failure, dispose, click events, menu pop, and bounds requests.
- [x] Mirror the same lines into Flutter's `fast_log` via the channel so the developer log file at `${configPath}/alembic.log` includes tray events.
- [x] Document how to tail logs at runtime: `log stream --predicate 'subsystem == "art.arcane.alembic.tray"'`.

### Phase 10 — Build, Lint, and Smoke Tests

- [x] Run `dart format lib/main.dart lib/util/window.dart lib/platform/macos_tray_service.dart`.
- [x] Run `flutter analyze` and resolve every diagnostic in changed files.
- [x] Run `flutter pub get`.
- [x] Run `flutter build macos --debug` to confirm the project compiles.
- [~] Manually verify on a clean macOS user account:
  - Status item appears within 250 ms of launch.
  - Left-click opens the Alembic window adjacent to the status item.
  - Right-click pops the context menu.
  - Selecting `Show Alembic` from the menu shows the window.
  - Selecting `Hide Alembic` hides the window.
  - Selecting `Quit Alembic` terminates the process.
  - Closing the window with the red traffic-light hides instead of quitting.
  - Window appears on the same display as the status item on multi-monitor setups.
  - Cold launch on Apple Silicon and Intel both succeed.
  - Cold launch with `WINDOW_MODE` marker present puts Alembic in the dock with no status item.

### Phase 11 — Follow-up Hygiene (Optional, Not Required for Fix)

- [ ] Replace the placeholder `PRODUCT_BUNDLE_IDENTIFIER = com.example.alembic` in `macos/Runner/Configs/AppInfo.xcconfig:11` with a project-owned identifier such as `art.arcane.alembic`. Coordinate with codesigning and `launch_at_login` Login Items entries.
- [ ] Update `PRODUCT_NAME` from `alembic` to `Alembic` if the user wants the bundle name capitalized in Finder.
- [ ] Audit `macos/Pods/` for any version pins that block macOS 14 features and bump as needed.
- [ ] Remove the now-unused `tray_manager` macOS pod registration if no Dart path on macOS uses it (still required for Windows; only remove from macOS GeneratedPluginRegistrant if Flutter tooling allows).

## Files Affected

- `macos/Runner/AlembicTrayController.swift` (new)
- `macos/Runner/AppDelegate.swift` (lifecycle simplification)
- `macos/Runner/MainFlutterWindow.swift` (remove `AlembicMenuBar`, replace channel name and wiring)
- `macos/Runner.xcodeproj/project.pbxproj` (add new Swift file, possibly add Run Script phase)
- `lib/platform/macos_tray_service.dart` (new)
- `lib/platform/macos_menu_bar.dart` (delete)
- `lib/util/window.dart` (route macOS through new service)
- `lib/main.dart` (set `AWM.tray` for macOS)
- `plans/2026-05-06-macos-tray-lifecycle-redesign-v1.md` (this file)

## Verification Criteria

A successful execution of this plan must satisfy all of:

1. The macOS status bar item is visible within 500 ms of `flutter run -d macos` cold launch on a fresh user account.
2. There are zero references to `scheduleLaunchReassertions`, `AlembicMenuBar`, or repeated `setActivationPolicy(.accessory)` calls in the codebase.
3. Left-clicking the status item shows the Alembic window adjacent to the item, on the same screen as the item.
4. Right-clicking the status item shows the context menu and never triggers the window toggle.
5. The window's red traffic-light button hides the window instead of quitting on macOS.
6. `flutter analyze` reports zero issues in the changed Dart files.
7. `flutter build macos --debug` completes successfully.
8. With `WINDOW_MODE` marker present, Alembic launches as a regular Cocoa app with a dock icon and no status item.

## Notes

- The user said the status item is "supposed to be in a tray/menu bar and it's NOT in the macOS menubar". This plan replaces the entire lifecycle rather than patching the symptom, because every prior attempt has been a band-aid (multiple activation-policy resets, scheduled re-installs).
- We avoid editing the `arcane_desktop` package directly. The `AWM.tray` sentinel pattern keeps the close-button-hides-window behavior working without a vendored fork.
- `os_log` was chosen over `print` so the logs can be filtered at runtime in `Console.app` or `log stream` without a debugger attached.
- All Swift code added here must use explicit types per `CODE_STYLE_*` policy where the language does not infer them from a literal.
- No new code comments are added per the project guidelines; the plan itself supplies the rationale.
