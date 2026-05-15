import 'dart:io';

import 'package:alembic/main.dart';
import 'package:path/path.dart' as p;

enum AlembicDesktopPlatform {
  macos,
  windows,
  other,
}

class DesktopPlatformAdapter {
  const DesktopPlatformAdapter._();

  static const DesktopPlatformAdapter instance = DesktopPlatformAdapter._();

  AlembicDesktopPlatform get currentPlatform {
    if (Platform.isMacOS) {
      return AlembicDesktopPlatform.macos;
    }
    if (Platform.isWindows) {
      return AlembicDesktopPlatform.windows;
    }
    return AlembicDesktopPlatform.other;
  }

  bool get isMacOS => currentPlatform == AlembicDesktopPlatform.macos;

  bool get isWindows => currentPlatform == AlembicDesktopPlatform.windows;

  bool get isTrayFirstPlatform => isMacOS || isWindows;

  String get defaultWorkspaceDirectory => switch (currentPlatform) {
        AlembicDesktopPlatform.windows => 'C:\\Developer\\RemoteGit',
        _ => '~/Developer/RemoteGit',
      };

  String get defaultArchiveDirectory => switch (currentPlatform) {
        AlembicDesktopPlatform.windows => 'C:\\Developer\\AlembicArchive',
        _ => '~/Developer/AlembicArchive',
      };

  String get defaultArchiveMasterDirectory => switch (currentPlatform) {
        AlembicDesktopPlatform.windows => 'C:\\Developer\\AlembicArchiveMaster',
        _ => '~/Developer/AlembicArchiveMaster',
      };

  String get fileExplorerName => switch (currentPlatform) {
        AlembicDesktopPlatform.macos => 'Finder',
        AlembicDesktopPlatform.windows => 'File Explorer',
        AlembicDesktopPlatform.other => 'File Browser',
      };

  String get updatePlatformName => switch (currentPlatform) {
        AlembicDesktopPlatform.macos => 'macos',
        AlembicDesktopPlatform.windows => 'windows',
        AlembicDesktopPlatform.other => 'desktop',
      };

  String get defaultHomeDirectory {
    if (isWindows) {
      final String userProfile =
          Platform.environment['USERPROFILE']?.trim() ?? '';
      if (userProfile.isNotEmpty) {
        return userProfile;
      }
      final String homeDrive = Platform.environment['HOMEDRIVE']?.trim() ?? '';
      final String homePath = Platform.environment['HOMEPATH']?.trim() ?? '';
      return '$homeDrive$homePath';
    }
    return Platform.environment['HOME']?.trim() ?? '';
  }

  String expandHomePath(String path) {
    if (path == '~') {
      final String home = defaultHomeDirectory;
      return home.isEmpty ? path : home;
    }
    if (!path.startsWith('~/') && !path.startsWith('~\\')) {
      return path;
    }
    final String home = defaultHomeDirectory;
    if (home.isEmpty) {
      return path;
    }
    final String relativePath = path.substring(2);
    return p.join(home, relativePath);
  }

  String joinPath(String root, String child) {
    String trimmedChild = child.trim();
    if (trimmedChild.isEmpty || trimmedChild == '/' || trimmedChild == '\\') {
      return expandHomePath(root);
    }
    while (trimmedChild.startsWith('/') || trimmedChild.startsWith('\\')) {
      trimmedChild = trimmedChild.substring(1);
    }
    return p.join(expandHomePath(root), trimmedChild);
  }

  String compressHomePath(String path) {
    if (isWindows) {
      return path;
    }

    final String home = defaultHomeDirectory;
    if (home.isEmpty) {
      return path;
    }

    final String normalizedHome = _normalize(path: home);
    final String normalizedPath = _normalize(path: path);
    if (normalizedPath == normalizedHome) {
      return '~';
    }
    if (normalizedPath.startsWith('$normalizedHome/')) {
      return normalizedPath.replaceFirst(normalizedHome, '~');
    }
    return path;
  }

  String currentInstallTarget() => switch (currentPlatform) {
        AlembicDesktopPlatform.macos => _currentMacAppPath(),
        AlembicDesktopPlatform.windows =>
          File(Platform.resolvedExecutable).parent.path,
        AlembicDesktopPlatform.other =>
          File(Platform.resolvedExecutable).parent.path,
      };

