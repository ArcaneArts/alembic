import 'package:alembic/main.dart';
import 'package:alembic/screen/home.dart';
import 'package:alembic/screen/login.dart';
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

  // Add to SplashScreen initState or create a separate method
  void checkTokenMigration() {
    if (box.get("authenticated", defaultValue: false)) {
      final token = box.get("1", defaultValue: "");
      final tokenType = box.get("token_type", defaultValue: "unknown");

      // If there's a token but no type is stored, check if it's a classic token
      if (tokenType == "unknown" && token.isNotEmpty) {
        if (!token.startsWith("github_pat_")) {
          // It's likely a classic token, mark it as such
          box.put("token_type", "classic");

          // Optionally show a migration dialog on next screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showTokenMigrationDialog(context);
          });
        } else {
          // It's already a fine-grained token
          box.put("token_type", "fine_grained");
        }
      }
    }
  }

  void showTokenMigrationDialog(BuildContext context) {
    DialogConfirm(
      title: "GitHub Token Update Required",
      description:
      "GitHub is deprecating classic tokens. Please create a new fine-grained token with 'repo' permissions and update your login.",
      confirmText: "Update Token",
      onConfirm: () {
        box.deleteAll(["1", "authenticated", "token_type"]).then((_) {
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false);
        });
      },
    ).open(context);
  }


  GitHub auth() {
    final token = box.get("1");
    final tokenType = box.get("token_type", defaultValue: "classic");

    // Authenticate with the token
    return GitHub(auth: Authentication.withToken(token));
  }

  @override
  Widget build(BuildContext context) {
    return FillScreen(
      child: Center(
        child: SvgPicture.asset("assets/icon.svg", width: 150, height: 150),
      ),
    );
  }
}
