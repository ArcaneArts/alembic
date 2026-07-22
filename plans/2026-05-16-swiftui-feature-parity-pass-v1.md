# SwiftUI / Glass Feature Parity Pass (macOS)

**Date**: 2026-05-16
**Version**: 1
**Status**: Authored — ready to execute
**Extends**: `plans/2026-05-15-native-rewrite-with-headless-flutter-v1.md` (Phase D — macOS feature parity)

---

## 1. Objective

The current SwiftUI/Glass UI on macOS shows the repository list and lets the user sign in/out, but **none of the other workflows are wired**:

- Cannot interact with repositories (no clone / open / pull / archive / fork / delete).
- No settings UI at all (cannot change workspace dir, archive dir, editor, git tool, etc.).
- No multi-account management (only single sign-in / sign-out via the empty-state).
- No application menu, no native About panel.
- Tray menu shows a single Show/Quit, no power-user actions.
- No repository detail view, no progress feedback, no archive-master controls.

This plan finishes Phase D of the headless-Flutter rewrite by exposing **every Dart-side capability that exists in `lib/core/arcane_repository.dart`, `lib/core/account_registry.dart`, `lib/util/repo_config.dart`, `lib/util/git_accounts.dart`, `lib/util/archive_master.dart`, and `lib/util/git_signing.dart`** through typed method channels and rendering the corresponding SwiftUI surfaces.

When this plan lands, the SwiftUI app reaches **functional parity** with the pre-rewrite Flutter UI documented in `lib/widget/repository_tile_actions.dart:1-142`.

---

## 2. Current State Snapshot

### What works today (Swift side)

- `macos/Runner/AlembicSpikeRootView.swift:1-321` — App shell with top bar (status chip, Import button, info, diagnostics toggle), diagnostics console, boot detail sheet, basic import sheet.
- `macos/Runner/AlembicRepositoryListView.swift:1-591` — Welcome / loading / error / empty / ready states; toolbar with search + owner filter + refresh; rows show owner, name, language, stars, forks, private/fork/archived badges.
- `macos/Runner/AlembicSignInSheet.swift` — Token entry sheet (works).
- `macos/Runner/AlembicImportSheet.swift` — Workspace scan + import (works).
- `macos/Runner/AlembicTrayController.swift` — Production-grade `NSStatusItem` with show/hide/exit menu and channel `alembic_tray`.

### What works today (Dart side)

- `lib/bloc/repository_list_store.dart:1-420` — Paginated GitHub fetch with rich diagnostics, pushed to Swift via `alembic.spike.repositories` channel.
- `lib/spike/repository_channel_bridge.dart:1-163` — Handles `refresh`, `retry`, `openInBrowser`, `signInWithToken`, `signOut`.
- `lib/spike/workspace_channel_bridge.dart:1-200` — Handles `getWorkspacePath`, `setWorkspacePath`, `scanDirectory`, `importDiscovered`.
- `lib/spike/spike_runtime.dart:1-155` — App heartbeat + status, no settings.
- `lib/core/arcane_repository.dart:1-934` — Full repo lifecycle (clone, pull, archive, unarchive, fork, archive-master, delete) — **completely unreachable from Swift today**.
- `lib/core/account_registry.dart:1-90`, `lib/util/git_accounts.dart:1-315` — Full multi-account CRUD — **only `add` and `remove` reachable from Swift**.
- `lib/util/repo_config.dart:1-199` — Global config (workspace dir, archive dir, archive master dir, days, editor, git tool) + per-repo config — **none reachable from Swift**.
- `lib/util/archive_master.dart`, `lib/core/archive_master_service.dart` — Archive master scheduler + per-repo state — **none reachable from Swift**.
- `lib/util/git_signing.dart:1-?` — Signing key management — **none reachable from Swift**.

### What's missing (the user complaint, decomposed)