  String _currentMacAppPath() {
    Directory directory = File(Platform.resolvedExecutable).parent;
    while (directory.path != directory.parent.path) {
      if (directory.path.endsWith('.app')) {
        return directory.path;
      }
      directory = directory.parent;
    }
    return File(Platform.resolvedExecutable).parent.path;
  }

  Future<int> launchSilentUpdateHelper({
    required String payloadPath,
    required String installTarget,
    required String manualInstallerUrl,
  }) {
    return switch (currentPlatform) {
      AlembicDesktopPlatform.macos => _launchMacUpdateHelper(
          payloadPath: payloadPath,
          installTarget: installTarget,
          manualInstallerUrl: manualInstallerUrl,
        ),
      AlembicDesktopPlatform.windows => _launchWindowsUpdateHelper(
          payloadPath: payloadPath,
          installTarget: installTarget,
          manualInstallerUrl: manualInstallerUrl,
        ),
      AlembicDesktopPlatform.other => launchDownloadedUpdate(payloadPath),
    };
  }

  Future<int> _launchMacUpdateHelper({
    required String payloadPath,
    required String installTarget,
    required String manualInstallerUrl,
  }) async {
    Directory helperDirectory =
        await Directory.systemTemp.createTemp('alembic-update-helper-');
    File script = File(p.join(helperDirectory.path, 'update.sh'));
    await script.writeAsString(r'''
#!/bin/sh
set -eu
payload="$1"
target="$2"
app_pid="$3"
manual="$4"
log_dir="${HOME:-/tmp}/Library/Logs"
mkdir -p "$log_dir" 2>/dev/null || true
log="$log_dir/AlembicUpdater.log"
exec >>"$log" 2>&1
echo "Starting Alembic update"
echo "Payload: $payload"
echo "Target: $target"
echo "App pid: $app_pid"
while kill -0 "$app_pid" 2>/dev/null; do
  sleep 1
done
if [ ! -f "$payload" ]; then
  echo "Update payload does not exist"
  [ -n "$manual" ] && open "$manual" || true
  exit 1
fi
staging="$(mktemp -d "${TMPDIR:-/tmp}/alembic-update.XXXXXX")"
backup="${target}.previous"
if ! ditto -x -k "$payload" "$staging"; then
  echo "Failed to extract update payload"
  [ -n "$manual" ] && open "$manual" || true
  exit 1
fi
app="$(find "$staging" -maxdepth 3 \( -name "Alembic.app" -o -name "alembic.app" \) -type d | head -n 1)"
if [ -z "$app" ]; then
  app="$(find "$staging" -maxdepth 3 -iname "*.app" -type d | head -n 1)"
fi
if [ -z "$app" ]; then
  echo "Alembic app bundle was not found in the update payload"
  [ -n "$manual" ] && open "$manual" || true
  exit 1
fi
rm -rf "$backup"
if [ -d "$target" ]; then
  mv "$target" "$backup"
fi
if ! mv "$app" "$target"; then
  echo "Failed to move update app into place"
  rm -rf "$target"
  if [ -d "$backup" ]; then
    mv "$backup" "$target"
  fi
  [ -n "$manual" ] && open "$manual" || true
  exit 1
fi
rm -rf "$backup" "$staging"
echo "Alembic update installed"
open "$target"
''');
    await Process.start(
      '/bin/sh',
      <String>[
        script.path,
        payloadPath,
        installTarget,
        '$pid',
        manualInstallerUrl
      ],
      mode: ProcessStartMode.detached,
    );
    return 0;
  }

