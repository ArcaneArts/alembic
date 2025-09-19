import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alembic/screen/splash.dart';
import 'package:alembic/util/window.dart';
import 'package:arcane/arcane.dart';
import 'package:fast_log/fast_log.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

late Box box;
late Box boxSettings;
late PackageInfo packageInfo;
bool windowMode = false;
late String configPath;

void main() async {
  try {
    await _initializeApp();
    runApp("alembic", const Alembic());
  } catch (e, stackTrace) {
    error("ERROR $e");
    error("ERROR $stackTrace");
  }
}

/// Initialize all app dependencies and configurations
Future<void> _initializeApp() async {
  // Setup debugging and Flutter binding
  lDebugMode = true;
  setupArcaneDebug();
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize app directories and logging
  await _setupDirectoriesAndLogging();

  // Initialize app settings and state
  await _setupAppSettings();

  // Log successful initialization
  success("=====================================");
}

/// Set up application directories and logging configuration
Future<void> _setupDirectoriesAndLogging() async {
  // Set up app directory
  final Directory appDocDir = await getApplicationDocumentsDirectory();
  configPath = "${appDocDir.path}/Alembic";
  await Directory(configPath).create(recursive: true);

  // Check window mode
  windowMode = Directory("$configPath/WINDOW_MODE").existsSync();
  info("App directory: $configPath");

  // Configure logging
  await _setupLogging();
}

/// Set up log file with rotation
Future<void> _setupLogging() async {
  final File logFile = File("$configPath/alembic.log");

  // Rotate log file if too large
  if (await logFile.exists()) {
    final int fileSize = await logFile.length();
    if (fileSize > 1024 * 1024) {
      await logFile.delete();
      verbose("Log file deleted because it exceeded 1MB");
    }
  }

  // Configure log handler
  final IOSink logSink = logFile.openWrite(mode: FileMode.writeOnlyAppend);
  lLogHandler = (LogCategory category, String message) {
    logSink.writeln("${category.name}: $message");
  };
}

/// Set up application settings, database, and startup configuration
Future<void> _setupAppSettings() async {
  verbose("Getting package info");
  final Future<PackageInfo> packageInfoFuture = PackageInfo.fromPlatform();

  // Initialize Hive database
  Hive.init(configPath);
  verbose("Opening Hive boxes");

  // Open encrypted box for sensitive data
  final Random random = Random(384858582220);
  box = await Hive.openBox(
      "d",
      encryptionCipher: HiveAesCipher(List.generate(32, (_) => random.nextInt(256)))
  );

  // Open settings box
  verbose("Opening settings box");
  boxSettings = await Hive.openBox("s");

  // Initialize window manager
  verbose("Init Window");
  await WindowUtil.init();

  // Configure startup settings
  await _configureStartup(packageInfoFuture);
}

/// Configure application startup behavior
Future<void> _configureStartup(Future<PackageInfo> packageInfoFuture) async {
  // Wait for package info
  verbose("Waiting for PackageInfo");
  await packageInfoFuture.then((value) {
    packageInfo = value;
    verbose("PackageInfo: ${packageInfo.version}");
    verbose("Configuring launch startup mode");

    // Set up launch at startup
    launchAtStartup.setup(
      appName: "Alembic",
      appPath: Platform.resolvedExecutable,
    );
  });

  // Apply autolaunch setting
  verbose("Checking if autolaunch is enabled");
  final bool autolaunchEnabled = boxSettings.get("autolaunch", defaultValue: true);

  if (autolaunchEnabled) {
    launchAtStartup.enable();
    verbose("Autolaunch enabled");
  } else {
    launchAtStartup.disable();
    verbose("Autolaunch disabled");
  }
}

/// Main application widget
class Alembic extends StatefulWidget {
  const Alembic({super.key});

  @override
  State<Alembic> createState() => _AlembicState();
}

class _AlembicState extends State<Alembic> {
  @override
  Widget build(BuildContext context) => ArcaneApp(
    debugShowCheckedModeBanner: false,
    title: 'Alembic',
    theme: ArcaneTheme(
      themeMode: ThemeMode.system,
      scheme: ContrastedColorScheme(
        dark: ColorSchemes.darkDefaultColor,
        light: ColorSchemes.lightDefaultColor
      ),
    ),
    home: const SplashScreen(),
  );
}

/// Expand path with home directory
String expandPath(String path) {
  if (path.startsWith('~')) {
    final String home = Platform.environment['HOME'] ?? '';
    return path.replaceFirst('~', home);
  }
  return path;
}

/// Execute shell command and capture output
Future<int> cmd(
    String command,
    List<String> args, {
      BehaviorSubject<String>? stdout,
      String? workingDirectory,
    }) async {
  // Expand paths in command and arguments
  command = expandPath(command);
  args = args.map(expandPath).toList();

  // Create shell command with arguments
  final shellArgs = [
    "-ilc",
    [command, ...args].join(" "),
  ];
  final shellCmd = Platform.environment['SHELL'] ?? '/bin/bash';

  // Log command (with token redaction)
  _logCommand(shellCmd, shellArgs);

  // Start process
  final Process process = await Process.start(
      shellCmd,
      shellArgs,
      workingDirectory: workingDirectory
  );

  // Handle stdout
  process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .map((String line) {
    stdout?.add(line);
    return line;
  })
      .listen((line) => verbose("cmd $command stdout: $line"));

  // Handle stderr
  process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) => error("cmd $command stderr: $line"));

  // Wait for completion
  final int exitCode = await process.exitCode;

  // Log outcome
  if (exitCode == 0) {
    success("cmd $command exit code: $exitCode");
  } else {
    error("cmd $command exit code: $exitCode");
  }

  return exitCode;
}

/// Helper function to log command with redacted tokens
void _logCommand(String command, List<String> args) {
  final String redactedArgs = args.map((String arg) {
    if (arg.contains("ghp_")) {
      return arg.split(" ").map((part) {
        if (part.contains("ghp_")) {
          return "ghp_********";
        }
        return part;
      }).join(" ");
    }
    return arg;
  }).join(" ");

  verbose("cmd $command $redactedArgs");
}