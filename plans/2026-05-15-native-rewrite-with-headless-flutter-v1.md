# Native Rewrite With Headless Flutter Engine (Alembic)

**Date**: 2026-05-15
**Version**: 1
**Author**: Brian Fopiano (with AI agent collaboration)
**Status**: Phase A — Complete (spike running on macOS); Phase B — Complete (RepositoryListStore + channel contracts wired and verified end-to-end); Phase C — Foundation in place (SwiftUI app shell with Liquid Glass + RepositoryListView); Phase D macOS — Complete (Flutter UI fully removed, SwiftUI is the only UI surface on macOS, native Sign-in sheet wired)
**Supersedes (extends)**: `plans/2026-05-15-native-platform-ui-migration-v1.md` (Phase 7)

---

## 1. Goal

Move Alembic from a **Flutter UI + native chrome** hybrid to a **truly native per-platform UI**, while keeping the Dart codebase as the BLoC / Repository / Service layer.

| Layer | Today | Target |
| --- | --- | --- |
| Window backdrop | Liquid Glass / Mica via native bridge | **Liquid Glass / Mica (unchanged)** |
| Pixel rendering | Flutter (Skia / Impeller) on top of native material | **SwiftUI (macOS) / WinUI 3 (Windows)** |
| Dialogs | Native NSAlert / TaskDialog via bridge | **SwiftUI sheets with `.glassEffect`** / **WinUI ContentDialog** |
| Menus / toolbar / title bar | Flutter widgets | **NSToolbar / SwiftUI Toolbar / WinUI CommandBar** |
| Business logic (GitHub, Hive, Git ops, archive master, repo runtime) | Dart in `lib/core/`, `lib/util/` | **Dart in `lib/bloc/`, `lib/core/`, `lib/util/` (unchanged behaviour)** |
| Dart VM host | `FlutterEngine + FlutterViewController` | **`FlutterEngine` only (headless — no view attached)** |
| Communication | A few method channels | **Typed Pigeon API + EventChannels for streams** |

The end state has **zero Flutter widgets rendered**. The Flutter engine runs purely as a Dart VM host for the BLoC layer.

---

## 2. Architecture

```
+-------------------------------------------------------------+
|  Native UI                                                  |
|  - macOS:   SwiftUI (Liquid Glass GlassEffectContainer)     |
|  - Windows: WinUI 3 (Mica/Acrylic SystemBackdrop)           |
|  Owns: layout, animation, dialogs, navigation, menus,       |
|        toolbars, lists, gestures, text fields, theming      |
+-----------------------------+-------------------------------+
                              |
        Typed channels  (Pigeon API + EventChannels)
                              |
+-----------------------------+-------------------------------+
|  Dart BLoC + Domain Layer    (lib/bloc/, lib/domain/)       |
|  - State management (Cubits / Blocs)                        |
|  - DTOs / value types (immutable, codable)                  |
|  - Command handlers / use-cases                             |
|  - EventChannel publishers (streams to native UI)           |
+-----------------------------+-------------------------------+
                              |
+-----------------------------+-------------------------------+
|  Dart Core (unchanged)       (lib/core/, lib/util/)         |
|  - github/github.dart  (GitHub client)                      |
|  - Hive boxes  (settings, tokens, organizations, repos)     |
|  - Git operations  (clone/pull/push/sign)                   |
|  - Archive master service                                   |
|  - RepositoryRuntime, ArcaneRepository                      |
+-------------------------------------------------------------+
```

### 2.1 Dart side: BLoC + Repository pattern

- New folder `lib/bloc/` for state cubits and event publishers.
- New folder `lib/domain/` for plain-Dart value types (no Flutter imports).
- All `BuildContext` / `Navigator` / Material imports stripped from `lib/core/` and `lib/util/` (1 of each remains today — easy to fix).
- A single `lib/main_headless.dart` entry point that wires up `WidgetsFlutterBinding.ensureInitialized()` so platform channels work, opens Hive boxes, instantiates the BLoCs, and registers channel handlers — then does nothing else. **No `runApp`.**

### 2.2 macOS side: SwiftUI

