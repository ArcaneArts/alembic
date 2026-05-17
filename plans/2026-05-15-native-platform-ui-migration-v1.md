# Native Platform UI Migration: Liquid Glass (macOS) + Mica/Acrylic (Windows)

## Objective

Move Alembic from a Flutter-only renderer toward a platform-native shell on macOS and Windows, so the app reads as a first-class native experience on each OS:

- **macOS**: SwiftUI-driven chrome, sheets, popovers, and dialogs using Liquid Glass (macOS 26 Tahoe `.glassEffect()` / `GlassEffectContainer`) for the elegance and refractive depth Apple ships in 2026.
- **Windows**: WinUI 3 / DWM-driven chrome and dialogs using Mica (preferred) and Acrylic (overlay popovers), with proper accent reactions and tinted backdrops.
- **Shared**: Keep the Dart/Flutter content surfaces (repository lists, search, work streams) where they earn their keep, and migrate everything modal, transient, or system-integrated to the native layer.

The end state is a "hybrid native" architecture: a thin platform shell renders the window, title-bar/toolbar, sidebar, modals, and menus natively. The Flutter view renders the bulk content (repository rows, dropdowns, inline forms) on top of the native material. We keep the Dart business logic (`lib/core/`, `lib/util/`) untouched and bridge native UI to it through method channels.

A fully native rewrite per platform (no Flutter) is documented in Phase 7 as an optional terminal state, but is not the recommended first move.

## Why Not a Full Native Rewrite First

- The business logic in `lib/core/arcane_repository.dart:1-935`, `lib/core/repository_runtime.dart`, `lib/util/git_signing.dart`, `lib/util/git_accounts.dart`, `lib/util/archive_master.dart`, and the GitHub client integration is ~3000 lines of stable, tested Dart. Rebuilding that in Swift and again in C# would double the surface and force two ports to stay in lock-step.
- The UX patterns most worth making native are: window chrome, modals, settings, menus, sheets, popovers, context menus, system tray integration. These are exactly the surfaces where Liquid Glass and Mica deliver visible polish. Repository row chrome is not where users feel "native vs not."
- A hybrid model lets Phase 1 ship a visible, immediate win (native materials behind the existing Flutter UI) within days, not months.
- If the hybrid model becomes limiting (e.g. tight Liquid Glass animations need to extend into the content), Phase 7 (full native per platform) is unlocked by the bridge layer built in Phases 2–4.

## Context and Constraints

### What we have today

- `pubspec.yaml:1-72`: Flutter desktop app, `arcane` design system on top of Material, fonts shipped, dependencies include `window_manager`, `tray_manager`, `flutter_acrylic` (declared but unused in `lib/`), `launch_at_startup`.
- `macos/Runner/MainFlutterWindow.swift:1-155`: Frameless `NSWindow` with a `NSVisualEffectView` "glass" layer (this is pre-Liquid-Glass vibrancy, not the 2026 material), corner radius 14, transparent Flutter view layered on top.
- `macos/Runner/AlembicTrayController.swift:1-749`: Production-quality `NSStatusItem` controller with method channel bridge `alembic_tray`. Establishes the pattern for native↔Dart bridging.
- `macos/Runner/AppDelegate.swift:1-34`: `.accessory` activation policy, prevents relaunch, owns the tray installation.
- `windows/runner/win32_window.cpp:1-80`: Stock Flutter Win32 window, no Mica or Acrylic, only sets `DWMWA_USE_IMMERSIVE_DARK_MODE`.
- `windows/runner/flutter_window.cpp:1-71`: Stock `FlutterWindow` subclass.
- `lib/main.dart:1-364`: App bootstrap, encrypted Hive boxes, `AlembicRoot` wraps `ArcaneApp` and dispatches to `SplashScreen`.
- `lib/util/window.dart:1-741`: `WindowUtil` does frameless setup, tray positioning, hide-on-blur, taskbar visibility, multi-display logic.
- `lib/platform/desktop_platform_adapter.dart:1-367`: Clean platform abstraction (paths, file-explorer launch, update helper) — exactly the right place to add native-modal entry points.
- `lib/app/alembic_dialogs.dart:1-97`: All three dialog primitives (`showAlembicInfoDialog`, `showAlembicConfirmDialog`, `showAlembicInputDialog`) are centralized. Single replacement point.
- `lib/screen/settings.dart:1-319` and `lib/screen/settings/`: Settings is already a separate `MaterialPageRoute` modal opened via `showSettingsModal`. Lift target is well-defined.
- `lib/screen/login.dart:1-266`: Login is a standalone screen invoked from splash — another good lift target.
- `lib/screen/home/`: Home is the densest Flutter surface. Top bar (`home_top_bar.dart`), repository rows (`home_repository_rows.dart` ~663 lines), tabs, search. Strongest case for keeping in Flutter (high content density, complex stream-driven rendering).
- Theme tokens at `lib/ui/alembic_tokens.dart:1-187` give us the explicit color palette and radii to translate into Swift/`Color` and WinUI `Brush`/`CornerRadius` resources.

