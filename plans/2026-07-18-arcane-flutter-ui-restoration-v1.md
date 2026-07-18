# Arcane Flutter UI Restoration — Plan v1

Date: 2026-07-18
Branch: `glass` (working tree; no commits — user handles git)
Status: PENDING

## Goal

Replace the native SwiftUI/Win32 "liquid glass" UI with a pure Flutter UI built on Arcane, restoring the app to what it was on `main` while retaining every feature added on `glass`. Zero changes to on-disk data formats, Hive keys, config paths, or workspace/archive filesystem layout.

## Non-negotiable constraints

1. No liquid glass, no transparency, no `flutter_acrylic`, no SwiftUI UI layer. Window is fully opaque.
2. No `arcane_desktop` (it hard-depends on `flutter_acrylic`). Tray/window handled directly via `tray_manager` / `window_manager` / `screen_retriever`.
3. Storage contract is immutable: `configPath = <Documents>/Alembic`, encrypted box `d` (`hive_data.key` AES with legacy-key fallback chain), box `s` and all its keys (`config`, `config/<owner>/<repo>`, `autolaunch`, `update_auto_check`, `clone_transport_mode_v1`, `archive_master_targets_v1`, `archive_master_states_v1`, `manual_repo_catalog_v1`), workspace `~/Developer/RemoteGit/<owner>/<repo>`, archives `~/Developer/AlembicArchive/archives/<owner>/<repo>.zip`, masters `~/Developer/AlembicArchiveMaster/<owner>/<repo>`. Boot hardening from glass `main.dart` (stale lock cleanup, settings-box retry with in-memory fallback, encrypted-box recovery, backup pruning, LegacyDataMigrator) is kept verbatim.
4. `lib/main.dart` keeps `box`, `boxSettings`, `configPath`, `cmd`, `expandPath`, `packageInfo`, `sanitizeSecrets`, `applyLaunchAtStartupPreference`, `restoreStoredAuthenticationState` importable (tests depend on them).
5. `test/release/release_workflow_test.dart` asserts literal pubspec content (asset list, `distrib:` scripts, no `flutter_distributor`) — pubspec edits touch dependency lines only.
6. CODE_STYLE_DART.md is mandatory: explicit types, no local `final`, no `var`, `package:` imports only, switch expressions only, no comments, no `buildX()` helpers (extract widgets), StatelessWidget preferred, member ordering.
7. No backwards compatibility, no shims. Deleted code is deleted completely.

## Decisions (resolving recon open questions)