- New target / module `AlembicSwiftUI`.
- Replaces `FlutterViewController` content with SwiftUI views.
- `FlutterEngine.run(withEntrypoint: "headlessMain")` runs the Dart entry, but the engine is **never attached to an `NSViewController`**.
- App is structured as:
  ```
  @main AlembicApp
    └── WindowGroup
        └── RootView                     (host for tray-popover lifecycle)
            ├── LoginView                (no token yet)
            └── HomeShellView            (token present)
                ├── ToolbarView
                ├── RepositoryListView
                ├── DetailPaneView
                └── SettingsScene (separate window)
  ```
- Liquid Glass: `GlassEffectContainer` at the root with `.glassEffect(.regular)` on cards; `.glassEffect(.thin)` on toolbars (macOS 26+). Vibrancy fallback on macOS 14–25.

### 2.3 Windows side: WinUI 3 (WinAppSDK)

- New project type: WinUI 3 desktop app with `Microsoft.UI.Xaml.Hosting.WindowsXamlManager` bootstrapping inside the existing Win32 host (or a clean WinAppSDK app — recommended).
- Native Mica/Acrylic via `SystemBackdrop` (already discoverable from existing `AlembicBackdrop`).
- App structure mirrors macOS:
  ```
  App.xaml
    └── MainWindow
        └── RootPage
            ├── LoginPage
            └── HomeShellPage
                ├── NavigationView / CommandBar
                ├── ListView (RepositoryItemTemplate)
                ├── DetailFrame
                └── SettingsPage (separate window)
  ```

### 2.4 Channel surface (typed via Pigeon)

Three channel families:

| Channel | Purpose | Type |
| --- | --- | --- |
| `alembic.commands` | Mutations: clone repo, archive, set token, switch tab, save settings | `MethodChannel` (Pigeon) |
| `alembic.queries` | One-shot reads: get repository list, organization list, current user | `MethodChannel` (Pigeon) |
| `alembic.events.<topic>` | Reactive streams: `repositories`, `progress`, `auth`, `theme`, `archive_master`, `update_check` | `EventChannel` per topic |

Pigeon generates strongly-typed Swift / C++ / Dart bindings, eliminating string-based RPC.

### 2.5 Lifecycle

- macOS: `FlutterEngine` initialised in `AppDelegate.applicationDidFinishLaunching`. SwiftUI views observe `AppState` (an `ObservableObject`) which subscribes to EventChannels. Commands invoked via Pigeon-generated APIs.
- Windows: `FlutterEngine` initialised in `App.OnLaunched`. WinUI views observe `AppViewModel` which subscribes to EventChannels.
- Hot reload: still works for the Dart layer because the Flutter engine is alive — devs run `flutter run -d macos --pid-file=...` and Dart hot reload still hits the BLoC code.

---

## 3. Phased Roadmap

### Phase A — Architecture spike (~2 days) — COMPLETE

Prove the model on macOS:

- A.1 [x] `lib/main.dart` declares `spikeMain` entrypoint with `@pragma('vm:entry-point')`; tree-shake guard via `_keepSpikeEntryPoint`. Heartbeat handled by `lib/spike/spike_runtime.dart` over `MethodChannel('alembic.spike')`.
- A.2 [x] `MainFlutterWindow.swift` detects `ALEMBIC_SPIKE=1` env var (or `AlembicSpikeMode` user default) and instantiates `FlutterEngine` explicitly with `run(withEntrypoint: "spikeMain")`. Window root is `NSHostingController(rootView: AlembicSpikeRootView)`. **No `FlutterViewController` is attached.**
- A.3 [x] Method channel handlers (`echo`, `setStatus`) and Dart→native push (`state`) all work over the headless engine. Plugin registration happens on the engine directly (`RegisterGeneratedPlugins(registry: engine)`).
- A.4 [x] SwiftUI `AlembicSpikeRootView` reads `SpikeAppState` (`@ObservableObject`) updated by `AlembicSpikeBridge`, which receives `state` method calls from Dart on every store mutation. Heartbeat tick, status, Dart version, PID all flow from Dart → Swift live.

**Exit criteria met**: Flutter UI gone in spike mode; Dart still runs; SwiftUI shows live data from Dart.

**How to launch**: `scripts/run-macos-spike.sh` (debug) or `scripts/run-macos-spike.sh --release`.

