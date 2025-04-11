import 'package:alembic/main.dart';
import 'package:alembic/screen/home.dart';
import 'package:alembic/screen/login.dart';
import 'package:arcane/arcane.dart';
import 'package:fast_log/fast_log.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:github/github.dart';

/// Splash screen displayed on app launch that handles authentication flow
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _handleAuthentication();
  }

  /// Determines whether to show login screen or main app
  void _handleAuthentication() {
    if (!box.get("authenticated", defaultValue: false)) {
      _navigateToLogin();
    } else {
      _checkTokenMigration();
      _navigateToHome();
    }
  }

  /// Navigates to login screen
  void _navigateToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    });
  }

  /// Navigates to home screen with authenticated GitHub instance
  void _navigateToHome() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => AlembicHome(github: _createGitHubInstance()),
        ),
            (route) => false,
      );
    });
  }

  /// Creates an authenticated GitHub instance
  GitHub _createGitHubInstance() {
    final String token = box.get("1");
    final String tokenType = box.get("token_type", defaultValue: "classic");

    info("Using $tokenType token for authentication");
    return GitHub(auth: Authentication.withToken(token));
  }

  /// Checks if token needs migration and identifies token type
  void _checkTokenMigration() {
    if (!box.get("authenticated", defaultValue: false)) return;

    final String token = box.get("1", defaultValue: "");
    final String tokenType = box.get("token_type", defaultValue: "unknown");

    // Handle unknown token type by detecting it
    if (tokenType == "unknown" && token.isNotEmpty) {
      _identifyAndStoreTokenType(token);
    } else if (tokenType == "classic") {
      // Show warning for classic tokens
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTokenMigrationWarning();
      });
    }
  }

  /// Identifies token type from format and stores it
  void _identifyAndStoreTokenType(String token) {
    if (token.startsWith("github_pat_")) {
      box.put("token_type", "fine_grained");
    } else if (token.startsWith("ghp_")) {
      box.put("token_type", "personal");
    } else {
      // It's likely a classic token
      box.put("token_type", "classic");

      // Show warning about classic token deprecation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTokenMigrationWarning();
      });
    }
  }

  /// Shows warning dialog about classic token deprecation
  void _showTokenMigrationWarning() {
    DialogConfirm(
      title: "GitHub Token Update Recommended",
      description:
      "GitHub is deprecating classic tokens. While they still work, we recommend creating a new fine-grained token with 'repo' and 'read:org' permissions for better security.",
      confirmText: "Update Token",
      cancelText: "Continue",
      onConfirm: () => _clearTokenAndNavigateToLogin(),
    ).open(context);
  }

  /// Clears stored token data and navigates to login screen
  void _clearTokenAndNavigateToLogin() {
    box.deleteAll(["1", "authenticated", "token_type"]).then((_) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    });
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