### What we will not lose

- All Hive storage (`box`, `boxSettings`).
- All Git/GitHub logic (`arcane_repository.dart`, `repository_runtime.dart`).
- Tray-first windowing model (small popover-near-tray, hide-on-blur).
- Existing method channels (`alembic_tray`, `launch_at_startup`).
- Update flow (`lib/core/app_update_service.dart`, helper scripts).
- Signing/auth (`git_signing.dart`, `repository_auth.dart`).

### Platform constraints

- **Liquid Glass requires Xcode 26 / macOS 26 SDK** (2025+). Builds against older SDKs fall back to vibrancy automatically; we will keep a runtime gate (`@available(macOS 26, *)`) so the app keeps running on macOS 12+ with `NSVisualEffectView` as the fallback material.
- **Mica requires Windows 11 22H2+** (`DWMWA_SYSTEMBACKDROP_TYPE`). Windows 10 must fall back to acrylic (via `SetWindowCompositionAttribute`, undocumented but stable) or solid color. The hybrid will detect and degrade.
- **Hybrid compositing caveat**: Flutter's Skia/Metal layer renders opaquely by default. To let native material show through, the Flutter window background must remain `Color(0x00000000)` (already true: `lib/util/window.dart:126`) AND the content surfaces (`AlembicScaffold`, `AlembicPanel`) must opt into translucency where they sit on top of native material. We add an explicit "translucent mode" to those primitives.
- **Native modals over Flutter** require either child `NSWindow`/`Window` (true window, full Liquid Glass) or `NSPanel`/`Popover` (lighter, attaches to status item). Settings = child window. Confirm/info dialogs = popover-style sheet anchored on the main window.
- **Right-click menus** are best done as `NSMenu`/Win32 `TrackPopupMenu`/WinUI `MenuFlyout`, not as Flutter `PopupMenuButton`. We will route right-click on repository rows through a Dart→native bridge.

## Strategy: Hybrid Phased Migration

The migration is sequenced so each phase ships visible value and leaves the app in a working state. Phases are independent enough that the user can pause at any phase and ship.

```
Phase 1: Native window chrome + materials      ← visible polish, ~1 week
Phase 2: Bridge layer (method channels)        ← infrastructure, ~3 days
Phase 3: Native modals (dialogs)               ← Liquid Glass dialogs, ~1 week
Phase 4: Native settings surface               ← first big modal lift, ~1.5 weeks
Phase 5: Native title bar + toolbar + sidebar  ← native chrome, ~1.5 weeks
Phase 6: Native context menus + system menus   ← right-click parity, ~3 days
Phase 7: (optional) Full native per platform   ← long-term, multi-month
```

## Architecture Target

### Layered view

```
+--------------------------------------------------------------+
| Platform Shell (Swift/SwiftUI on macOS, C++/WinUI on Windows)|
|   - NSWindow / Window with Liquid Glass / Mica backdrop      |
|   - Native title bar, traffic lights / caption buttons       |
|   - Native modals (sheets, popovers, dialogs)                |
|   - Native context menus, application menu, tray menu        |
+--------------------------------------------------------------+
| Bridge Layer (MethodChannels, EventChannels)                 |
|   - alembic_modals   (open/confirm/input/sheet)              |
|   - alembic_menus    (context_menu, app_menu)                |
|   - alembic_window   (drag region, theme sync, materials)    |
|   - alembic_settings (open native settings, read/write keys) |
|   - alembic_tray     (existing)                              |
+--------------------------------------------------------------+
| Dart Content Layer (Flutter)                                 |
|   - Splash, home repository browser, search, dropdowns       |
|   - Translucent surfaces that let native material show       |
|   - Theme tokens shared with native via JSON bootstrap       |
+--------------------------------------------------------------+
| Dart Business Layer (unchanged)                              |
|   - core/, util/, presentation/                              |
|   - Hive storage, GitHub client, runtime, archive            |
+--------------------------------------------------------------+
```

### File layout target