| Capability | Today in Swift | Today in Dart | Phase |
| --- | --- | --- | --- |
| Right-click / context-menu on repository row | absent | not exposed | 1 |
| Clone / open / pull on a repository | absent | `ArcaneRepository.ensureRepositoryActive`, `open`, `ensureRepositoryUpdated` | 1 |
| Archive / unarchive a repository | absent | `ArcaneRepository.archive`, `unarchive`, `updateArchive`, `archiveFromCloud` | 1 |
| Fork-and-clone | absent | `ArcaneRepository.forkAndClone` | 1 |
| Delete repository / delete archive | absent | `ArcaneRepository.deleteRepository`, `deleteArchive` | 1 |
| Open in Finder | absent | `ArcaneRepository.openInFinder` | 1 |
| Repo state (active / archived / cloud) indicator | absent | `ArcaneRepository.state` | 1 |
| Work-in-progress (clone %, pull, archive) live | absent | `RepositoryRuntime.repoWork`, `streamWorkEntries` | 1 |
| Archive Master enroll / unenroll / refresh / promote | absent | `ArcaneRepository.ensureArchiveMaster`, `removeArchiveMaster`, `promoteArchiveMaster` | 1 |
| Multi-account list + reorder + set primary | absent | `loadGitAccounts`, `setPrimaryGitAccount`, `reorderGitAccounts`, `renameGitAccount` | 2 |
| Sign in with token (multi) | empty state only | `addGitAccount` via channel | 2 |
| General settings (theme, autolaunch, hide-on-blur, start-hidden) | absent | `boxSettings.get/put` | 3 |
| Workspace settings (workspace dir, archive dir, archive master dir, days) | absent | `AlembicConfig` | 3 |
| Tools settings (editor, git tool, signing) | absent | `ApplicationTool`, `GitTool`, `GitSigningManager` | 3 |
| Archive Master settings (interval) | absent | `AlembicConfig.archiveMasterIntervalMinutes` | 3 |
| Per-repo settings (editor override, git override, open dir, account) | absent | `AlembicRepoConfig` | 4 |
| Application menu (Cmd-,, About, Quit) | empty | n/a | 5 |
| Tray menu power-user actions | minimal | n/a | 5 |
| Repository detail view (metadata, work stream, last-opened) | absent | `ArcaneRepository.repoPath`, `streamWorkEntries`, `daysUntilArchival`, `getLatestFileModificationTime` | 6 |

---

## 3. Architecture Decisions

### 3.1 Channel layout

We extend the existing channel surface rather than introducing Pigeon at this stage. Pigeon comes later (Phase B of the parent rewrite plan); for now we keep the hand-written method channels because the surfaces in this plan are bounded and shippable today.

| Channel | Existing | Plan extends | New verbs |
| --- | --- | --- | --- |
| `alembic.spike` | yes | — | — |
| `alembic.spike.repositories` | yes (read-only + sign-in) | **yes** | `cloneRepository`, `pullRepository`, `openRepository`, `openInFinder`, `archiveRepository`, `unarchiveRepository`, `updateArchive`, `archiveFromCloud`, `deleteRepository`, `deleteArchive`, `forkRepository`, `enrollArchiveMaster`, `unenrollArchiveMaster`, `refreshArchiveMaster`, `promoteArchiveMaster` |
| `alembic.spike.repositories.work` | **new** | — | `workEntries` (Dart→Swift push), `syncingRepositories`, `activeRepositories`, `archivedRepositories`, `archiveMasterStates` |
| `alembic.spike.workspace` | yes | — | — |
| `alembic.spike.accounts` | **new** | — | `state` (push), `addAccount`, `removeAccount`, `renameAccount`, `setPrimary`, `reorderAccounts` |
| `alembic.spike.settings` | **new** | — | `state` (push), `getAll`, `setGeneral`, `setWorkspace`, `setTools`, `setArchiveMaster`, `setRepoConfig`, `pickDirectory` |
| `alembic.spike.diagnostics` | yes | — | — |

### 3.2 Channel design rules

