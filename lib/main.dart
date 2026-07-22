import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:alembic/app/alembic_root.dart';
import 'package:alembic/bloc/repository_list_store.dart';
import 'package:alembic/core/account_registry.dart';
import 'package:alembic/core/archive_master_service.dart';
import 'package:alembic/core/boot_context.dart';
import 'package:alembic/core/diagnostics.dart';
import 'package:alembic/core/legacy_data_migrator.dart';
import 'package:alembic/core/repository_actions_controller.dart';
import 'package:alembic/core/repository_runtime_instance.dart';
import 'package:alembic/core/update_controller.dart';
import 'package:alembic/core/workspace_scan_service.dart';
import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:alembic/util/git_accounts.dart';
import 'package:alembic/util/legacy_prefs_migration.dart';
import 'package:alembic/util/window.dart';
import 'package:fast_log/fast_log.dart';
import 'package:flutter/widgets.dart' as fw;
import 'package:hive_flutter/adapters.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

late Box box;
late Box boxSettings;
late PackageInfo packageInfo;
bool windowMode = false;
late String configPath;

late AccountRegistry accountRegistry;
late RepositoryListStore repositoryListStore;
late WorkspaceScanService workspaceScanService;
late UpdateController updateController;
late RepositoryActionsController repositoryActionsController;

typedef CommandRunner = Future<int> Function(
  String command,
  List<String> args, {
  BehaviorSubject<String>? stdout,
  BehaviorSubject<String>? stderr,
  String? workingDirectory,
  bool redactOutput,
});

Future<void> main() async {
  fw.WidgetsFlutterBinding.ensureInitialized();
  try {
    await _initializeDartRuntime();
    await _startServices();
    await WindowUtil.init();
    AlembicDiagnostics.instance.success('main', 'Alembic Dart runtime ready');
    success('Alembic Dart runtime ready');
    fw.runApp(const AlembicRoot());
  } catch (e, stackTrace) {
    AlembicDiagnostics.instance
        .error('main', 'Dart runtime init failed: $e\n$stackTrace');
    error('Dart runtime init failed: $e');
    error('$stackTrace');
  }
}

Future<void> _startServices() async {
  accountRegistry = AccountRegistry.fromCurrentStorage();
  repositoryListStore = RepositoryListStore(registry: accountRegistry);
  workspaceScanService = WorkspaceScanService(
    store: repositoryListStore,
    runtime: repositoryRuntimeInstance,
  );
  updateController = UpdateController();
  repositoryActionsController = RepositoryActionsController(
    store: repositoryListStore,
    runtime: repositoryRuntimeInstance,
  );
  ArchiveMasterService archiveMaster = ArchiveMasterService(
    registry: accountRegistry,
    runtime: repositoryRuntimeInstance,
  );
  setArchiveMasterService(archiveMaster);
  archiveMaster.start();
  await workspaceScanService.start();
  updateController.start();
  unawaited(repositoryListStore.refresh());
  success('Services constructed and started');
}

Future<void> _initializeDartRuntime() async {
  lDebugMode = Platform.environment['ALEMBIC_FAST_LOG_STDOUT'] == '1' ||
      Platform.environment['ALEMBIC_DIAGNOSTICS_STDOUT'] == '1';
  await _setupDirectoriesAndLogging();
  await _cleanupStaleLockFiles();
  await _cleanupOldBackupFiles();
  await _migrateLegacyDataIfNeeded();
  final Future<PackageInfo> packageInfoFuture = PackageInfo.fromPlatform();
  Hive.init(configPath);
  box = await _openEncryptedDataBox();
  BootContext.instance.hiveEntries = box.length;
  boxSettings = await _openSettingsBoxWithRetry();
  await LegacyPrefsMigration.run();
  await restoreStoredAuthenticationState();
  packageInfo = await packageInfoFuture;
  await _configureStartup();
  success('Dart storage and auth state initialized');
}