```
macos/Runner/
  AppDelegate.swift                        (existing, unchanged behavior)
  MainFlutterWindow.swift                  (refactored: hosts SwiftUI shell)
  AlembicTrayController.swift              (existing, unchanged)
  Shell/
    AlembicWindowChrome.swift              (NEW: SwiftUI window chrome)
    AlembicGlassBackdrop.swift             (NEW: Liquid Glass + vibrancy fallback)
    AlembicTheme.swift                     (NEW: Color/Material tokens)
  Modals/
    AlembicNativeModals.swift              (NEW: bridges alembic_modals)
    AlembicConfirmSheet.swift              (NEW: Liquid Glass confirm)
    AlembicInfoSheet.swift                 (NEW: Liquid Glass info)
    AlembicInputSheet.swift                (NEW: Liquid Glass input)
    AlembicSettingsWindow.swift            (NEW: Phase 4)
  Menus/
    AlembicContextMenu.swift               (NEW: NSMenu bridge)
    AlembicApplicationMenu.swift           (NEW: NSMenu main menu)

windows/runner/
  flutter_window.cpp                       (refactored to host backdrop)
  win32_window.cpp                         (extended: Mica/Acrylic)
  shell/
    AlembicBackdrop.h/.cpp                 (NEW: Mica + Acrylic with fallback)
    AlembicCaption.h/.cpp                  (NEW: custom caption buttons)
    AlembicTheme.h/.cpp                    (NEW: brushes, corner radius)
  modals/
    AlembicNativeModals.h/.cpp             (NEW: bridges alembic_modals)
    AlembicConfirmDialog.h/.cpp            (NEW: ContentDialog)
    AlembicInfoDialog.h/.cpp               (NEW: ContentDialog)
    AlembicInputDialog.h/.cpp              (NEW: ContentDialog)
    AlembicSettingsWindow.h/.cpp           (NEW: Phase 4)
  menus/
    AlembicContextMenu.h/.cpp              (NEW: MenuFlyout / TrackPopupMenu)

lib/
  app/
    alembic_dialogs.dart                   (refactored: routes to native bridge)
  platform/
    native_modals.dart                     (NEW: typed API over alembic_modals)
    native_menus.dart                      (NEW: typed API over alembic_menus)
    native_window.dart                     (NEW: drag region, theme sync)
    native_settings.dart                   (NEW: Phase 4)
    desktop_platform_adapter.dart          (existing, unchanged)
  ui/
    alembic_layout.dart                    (extended: AlembicSurfaceTone.translucent)
```

### Native vs Flutter ownership matrix

| Surface | Today | After Migration | Phase |
| --- | --- | --- | --- |
| Window backdrop / material | `NSVisualEffectView` (mac) + nothing (win) | Liquid Glass (mac) + Mica (win) | 1 |
| Window chrome (corner radius, shadow, drag) | Flutter | Native shell wraps Flutter view | 1 |
| Traffic lights / caption buttons | Hidden / default | Native, custom-styled | 5 |
| App menu (mac) | Default | Native NSMenu, populated by bridge | 6 |
| Tray icon + tray menu | Native (`AlembicTrayController.swift:1-749`) | Native (unchanged) | — |
| Splash screen | Flutter (`lib/screen/splash.dart:1-181`) | Flutter (unchanged) | — |
| Login screen | Flutter (`lib/screen/login.dart:1-266`) | Flutter w/ translucent surface | 1 |
| Home top bar | Flutter (`home_top_bar.dart`) | Native toolbar with embedded Flutter search | 5 |
| Home repository list | Flutter (`home_repository_rows.dart`) | Flutter (kept) | — |
| Search input | Flutter | Native (mac: NSSearchField) / Flutter fallback | 5 |
| Tabs (active/archived/repos) | Flutter | Native segmented control | 5 |
| Organization filter dropdown | Flutter | Native popover menu | 5 |
| Confirm dialog | Flutter (`AlembicDialogCard`) | Native sheet (mac) / ContentDialog (win) | 3 |
| Info dialog | Flutter | Native sheet / ContentDialog | 3 |
| Input dialog | Flutter | Native sheet / ContentDialog | 3 |
| Settings modal | Flutter `MaterialPageRoute` | Native child window | 4 |
| Repository auth dialog | Flutter (`repository_auth_dialog.dart`) | Native sheet (Phase 4.5) | 4 |
| Right-click repository row | Flutter `PopupMenuButton` | Native context menu (NSMenu / MenuFlyout) | 6 |
| Update prompt | Flutter | Native sheet | 3 |

## Risk Register

1. **Liquid Glass + Flutter compositing.** Flutter renders to a Metal layer. Liquid Glass needs to refract content behind it. If the Flutter layer is opaque, glass refracts nothing useful. **Mitigation**: keep the root Flutter scaffold transparent (already true at `lib/util/window.dart:126`), add `AlembicSurfaceTone.translucent` for surfaces that sit directly on native material, document which surfaces are translucent-safe.

2. **macOS 26 SDK availability on build agents.** Liquid Glass APIs require Xcode 26. **Mitigation**: gate all Liquid Glass calls behind `if #available(macOS 26.0, *)`, ship a `NSVisualEffectView` fallback that matches the visual contract closely on macOS 12–25.

3. **Method-channel chattiness for menus and modals.** Repository row right-click → native menu → Dart action callback round-trip must be sub-frame to feel native. **Mitigation**: pre-register menu schemas at startup; native side renders synchronously from cached schema, only sends Dart the chosen action key.

4. **Native modal blocks the Flutter event loop.** A SwiftUI sheet anchored on the main window must not block Flutter's vsync; using `NSWindow.beginSheet(_:completionHandler:)` and WinUI `ShowAsync` are both non-blocking. **Mitigation**: explicit non-blocking API contracts in the bridge; assert in code review.

