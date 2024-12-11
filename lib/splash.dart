import 'package:alembic/home.dart';
import 'package:alembic/login.dart';
import 'package:alembic/main.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:github/github.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  void doLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
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
            MaterialPageRoute(
                builder: (context) => AlembicHome(github: auth())),
            (route) => false);
      });
    }

    super.initState();
  }

  GitHub auth() => GitHub(auth: Authentication.withToken(box.get("1")));

  @override
  Widget build(BuildContext context) {
    return FillScreen(
      child: Center(
        child: SvgPicture.asset("assets/icon.svg", width: 150, height: 150),
      ),
    );
  }
}
