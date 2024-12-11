import 'package:alembic/main.dart';
import 'package:alembic/splash.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late TextEditingController tokenController;
  late FocusNode fToken;

  @override
  void initState() {
    tokenController = TextEditingController();
    fToken = FocusNode();
    super.initState();
  }

  void _doLogin(String? g) async {
    await box.put("1", g ?? tokenController.value.text);
    await box.put("authenticated", true);
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SplashScreen()),
        (route) => false);
  }

  @override
  Widget build(BuildContext context) => FillScreen(
          child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset("assets/login.svg", width: 100, height: 100),
            PaddingHorizontal(
                padding: 32,
                child: TextField(
                  focusNode: fToken,
                  controller: tokenController,
                  obscureText: true,
                  leading: Icon(Icons.lock_fill),
                  onSubmitted: (g) {
                    _doLogin(g);
                  },
                  textAlign: TextAlign.left,
                ))
          ],
        ),
      ));
}