1. **Push-on-mutate**: every mutation handler invokes the appropriate `state` push back to Swift so the SwiftUI `ObservableObject` reflects the new state without polling.
2. **Per-repo addressing**: all repo-action verbs take `fullName` (string) and look up the live `Repository` from a small registry kept on `RepositoryListStore` (we already have the DTOs there, but for actions we need the live `github.dart` `Repository` object — see §3.3).
3. **Errors as values**: every mutation returns `{ok: bool, error?: string}` (never a `FlutterError`) so the Swift UI can show inline error toasts without exception handling.
4. **Idempotent reads**: every `getAll` / `state` push includes the full snapshot; no incremental diffs (simplicity > bytes saved for ~50 settings keys and <10k repos).
5. **Hand-off back to existing flutter UI is out of scope.** SwiftUI is the only UI on macOS as of this plan's predecessor.

### 3.3 Live repository registry

The action verbs operate on a `github.dart` `Repository` object (which `ArcaneRepository` requires). `RepositoryListStore` already builds a `Repository` from the GitHub API response (`lib/bloc/repository_list_store.dart:319`), but it currently throws the object away and keeps only the DTO. We will:

- Add `RepositoryListStore._cache: Map<String, Repository>` (key: lowercased fullName).
- Populate it inside `_fetchRepositoriesPaginated` (line 319) alongside the DTO push.
- Expose `Repository? findRepository(String fullName)` for the action bridge.
- Keep memory bounded: when a refresh replaces the list, drop entries not in the new list.

### 3.4 Repository runtime singleton

`ArcaneRepository` requires a `RepositoryRuntime`. Today, the spike has no runtime instance (it never instantiates `ArcaneRepository`). We will:

- Create `lib/spike/spike_repository_runtime.dart` exporting a top-level `final RepositoryRuntime spikeRepositoryRuntime = RepositoryRuntime();`.
- All action handlers use this singleton.
- The action bridge subscribes to `spikeRepositoryRuntime.repoWork` and `syncingRepositories` and pushes the snapshot over `alembic.spike.repositories.work`.

### 3.5 SwiftUI ownership

The SwiftUI side gets four new `ObservableObject` bridges:

- `RepositoryActionsBridgeState` — holds work entries, syncing/active sets, exposes async action methods to views.
- `AccountsBridgeState` — holds account list, primary, supports CRUD.
- `SettingsBridgeState` — holds general + workspace + tools + archive-master snapshots.
- `RepositoryDetailBridgeState` — holds per-repo overrides + live work stream filtered to one repo (Phase 6).

Each bridge follows the existing pattern in `AlembicRepositoryListBridge` (`macos/Runner/AlembicRepositoryListBridge.swift:62-302`): one `*BridgeState: ObservableObject` for views, one bridge class that owns the `FlutterMethodChannel` and translates state pushes.

---

## 4. Phased Execution

### Phase 1 — Repository Actions and Live State (1.5 days)

**Goal**: every action exposed by `ArcaneRepository` is reachable from a right-click on a repository row in the SwiftUI list.

#### 1.1 Dart side

