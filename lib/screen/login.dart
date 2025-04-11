import 'package:alembic/main.dart';
import 'package:alembic/screen/splash.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:github/github.dart';
import 'package:url_launcher/url_launcher_string.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late TextEditingController tokenController;
  late FocusNode fToken;
  bool isTokenValid = false;

  @override
  void initState() {
    tokenController = TextEditingController();
    fToken = FocusNode();
    tokenController.addListener(_validateToken);
    super.initState();
  }

  @override
  void dispose() {
    tokenController.removeListener(_validateToken);
    tokenController.dispose();
    fToken.dispose();
    super.dispose();
  }

  // Validate token format for both classic and fine-grained tokens
  void _validateToken() {
    final text = tokenController.text;
    setState(() {
      // Support all token types:
      // - Classic tokens are 40-character hexadecimal strings
      // - Fine-grained tokens start with github_pat_
      // - Personal access tokens start with ghp_
      isTokenValid = text.isNotEmpty &&
          (text.startsWith('github_pat_') ||
              text.startsWith('ghp_') ||
              (text.length == 40 && RegExp(r'^[a-f0-9]+$').hasMatch(text)));
    });
  }

  void _doLogin(String? g) async {
    final token = g ?? tokenController.text.trim();

    // Detect token type
    String tokenType = "classic";
    if (token.startsWith('github_pat_')) {
      tokenType = "fine_grained";
    }

    await box.put("1", token);
    await box.put("token_type", tokenType);
    await box.put("authenticated", true);

    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SplashScreen()),
            (route) => false);
  }

  void _openTokenCreationPage() async {
    await launchUrlString('https://github.com/settings/tokens/new?scopes=repo,read:org,admin:org');
  }

  @override
  Widget build(BuildContext context) => FillScreen(
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset("assets/login.svg", width: 100, height: 100),
          const Gap(24),
          const Text(
            "GitHub Personal Access Token",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Gap(8),
          Text(
            "Supports both classic and fine-grained tokens",
            style: TextStyle(
              fontSize: 14,
            ),
          ),
          const Gap(16),
          PaddingHorizontal(
            padding: 32,
            child: TextField(
              placeholder: "github_pat_... or classic token",
              focusNode: fToken,
              controller: tokenController,
              obscureText: true,
              leading: Icon(Icons.lock_fill),
              onSubmitted: isTokenValid ? _doLogin : null,
              textAlign: TextAlign.left,
            ),
          ),
          const Gap(16),
          PaddingHorizontal(
            padding: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _openTokenCreationPage,
                  child: Text("Create New Token"),
                ),
                GhostButton(
                  onPressed: isTokenValid ? () => _doLogin(null) : null,
                  child: Text("Login"),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}