5. **Theme drift between Dart and native.** Dart owns the canonical theme tokens (`alembic_tokens.dart:1-187`). Native shells need the same colors. **Mitigation**: at startup, Dart pushes a `theme_tokens` JSON payload over `alembic_window` channel; native shell rebuilds its color/material tables. Theme mode changes (`saveAlembicThemeMode`) re-push.

6. **Window drag regions break with native title bar.** Flutter views don't participate in `mouseDownCanMoveWindow`. **Mitigation**: native title-bar strip claims drag region; Flutter content area below it does not need to drag. Confirm with existing `_isMovableByWindowBackground=false` (`MainFlutterWindow.swift:27`) — already aligned.

7. **Hide-on-blur and native modals.** Today, blurring the window hides it (`window.dart:687`). If a native modal opens a child window and that child gains focus, the main window blurs and hides itself, taking the modal with it. **Mitigation**: extend `WindowUtil.suspendHideOnBlur()` and call it from the native side over `alembic_window` before opening any child window or sheet.

8. **Right-click menus on multi-monitor / DPI scaling.** Especially on Windows with mixed-DPI displays. **Mitigation**: native menus use platform APIs that handle DPI correctly; explicit testing matrix in verification.

9. **Code signing and notarization.** SwiftUI Liquid Glass code may pull new entitlement requirements. **Mitigation**: revalidate `macos/Runner/Release.entitlements` and `DebugProfile.entitlements` after Phase 1; run a notarization pass before Phase 2 lands.

10. **Bundle ID and Login Items state.** Plan `2026-05-06-macos-tray-lifecycle-redesign-v1.md:26` already flags the default bundle ID. Liquid Glass and SwiftUI windows persist state per bundle ID. **Mitigation**: confirm bundle ID before Phase 4 (settings window) ships.

## Execution Status

### Phase 1 — Native Window Chrome and Material

Goal: replace `NSVisualEffectView` with Liquid Glass on macOS, add Mica/Acrylic on Windows. Flutter UI runs unchanged on top.

- [ ] Confirm Xcode 26 / macOS 26 SDK is installed on the macOS build machine; document the minimum Xcode version in `scripts/release/build_macos.sh`.
- [ ] Add `macos/Runner/Shell/AlembicTheme.swift` with `AlembicMaterial` enum (`liquidGlass`, `vibrancy`, `solid`) and a `current()` factory that picks based on `@available(macOS 26, *)`.
- [ ] Add `macos/Runner/Shell/AlembicGlassBackdrop.swift`: a `NSView` subclass that, on macOS 26+, hosts a SwiftUI `GlassEffectContainer` view with `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))` filling its bounds; on older macOS, falls back to the existing `NSVisualEffectView` setup at `MainFlutterWindow.swift:36-50`.
- [ ] Refactor `macos/Runner/MainFlutterWindow.swift:34-50` so the host glass view is created via `AlembicGlassBackdrop` instead of constructing `NSVisualEffectView` inline.
- [ ] Add a `setMaterial(_ material: AlembicMaterial)` method on `AlembicGlassBackdrop` so the bridge layer (Phase 2) can change material at runtime (e.g. dim during drag).
- [ ] Verify on macOS 26 the window shows the new refractive Liquid Glass material; verify on macOS 14 the old vibrancy material still renders identically to today.
- [ ] Add `windows/runner/shell/AlembicBackdrop.h/.cpp`: a class that wraps `DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &MICA, ...)` on Windows 11 22H2+, falls back to `SetWindowCompositionAttribute(hwnd, ACCENT_ENABLE_ACRYLICBLURBEHIND)` on Windows 10/early-11, and to a solid brush on the rest.
- [ ] Update `windows/runner/win32_window.cpp:1-80` `Win32Window::Create` so it sets the window class background to `NULL_BRUSH`, the window's `WS_EX_LAYERED` and `WS_EX_NOREDIRECTIONBITMAP` flags appropriately, and calls `AlembicBackdrop::Apply(hwnd, AlembicBackdrop::Detect())` after creation.
- [ ] Update `windows/runner/flutter_window.cpp:11-39` so the Flutter view background is transparent (set `SetWindowLong(GWL_EXSTYLE, ...)`, ensure the embedded view does not paint an opaque background).
- [ ] Verify on Windows 11 the window shows Mica with the user's accent tint; verify on Windows 10 it shows acrylic; verify on Windows 8/7 it shows the configured solid color without crashing.
- [ ] Audit `lib/ui/alembic_layout.dart:24-127` for any opaque backgrounds on top-level scaffolds; switch `AlembicScaffold` to use `Colors.transparent` when running in tray-first mode so the native material shows through.
- [ ] Add `AlembicSurfaceTone.translucent` to `lib/ui/alembic_layout.dart:5-10` and render it with a card color whose alpha is 0.45 in dark mode and 0.65 in light mode; document that this tone is the default for surfaces sitting directly on native material.
- [ ] Update `AlembicPanel` so that when `tone == translucent`, it draws a thin 0.5px border for separation without any solid fill.
- [ ] Update `lib/screen/splash.dart:117-176` and `lib/screen/login.dart` panels to use `AlembicSurfaceTone.translucent` so the splash and login surfaces show the native material behind them.
- [ ] Verify visually on macOS 26 that the splash panel refracts the desktop behind it (Liquid Glass).
- [ ] Verify visually on Windows 11 that the login panel shows the Mica wallpaper tint behind it.
- [ ] Run `flutter run -d macos` and `flutter run -d windows` smoke tests; confirm no regressions in hide-on-blur, tray click, window positioning.