- Window paradigm: opaque tray-first window. `window_manager` with `TitleBarStyle.hidden`, opaque background from theme, native shadow and traffic lights, `setPreventClose(true)` with close = hide. Default 1080x720, min 920x600, size persisted in `boxSettings` (main's mechanism, glass's dimensions). Positioned near tray on summon via `screen_retriever` (main's `_positionNearTray` math). Drag via `DragToMoveArea` wrapping the top bar.
- Hide-on-blur: machinery restored from main's `WindowUtil` (suspend counts, grace period) but the setting defaults OFF, matching the newest glass working-tree intent. `start_hidden` setting restored (default true — tray-first).
- Theme: main's `AlembicShadcnTokens` scheme + `ArcaneTheme(radius: 0.32, surfaceEffect: StaticSurfaceEffect(), surfaceOpacity: 1)` + ThemeMode persisted in `boxSettings` (`alembicThemeModeKey`). One-shot best-effort migration of the glass-era UserDefaults theme preference via `defaults read` at first boot; fall back to system. Glass enabled/intensity/pin/movable UserDefaults are dropped.
- UI kit: salvage main's `lib/ui/**` Alembic control kit and screens verbatim where possible, rebuild glass-only screens in the same kit style. Arcane widgets (`ContextMenu`, `DialogConfirm`, badges, etc.) fill gaps.
- Repo list: glass `RepositoryListStore` is the engine, extended to main's aggregation semantics — fetch across ALL account clients (not just primary), merge workspace-scanned refs and `manual_repo_catalog_v1` refs.
- Main-only features restored: bulk actions, per-repo auth badge + change-auth dialog, clone-transport setting, commit-signing configuration UI, manual repository catalog (wire orphaned `util/repository_catalog.dart`), GitHub shortcut actions (Issues / PRs / New issue / New PR), stale-repo auto-archive timer (`isStaleActive` + `archive()`), token-rotation propagation (`checkAndUpdateToken`), 15-min background refresh, `start_hidden`, `windowMode` marker-dir behavior.
- Glass features retained: everything in the recon feature list — archiveEnabled gating end-to-end, parallel paginated fetch with rate-limit handling, state filter + sort modes + stats strip, activity panel + clone-from-URL, import scanner flow, detail view with per-repo overrides/paths/archive-master card, Updates pane + UpdateSnapshot pipeline + auto-check, diagnostics console, accounts pane semantics, richer tray menu (Refresh / Import / Settings / Restart), boot hardening, legacy data migration.
- `ArchiveMasterService` is constructed and started in the composition root (it was never constructed on glass — latent bug).
- Update install: after `launchSilentUpdateHelper`, the app exits itself (`windowManager.destroy()` + `exit(0)`), since native termination is gone.
- Import semantics: importing selected repos sets the workspace when the scanned root is chosen as workspace, and adds selected GitHub slugs to the manual catalog so they appear in the list.
- Repository detail: single Flutter detail dialog replaces both glass's detail sheet and main's `repository_settings.dart` screen (overrides incl. open subdirectory, account, editor, git tool; paths; archive-master card; actions; live work).
- Diagnostics: `SpikeDiagnostics` becomes `AlembicDiagnostics` (`lib/core/diagnostics.dart`) with an added broadcast stream for the live console.
- Windows: restore main's stock runner files, delete `alembic_bridges.*` / `alembic_backdrop.*`, revert CMakeLists; tray via `tray_manager` (main's WindowUtil path). Windows regains a full UI automatically since the UI is Flutter again.
- Deleted Dart: `lib/spike/` channel layer (`*_channel_bridge.dart`, `repository_actions_bridge.dart`, `repository_work_bridge.dart`, `spike_channels.dart`, `spike_runtime.dart`), `lib/platform/native_*.dart`, `lib/util/goauth.dart` (dead, hardcoded secret), `lib/bloc/spike_app_state_store.dart`, `lib/domain/spike_app_state.dart`. `oauth2` dependency dropped with goauth.

## Target lib/ layout

- `lib/main.dart` — glass boot sections verbatim + composition root (AccountRegistry, RepositoryListStore, WorkspaceScanService, UpdateController, ArchiveMasterService construct+start, diagnostics) + `runApp(AlembicRoot)`.
- `lib/app/` — `alembic_root.dart` (ArcaneApp + theme), `alembic_theme.dart`, `alembic_dialogs.dart`.
- `lib/bloc/repository_list_store.dart` — extended (multi-account + catalog + workspace merge).
- `lib/core/` — existing services unchanged, plus relocated: `workspace_scan_service.dart` (from repository_work_bridge logic: disk scans, 5 s rescan, debounce, localStates/daysUntilArchive derivation, snapshot stream), `update_controller.dart` (from update_channel_bridge: snapshot state machine, auto-check 4 s, throttled progress, install + self-exit), `repository_actions_controller.dart` (from repository_actions_bridge: _resolveContext account precedence, archiveEnabled gates, getDetail composition), `repo_import_scanner.dart`, `legacy_data_migrator.dart`, `boot_context.dart`, `repository_runtime_instance.dart` (the shared runtime global), `diagnostics.dart`.
- `lib/domain/` — `repository_dto.dart` + `repository_list_status.dart` (relocated status/state constants).
- `lib/platform/` — `desktop_platform_adapter.dart`, `macos_tray_service.dart` (restored from main).
- `lib/util/` — as on glass, plus restored `window.dart` (WindowUtil minus all transparency/frameless calls; opaque, hidden titlebar, tray positioning, size persistence, hide-on-blur machinery, start_hidden).
- `lib/presentation/`, `lib/screen/`, `lib/theme/alembic_scroll_behavior.dart`, `lib/ui/`, `lib/widget/` — salvaged from main and extended per screen inventory below.

## Screen inventory (parity targets)

