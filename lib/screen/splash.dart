import 'package:alembic/main.dart';
import 'package:alembic/screen/home.dart';
import 'package:alembic/screen/login.dart';
import 'package:arcane/arcane.dart';
import 'package:fast_log/fast_log.dart';
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
      // Check if token needs migration or if a warning should be shown
      checkTokenMigration();

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

// You should also update the token type detection in checkTokenMigration in lib/screen/splash.dart
  void checkTokenMigration() {
    if (box.get("authenticated", defaultValue: false)) {
      final token = box.get("1", defaultValue: "");
      final tokenType = box.get("token_type", defaultValue: "unknown");

      // If there's a token but no type is stored, determine the type
      if (tokenType == "unknown" && token.isNotEmpty) {
        if (token.startsWith("github_pat_")) {
          // It's a fine-grained token
          box.put("token_type", "fine_grained");
        } else if (token.startsWith("ghp_")) {
          // It's a personal access token
          box.put("token_type", "personal");
        } else {
          // It's likely a classic token
          box.put("token_type", "classic");

          // Show warning about classic token deprecation
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showTokenMigrationWarning(context);
          });
        }
      } else if (tokenType == "classic") {
        // Show warning for classic tokens
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showTokenMigrationWarning(context);
        });
      }
    }
  }

  void showTokenMigrationWarning(BuildContext context) {
    DialogConfirm(
      title: "GitHub Token Update Recommended",
      description:
      "GitHub is deprecating classic tokens. While they still work, we recommend creating a new fine-grained token with 'repo' and 'read:org' permissions for better security.",
      confirmText: "Update Token",
      cancelText: "Continue",
      onConfirm: () {
        // Clear token and go to login screen
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

    // Log the token type being used (for debugging)
    info("Using $tokenType token for authentication");

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