### Phase 2 — Bridge Layer (Method Channels)

Goal: lay down typed Dart APIs and native handlers for modals, menus, window control, and theme sync. No user-visible UI changes; this is the substrate for Phases 3–6.

- [ ] Define `lib/platform/native_window.dart` with a `NativeWindow` singleton exposing:
  - [ ] `Future<void> setMaterial(NativeMaterial material)` — bridges to `alembic_window.setMaterial`.
  - [ ] `Future<void> pushThemeTokens(Map<String, Object?> tokens)` — bridges to `alembic_window.pushThemeTokens`.
  - [ ] `Stream<NativeThemeChange> get themeChanges` — bridges over an event channel.
  - [ ] `Future<void> suspendHideOnBlur()` / `Future<void> resumeHideOnBlur()` — bridges to the existing `WindowUtil` calls so native modals can pause hide-on-blur.
- [ ] Define `lib/platform/native_modals.dart` with `NativeModals` and types:
  - [ ] `Future<void> showInfo({required String title, required String message, String? primaryLabel})`.
  - [ ] `Future<bool> showConfirm({required String title, required String description, String confirmText, String cancelText, bool destructive})`.
  - [ ] `Future<String?> showInput({required String title, required String description, required String placeholder, String confirmText, String? initialValue})`.
  - [ ] `Future<NativeSheetResult> showSheet({required NativeSheetSpec spec})` — generic for richer sheets (auth, update).
- [ ] Define `lib/platform/native_menus.dart`:
  - [ ] `Future<String?> showContextMenu({required Offset anchor, required List<NativeMenuItem> items})`.
  - [ ] `Future<void> setApplicationMenu(NativeApplicationMenuSpec spec)` (mac-only no-op on Windows for now).
- [ ] Wire native handlers on macOS:
  - [ ] `macos/Runner/Modals/AlembicNativeModals.swift` registers `alembic_modals` and dispatches to per-modal classes (skeletons only in this phase).
  - [ ] `macos/Runner/Menus/AlembicContextMenu.swift` registers `alembic_menus.showContextMenu` returning a chosen item key.
  - [ ] `macos/Runner/Shell/AlembicWindowChrome.swift` registers `alembic_window` for material switching, theme tokens, and hide-on-blur suspend.
  - [ ] Register all four channels in `MainFlutterWindow.swift:60-114` alongside the existing `alembic_tray` registration.
- [ ] Wire native handlers on Windows:
  - [ ] `windows/runner/modals/AlembicNativeModals.h/.cpp` registers `alembic_modals` and dispatches to per-modal classes (skeletons).
  - [ ] `windows/runner/menus/AlembicContextMenu.h/.cpp` registers `alembic_menus.showContextMenu` using `TrackPopupMenuEx` for Phase 2, upgrading to WinUI `MenuFlyout` in Phase 6 when WinAppSDK is wired in.
  - [ ] `windows/runner/shell/AlembicBackdrop` extended to handle `alembic_window` calls.
  - [ ] Register all channels in `windows/runner/flutter_window.cpp:11-39` after `RegisterPlugins`.
- [ ] At startup in `lib/main.dart:51-95`, after `_setupAppSettings()`, push the current theme tokens (`AlembicShadcnTokens.lightScheme` / `darkScheme`) to native via `NativeWindow.pushThemeTokens`.
- [ ] Add a unit test under `test/platform/native_modals_test.dart` that mocks the method channel and verifies argument shapes and result decoding for all five modal verbs.
- [ ] Add a contract test under `test/platform/native_window_test.dart` for theme-tokens round-trip and hide-on-blur suspend/resume.
- [ ] Verify the bridge by adding a debug-only "dump native bridge" entry to the settings diagnostics pane (`lib/screen/settings/diagnostics_pane.dart:1-...`) that calls each channel and prints results to the log.

### Phase 3 — Native Modals (Dialogs, Sheets, Popovers)

Goal: route the three dialog primitives in `lib/app/alembic_dialogs.dart:1-97` through the native bridge so every confirm/info/input becomes a Liquid Glass sheet on macOS and a WinUI ContentDialog on Windows.