1. Splash — main's, rewired to new composition (services come from main.dart root, not constructed in splash).
2. Login — main's, plus welcome parity: scope chips (repo, read:org), generate-token deep link.
3. Home — main's shell (HomeTopBar brand/search/org filter, AlembicScaffold) with: state filter (All/Active(n)/Archived(n)/Cloud/Syncing(n)) via AlembicTabs replacing the old 3-tab model; sort menu (Needs attention default / Archive soon / Recently updated / State / Name / Owner — exact ranking rules from recon); stats strip (Total/Active/Archived/Cloud/Syncing/Private+forks); repo rows (main's row widgets + glass badges: archive countdown, GitHub archived, work spinner; auth badge restored); state-aware context menu via Arcane `ContextMenu` (glass menu set + restored GitHub shortcuts + Archive Master submenu + change-auth); bulk actions (main); activity panel + clone-from-URL card (glass), responsive (<980 stacked); welcome/loading/error/rate-limited/empty/filtered-empty states (glass phases + diagnosticTail); double-click and details action open detail dialog.
4. Repository detail dialog — glass detail sheet content in Alembic kit (summary chips, actions grid incl. destructive confirms via `DialogConfirm(destructive:)`, in-progress card with %, archive-master card, per-repo overrides incl. account + open subdirectory, paths card). Fix the ".tar.zst" copy — archives are `.zip`.
5. Settings — main's navigation + panes, updated: General (theme mode, launch at startup, update auto-check, hide-on-blur default off, start hidden, data location + reveal); Workspace (dirs + archiveEnabled toggle + days + master dir, pickers via file_picker); Tools (editor/git pickers + clone transport + commit signing status/configure); Archive Master (interval, tracked summary, refresh now, disabled notice); Accounts (main's pane: add/rename/set primary/remove/replace token); Updates (glass pane: status card, progress, Update Now / Check Now / Release page, auto-check toggle, amber dot); Advanced (recreate tray, reveal data folder, diagnostics pointer); Diagnostics info (config path, log file, boot context, migration report — the glass Runtime page content).
6. Import screen — glass import flow in Flutter (folder pick, scan progress, results with filter + Only-GitHub + select all, warnings, import selected).
7. Diagnostics console — glass console in Flutter (live stream, level pills + counts, level/text filters, auto-scroll, copy filtered, mono rows, 500-entry buffer).
8. About dialog — Flutter dialog (name/version/build), replacing native About panel.

daysUntilArchival trap: when `archiveEnabled` is false the Dart getter returns 0 — UI must not render countdown badges or archive-due sorting in that case (glass substituted Int.max at the UI layer).

## Native shells

macOS target: 4 hand-written files. `AppDelegate.swift` (main's: accessory policy, tray install, disableRelaunchOnLogin, no-quit-on-close). `AlembicTrayController.swift` (main's 749-line version as base — pairs with `macos_tray_service.dart`, has `setActivationPolicy` — extended with glass's menu set: Show, Hide, Refresh Repositories, Import Repositories..., Settings..., Restart Alembic, Quit, all forwarded as `onMenuItem` events). `MainFlutterWindow.swift` rewritten: standard `FlutterViewController`, opaque, `launch_at_startup` channel (LaunchAtLogin SPM — KEEP the SPM dependency) + `alembic_tray` channel wiring, start hidden (`orderOut`). Delete the other ~21 Swift files with full pbxproj reference surgery (old-style explicit refs, ~6 per file; use ruby xcodeproj if available, else scripted edits). Keep `LSUIElement=true`, entitlements, Podfile, `AlembicTray.imageset`.

Windows target: main's stock runner (`main.cpp`, `flutter_window.cpp`, `win32_window.cpp`, CMakeLists) restored via `git show main:...`; delete `alembic_bridges.{h,cpp}`, `alembic_backdrop.{h,cpp}`.

## pubspec changes

Add: `arcane: ^6.5.13`, `window_manager: ^0.5.1`, `tray_manager: ^0.5.2`, `screen_retriever: ^0.2.0`, `flutter_svg: ^2.2.3`. Remove: `oauth2`. Keep everything else. Do NOT add `arcane_desktop` or `flutter_acrylic`.

## Verification gates

1. `flutter analyze` — zero issues.
2. `flutter test` — full suite green, zero failures (including release guardrail tests).
3. `flutter build macos --debug` — succeeds.
4. Launch the built app: boots to UI, log shows clean boot, tray icon present, window summons.
5. Storage contract audit: no writes to new Hive keys except documented ones; no changes to key formats.