Future<Box> _openSettingsBoxWithRetry() async {
  final AlembicDiagnostics diagnostics = AlembicDiagnostics.instance;
  const int maxAttempts = 4;
  Object? lastError;
  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      final Box opened = await Hive.openBox('s');
      if (attempt > 1) {
        diagnostics.success(
            'hive_open', 'settings box opened on attempt $attempt');
      }
      return opened;
    } catch (e) {
      lastError = e;
      diagnostics.warn(
        'hive_open',
        'settings box open attempt $attempt failed: $e',
      );
      final File lockFile = File('$configPath/s.lock');
      if (lockFile.existsSync()) {
        try {
          lockFile.deleteSync();
          diagnostics.log('hive_open', 'deleted stale s.lock to retry');
        } catch (deleteError) {
          diagnostics.warn(
              'hive_open', 'could not delete s.lock: $deleteError');
        }
      }
      await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
    }
  }
  diagnostics.error(
    'hive_open',
    'settings box failed after $maxAttempts attempts; using in-memory fallback: $lastError',
  );
  return Hive.openBox<dynamic>(
    's_fallback_${DateTime.now().millisecondsSinceEpoch}',
    bytes: Uint8List(0),
  );
}

Future<void> _cleanupStaleLockFiles() async {
  final AlembicDiagnostics diagnostics = AlembicDiagnostics.instance;
  final List<String> lockNames = <String>[
    's.lock',
    'd.lock',
    'alembic.cb.lock',
    'alembic.hb.lock',
  ];
  for (final String name in lockNames) {
    final File lockFile = File('$configPath/$name');
    if (!lockFile.existsSync()) {
      continue;
    }
    try {
      final FileStat stat = lockFile.statSync();
      final Duration age = DateTime.now().difference(stat.modified);
      if (age.inMinutes > 5 || stat.size == 0) {
        lockFile.deleteSync();
        diagnostics.log(
          'lock_cleanup',
          'removed stale lock $name (age=${age.inMinutes}m size=${stat.size})',
        );
      }
    } catch (e) {
      diagnostics.trace('lock_cleanup', 'could not inspect/delete $name: $e');
    }
  }
}

Future<void> _cleanupOldBackupFiles() async {
  final AlembicDiagnostics diagnostics = AlembicDiagnostics.instance;
  final Directory dir = Directory(configPath);
  if (!dir.existsSync()) {
    return;
  }
  try {
    final List<FileSystemEntity> entries = dir.listSync();
    final List<File> backups = entries
        .whereType<File>()
        .where((File f) => f.path.contains('.pre_migration_'))
        .toList()
      ..sort((File a, File b) =>
          b.statSync().modified.compareTo(a.statSync().modified));
    if (backups.length <= 1) {
      return;
    }
    final List<File> toDelete = backups.sublist(1);
    int deleted = 0;
    for (final File file in toDelete) {
      try {
        file.deleteSync();
        deleted++;
      } catch (_) {}
    }
    if (deleted > 0) {
      diagnostics.log(
        'backup_cleanup',
        'removed $deleted old pre_migration backup(s); kept newest',
      );
    }
  } catch (e) {
    diagnostics.trace('backup_cleanup', 'cleanup failed: $e');
  }
}

Future<void> _migrateLegacyDataIfNeeded() async {
  if (!Platform.isMacOS) {
    return;
  }
  try {
    final LegacyDataMigrator migrator = LegacyDataMigrator();
    final MigrationReport report = await migrator.migrateIfNeeded(configPath);
    BootContext.instance.migrationReport = report;
    if (report.migrated) {
      AlembicDiagnostics.instance.success(
          'main',
          'Migrated legacy account data from ${report.sourcePath} '
              '(${report.copied.length} file(s))');
    } else if (report.attempted) {
      AlembicDiagnostics.instance.warn(
          'main',
          'Legacy migration attempted but no files were copied '
              '(source=${report.sourcePath ?? '<unknown>'})');
    } else {
      AlembicDiagnostics.instance.trace('main',
          'No legacy migration needed; searched ${report.searchedPaths.length} path(s)');
    }
  } catch (e, stackTrace) {
    AlembicDiagnostics.instance
        .error('main', 'Legacy data migration failed: $e');
    AlembicDiagnostics.instance.trace('main', 'migration stack: $stackTrace');
  }
}