- [ ] Implement `macos/Runner/Modals/AlembicConfirmSheet.swift`:
  - [ ] SwiftUI `View` with title, description, primary/secondary buttons; `.presentationBackground(.glass)` (Liquid Glass), `.presentationCornerRadius(14)`.
  - [ ] Presented via `NSWindow.beginSheet(_:completionHandler:)` anchored on `MainFlutterWindow`.
  - [ ] Fallback for macOS < 26: `.presentationBackground(.thickMaterial)` + manual rounded corners.
- [ ] Implement `AlembicInfoSheet.swift` (same pattern, single button, no destructive variant).
- [ ] Implement `AlembicInputSheet.swift` (same pattern, `TextField` with placeholder, returns trimmed string or `nil`).
- [ ] Wire `AlembicNativeModals.swift` to dispatch the three verbs to the corresponding sheet, calling `WindowUtil` hide-on-blur suspend before opening and resuming after dismissal.
- [ ] Implement `windows/runner/modals/AlembicConfirmDialog.h/.cpp` using `MessageBoxIndirect` (Phase 3a, no WinAppSDK dependency) or a `TaskDialog` with custom buttons (Phase 3b, preferred for Mica integration).
- [ ] Implement `AlembicInfoDialog.h/.cpp` analogously.
- [ ] Implement `AlembicInputDialog.h/.cpp` as a custom Win32 dialog (modeless, Mica-backed) since `MessageBox` has no input field.
- [ ] Refactor `lib/app/alembic_dialogs.dart:5-23` so `showAlembicInfoDialog` calls `NativeModals.showInfo` when running on `isMacOS || isWindows`, falling back to the existing Flutter `AlembicDialogCard` only when the native call throws (defensive, for early dogfooding).
- [ ] Refactor `showAlembicConfirmDialog` and `showAlembicInputDialog` the same way.
- [ ] Delete the now-unused `AlembicDialogCard` class from `lib/ui/alembic_layout.dart:360-403` once all callers are migrated. (Backward compatibility is opt-in only; we are not preserving it.)
- [ ] Audit all callers of the three dialog functions:
  - [ ] `lib/screen/home/home_repository_browser.dart`
  - [ ] `lib/screen/home/home_repository_importer.dart`
  - [ ] `lib/screen/home/home_repository_operations.dart`
  - [ ] `lib/screen/settings.dart:204-222`
  - [ ] `lib/screen/settings/accounts_pane.dart`
  - [ ] `lib/screen/home.dart:219-225`
  - [ ] Anywhere else `fs_search` turns up `showAlembic.*Dialog`.
- [ ] Verify on macOS 26 that every dialog reads as a Liquid Glass sheet, dismisses with the standard macOS sheet animation, and properly returns `bool`/`String?` to Dart.
- [ ] Verify on Windows 11 that every dialog reads as a Mica-tinted dialog, dismisses with WinUI standard animation, and returns the expected values.
- [ ] Add an integration test that drives a confirm-flow end-to-end via a fake method-channel handler.

### Phase 4 — Native Settings Surface

Goal: replace the Flutter settings modal (`lib/screen/settings.dart:1-319` and `lib/screen/settings/*`) with a native child window on each platform, while keeping the Dart business logic that reads/writes settings.

- [ ] Inventory all settings keys read/written by the existing panes:
  - [ ] General (`general_pane.dart`): theme mode, autolaunch, start hidden, hide on blur.
  - [ ] Workspace (`workspace_pane.dart`): workspace dir, archive dir, archive master dir.
  - [ ] Accounts (`accounts_pane.dart`): list/add/remove GitHub accounts.
  - [ ] Tools (`tools_pane.dart`): editor selections, commit signing.
  - [ ] Archive Master (`archive_master_pane.dart`): days to archive.
  - [ ] Diagnostics (`diagnostics_pane.dart`): dump diagnostics.
- [ ] Add `lib/platform/native_settings.dart` exposing typed read/write methods for each setting, all going through Hive boxes underneath. This becomes the API the native settings windows call into.
- [ ] Add a `settings_bridge` MethodChannel that lets the native shell read/write each typed setting and subscribe to changes (`EventChannel`).
- [ ] Add `lib/platform/native_settings.dart`'s `openNative()` method which calls `settings_bridge.open` to show the native window.
- [ ] Implement `macos/Runner/Modals/AlembicSettingsWindow.swift`:
  - [ ] `NSWindow` subclass with `.titlebarAppearsTransparent`, `fullSizeContentView`, Liquid Glass backdrop.
  - [ ] SwiftUI `NavigationSplitView` with sidebar listing the six panes.
  - [ ] One SwiftUI view per pane mirroring the Dart pane's controls; data flow via `@StateObject` bound to `settings_bridge`.
  - [ ] Window is its own `NSWindow`, not a sheet, so it can be moved and resized like a real settings window.
