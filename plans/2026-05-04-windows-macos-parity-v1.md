# Windows/macOS Parity Execution Checklist

## Objective

Make Alembic behave on Windows like the existing macOS tray/menu-bar flow while preserving platform-native Windows expectations.

## Execution Status

### Phase 1 — Define Exact Windows Behavior Contract

- [x] Treat Windows and macOS as tray-first desktop platforms.
- [x] Default fresh Windows installs to `start_hidden = true`.
- [x] Default fresh Windows installs to `hide_on_blur = true`.
- [x] Hide the window from the taskbar for tray-first operation.
- [x] Preserve existing user settings when keys already exist.

### Phase 2 — Window and Tray Parity

- [x] Add shared `isTrayFirstPlatform` platform helper.
- [x] Use tray-first helper for `hide_on_blur` defaults.
- [x] Use tray-first helper for `start_hidden` defaults.
- [x] Use tray-first helper for `skipTaskbar`.
- [x] Add tray menu item: Show Alembic.
- [x] Add tray menu item: Hide Alembic.
- [x] Keep tray menu item: Exit Alembic.
- [x] Route tray Show/Hide/Exit clicks to the correct window behavior.
- [x] Enable close interception with `setPreventClose(true)`.
- [x] Make close button hide the window instead of terminating the app.
- [x] Keep Exit Alembic as the explicit quit path.

### Phase 3 — Windows Positioning and Focus Polish

- [x] Keep tray-click show/focus behavior.
- [x] Clamp window position to display visible bounds.
- [x] Add fallback positioning for unreliable or missing tray bounds.
- [x] Use primary display fallback when tray bounds cannot identify a display.
- [x] Reassert frameless/transparent window visuals after showing.
- [ ] Manually validate taskbar bottom layout on Windows.
- [ ] Manually validate taskbar top layout on Windows.
- [ ] Manually validate taskbar left/right layout on Windows, if available.
- [ ] Manually validate auto-hidden taskbar behavior on Windows.
- [ ] Manually validate multi-monitor positioning on Windows.
- [ ] Manually validate 100%, 125%, and 150% DPI scaling.

### Phase 4 — Windows Startup / Login Launch

- [x] Centralize startup preference application.
- [x] Apply startup preference during app initialization.
- [x] Apply startup preference immediately when changed in settings.
- [x] Add logging for startup enable/disable success.
- [x] Add warning logging for startup enable/disable false returns.
- [x] Add exception logging for startup enable/disable failures.
- [x] Warn if Windows autostart path does not look like a packaged `.exe`.
- [ ] Manually validate Startup Apps entry after packaging.
- [ ] Manually validate restart/log-in starts Alembic hidden in tray.

### Phase 5 — Windows Path, Tool Launch, and Repo Workflow Parity

- [x] Keep Windows workspace default as `C:\Developer\RemoteGit`.
- [x] Keep Windows archive default as `C:\Developer\AlembicArchive`.
- [x] Add Windows archive master default as `C:\Developer\AlembicArchiveMaster`.
- [x] Add cross-platform home-path expansion in the platform adapter.
- [x] Add platform-aware path joining for repository open directories.
- [x] Use platform-aware path joining when opening repositories in editors.
- [x] Use platform-aware path joining when finding Dart packages for macros.
- [x] Route repository reveal/open-in-file-explorer through the platform adapter.
- [x] Use Windows Explorer `/select,` for files.
- [x] Use Windows Explorer direct directory opening for folders.
- [x] Hide unsupported macOS-only tools from Windows settings.
- [x] Add Windows fallback executable lookup for common editor installs.
- [x] Add Windows fallback executable lookup for common Git GUI installs.
- [x] Log actionable external-tool launch failures.
- [ ] Manually validate VS Code launch for a normal Windows install.
- [ ] Manually validate IntelliJ launch for a normal Windows install.
- [ ] Manually validate Zed launch for a normal Windows install, if installed.
- [ ] Manually validate GitHub Desktop launch for a normal Windows install.
- [ ] Manually validate GitKraken launch for a normal Windows install.
- [ ] Manually validate Fork launch for a normal Windows install, if installed.
- [ ] Manually validate SourceTree launch for a normal Windows install, if installed.

