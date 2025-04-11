import 'package:alembic/main.dart';
import 'package:alembic/screen/splash.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher_string.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers and state
  late final TextEditingController _tokenController;
  late final FocusNode _tokenFocusNode;
  bool _isTokenValid = false;

  // Constants
  static const String _tokenCreationUrl =
      'https://github.com/settings/tokens/new?scopes=repo,read:org,admin:org';

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController();
    _tokenFocusNode = FocusNode();
    _tokenController.addListener(_validateToken);
  }

  @override
  void dispose() {
    _tokenController.removeListener(_validateToken);
    _tokenController.dispose();
    _tokenFocusNode.dispose();
    super.dispose();
  }

  /// Validate token format for all GitHub token types
  void _validateToken() {
    final String text = _tokenController.text;
    setState(() {
      _isTokenValid = text.isNotEmpty && (
          text.startsWith('github_pat_') ||
              text.startsWith('ghp_') ||
              (text.length == 40 && RegExp(r'^[a-f0-9]+$').hasMatch(text))
      );
    });
  }

  /// Process login with the provided token
  Future<void> _doLogin(String? providedToken) async {
    final String token = providedToken ?? _tokenController.text.trim();
    final String tokenType = _detectTokenType(token);

    // Save token information
    await box.put("1", token);
    await box.put("token_type", tokenType);
    await box.put("authenticated", true);

    // Navigate to splash screen
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SplashScreen()),
            (route) => false
    );
  }

  /// Determine token type from its format
  String _detectTokenType(String token) {
    if (token.startsWith('github_pat_')) {
      return "fine_grained";
    }
    return "classic";
  }

  /// Open GitHub token creation page in browser
  Future<void> _openTokenCreationPage() async {
    await launchUrlString(_tokenCreationUrl);
  }

  @override
  Widget build(BuildContext context) {
    return FillScreen(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildLogoSection(),
            _buildHeaderSection(),
            _buildTokenInputSection(),
            _buildActionButtonsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return SvgPicture.asset(
        "assets/login.svg",
        width: 100,
        height: 100
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      children: [
        const Gap(24),
        const Text(
          "GitHub Personal Access Token",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Gap(8),
        const Text(
          "Supports both classic and fine-grained tokens",
          style: TextStyle(
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildTokenInputSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: TextField(
        placeholder: const Text("github_pat_... or classic token"),
        focusNode: _tokenFocusNode,
        controller: _tokenController,
        obscureText: true,
        leading: const Icon(Icons.lock_fill),
        onSubmitted: _isTokenValid ? _doLogin : null,
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget _buildActionButtonsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _openTokenCreationPage,
            child: const Text("Create New Token"),
          ),
          GhostButton(
            onPressed: _isTokenValid ? () => _doLogin(null) : null,
            child: const Text("Login"),
          ),
        ],
      ),
    );
  }
}