  Future<int> _launchWindowsUpdateHelper({
    required String payloadPath,
    required String installTarget,
    required String manualInstallerUrl,
  }) async {
    Directory helperDirectory =
        await Directory.systemTemp.createTemp('alembic-update-helper-');
    File script = File(p.join(helperDirectory.path, 'update.ps1'));
    await script.writeAsString(r'''
param(
  [string]$Payload,
  [string]$Target,
  [int]$Pid,
  [string]$Manual
)
$ErrorActionPreference = "Stop"
$Log = Join-Path $env:TEMP "AlembicUpdater.log"
$Backup = ""
Start-Transcript -Path $Log -Append | Out-Null
try {
  Write-Output "Starting Alembic update"
  Write-Output "Payload: $Payload"
  Write-Output "Target: $Target"
  Write-Output "App pid: $Pid"
  while (Get-Process -Id $Pid -ErrorAction SilentlyContinue) {
    Start-Sleep -Seconds 1
  }
  if (!(Test-Path -LiteralPath $Payload)) {
    throw "Update payload does not exist"
  }
  $Staging = Join-Path $env:TEMP ("alembic-update-" + [guid]::NewGuid())
  New-Item -ItemType Directory -Path $Staging -Force | Out-Null
  Expand-Archive -LiteralPath $Payload -DestinationPath $Staging -Force
  $Exe = Get-ChildItem -Path $Staging -Recurse -Filter "Alembic.exe" | Select-Object -First 1
  if ($null -eq $Exe) {
    throw "Alembic.exe was not found in update payload"
  }
  $Source = $Exe.Directory.FullName
  $Parent = Split-Path -Parent $Target
  $Leaf = Split-Path -Leaf $Target
  $Backup = Join-Path $Parent "$Leaf.previous"
  Remove-Item -LiteralPath $Backup -Recurse -Force -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $Target) {
    Move-Item -LiteralPath $Target -Destination $Backup -Force
  }
  New-Item -ItemType Directory -Path $Target -Force | Out-Null
  Copy-Item -Path (Join-Path $Source "*") -Destination $Target -Recurse -Force
  Remove-Item -LiteralPath $Backup -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $Staging -Recurse -Force -ErrorAction SilentlyContinue
  Start-Process -FilePath (Join-Path $Target "Alembic.exe")
} catch {
  if (![string]::IsNullOrWhiteSpace($Backup) -and (Test-Path -LiteralPath $Backup)) {
    Remove-Item -LiteralPath $Target -Recurse -Force -ErrorAction SilentlyContinue
    Move-Item -LiteralPath $Backup -Destination $Target -Force
  }
  if (![string]::IsNullOrWhiteSpace($Manual)) {
    Start-Process $Manual
  }
  exit 1
} finally {
  Stop-Transcript | Out-Null
}
''');
    await Process.start(
      'powershell.exe',
      <String>[
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        script.path,
        '-Payload',
        payloadPath,
        '-Target',
        installTarget,
        '-Pid',
        '$pid',
        '-Manual',
        manualInstallerUrl,
      ],
      mode: ProcessStartMode.detached,
      runInShell: true,
    );
    return 0;
  }

  Future<int> openInFileExplorer(String path) {
    final String resolved = expandHomePath(path);
    return switch (currentPlatform) {
      AlembicDesktopPlatform.macos => cmd('open', <String>[resolved]),
      AlembicDesktopPlatform.windows => _openInWindowsFileExplorer(resolved),
      AlembicDesktopPlatform.other => cmd('xdg-open', <String>[resolved]),
    };
  }

  Future<int> _openInWindowsFileExplorer(String path) async {
    final FileSystemEntityType type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.file) {
      return cmd('explorer', <String>['/select,$path']);
    }
    return cmd('explorer', <String>[path]);
  }

  Future<int> launchDownloadedUpdate(String path) {
    final String resolved = expandHomePath(path);
    return switch (currentPlatform) {
      AlembicDesktopPlatform.macos => cmd('open', <String>[resolved]),
      AlembicDesktopPlatform.windows =>
        cmd('cmd', <String>['/c', 'start', '""', resolved]),
      AlembicDesktopPlatform.other => cmd('xdg-open', <String>[resolved]),
    };
  }

  Future<int> openPath(String path) {
    final String resolved = expandHomePath(path);
    if (isWindows &&
        FileSystemEntity.typeSync(resolved) == FileSystemEntityType.directory) {
      return openInFileExplorer(resolved);
    }
    return launchDownloadedUpdate(resolved);
  }

  String _normalize({required String path}) {
    if (isWindows) {
      return path.replaceAll('\\', '/');
    }
    return path;
  }
}