### Phase 6 — Update Flow and Installer Launch

- [x] Keep Windows update artifact target as `windows`.
- [x] Keep Windows update artifact extension as `.exe`.
- [x] Centralize artifact version label generation.
- [x] Use platform-aware download paths.
- [x] Launch Windows update installer through `cmd /c start`.
- [x] Throw an explicit failure if installer launch returns non-zero.
- [x] Shut down Alembic after launching the downloaded installer.
- [ ] Manually validate produced installer name matches update URL logic.
- [ ] Manually validate downloaded Windows installer launches from temp storage.

### Phase 7 — Windows Runner Metadata and Branding

- [x] Update Windows company metadata.
- [x] Update Windows file description metadata.
- [x] Update Windows internal name metadata.
- [x] Update Windows original filename metadata.
- [x] Update Windows product name metadata.
- [x] Update Windows copyright metadata.
- [x] Set Windows native window title to Alembic.
- [x] Set Windows executable target name to Alembic.
- [ ] Manually validate Windows file properties show Alembic branding.
- [ ] Manually validate Task Manager/Startup Apps branding after install.

### Phase 8 — Packaging / Distribution for Windows

- [x] Add Windows job to `distribute_options.yaml`.
- [x] Add Windows distribution script entry.
- [x] Keep macOS distribution job intact.
- [ ] Manually validate `flutter_distributor` Windows EXE packaging output.
- [ ] Manually validate installer supports upgrade over an existing install.
- [ ] Manually validate uninstall removes app cleanly.

### Phase 9 — Regression Test Plan

- [x] Run `dart format` on modified Dart files.
- [x] Run `dart analyze` successfully.
- [x] Run `flutter analyze` successfully.
- [x] Run `flutter pub get` successfully.
- [ ] Run `flutter test` successfully. Blocked: project currently has no `test` directory, so Flutter exits before running any tests.
- [x] Run `flutter build windows --release` successfully. Completed after adding a CMake plugin-source staging step for generated Flutter plugin symlinks that were present but not traversable in this Windows environment.
- [ ] Complete manual Windows acceptance tests from this checklist. Blocked: requires a packaged app and an interactive Windows tray/login session.

## Manual Acceptance Checklist

- [ ] Fresh install launches hidden in tray.
- [ ] Tray left-click opens/focuses Alembic.
- [ ] Tray right-click opens context menu.
- [ ] Show Alembic menu item opens/focuses window.
- [ ] Hide Alembic menu item hides window.
- [ ] Exit Alembic menu item terminates process.
- [ ] Clicking outside hides window when hide-on-blur is enabled.
- [ ] Clicking outside does not hide window when hide-on-blur is disabled.
- [ ] Clicking X hides to tray and does not quit.
- [ ] Autolaunch starts hidden after Windows login.
- [ ] Multi-monitor tray positioning remains on-screen.
- [ ] Repository opens in File Explorer.
- [ ] Repository opens in configured editor.
- [ ] Repository opens in configured Git GUI.
- [ ] Clone/archive/restore workflows use Windows paths correctly.
- [ ] Update check downloads Windows artifact.
- [ ] Downloaded Windows installer launches.
- [ ] Upgrade preserves expected settings.
- [ ] Uninstall removes app cleanly.

## Notes

- `flutter test` cannot currently pass because the repository has no `test` directory.
- `flutter build windows --release` now succeeds and produced `build\windows\x64\runner\Release\Alembic.exe`. The build needed a CMake plugin-source staging step because Flutter generated plugin symlinks were present but not traversable in this Windows environment.
- The Cargokit `Get-Item C:\Users\brian\AppData` message was caused by plugin tooling resolving through hidden/symlinked paths; staged Cargokit CMake files are now patched to skip `resolve_symlinks.ps1` because the staged build path is already real.
- Flutter emitted non-fatal pub advisory decode/newer-package warnings during dependency resolution.
- Manual desktop validation still requires a packaged Windows app and an interactive Windows tray/login session.
