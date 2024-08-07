import 'package:alembic/home.dart';
import 'package:alembic/login.dart';
import 'package:alembic/main.dart';
import 'package:fast_log/fast_log.dart';
import 'package:flutter/cupertino.dart';
import 'package:github/github.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  void doLogin() {
    warn("Not Logged In");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushAndRemoveUntil(
          context,
          CupertinoPageRoute(builder: (context) => const LoginScreen()),
          (route) => false);
    });
  }

  @override
  void initState() {
    if (!box.get("authenticated", defaultValue: false)) {
      doLogin();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushAndRemoveUntil(
            context,
            CupertinoPageRoute(
                builder: (context) => AlembicHome(github: auth())),
            (route) => false);
      });
    }

    super.initState();
  }

  GitHub auth() =>
      GitHub(auth: Authentication.basic(box.get("1"), box.get("2")));

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.transparent,
      child: Center(
        child: SvgPicture.asset("assets/icon.svg", width: 150, height: 150),
      ),
    );
  }
}
