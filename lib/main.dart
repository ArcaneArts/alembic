import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alembic/screen/splash.dart';
import 'package:alembic/util/window.dart';
import 'package:arcane/arcane.dart';
import 'package:fast_log/fast_log.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:path_provider/path_provider.dart';

late Box box;
late Box boxSettings;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("${(await getApplicationDocumentsDirectory()).path}/Alembic");
  Hive.init("${(await getApplicationDocumentsDirectory()).path}/Alembic");
  Random r = Random(384858582220);
  box = await Hive.openBox("d",
      encryptionCipher:
          HiveAesCipher(List.generate(32, (_) => r.nextInt(256))));
  boxSettings = await Hive.openBox("s");
  await WindowUtil.init();
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

Future<int> cmd(String cmd, List<String> args) async {
  cmd = expandPath(cmd);
  args = args.map(expandPath).toList();
  info("cmd $cmd ${args.map((m) {
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
  Process p = await Process.start(cmd, args);

  p.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) => verbose("cmd $cmd stdout: $line"));

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
