import 'dart:io';

import 'package:alembic/main.dart';

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

  String get fileExplorerName => switch (currentPlatform) {
        AlembicDesktopPlatform.macos => 'Finder',
        AlembicDesktopPlatform.windows => 'File Explorer',
        AlembicDesktopPlatform.other => 'File Browser',
      };

  String get updateArtifactExtension => switch (currentPlatform) {
        AlembicDesktopPlatform.macos => 'dmg',
        AlembicDesktopPlatform.windows => 'exe',
        AlembicDesktopPlatform.other => 'zip',
      };

  String get updateArtifactTarget => switch (currentPlatform) {
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
    if (!path.startsWith('~')) {
      return path;
    }
    final String home = defaultHomeDirectory;
    if (home.isEmpty) {
      return path;
    }
    return path.replaceFirst('~', home);
  }

  String compressHomePath(String path) {
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

  String updateDownloadUrl(String version) {
    final String extension = updateArtifactExtension;
    final String target = updateArtifactTarget;
    return 'https://github.com/ArcaneArts/alembic/raw/refs/heads/main/dist/$version/alembic-$version+$version-$target.$extension';
  }

  String updateDownloadPath({
    required String temporaryDirectory,
    required String version,
  }) {
    final String extension = updateArtifactExtension;
    final String target = updateArtifactTarget;
    return '$temporaryDirectory/Alembic/alembic-$version+$version-$target.$extension';
  }

  Future<int> openInFileExplorer(String path) {
    final String resolved = expandHomePath(path);
    return switch (currentPlatform) {
      AlembicDesktopPlatform.macos => cmd('open', <String>[resolved]),
      AlembicDesktopPlatform.windows => cmd('explorer', <String>[resolved]),
      AlembicDesktopPlatform.other => cmd('xdg-open', <String>[resolved]),
    };
  }

  Future<int> launchDownloadedUpdate(String path) {
    final String resolved = expandHomePath(path);
    return switch (currentPlatform) {
      AlembicDesktopPlatform.macos => cmd('open', <String>[resolved]),
      AlembicDesktopPlatform.windows =>
        cmd('cmd', <String>['/c', 'start', '', resolved]),
      AlembicDesktopPlatform.other => cmd('xdg-open', <String>[resolved]),
    };
  }

  Future<int> openPath(String path) {
    return launchDownloadedUpdate(path);
  }

  String _normalize({required String path}) {
    if (isWindows) {
      return path.replaceAll('\\', '/');
    }
    return path;
  }
}