- Add `lib/spike/spike_repository_runtime.dart` defining a single shared `RepositoryRuntime`.
- Extend `RepositoryListStore` to cache `Repository` objects keyed by lowercased fullName and to expose `Repository? findRepository(String)`.
- Add `lib/spike/repository_actions_bridge.dart`:
  - Method channel `alembic.spike.repositories.actions` (split from the existing `repositories` channel so we don't bloat the existing handler).
  - Handlers for: `clone`, `pull`, `open`, `openInFinder`, `archive`, `unarchive`, `updateArchive`, `archiveFromCloud`, `delete`, `deleteArchive`, `fork`, `enrollArchiveMaster`, `unenrollArchiveMaster`, `refreshArchiveMaster`, `promoteArchiveMaster`.
  - Each handler resolves the `Repository`, builds an `ArcaneRepository` with the shared runtime and the resolved `accountId` (from per-repo config) or the primary account, runs the operation, and returns `{ok, error?, state?}`.
  - On success, push the updated repo state snapshot back to Swift on the work channel.
- Add `lib/spike/repository_work_bridge.dart`:
  - Method channel `alembic.spike.repositories.work` for native-side requests (e.g. `getSnapshot`).
  - Subscribes to `spikeRepositoryRuntime.repoWork`, `syncingRepositories`, and `changed` streams.
  - Computes and pushes:
    - `activeRepositories: [String]` — repo full names with `.git` directory present.
    - `archivedRepositories: [String]` — repo full names with archive zip present.
    - `archiveMasterStates: Map<String, ArchiveMasterRepoState>` from `lib/util/archive_master.dart`.
    - `syncingRepositories: [String]`.
    - `workEntries: [{fullName, kind, message, progress?}]`.
  - Recomputes whenever the streams fire or when `clearActiveRepositories`/`addActiveRepository` is called.
  - The first snapshot is computed by scanning the workspace and archive dirs on bridge attach.
- Wire the two new bridges in `lib/spike/spike_runtime.dart` next to `_repositoryBridge` and `_workspaceBridge`.
- Update `lib/spike/spike_channels.dart` with the new channel name constants and method-name constants.

#### 1.2 Swift side

- Add `macos/Runner/AlembicRepositoryActionsBridge.swift`:
  - `RepositoryActionsBridgeState: ObservableObject` with:
    - `@Published var activeRepositories: Set<String>`
    - `@Published var archivedRepositories: Set<String>`
    - `@Published var syncingRepositories: Set<String>`
    - `@Published var workEntries: [RepositoryWorkEntry]`
    - `@Published var archiveMasterStates: [String: ArchiveMasterRepoStateView]`
  - `AlembicRepositoryActionsBridge` (singleton):
    - `attach(messenger:)` — installs handlers on `alembic.spike.repositories.actions` (callbacks from Dart for action results) and `alembic.spike.repositories.work` (state pushes).
    - One method per action that wraps `channel.invokeMethod` with completion handler returning `ActionResult` (`ok`, `errorMessage`).
- Update `macos/Runner/AlembicRepositoryListView.swift`:
  - Add `repoStateIcon(for: RepositoryItem)`: cloud / disc / archive-box badge based on bridge state.
  - Add `.contextMenu` modifier on each `AlembicRepositoryRow` building the action list dynamically based on state.
  - Reuse the existing menu builder in `AlembicMenusBridge` only for non-list right-clicks; for SwiftUI rows we use SwiftUI's native `.contextMenu` (already Liquid-Glass-styled by SwiftUI on macOS 26).
  - Show a small inline progress / status pill on rows with active `workEntries`.
- Add `macos/Runner/AlembicRepositoryActionsConfirmSheets.swift`:
  - Reusable destructive-confirm sheet (`Delete repository?`, `Delete archive?`, `Unenroll archive master?`) presented via `.alert` with `.destructive` button.
- Update `macos/Runner/MainFlutterWindow.swift:120-126` to attach the new bridge.
- Update `macos/Runner/AlembicSpikeRootView.swift` to inject the new bridge into the repo list view.

#### 1.3 Verification

- Right-clicking a repo with no local clone shows: Clone, Fork, Archive From Cloud, Open on GitHub, Issues, Pull Requests.
- Right-clicking a repo with a local clone shows: Open, Pull, Open in Finder, Archive, Delete, Fork (greyed if same owner), Open on GitHub, ...
- Right-clicking an archived repo shows: Activate, Update Archive, Delete Archive, Open on GitHub.
- Clicking Clone shows live progress percent in the row pill (driven by `workEntries`).
- After clone, the row state icon flips from cloud to disc within 200 ms.

---

### Phase 2 — Accounts Management (0.5 day)

**Goal**: multi-account list, primary selection, rename, remove, reorder, add — all from a native pane.

#### 2.1 Dart side

- Add `lib/spike/accounts_channel_bridge.dart`:
  - Channel `alembic.spike.accounts`.
  - Verbs (Swift→Dart): `getAll`, `add` (token + name), `remove` (id), `rename` (id, name), `setPrimary` (id), `reorder` ([ids]).
  - Push (Dart→Swift): `state` — `{accounts: [{id, name, login, tokenType, createdAtMs}], primaryId}`.
  - `add` reuses `TokenValidator` and `addGitAccount`. On success triggers a repository refresh.
  - Subscribe to changes by re-reading `loadGitAccounts()` after every mutation (Hive is synchronous so this is fine).
- Wire in `spike_runtime.dart`.

#### 2.2 Swift side

- Add `macos/Runner/AlembicAccountsBridge.swift`:
  - `AccountsBridgeState: ObservableObject` with:
    - `@Published var accounts: [AccountSummary]`
    - `@Published var primaryAccountId: String?`
  - `AlembicAccountsBridge` singleton mirroring the existing pattern.
- Add `macos/Runner/Settings/AlembicAccountsPane.swift`:
  - `List` of accounts with rename inline edit, "Set primary" radio, "Sign out" destructive button.
  - "Add account..." footer button presents the existing `AlembicSignInSheet`.
  - Drag-to-reorder via SwiftUI `.onMove`.
- Settings window scaffolding lives under `macos/Runner/Settings/` (new directory). The Accounts pane is reachable via the Settings entry added in Phase 3.

#### 2.3 Verification

- Adding a second token shows two accounts; the first remains primary unless changed.
- Renaming an account updates the chip in the top bar within 100 ms.
- Removing the primary auto-promotes the next account.
- Reordering persists across app restart.

---

### Phase 3 — Settings Window (1 day)

**Goal**: native macOS settings window with sidebar navigation; every key that exists in `AlembicConfig` is editable.

#### 3.1 Dart side

- Add `lib/spike/settings_channel_bridge.dart`:
  - Channel `alembic.spike.settings`.
  - Verbs (Swift→Dart):
    - `getAll` → snapshot of `{general, workspace, tools, archiveMaster}`.
    - `setGeneral` → `{themeMode?, autolaunchEnabled?, startHidden?, hideOnBlur?}`. Persists to `boxSettings` and re-applies `launch_at_startup` via existing `applyLaunchAtStartupPreference`.
    - `setWorkspace` → `{workspaceDirectory?, archiveDirectory?, archiveMasterDirectory?, daysToArchive?}`. Persists to `AlembicConfig`.
    - `setTools` → `{editorTool?, gitTool?}`. Persists to `AlembicConfig`.
    - `setArchiveMaster` → `{intervalMinutes?}`. Persists to `AlembicConfig`.
    - `pickDirectory` → `{currentPath, title}` → returns chosen path (Swift opens `NSOpenPanel`, Dart only persists the result on the follow-up `setWorkspace`/etc. call).
  - Push (Dart→Swift): `state` after every mutation.
- Wire in `spike_runtime.dart`.

#### 3.2 Swift side

- Add `macos/Runner/AlembicSettingsBridge.swift`:
  - `SettingsBridgeState: ObservableObject` with sub-objects: `general`, `workspace`, `tools`, `archiveMaster`.
  - Each sub-object has `@Published` properties for every settable key, plus a `commit()` that calls the appropriate Dart verb and reverts on error.
- Add `macos/Runner/Settings/AlembicSettingsWindow.swift`:
  - Standalone `NSWindow` (not a sheet) opened on demand.
  - `NavigationSplitView` with sidebar: General, Workspace, Tools, Archive Master, Accounts, Diagnostics.
  - Each pane is a separate SwiftUI view file in `macos/Runner/Settings/`.
- Add `macos/Runner/Settings/AlembicGeneralPane.swift`:
  - Theme mode picker (Auto / Light / Dark).
  - Toggles: launch at login, start hidden, hide on blur.
- Add `macos/Runner/Settings/AlembicWorkspacePane.swift`:
  - Three labelled path rows with browse buttons (each invokes the `pickDirectory` verb).
  - "Days until archive" stepper.
- Add `macos/Runner/Settings/AlembicToolsPane.swift`:
  - Editor tool dropdown (VS Code, IntelliJ, Zed, Xcode — filter by `supportedOnCurrentPlatform`).
  - Git tool dropdown (GitHub Desktop, GitKraken, Tower, Fork, SourceTree).
- Add `macos/Runner/Settings/AlembicArchiveMasterPane.swift`:
  - "Sync interval" stepper in minutes (default 1440).
  - List of enrolled repos (driven by `archiveMasterStates` from the actions bridge in Phase 1).
- Add `macos/Runner/Settings/AlembicDiagnosticsPane.swift`:
  - Reuses the existing `AlembicDiagnosticsConsole`.
  - "Reveal data folder" button → opens `state.configPath` in Finder via channel call.
- Wire the Settings window open command via the `,` keyboard shortcut on the main app menu (Phase 5).

#### 3.3 Verification

- Each setting persists across app restart.
- Changing workspace dir triggers a repo state refresh in the actions bridge (because active-repo detection scans the new directory).
- Changing launch-at-login flips the macOS Login Items entry.
- Theme mode is wired but a no-op visually until SwiftUI views read it (acceptable: Liquid Glass already adapts to system theme).

---

### Phase 4 — Per-Repository Settings (0.25 day)

**Goal**: per-repo overrides for editor, git tool, open directory, and account.

#### 4.1 Dart side

- Extend `settings_channel_bridge.dart` with two more verbs:
  - `getRepoConfig` → `{fullName}` → `{editorTool?, gitTool?, openDirectory, accountId?}`.
  - `setRepoConfig` → `{fullName, editorTool?, gitTool?, openDirectory?, accountId?}` → persists via `setRepoConfig(repository, AlembicRepoConfig(...))` and pushes the new repo state.

#### 4.2 Swift side

- Add `macos/Runner/AlembicRepoSettingsSheet.swift`:
  - SwiftUI sheet anchored on the main window.
  - Form fields: editor override, git tool override, open directory (with TextField + Browse), account override (account dropdown from `AccountsBridgeState`).
  - Saved via `setRepoConfig` and dismissed.
- Hook into the Phase 1 context menu: "Repository Settings..." menu item presents this sheet.

#### 4.3 Verification

- Per-repo overrides win over global defaults when opening.
- Cleared overrides fall back to globals on next open.

---

### Phase 5 — Application Menu, About, Expanded Tray (0.25 day)

**Goal**: native menu bar with About / Preferences / Quit; tray menu with quick actions.

#### 5.1 Application menu (macOS)

- Add `macos/Runner/AlembicApplicationMenu.swift`:
  - Built and assigned in `AppDelegate.applicationDidFinishLaunching`.
  - Standard `App` menu: About Alembic (calls `NSApp.orderFrontStandardAboutPanel`), Preferences... (`⌘,` → opens settings window), Hide / Quit.
  - File menu: New Token... (`⌘N` → opens sign-in sheet), Import Workspace... (`⌘O` → opens import sheet).
  - Edit menu: standard cut/copy/paste/select all (provided by SwiftUI defaults).
  - View menu: Toggle Diagnostics Console (`⌘D`), Refresh Repositories (`⌘R`).
  - Window menu: standard zoom / minimize.

#### 5.2 About panel

- Set `CFBundleShortVersionString` and `CFBundleVersion` from `Info.plist` so the standard about panel shows the right version.
- Add a credits .rtf to `macos/Runner/Resources/Credits.rtf` so the about panel has Alembic branding.

#### 5.3 Tray menu

- Extend `AlembicTrayController` (`macos/Runner/AlembicTrayController.swift`) right-click menu to include:
  - Show / Hide Alembic (existing).
  - Refresh Repositories.
  - Settings... (`⌘,`).
  - Sign In... (only if no accounts).
  - About Alembic.
  - Quit (existing).

#### 5.4 Verification

- `⌘,` from anywhere in the app opens settings.
- `⌘R` from anywhere refreshes repos.
- About menu shows correct version + Alembic credits.

---

### Phase 6 — Repository Detail View (0.5 day)

**Goal**: optional detail pane / sheet showing repo metadata, live work stream, and days-until-archive.

#### 6.1 Dart side

- Extend the actions bridge with `getRepoDetail(fullName)` returning:
  - `repoPath`, `imagePath`, `archiveMasterPath`.
  - `state` (active / archived / cloud).
  - `lastOpenMs`, `daysUntilArchival`, `latestFileModificationMs`.
  - Resolved account id and login.
- Push live `workEntries` filtered to this repo over the existing work channel.

#### 6.2 Swift side

- Add `macos/Runner/AlembicRepositoryDetailSheet.swift`:
  - Triggered from row tap (single-click currently does nothing meaningful) or "Details" context-menu entry.
  - Shows metadata, copyable paths, work list with progress bars, archive-master status badge.
  - "Open on GitHub", "Open in Finder", "Repository Settings..." action row.

#### 6.3 Verification

- Detail sheet shows live clone progress.
- Closing the sheet doesn't cancel the operation.
- Days-until-archive matches what the legacy Flutter UI showed.

---

## 5. File Inventory

### New Dart files

- `lib/spike/spike_repository_runtime.dart`
- `lib/spike/repository_actions_bridge.dart`
- `lib/spike/repository_work_bridge.dart`
- `lib/spike/accounts_channel_bridge.dart`
- `lib/spike/settings_channel_bridge.dart`

### Modified Dart files

- `lib/spike/spike_channels.dart` — new channel + method constants.
- `lib/spike/spike_runtime.dart` — wire new bridges.
- `lib/bloc/repository_list_store.dart` — `Repository` cache + `findRepository`.

### New Swift files

- `macos/Runner/AlembicRepositoryActionsBridge.swift`
- `macos/Runner/AlembicRepositoryActionsConfirmSheets.swift`
- `macos/Runner/AlembicAccountsBridge.swift`
- `macos/Runner/AlembicSettingsBridge.swift`
- `macos/Runner/AlembicApplicationMenu.swift`
- `macos/Runner/AlembicRepoSettingsSheet.swift`
- `macos/Runner/AlembicRepositoryDetailSheet.swift`
- `macos/Runner/Settings/AlembicSettingsWindow.swift`
- `macos/Runner/Settings/AlembicGeneralPane.swift`
- `macos/Runner/Settings/AlembicWorkspacePane.swift`
- `macos/Runner/Settings/AlembicToolsPane.swift`
- `macos/Runner/Settings/AlembicArchiveMasterPane.swift`
- `macos/Runner/Settings/AlembicAccountsPane.swift`
- `macos/Runner/Settings/AlembicDiagnosticsPane.swift`

### Modified Swift files

- `macos/Runner/AlembicSpikeRootView.swift` — inject new bridges, add "Settings" button.
- `macos/Runner/AlembicRepositoryListView.swift` — add `.contextMenu`, state-aware row.
- `macos/Runner/MainFlutterWindow.swift` — attach new bridges.
- `macos/Runner/AppDelegate.swift` — install application menu.
- `macos/Runner/AlembicTrayController.swift` — expanded right-click menu.

---

## 6. Risk Register

| # | Risk | Mitigation |
| --- | --- | --- |
| 1 | `ArcaneRepository` was authored against the Flutter-rooted runtime and may import `BuildContext` indirectly | `arcane_repository.dart` only imports `package:github/github.dart`, `package:rxdart`, `package:fast_log`, `package:archive` and other pure-Dart packages plus `lib/main.dart` for `cmd`/`box`. Verified by reading the imports at `lib/core/arcane_repository.dart:1-18`. Safe to invoke from the headless engine. |
| 2 | Long-running operations (clone of a 1 GB repo) block the method-channel reply | Use `unawaited(handler(...))` and return immediately; the work-channel `state` push communicates progress separately. Confirmed pattern in `repository_channel_bridge.dart:118` (`unawaited(_store.refresh())`). |
| 3 | `RepositoryRuntime.activeRepositories` is built from `addActiveRepository` calls but the spike never warm-starts it from disk | Phase 1.1 work bridge scans `${config.workspaceDirectory}/<owner>/<repo>/.git` and `${config.archiveDirectory}/archives/<owner>/<repo>.zip` on attach, seeding `_activeRepositories` and `archivedRepositories` before the first push. |
| 4 | NSOpenPanel must run on the main thread; Dart's `pickDirectory` verb requires a Swift implementation, not a Dart one | Swift-side `pickDirectory` opens `NSOpenPanel` and then calls back to Dart with the chosen path. Modelled on the existing pattern in `AlembicWorkspaceBridge.presentFolderPicker:120-161`. |
| 5 | SwiftUI `.contextMenu` on macOS 26 supports Liquid Glass automatically; on macOS 12-25 it falls back to standard menu | Acceptable — feature parity is preserved on all supported macOS versions. |
| 6 | Account list reorder via `.onMove` requires a stable identity | Use `account.id` (already stable in `GitAccount`). |
| 7 | Archive Master pane may try to enroll a repo before the work bridge has scanned the workspace | Disable enroll actions until `RepositoryActionsBridgeState.activeRepositories.contains(fullName)`. |
| 8 | Per-repo settings sheet must read the current per-repo overrides; the channel call is async; UI flashes empty fields | Pre-fetch in the row context-menu handler before presenting the sheet (await `getRepoConfig` then construct the sheet with seeded values). |
| 9 | New channel pushes increase chattiness; diagnostics console may flood | The work bridge throttles to one push per 100 ms when streams fire faster (debounce via `Stream.throttle`). |
| 10 | `flutter analyze` may complain about new bridges referencing private fields | All new bridges expose only public API; verified pattern in `repository_channel_bridge.dart`. |

---

## 7. Verification Plan

### Per-phase

Each phase is independently shippable. After each:

- `flutter analyze` returns clean.
- `flutter build macos --debug` succeeds.
- The phase's specific verification steps (§ above) pass on a clean macOS run.

### End-to-end (after all phases)

- Cold launch → sign in → see repos → right-click → clone → see progress → row flips to active.
- Settings → change workspace dir to an empty folder → re-clone the repo → succeeds with new path.
- Settings → Accounts → add second token → switch primary → repo list re-fetches with new account.
- Per-repo settings → set IntelliJ override → Open → IntelliJ opens (not the global default).
- Archive a repo → row shows archive badge → context-menu shows Activate → Activate succeeds.
- Fork a repo from a different owner → fork appears in the list → row state is active.
- Application menu Cmd-, → settings window opens.
- Tray menu Refresh Repositories → list re-fetches.
- Quit via tray, relaunch → settings persist.

### Regression checks

- Existing flows still work: sign-in, sign-out, browser open, workspace import.
- No regressions in tray click, hide-on-blur, window positioning.
- Diagnostics console still streams.

---

## 8. Out of Scope (for this plan)

- **Windows / WinUI** — Phase F of the parent rewrite; this plan is macOS only.
- **Pigeon migration** — Phase B of the parent rewrite; we extend hand-written channels here.
- **Background sync / scheduled archive master cron** — `archive_master_service.dart` exists but is not yet started; will be wired in a follow-up plan.
- **Repository auth migration to native sheet** — Phase 4.5 of the parent rewrite; not needed for this parity pass since we expose multi-account from the new accounts pane.
- **Update flow modernization** — `app_update_service.dart` will keep using whatever Flutter triggers it has; out of scope.

---

## 9. Decision Log

- **2026-05-16**: Plan authored to close the gap reported by the user (`Repos visible, no interaction, no settings`). The parent rewrite plan's Phase D milestones are still abstract; this plan reduces them to concrete files and verbs.
- **2026-05-16**: Split repo state-push and repo actions into separate channels (`alembic.spike.repositories.work` vs `alembic.spike.repositories.actions`) so chatty action results don't compete with the high-frequency state pushes on a single channel.
- **2026-05-16**: Keep using hand-written method channels; Pigeon migration deferred to parent plan Phase B to avoid a tooling step blocking this user-visible work.
- **2026-05-16**: Use SwiftUI `.contextMenu` for row right-clicks rather than `AlembicMenusBridge`. The bridge stays for application-menu integration only.
