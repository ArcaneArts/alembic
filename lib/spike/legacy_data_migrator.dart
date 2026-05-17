import 'dart:io';

import 'package:alembic/spike/spike_diagnostics.dart';

class LegacyDataMigrator {
  LegacyDataMigrator({
    SpikeDiagnostics? diagnostics,
  }) : _diagnostics = diagnostics ?? SpikeDiagnostics.instance;

  static const String _logTag = 'data_migrate';
  static const String _sentinelFileName = '.migration_completed_v1';

  static const List<String> _legacyBundleIds = <String>[
    'art.arcane.alembic',
    'com.arcane.alembic',
    'com.volmitsoftware.alembic',
    'com.alembic.app',
    'art.arcane.alembic.macos',
  ];

  static const List<String> _legacyAppNames = <String>[
    'Alembic',
    'alembic',
    'AlembicApp',
  ];

  static const List<String> _accountDataFiles = <String>[
    'd.hive',
    'd.lock',
    'hive_data.key',
  ];

  static const List<String> _hiveVariants = <String>[
    'd.hive',
    'data.hive',
    'auth.hive',
    'accounts.hive',
  ];

  static const List<String> _settingsFiles = <String>[
    's.hive',
    's.lock',
  ];

  final SpikeDiagnostics _diagnostics;

  Future<MigrationReport> migrateIfNeeded(String targetPath) async {
    _diagnostics.trace(_logTag, 'inspecting target path: $targetPath');
    final Directory targetDirectory = Directory(targetPath);
    if (!targetDirectory.existsSync()) {
      targetDirectory.createSync(recursive: true);
      _diagnostics.trace(_logTag, 'created target directory');
    }

    final File sentinel = File('${targetDirectory.path}/$_sentinelFileName');
    if (sentinel.existsSync()) {
      _diagnostics.trace(_logTag,
          'sentinel present (.migration_completed_v1); skipping legacy scan');
      return const MigrationReport(
        attempted: false,
        sourcePath: null,
        copied: <String>[],
        skipped: <String>['sentinel exists; previous migration already ran'],
        searchedPaths: <String>[],
      );
    }

    final bool targetHasAccount = _targetHasAccountData(targetDirectory);
    final bool targetHasSettings = _targetHasSettingsData(targetDirectory);
    _diagnostics.trace(_logTag,
        'target inventory: hasAccount=$targetHasAccount hasSettings=$targetHasSettings');

    if (targetHasAccount && targetHasSettings) {
      _diagnostics.log(_logTag,
          'target already has populated account+settings data; writing sentinel and skipping');
      _writeSentinel(sentinel, 'target already populated');
      return const MigrationReport(
        attempted: false,
        sourcePath: null,
        copied: <String>[],
        skipped: <String>[],
        searchedPaths: <String>[],
      );
    }

    final String? home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      _diagnostics.warn(_logTag, 'HOME env not set; cannot scan legacy paths');
      return const MigrationReport(
        attempted: false,
        sourcePath: null,
        copied: <String>[],
        skipped: <String>[],
        searchedPaths: <String>[],
      );
    }

    final List<String> candidates = _generateCandidatePaths(home);
    _diagnostics.trace(
        _logTag, 'generated ${candidates.length} candidate path(s) to scan');

    final List<String> searchedPaths = <String>[];
    String? bestSource;
    int bestPayload = 0;
    for (final String candidate in candidates) {
      final Directory directory = Directory(candidate);
      if (!directory.existsSync()) {
        searchedPaths.add('$candidate (missing)');
        _diagnostics.trace(_logTag, 'candidate missing: $candidate');
        continue;
      }
      final int payloadBytes = _accountPayloadBytes(directory);
      searchedPaths.add('$candidate ($payloadBytes bytes)');
      _diagnostics.log(_logTag,
          'candidate present: $candidate (accountPayloadBytes=$payloadBytes)');
      if (payloadBytes > bestPayload) {
        bestSource = candidate;
        bestPayload = payloadBytes;
      }
    }