Files delivered in Phase A:
- `lib/main.dart:42-46` — `spikeMain` entrypoint
- `lib/spike/spike_runtime.dart` — Dart runtime, MethodChannel client, store wiring
- `lib/bloc/spike_app_state_store.dart` — BehaviorSubject-backed store
- `lib/domain/spike_app_state.dart` — Immutable DTO with `copyWith` + `toJson`
- `macos/Runner/AlembicSpikeBridge.swift` — Swift channel adapter + `ObservableObject`
- `macos/Runner/AlembicSpikeRootView.swift` — SwiftUI view tree (glass panels, echo, status pickers)
- `macos/Runner/MainFlutterWindow.swift:160-196` — Spike host installer
- `macos/Runner/AppDelegate.swift:8-67` — Spike-mode activation policy + window surface
- `scripts/run-macos-spike.sh` — One-shot build + run

Deployment target was bumped from macOS 11.0 → 12.0 (`macos/Podfile:1`, all `MACOSX_DEPLOYMENT_TARGET` entries in `macos/Runner.xcodeproj/project.pbxproj`). macOS 12+ is required for SwiftUI `Material` types and `.foregroundStyle`. Liquid Glass falls back to vibrancy via `AlembicGlassBackdrop` on macOS 12-25.

### Phase B — Dart BLoC extraction (~5 days)