Future<void> _setupDirectoriesAndLogging() async {
  final Directory appDocDir = await getApplicationDocumentsDirectory();
  configPath = '${appDocDir.path}/Alembic';
  await Directory(configPath).create(recursive: true);
  BootContext.instance.configPath = configPath;
  windowMode = Directory('$configPath/WINDOW_MODE').existsSync();
  await _setupLogging();
  info('App directory: $configPath');
}

Future<void> _setupLogging() async {
  final File logFile = File('$configPath/alembic.log');
  if (await logFile.exists()) {
    final int fileSize = await logFile.length();
    if (fileSize > 1024 * 1024) {
      await logFile.delete();
      verbose('Log file deleted because it exceeded 1MB');
    }
  }

  final IOSink logSink = logFile.openWrite(mode: FileMode.writeOnlyAppend);
  lLogHandler = (LogCategory category, String message) {
    logSink.writeln('${category.name}: $message');
    _forwardFastLogToDiagnostics(category, message);
  };
}

void _forwardFastLogToDiagnostics(LogCategory category, String message) {
  AlembicDiagnostics diagnostics = AlembicDiagnostics.instance;
  (String, void Function(String, String)) route = switch (category) {
    LogCategory.error => ('fast_log', diagnostics.error),
    LogCategory.warning => ('fast_log', diagnostics.warn),
    LogCategory.success => ('fast_log', diagnostics.success),
    LogCategory.verbose => ('fast_log', diagnostics.trace),
    LogCategory.network => ('fast_log:network', diagnostics.trace),
    LogCategory.navigation => ('fast_log:nav', diagnostics.trace),
    LogCategory.actioned => ('fast_log:action', diagnostics.log),
    _ => ('fast_log', diagnostics.log),
  };
  route.$2(route.$1, message);
}

Future<void> restoreStoredAuthenticationState() async {
  await migrateLegacyTokenIfNeeded();
  final List<GitAccount> accounts = loadGitAccounts();
  final bool hasAccounts = accounts.isNotEmpty;
  final bool storedAuthFlag =
      box.get(gitAccountsLegacyAuthFlag, defaultValue: false) == true;

  if (!hasAccounts) {
    if (storedAuthFlag) {
      await box.put(gitAccountsLegacyAuthFlag, false);
    }
    return;
  }

  if (!storedAuthFlag) {
    await box.put(gitAccountsLegacyAuthFlag, true);
  }

  final GitAccount? primary = loadPrimaryGitAccount();
  if (primary == null) {
    return;
  }

  final String legacyToken =
      box.get(gitAccountsLegacyTokenKey, defaultValue: '').toString().trim();
  if (legacyToken != primary.token) {
    await box.put(gitAccountsLegacyTokenKey, primary.token);
  }

  final String legacyType =
      box.get(gitAccountsLegacyTypeKey, defaultValue: '').toString().trim();
  if (legacyType != primary.tokenType) {
    await box.put(gitAccountsLegacyTypeKey, primary.tokenType);
  }
}