    if (bestSource == null || bestPayload == 0) {
      _diagnostics.log(_logTag,
          'no legacy account data discovered; writing sentinel so we do not re-scan');
      _writeSentinel(sentinel, 'no legacy data found in any candidate');
      return MigrationReport(
        attempted: false,
        sourcePath: null,
        copied: const <String>[],
        skipped: const <String>[],
        searchedPaths: searchedPaths,
      );
    }

    _diagnostics.success(_logTag,
        'discovered legacy source $bestSource with $bestPayload bytes of account data');
    final List<String> copied = <String>[];
    final List<String> skipped = <String>[];
    final Directory sourceDirectory = Directory(bestSource);

    if (!targetHasAccount) {
      _diagnostics.log(_logTag,
          'migrating ACCOUNT data (hive variants + hive_data.key + locks)');
      await _backupIfPresent(targetDirectory, _accountDataFiles);
      _copyGroup(
        sourceDirectory: sourceDirectory,
        targetDirectory: targetDirectory,
        files: _accountDataFiles,
        copied: copied,
        skipped: skipped,
      );
      _copyHiveVariants(
        sourceDirectory: sourceDirectory,
        targetDirectory: targetDirectory,
        copied: copied,
        skipped: skipped,
      );
    } else {
      _diagnostics.log(
          _logTag, 'preserving existing ACCOUNT data; not overwriting');
      for (final String filename in _accountDataFiles) {
        skipped.add('$filename (target already has data)');
      }
    }

    if (!targetHasSettings) {
      _diagnostics.log(_logTag, 'migrating SETTINGS data (s.hive + lock)');
      _copyGroup(
        sourceDirectory: sourceDirectory,
        targetDirectory: targetDirectory,
        files: _settingsFiles,
        copied: copied,
        skipped: skipped,
      );
    } else {
      _diagnostics.log(
          _logTag, 'preserving existing SETTINGS data; not overwriting');
      for (final String filename in _settingsFiles) {
        skipped.add('$filename (target already has data)');
      }
    }

    if (copied.isEmpty) {
      _diagnostics.warn(
          _logTag,
          'discovered legacy source but copied zero files; '
          'this usually means a permissions issue');
    } else {
      _diagnostics.success(_logTag,
          'legacy migration complete: ${copied.length} file(s) copied');
    }

    _writeSentinel(sentinel,
        'migration ran (copied=${copied.length} skipped=${skipped.length})');