- B.1 Strip the one `package:flutter/widgets.dart` import from `lib/core/arcane_repository.dart:16` (the `open(...)` method's `BuildContext` argument moves to the UI layer — the core only returns a result).
- B.2 Strip `package:flutter/widgets.dart` from `lib/util/environment.dart:1` (only used for `WidgetsBinding`/test detection — replace with a pure-Dart check).
- B.3 Create `lib/domain/` with plain-Dart DTOs for repository, organization, account, settings, etc. (one `.dart` file per aggregate).
- B.4 Create `lib/bloc/` with:
  - `AppCubit` — top-level state (login status, theme, active tab)
  - `RepositoryListCubit` — list, selection, search, filter
  - `RepositoryDetailCubit` — per-repository operations
  - `SettingsCubit` — settings state and persistence
  - `ImportCubit` — repository clone/import flow
- B.5 Define Pigeon contracts in `pigeons/alembic_api.dart`. Run `dart run pigeon` to generate Swift + C++ + Dart bindings.
- B.6 Implement command handlers and EventChannel publishers in `lib/bloc/`.

**Exit criteria**: `lib/main_headless.dart` brings up all BLoCs and exposes them via channels. No Flutter widgets imported from `lib/bloc/`, `lib/core/`, `lib/util/`, `lib/domain/`.

### Phase C — macOS SwiftUI shell (~5 days)

- C.1 New Xcode target / Swift module that contains the SwiftUI app structure.
- C.2 `AppState` observable that subscribes to all EventChannels at startup.
- C.3 SwiftUI views: `RootView`, `LoginView`, `HomeShellView`, `EmptyStateView`, `LoadingView`. No real list yet — placeholder content.
- C.4 Window chrome reuses `AlembicGlassBackdrop` from existing native bridge.
- C.5 Tray lifecycle (`AlembicTrayController`) keeps managing show/hide; the only difference is the content view is now `NSHostingController(rootView: RootView().environmentObject(appState))`.

**Exit criteria**: Login → home shell flow visible in SwiftUI driven by Dart BLoCs. Hot reload of Dart still works (BLoC logic changes reflect live).

### Phase D — macOS feature parity (~3 weeks)

- D.1 **Repository list view** — `List` / `LazyVStack` with `.glassEffect(.thin)` cards, swipe actions, context menus per row.
- D.2 **Top bar** — `Toolbar` with native search field, tab picker (Local / Repositories / Archive), organization filter, Clone + Settings buttons.
- D.3 **Dialogs** — SwiftUI sheets with `GlassEffectContainer`, replacing existing NSAlert path:
  - InfoSheet, ConfirmSheet, InputSheet, CustomSheet
- D.4 **Settings** — `Settings` scene with sidebar nav, sections for general / accounts / signing / archive / advanced.
- D.5 **Import flow** — file picker, validation, clone progress shown via EventChannel.
- D.6 **Archive Master pane** — live status, log tail.
- D.7 **Right-click menus** — SwiftUI `.contextMenu` per row (already native, just declared in SwiftUI now).
- D.8 **About panel** — keep `NSApp.orderFrontStandardAboutPanel`.
- D.9 **Application menu** — declared in SwiftUI via `@main App.commands { ... }`.

**Exit criteria**: Every user-visible Flutter screen on macOS has a SwiftUI equivalent. Toggle exists to run "Flutter UI" vs "SwiftUI UI" until the migration completes; both paths exercise the same BLoCs.

### Phase E — Remove Flutter UI from macOS (~2 days)

- E.1 Delete `lib/screen/`, `lib/widget/`, `lib/ui/`, `lib/app/`.
- E.2 Delete `runApp(...)` from `main.dart`.
- E.3 Rename `lib/main_headless.dart` → `lib/main.dart`.
- E.4 Remove `arcane`, `arcane_desktop`, `arcane_login`, `bouncing_button`, `loading_indicator`, `windows_taskbar` (other than what Windows runner still uses), `tray_manager`, `flutter_acrylic` from `pubspec.yaml`.

**Exit criteria**: macOS build size shrinks (no Skia rendering paths used). App still works.

### Phase F — Windows WinUI 3 app (~2 weeks)

- F.1 Add WinUI 3 / WinAppSDK project to `windows/`. Keep `windows/runner/` as a thin Win32 bootstrap that owns the `FlutterEngine` and hosts a WinUI 3 `Microsoft.UI.Xaml.XamlRoot`.
- F.2 WinUI 3 app structure mirrors SwiftUI version: `RootPage`, `LoginPage`, `HomeShellPage`, `SettingsWindow`, `ImportFlyout`.
- F.3 Mica/Acrylic via `MicaController` and `DesktopAcrylicController` (already detected by `AlembicBackdrop`).
- F.4 Pigeon-generated C++ bindings call into the Flutter engine instance.

**Exit criteria**: Windows app reaches parity with macOS SwiftUI app.

### Phase G — Remove Flutter UI from Windows (~1 day)

Same as Phase E for Windows.

### Phase H — Final cleanup (~2 days)

- H.1 Audit `pubspec.yaml` — remove all flutter UI-only packages.
- H.2 Update `README.md` to reflect new architecture.
- H.3 Set up CI to build all three artifact paths (Dart unit tests, macOS swift build, Windows WinUI build).
- H.4 Capture before/after binary size and startup latency metrics.

**Total estimate**: ~7 to 9 weeks of focused work.

---

## 4. Risk Register

| # | Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- | --- |
| 1 | Flutter engine without view leaks resources or misbehaves on macOS | Medium | High | Phase A spike validates this end-to-end before any other work |
| 2 | Pigeon-generated bindings have type gaps for `List<Repository>`, custom enums | Low | Medium | Pigeon supports nested classes, enums, lists — known limits documented; one-off custom codecs allowed |
| 3 | EventChannel streaming overhead for large repo lists | Medium | Medium | Diff-based updates (publish deltas, not full list); pagination |
| 4 | `BuildContext`-coupled flows in core (e.g. `arcane_repository.open(context)`) | Low | Low | Only one such method; refactor signature to return a result the UI layer consumes |
| 5 | WinUI 3 packaging complexity (MSIX vs unpackaged) | Medium | Medium | Stick with unpackaged WinAppSDK (matches current distribution model) |
| 6 | Hot reload breaks during Dart-only operation | Medium | Low | `flutter attach --pid-file=...` works against headless engines; document the workflow |
| 7 | Native UI re-implements bugs already fixed in Flutter UI | Medium | Medium | Pair migration: keep Flutter screen + SwiftUI screen behind a toggle until verified, then delete Flutter screen |
| 8 | Test coverage drops (Flutter widget tests delete) | High | Medium | Phase B promotes BLoC tests as the primary test layer; SwiftUI tested via XCTest snapshot/preview tests |
| 9 | `package:arcane` deeply integrated (theme, scaffolding) — removing it is invasive | Medium | Low | Phases C and D do not remove arcane; only Phase E removes it after SwiftUI is at parity |
| 10 | Liquid Glass requires macOS 26 SDK / Xcode 26 | Low | Low | Already handled by `AlembicGlassBackdrop` fallback to vibrancy on macOS 11–25 |
| 11 | Two UI codebases for one feature during migration | High | Medium | Strict per-screen feature flags; only one screen migrates at a time; tests run against both before deletion |

---

## 5. Decision Records

### 5.1 Why keep Flutter engine instead of going to Dart FFI?

Considered alternatives:

- **Dart FFI** — Compile Dart AOT as a `.dylib` / `.dll` with C exports. Rejected because: (a) Dart AOT C exports are limited (no streams / async / GC roots across the FFI boundary), (b) the GitHub client uses heavy isolate/future patterns that don't translate cleanly to C ABI, (c) loses Dart hot reload entirely.
- **IPC microservice** (separate Dart process) — Rejected because: (a) lifecycle complexity (start/stop/restart), (b) extra IPC overhead for high-frequency streams (progress), (c) packaging now requires shipping two binaries.
- **Headless Flutter engine** (chosen) — Pros: (a) preserves Dart hot reload, (b) channels are battle-tested, (c) zero new tooling, (d) minimal new code in Dart land. Cons: (a) ships Flutter engine binary even though no UI is rendered (~10MB), (b) startup overhead of Flutter engine boot. The 10MB cost is acceptable.

### 5.2 Why WinUI 3 instead of Win32 / WPF / MAUI?

- **Win32 + C++** — Considered for symmetry with current `windows/runner/`. Rejected because Mica/Acrylic / dark mode / RTL handling in raw Win32 is painful, and there's no good list-virtualization control.
- **WPF** — Rejected: not getting new platform features (Mica is a WinUI 3 primitive).
- **MAUI** — Rejected: ships its own UI abstraction layer that defeats the "native feel" goal.
- **WinUI 3 (WinAppSDK)** — Chosen: native Mica/Acrylic, modern XAML, proper compositor, virtualised lists, supports unpackaged distribution.

### 5.3 Why SwiftUI instead of AppKit?

- **AppKit only** — Considered: most reliable, but verbose and lacks the Liquid Glass declarative API.
- **SwiftUI** (chosen): declarative, has `GlassEffectContainer` / `.glassEffect`, integrates with AppKit where needed via `NSHostingController` / `NSViewRepresentable`. Existing native code (status item, sheets) keeps using AppKit; new view code is SwiftUI.

### 5.4 Why Pigeon instead of hand-written codecs?

- **Hand-written** — Stringly-typed, error-prone, manual codec maintenance. Used today by `AlembicWindowBridge` / `AlembicModalsBridge`.
- **Pigeon** — Generates Swift + C++ + Dart bindings from one Dart definition. Compile-time type safety. Bigger up-front investment but pays back during Phase D / F.

---

## 6. Verification Criteria

A phase is "done" only when ALL of these pass:

- `flutter analyze` clean
- `flutter build macos --release` succeeds
- `flutter build windows --release` succeeds
- `dart test` for BLoC tests passes
- `xcodebuild test` for SwiftUI snapshot tests passes (where added)
- Manual smoke test: clone repo, switch tab, change setting, restart app, settings persist
- No `package:flutter/material.dart` or `package:flutter/cupertino.dart` imports anywhere outside `lib/legacy/` (which doesn't exist post-Phase E)

---

## 7. Out of Scope

- **Mobile** (iOS, Android) — current product is desktop-only.
- **Linux** — out of scope; existing pubspec already doesn't target Linux.
- **Cloud sync / collaboration** — separate roadmap item.
- **Localization** — English-only for now.

---

## 8. Open Questions

1. Should the SwiftUI app target macOS 14 (min) or 15 (min)? Liquid Glass is macOS 26+, but fallback works fine on 14+.
2. Should Windows target Win10 + Win11, or Win11 only? WinUI 3 supports Win10 1809+ but Mica requires Win11 22H2+.
3. Do we want a "theme override" UI in the new app, or just track system theme always? (Currently we have an override stored in Hive.)
4. Is there appetite for a CLI build target later (re-using the same BLoCs)? That would inform how reusable we make the BLoC layer.

---

## 9. Next Actions

1. Approve plan (you).
2. Land Phase A spike (small, contained, reversible).
3. After A success, schedule Phase B (BLoC extraction) and Phase C (SwiftUI shell) in parallel where possible.
