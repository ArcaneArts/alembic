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
late bool windowMode = false;
late String configPath;

void main() async {
  try {
    lDebugMode = true;
    WidgetsFlutterBinding.ensureInitialized();
    configPath = "${(await getApplicationDocumentsDirectory()).path}/Alembic";
    File logFile = File("$configPath/alembic.log");
    IOSink logSink = logFile.openWrite(
      mode: FileMode.writeOnlyAppend,
    );
    lLogHandler = (cat, l) {
      logSink.writeln("${cat.name}: $l");
    };
    verbose("Getting package info");
    Future<PackageInfo> pinf = PackageInfo.fromPlatform();
    windowMode = Directory(
            "${(await getApplicationDocumentsDirectory()).path}/Alembic/WINDOW_MODE")
        .existsSync();
    info("${(await getApplicationDocumentsDirectory()).path}/Alembic");
    Hive.init("${(await getApplicationDocumentsDirectory()).path}/Alembic");
    verbose("Opening Hive boxes");
    Random r = Random(384858582220);
    box = await Hive.openBox("d",
        encryptionCipher:
            HiveAesCipher(List.generate(32, (_) => r.nextInt(256))));
    verbose("Opening settings box");
    boxSettings = await Hive.openBox("s");
    verbose("Init Window");
    await WindowUtil.init();
    verbose("Waiting for PackageInfo");
    await pinf.then((value) {
      packageInfo = value;
      verbose("PackageInfo: ${packageInfo.version}");
      verbose("Configuring launch startup mode");
      launchAtStartup.setup(
        appName: "Alembic",
        appPath: Platform.resolvedExecutable,
      );
    });

    verbose("Checking if autolaunch is enabled");

    if (boxSettings.get("autolaunch", defaultValue: true) == true) {
      launchAtStartup.enable();
      verbose("Autolaunch enabled");
    } else {
      launchAtStartup.disable();
      verbose("Autolaunch disabled");
    }
  } catch (e, es) {
    error("ERROR $e");
    error("ERROR $es");
  }

  success("=====================================");

  runApp(const Alembic());
}

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
              dark: ColorSchemes.darkZinc(),
              light: ColorSchemes.lightZinc(),
            )),
        home: SplashScreen(),
      );
}

String expandPath(String path) {
  if (path.startsWith('~')) {
    final home = Platform.environment['HOME'] ?? '';
    return path.replaceFirst('~', home);
  }
  return path;
}

Future<int> cmd(String cmd, List<String> args,
    {BehaviorSubject<String>? stdout, String? workingDirectory}) async {
  cmd = expandPath(cmd);
  args = args.map(expandPath).toList();
  args = [
    "-ilc",
    [cmd, ...args].join(" "),
  ];
  cmd = Platform.environment['SHELL'] ?? '/bin/bash';

  verbose("cmd $cmd ${args.map((m) {
    if (m.contains("ghp_")) {
      return m.split(" ").map((i) {
        if (i.contains("ghp_")) {
          return "ghp_********";
        }
        return i;
      }).join(" ");
    }

    return m;
  }).join(" ")}");
  Process p =
      await Process.start(cmd, args, workingDirectory: workingDirectory);

  p.stdout.transform(utf8.decoder).transform(const LineSplitter()).map((i) {
    stdout?.add(i);
    return i;
  }).listen((line) => verbose("cmd $cmd stdout: $line"));

  p.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) => error("cmd $cmd stderr: $line"));

  int c = await p.exitCode;

  if (c == 0) {
    success("cmd $cmd exit code: $c");
  } else {
    error("cmd $cmd exit code: $c");
  }

  return c;
}