    return MigrationReport(
      attempted: true,
      sourcePath: bestSource,
      copied: copied,
      skipped: skipped,
      searchedPaths: searchedPaths,
    );
  }

  void _writeSentinel(File sentinel, String note) {
    try {
      sentinel.writeAsStringSync(
        'Alembic data migration sentinel\n'
        'Created: ${DateTime.now().toIso8601String()}\n'
        'Reason: $note\n'
        'Delete this file to re-run legacy data migration on next launch.\n',
      );
      _diagnostics.trace(
          _logTag, 'wrote sentinel ${sentinel.path} (delete to re-run)');
    } catch (e) {
      _diagnostics.warn(_logTag, 'could not write migration sentinel: $e');
    }
  }

  void _copyGroup({
    required Directory sourceDirectory,
    required Directory targetDirectory,
    required List<String> files,
    required List<String> copied,
    required List<String> skipped,
  }) {
    for (final String filename in files) {
      final File sourceFile = File('${sourceDirectory.path}/$filename');
      final File targetFile = File('${targetDirectory.path}/$filename');
      if (!sourceFile.existsSync()) {
        _diagnostics.trace(_logTag, 'skip missing $filename');
        skipped.add(filename);
        continue;
      }
      try {
        sourceFile.copySync(targetFile.path);
        final int bytes = targetFile.lengthSync();
        copied.add('$filename ($bytes bytes)');
        _diagnostics.log(_logTag, 'copied $filename ($bytes bytes)');
      } catch (e) {
        skipped.add('$filename ($e)');
        _diagnostics.error(_logTag, 'failed to copy $filename: $e');
      }
    }
  }

  void _copyHiveVariants({
    required Directory sourceDirectory,
    required Directory targetDirectory,
    required List<String> copied,
    required List<String> skipped,
  }) {
    for (final String variant in _hiveVariants) {
      if (variant == 'd.hive') {
        continue;
      }
      final File sourceFile = File('${sourceDirectory.path}/$variant');
      if (!sourceFile.existsSync()) {
        continue;
      }
      final int sourceBytes = sourceFile.lengthSync();
      if (sourceBytes == 0) {
        continue;
      }
      final File targetFile = File('${targetDirectory.path}/$variant');
      try {
        sourceFile.copySync(targetFile.path);
        copied.add('$variant ($sourceBytes bytes)');
        _diagnostics.log(_logTag,
            'copied alternate hive variant $variant ($sourceBytes bytes)');
      } catch (e) {
        skipped.add('$variant ($e)');
        _diagnostics.error(_logTag, 'failed to copy variant $variant: $e');
      }
    }
  }

  Future<void> _backupIfPresent(
    Directory targetDirectory,
    List<String> filenames,
  ) async {
    final int stamp = DateTime.now().millisecondsSinceEpoch;
    for (final String filename in filenames) {
      final File file = File('${targetDirectory.path}/$filename');
      if (!file.existsSync()) {
        continue;
      }
      final int bytes = file.lengthSync();
      if (bytes == 0) {
        try {
          file.deleteSync();
          _diagnostics.trace(_logTag, 'removed empty pre-existing $filename');
        } catch (_) {}
        continue;
      }
      final File backupFile =
          File('${targetDirectory.path}/$filename.pre_migration_$stamp');
      try {
        file.copySync(backupFile.path);
        _diagnostics.log(_logTag,
            'backed up pre-existing $filename ($bytes bytes) to ${backupFile.path}');
      } catch (e) {
        _diagnostics.warn(_logTag, 'could not backup $filename: $e');
      }
    }
  }

  bool _targetHasAccountData(Directory directory) {
    final File keyFile = File('${directory.path}/hive_data.key');
    if (!keyFile.existsSync() || keyFile.lengthSync() == 0) {
      return false;
    }
    for (final String variant in _hiveVariants) {
      final File hiveFile = File('${directory.path}/$variant');
      if (hiveFile.existsSync() && hiveFile.lengthSync() > 0) {
        return true;
      }
    }
    return false;
  }

  bool _targetHasSettingsData(Directory directory) {
    final File hiveFile = File('${directory.path}/s.hive');
    if (!hiveFile.existsSync()) {
      return false;
    }
    return hiveFile.lengthSync() > 0;
  }

  int _accountPayloadBytes(Directory directory) {
    int total = 0;
    for (final String variant in _hiveVariants) {
      final File file = File('${directory.path}/$variant');
      if (file.existsSync()) {
        total += file.lengthSync();
      }
    }
    final File keyFile = File('${directory.path}/hive_data.key');
    if (keyFile.existsSync()) {
      total += keyFile.lengthSync();
    }
    return total;
  }

  List<String> _generateCandidatePaths(String home) {
    final List<String> candidates = <String>[];
    for (final String bundleId in _legacyBundleIds) {
      candidates
          .add('$home/Library/Containers/$bundleId/Data/Documents/Alembic');
      candidates.add(
          '$home/Library/Containers/$bundleId/Data/Library/Application Support/Alembic');
      candidates.add(
          '$home/Library/Containers/$bundleId/Data/Library/Caches/Alembic');
      candidates.add('$home/Library/Group Containers/$bundleId/Alembic');
      candidates.add('$home/Library/Group Containers/$bundleId');
    }
    for (final String appName in _legacyAppNames) {
      candidates.add('$home/Library/Application Support/$appName');
      candidates.add('$home/Library/Caches/$appName');
    }
    final List<String> deduped = <String>[];
    final Set<String> seen = <String>{};
    for (final String candidate in candidates) {
      if (seen.add(candidate)) {
        deduped.add(candidate);
      }
    }
    return deduped;
  }
}

class MigrationReport {
  const MigrationReport({
    required this.attempted,
    required this.sourcePath,
    required this.copied,
    required this.skipped,
    required this.searchedPaths,
  });

  final bool attempted;
  final String? sourcePath;
  final List<String> copied;
  final List<String> skipped;
  final List<String> searchedPaths;

  bool get migrated => attempted && copied.isNotEmpty;
}