- [ ] Implement `windows/runner/modals/AlembicSettingsWindow.h/.cpp`:
  - [ ] WinUI 3 `Window` (or Win32 host with XAML Islands if WinAppSDK is heavy) with Mica backdrop, `NavigationView` sidebar, one `Page` per pane.
- [ ] Refactor `lib/screen/home.dart:310-318` `_openSettings` to call `NativeSettings.openNative()` instead of `showSettingsModal`.
- [ ] Delete `lib/screen/settings.dart`, `lib/screen/settings/`, and the entire `Settings` widget tree once all settings are reachable via the native window. (Clean removal, not behind a flag.)
- [ ] Migrate the Quick Actions list (`settings_navigation.dart:settings_navigation.dart`) into the native window's sidebar footer.
- [ ] Update `lib/screen/home/home_menu_handler.dart` so `handleSettingsAction` routes through native deep-links (`alembic://settings/general`, `/accounts`, etc.) instead of navigating Flutter routes.
- [ ] Verify on macOS that the settings window opens as a sibling NSWindow with Liquid Glass chrome, sidebar navigation, and all reads/writes correctly persist to Hive.
- [ ] Verify on Windows that the settings window opens with Mica backdrop, NavigationView, and all reads/writes persist.
- [ ] Verify that closing the main window from the tray does not orphan the settings window; settings window closes too.
- [ ] Optional (Phase 4.5): migrate `lib/screen/home/repository_auth_dialog.dart:1-...` to a native sheet using the same bridge.

### Phase 5 — Native Title Bar / Toolbar / Sidebar

Goal: replace the Flutter top bar (`lib/screen/home/home_top_bar.dart:1-376`) with a native toolbar that hosts the search field, tabs, and action buttons. Flutter renders only below the toolbar.

- [ ] Add `macos/Runner/Shell/AlembicWindowChrome.swift`:
  - [ ] `NSToolbar` with native `NSToolbarItem` entries for search (`NSSearchField`), tabs (`NSSegmentedControl`), organization filter (`NSPopUpButton`), import button, settings button.
  - [ ] Toolbar is hosted on `MainFlutterWindow` with `titleVisibility = .hidden`, `unifiedTitleAndToolbar`.
  - [ ] On macOS 26, the toolbar inherits Liquid Glass from the window.
  - [ ] Toolbar changes (search text, tab selection) are pushed to Dart via an EventChannel `alembic_window.toolbar_events`.
- [ ] Add `windows/runner/shell/AlembicCaption.h/.cpp`:
  - [ ] WinUI 3 `TitleBar` (Windows 11) with embedded `AutoSuggestBox`, `Segmented` (community toolkit), `DropDownButton`, action buttons.
  - [ ] Toolbar events pushed to Dart via the same EventChannel.
- [ ] Add `lib/platform/native_toolbar.dart` exposing:
  - [ ] `Stream<String> searchText`.
  - [ ] `Stream<HomeTab> tabSelected`.
  - [ ] `Stream<OrganizationFilter> organizationSelected`.
  - [ ] `Stream<NativeToolbarAction> actions` (import, settings, etc.).
  - [ ] `Future<void> setProgress({double? value, String? label})` so the runtime can show a native progress indicator in the toolbar.
- [ ] Refactor `lib/screen/home.dart:329-399` so:
  - [ ] The top bar widget is removed from the Flutter tree.
  - [ ] Search/tab/org selection state is sourced from `NativeToolbar` streams.
  - [ ] The Flutter content area renders only the repository browser pane.
- [ ] Delete `lib/screen/home/home_top_bar.dart`, `lib/ui/controls/alembic_tabs.dart` (if no longer referenced), and the associated Flutter widgets once verified.
- [ ] Verify the native toolbar feels truly native on each platform: keyboard shortcuts (⌘F focuses search, Ctrl+F on Windows), drag region on the empty toolbar area moves the window, double-click on title zooms/maximizes per platform convention.
- [ ] Verify that progress indicator from `_controller.progress` (`lib/screen/home/home_controller.dart`) flows into the native toolbar progress.
- [ ] Optional: add a native sidebar (NavigationSplitView on mac, NavigationView on win) listing organizations, replacing the Flutter org dropdown.

### Phase 6 — Native Context Menus and System Menus

Goal: every right-click and every application-menu interaction is rendered natively.

- [ ] Inventory all `PopupMenuButton` / `MenuAnchor` / `showMenu` usages in `lib/screen/home/` and elsewhere.
- [ ] For each, define a `NativeContextMenuSpec` listing items, separators, submenus, destructive flags, keyboard shortcuts, and the action key to return.
- [ ] Implement `macos/Runner/Menus/AlembicContextMenu.swift` upgrades:
  - [ ] Convert from skeleton (Phase 2) to a full `NSMenu` builder that supports submenus, key equivalents (`.command + "k"`), checkboxes, separators.
  - [ ] Return chosen action key over the method channel.