Future<Box> _openEncryptedDataBox() async {
  final AlembicDiagnostics diagnostics = AlembicDiagnostics.instance;
  final File hiveFile = File('$configPath/d.hive');
  final int initialBytes = hiveFile.existsSync() ? hiveFile.lengthSync() : 0;
  diagnostics.trace(
    'hive_open',
    'opening encrypted box d at $configPath/d.hive (existing=$initialBytes bytes)',
  );

  final List<int> secureKey = await _loadOrCreateDataKey();
  diagnostics.trace(
    'hive_open',
    'loaded secure key (${secureKey.length} bytes) from hive_data.key',
  );

  try {
    final Box box = await Hive.openBox(
      'd',
      encryptionCipher: HiveAesCipher(secureKey),
    );
    diagnostics.trace(
      'hive_open',
      'opened with primary key; entries=${box.length} '
          'keys=${box.keys.take(8).toList()}',
    );
    return box;
  } catch (e, stackTrace) {
    diagnostics.warn(
      'hive_open',
      'primary key failed (likely from a previous install with deterministic key): $e',
    );
    diagnostics.trace('hive_open', 'primary key error stack: $stackTrace');

    final List<int> legacyKey = _legacyHiveKey();
    diagnostics.log(
      'hive_open',
      'attempting deterministic legacy key fallback (${legacyKey.length} bytes)',
    );

    final Box legacyBox;
    try {
      legacyBox = await Hive.openBox(
        'd',
        encryptionCipher: HiveAesCipher(legacyKey),
      );
    } catch (e2, stackTrace2) {
      diagnostics.error(
        'hive_open',
        'BOTH primary and legacy keys failed to decrypt d.hive '
            '(initialBytes=$initialBytes): $e2',
      );
      diagnostics.trace('hive_open', 'legacy key error stack: $stackTrace2');
      diagnostics.error(
        'hive_open',
        'd.hive is unrecoverable with both keys; opening a fresh empty box',
      );
      await Hive.deleteBoxFromDisk('d');
      return Hive.openBox(
        'd',
        encryptionCipher: HiveAesCipher(secureKey),
      );
    }

    final Map<dynamic, dynamic> legacyData =
        Map<dynamic, dynamic>.from(legacyBox.toMap());
    diagnostics.success(
      'hive_open',
      'legacy key decrypted box; recovered ${legacyData.length} key(s) '
          'keys=${legacyData.keys.take(8).toList()}',
    );
    await legacyBox.close();
    await Hive.deleteBoxFromDisk('d');
    diagnostics.trace('hive_open', 'deleted old encrypted box from disk');

    final Box migratedBox = await Hive.openBox(
      'd',
      encryptionCipher: HiveAesCipher(secureKey),
    );
    if (legacyData.isNotEmpty) {
      await migratedBox.putAll(legacyData);
      diagnostics.success(
        'hive_open',
        're-encrypted ${legacyData.length} entries with the new key',
      );
    } else {
      diagnostics.warn(
        'hive_open',
        'legacy box contained zero entries; nothing carried over',
      );
    }
    await migratedBox.close();
    final Box finalBox = await Hive.openBox(
      'd',
      encryptionCipher: HiveAesCipher(secureKey),
    );
    diagnostics.success(
      'hive_open',
      'reopened with new key; final entries=${finalBox.length}',
    );
    return finalBox;
  }
}

Future<List<int>> _loadOrCreateDataKey() async {
  final File keyFile = File('$configPath/hive_data.key');
  if (await keyFile.exists()) {
    final String encoded = (await keyFile.readAsString()).trim();
    final List<int> decoded = base64Decode(encoded);
    if (decoded.length != 32) {
      throw Exception('Invalid Hive key length');
    }
    return decoded;
  }

  final Random random = Random.secure();
  final List<int> key = List<int>.generate(32, (_) => random.nextInt(256));
  await keyFile.writeAsString(base64Encode(key), flush: true);
  return key;
}

List<int> _legacyHiveKey() {
  final Random random = Random(384858582220);
  return List<int>.generate(32, (_) => random.nextInt(256));
}

Future<void> _configureStartup() async {
  verbose('PackageInfo: ${packageInfo.version}');

  final String startupExecutable = Platform.resolvedExecutable;
  verbose('Configuring launch startup mode for $startupExecutable');
  if (DesktopPlatformAdapter.instance.isWindows &&
      !startupExecutable.toLowerCase().endsWith('.exe')) {
    warn('Windows autolaunch executable does not look like a packaged .exe: '
        '$startupExecutable');
  }

  launchAtStartup.setup(
    appName: 'Alembic',
    appPath: startupExecutable,
  );

  final bool autolaunchEnabled =
      boxSettings.get('autolaunch', defaultValue: true) == true;
  await applyLaunchAtStartupPreference(autolaunchEnabled);
}

