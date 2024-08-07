import 'dart:math';

import 'package:alembic/splash.dart';
import 'package:alembic/util/window.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:path_provider/path_provider.dart';

late Box box;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("${(await getApplicationDocumentsDirectory()).path}/Alembic");
  Hive.init("${(await getApplicationDocumentsDirectory()).path}/Alembic");
  Random r = Random(384858582220);
  box = await Hive.openBox("d",
      encryptionCipher:
          HiveAesCipher(List.generate(32, (_) => r.nextInt(256))));
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
  Widget build(BuildContext context) => const CupertinoApp(
        debugShowCheckedModeBanner: false,
        title: 'Alembic',
        theme: CupertinoThemeData(scaffoldBackgroundColor: Colors.transparent),
        home: SplashScreen(),
      );
}