- [ ] Implement `windows/runner/menus/AlembicContextMenu.h/.cpp`:
  - [ ] Upgrade from `TrackPopupMenuEx` to WinUI `MenuFlyout` (Mica-tinted) when WinAppSDK is wired in.
- [ ] Refactor `lib/widget/repository_tile_actions.dart` so the right-click handler calls `NativeMenus.showContextMenu` with the action spec; remove the Flutter popup implementation.
- [ ] Add `macos/Runner/Menus/AlembicApplicationMenu.swift`:
  - [ ] Build the main `NSMenu`: Alembic (about, preferences = open settings, quit), File (import, new repo), Edit (cut/copy/paste/select all defaults), View (toggle tabs, toggle org filter), Window (minimize, zoom), Help.
  - [ ] Items deep-link to the same actions used by the toolbar and tray, going through `home_menu_handler.dart`.
- [ ] On Windows, no application-menu equivalent; system menu (right-click caption) is handled by Win32. Add Alembic-specific items to it (Settings, About) via `GetSystemMenu` + `AppendMenu`.
- [ ] Verify right-click on a repository row opens a native menu with correct items, correct destructive styling, correct keyboard shortcuts, and correct return values.
- [ ] Verify the macOS application menu picks up Cmd+, for Preferences (opens native settings window from Phase 4).

### Phase 7 — (Optional) Full Native Per-Platform Shells

Goal: terminal state. The Flutter renderer is removed entirely. macOS app is pure SwiftUI; Windows app is pure WinUI 3 / .NET; business logic moves to a shared core.

This phase is intentionally deferred and may never be necessary if Phases 1–6 deliver enough native polish.

- [ ] Decide on shared-core language: Dart compiled to native (`dart_native_assets`, AOT snapshot reused as an FFI library) vs. Rust port.
- [ ] If Dart: build `core_ffi` package that exposes `arcane_repository`, `repository_runtime`, `archive_master`, `git_signing`, GitHub client as a C ABI.
- [ ] If Rust: port `lib/core/` and `lib/util/` to a `core` Rust crate, publish `core.framework` (mac) and `core.dll` (win).
- [ ] Build pure SwiftUI macOS app `Alembic.app` consuming the core via FFI.
- [ ] Build pure WinUI 3 Windows app `Alembic.exe` consuming the core via FFI.
- [ ] Migrate the remaining home repository browser (still Flutter at end of Phase 6) into each native shell:
  - [ ] SwiftUI: `List`/`LazyVStack` with row views, streams via Combine.
  - [ ] WinUI: `ItemsRepeater` / `ListView` with row controls, streams via `IObservable`.
- [ ] Remove the Flutter project, `pubspec.yaml`, and `lib/`.
- [ ] Re-do release scripts for two native projects.

This phase is a multi-month effort. Phases 1–6 are designed to be a complete shipping milestone without requiring it.

## Verification Criteria

- **Phase 1**: Visual diff against today shows Liquid Glass refraction on macOS 26 (or unchanged vibrancy on older macOS) and Mica/acrylic on Windows. No regressions in tray click, hide-on-blur, window positioning, or window size persistence.
- **Phase 2**: All five native channels respond to `dumpFullDebug`-style probes with valid JSON payloads. Unit tests for `native_modals.dart` and `native_window.dart` pass.
- **Phase 3**: Every dialog in the app renders natively. `git grep "AlembicDialogCard"` returns zero results. End-to-end test of clone-confirm flow passes.
- **Phase 4**: Settings is a separate native window per platform. `lib/screen/settings.dart` is deleted. Settings persistence round-trips correctly: change theme in native settings → Flutter content rebuilds in the new theme within 100 ms.
- **Phase 5**: Top bar is gone from `home.dart`. Search, tabs, organization filter all originate from the native toolbar. Cmd+F / Ctrl+F focuses search.
- **Phase 6**: Right-click on any repository row opens a native menu. macOS application menu is populated. `git grep "PopupMenuButton"` returns zero results.
- **Cross-phase**: No regression in update flow, autolaunch, tray, encrypted Hive storage, GitHub client. End-to-end clone + archive + open-in-editor flow works on both platforms after each phase.

## Decision Log

- **2026-05-15**: Plan drafted. Recommended hybrid migration over full native rewrite. Hybrid lets us ship Phase 1 in days and reach full native modals + settings in ~6 weeks of focused work; a full rewrite would take 3–6 months and double-port every business logic change in the meantime. Phase 7 reserved as terminal state if hybrid proves limiting.
- **2026-05-15**: `flutter_acrylic` dependency (`pubspec.yaml:17`) is declared but never imported. Decision: remove it once Phase 1 lands `AlembicBackdrop` natively. (Backward compatibility is opt-in only; we are not keeping unused plugins.)
- **2026-05-15**: Backwards-compat for the Dart `AlembicDialogCard` class is not preserved. Native dialogs become the only path on macOS and Windows after Phase 3.