Future<bool> applyLaunchAtStartupPreference(bool enabled) async {
  final String action = enabled ? 'enable' : 'disable';
  try {
    final bool result = enabled
        ? await launchAtStartup.enable()
        : await launchAtStartup.disable();
    if (result) {
      verbose('Autolaunch ${enabled ? 'enabled' : 'disabled'}');
    } else {
      warn('Autolaunch $action returned false');
    }
    return result;
  } catch (e, stackTrace) {
    error('Failed to $action autolaunch: $e');
    error('Failed to $action autolaunch stack trace: $stackTrace');
    return false;
  }
}

String expandPath(String path) {
  return DesktopPlatformAdapter.instance.expandHomePath(path);
}

Future<int> cmd(
  String command,
  List<String> args, {
  BehaviorSubject<String>? stdout,
  BehaviorSubject<String>? stderr,
  String? workingDirectory,
  bool redactOutput = true,
}) async {
  String resolvedCommand = expandPath(command);
  List<String> resolvedArgs = args.map(expandPath).toList();
  String? resolvedWorkingDirectory =
      workingDirectory == null ? null : expandPath(workingDirectory);
  _logCommand(resolvedCommand, resolvedArgs);

  Process process = await Process.start(
    resolvedCommand,
    resolvedArgs,
    workingDirectory: resolvedWorkingDirectory,
    runInShell: true,
  );

  bool sawStderr = false;
  Future<void> stdoutDone = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .map((String line) {
        String safe = sanitizeSecrets(line);
        stdout?.add(redactOutput ? safe : line);
        return safe;
      })
      .listen((String line) => verbose('cmd $resolvedCommand stdout: $line'))
      .asFuture<void>();

  Future<void> stderrDone = process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .map((String line) {
        sawStderr = true;
        String safe = sanitizeSecrets(line);
        stderr?.add(redactOutput ? safe : line);
        return safe;
      })
      .listen((String line) => error('cmd $resolvedCommand stderr: $line'))
      .asFuture<void>();

  int exitCode = await process.exitCode;
  await Future.wait<void>(<Future<void>>[stdoutDone, stderrDone]);
  if (exitCode == 0) {
    success('cmd $resolvedCommand exit code: $exitCode');
  } else if (_isExpectedMissingGitConfigValue(
    resolvedCommand,
    resolvedArgs,
    exitCode,
    sawStderr,
  )) {
    verbose('cmd $resolvedCommand exit code: $exitCode');
  } else {
    error('cmd $resolvedCommand exit code: $exitCode');
  }
  return exitCode;
}

bool _isExpectedMissingGitConfigValue(
  String command,
  List<String> args,
  int exitCode,
  bool sawStderr,
) {
  String normalizedCommand = command.replaceAll('\\', '/');
  String commandName = normalizedCommand.split('/').last.toLowerCase();
  return commandName == 'git' &&
      exitCode == 1 &&
      !sawStderr &&
      args.contains('config') &&
      args.contains('--get');
}

void _logCommand(String command, List<String> args) {
  String redactedArgs = args.map((String arg) {
    return sanitizeSecrets(arg);
  }).join(' ');
  verbose('cmd $command $redactedArgs');
}

String sanitizeSecrets(String input) {
  String output = input;
  output = output.replaceAllMapped(
    RegExp(r'ghp_[A-Za-z0-9_]+'),
    (_) => 'ghp_********',
  );
  output = output.replaceAllMapped(
    RegExp(r'github_pat_[A-Za-z0-9_]+'),
    (_) => 'github_pat_********',
  );
  output = output.replaceAllMapped(
    RegExp(r'https://([^:@/]+)@github\.com'),
    (_) => 'https://********@github.com',
  );
  return output;
}
