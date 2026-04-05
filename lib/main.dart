import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alembic/app/alembic_theme.dart';
import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:alembic/screen/splash.dart';
import 'package:alembic/util/window.dart';
import 'package:arcane/arcane.dart';
import 'package:arcane_desktop/arcane_desktop.dart';
import 'package:fast_log/fast_log.dart';
import 'package:flutter/widgets.dart' as fw;
import 'package:hive_flutter/adapters.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';

late Box box;
late Box boxSettings;
late PackageInfo packageInfo;
bool windowMode = false;
late String configPath;

typedef CommandRunner = Future<int> Function(
  String command,
  List<String> args, {
  BehaviorSubject<String>? stdout,
  BehaviorSubject<String>? stderr,
  String? workingDirectory,
  bool redactOutput,
});

Future<void> main() async {
  try {
    fw.WidgetsFlutterBinding.ensureInitialized();
    await _initializeApp();
    AWM.barTitle = _buildWindowTitle;
    AWM.barLeading = _buildWindowLeading;
    AWM.tray = trayManager;
    fw.runApp(const AlembicRoot());
  } catch (e, stackTrace) {
    error('ERROR $e');
    error('ERROR $stackTrace');
  }
}

Future<void> _initializeApp() async {
  lDebugMode = true;
  await _setupDirectoriesAndLogging();
  await _setupAppSettings();
  success('=====================================');
}

Future<void> _setupDirectoriesAndLogging() async {
  final Directory appDocDir = await getApplicationDocumentsDirectory();
  configPath = '${appDocDir.path}/Alembic';
  await Directory(configPath).create(recursive: true);
  windowMode = Directory('$configPath/WINDOW_MODE').existsSync();
  info('App directory: $configPath');
  await _setupLogging();
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
  };
}

Future<void> _setupAppSettings() async {
  verbose('Getting package info');
  final Future<PackageInfo> packageInfoFuture = PackageInfo.fromPlatform();
  Hive.init(configPath);
  verbose('Opening Hive boxes');
  box = await _openEncryptedDataBox();
  verbose('Opening settings box');
  boxSettings = await Hive.openBox('s');
  await restoreStoredAuthenticationState();
  verbose('Init Window');
  await WindowUtil.init();
  await _configureStartup(packageInfoFuture);
}

Future<void> restoreStoredAuthenticationState() async {
  String token = box.get('1', defaultValue: '').toString().trim();
  bool authenticated = box.get('authenticated', defaultValue: false) == true;
  if (token.isEmpty) {
    if (authenticated) {
      await box.put('authenticated', false);
    }
    return;
  }

  if (!authenticated) {
    await box.put('authenticated', true);
  }

  String tokenType = box.get('token_type', defaultValue: 'unknown').toString();
  if (tokenType == 'unknown' || tokenType.isEmpty) {
    await box.put('token_type', detectStoredTokenType(token));
  }
}

String detectStoredTokenType(String token) {
  if (token.startsWith('github_pat_')) {
    return 'fine_grained';
  }
  if (token.startsWith('ghp_')) {
    return 'personal';
  }
  return 'classic';
}

Future<Box> _openEncryptedDataBox() async {
  final List<int> secureKey = await _loadOrCreateDataKey();
  try {
    return await Hive.openBox(
      'd',
      encryptionCipher: HiveAesCipher(secureKey),
    );
  } catch (_) {
    final List<int> legacyKey = _legacyHiveKey();
    final Box legacyBox = await Hive.openBox(
      'd',
      encryptionCipher: HiveAesCipher(legacyKey),
    );
    final Map<dynamic, dynamic> legacyData =
        Map<dynamic, dynamic>.from(legacyBox.toMap());
    await legacyBox.close();
    await Hive.deleteBoxFromDisk('d');
    final Box migratedBox = await Hive.openBox(
      'd',
      encryptionCipher: HiveAesCipher(secureKey),
    );
    if (legacyData.isNotEmpty) {
      await migratedBox.putAll(legacyData);
    }
    await migratedBox.close();
    return Hive.openBox(
      'd',
      encryptionCipher: HiveAesCipher(secureKey),
    );
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

Future<void> _configureStartup(Future<PackageInfo> packageInfoFuture) async {
  verbose('Waiting for PackageInfo');
  await packageInfoFuture.then((PackageInfo value) {
    packageInfo = value;
    verbose('PackageInfo: ${packageInfo.version}');
    verbose('Configuring launch startup mode');
    launchAtStartup.setup(
      appName: 'Alembic',
      appPath: Platform.resolvedExecutable,
    );
  });

  verbose('Checking if autolaunch is enabled');
  final bool autolaunchEnabled =
      boxSettings.get('autolaunch', defaultValue: true);
  if (autolaunchEnabled) {
    launchAtStartup.enable();
    verbose('Autolaunch enabled');
  } else {
    launchAtStartup.disable();
    verbose('Autolaunch disabled');
  }
}

class AlembicRoot extends StatelessWidget {
  const AlembicRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return ArcaneWindow(
      child: ArcaneApp(
        debugShowCheckedModeBanner: false,
        title: 'Alembic',
        theme: buildAlembicTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}

Widget _buildWindowLeading(BuildContext context) {
  return const SizedBox(width: 8);
}

Widget _buildWindowTitle(BuildContext context) {
  return Text(
    'Alembic',
    style: Theme.of(context).typography.small.copyWith(
          fontWeight: FontWeight.w600,
        ),
  );
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
  final String resolvedCommand = expandPath(command);
  final List<String> resolvedArgs = args.map(expandPath).toList();
  _logCommand(resolvedCommand, resolvedArgs);

  final Process process = await Process.start(
    resolvedCommand,
    resolvedArgs,
    workingDirectory: workingDirectory,
    runInShell: true,
  );

  process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .map((String line) {
    final String safe = sanitizeSecrets(line);
    stdout?.add(redactOutput ? safe : line);
    return safe;
  }).listen((String line) => verbose('cmd $resolvedCommand stdout: $line'));

  process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .map((String line) {
    final String safe = sanitizeSecrets(line);
    stderr?.add(redactOutput ? safe : line);
    return safe;
  }).listen((String line) => error('cmd $resolvedCommand stderr: $line'));

  final int exitCode = await process.exitCode;
  if (exitCode == 0) {
    success('cmd $resolvedCommand exit code: $exitCode');
  } else {
    error('cmd $resolvedCommand exit code: $exitCode');
  }
  return exitCode;
}

void _logCommand(String command, List<String> args) {
  final String redactedArgs = args.map((String arg) {
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
