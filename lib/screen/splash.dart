import 'package:alembic/main.dart';
import 'package:alembic/core/repository_runtime.dart';
import 'package:alembic/screen/home.dart';
import 'package:alembic/screen/login.dart';
import 'package:alembic/theme/alembic_tokens.dart';
import 'package:alembic/widget/glass_drag_strip.dart';
import 'package:alembic/widget/glass_panel.dart';
import 'package:alembic/widget/glass_shell.dart';
import 'package:fast_log/fast_log.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:github/github.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    _handleAuthentication();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleAuthentication() {
    if (!box.get('authenticated', defaultValue: false)) {
      _navigateToLogin();
    } else {
      _ensureTokenType();
      _navigateToHome();
    }
  }

  void _navigateToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    });
  }

  void _navigateToHome() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute<void>(
          builder: (_) => AlembicHome(
            github: _createGitHubInstance(),
            runtime: RepositoryRuntime(),
          ),
        ),
        (_) => false,
      );
    });
  }

  GitHub _createGitHubInstance() {
    String token = box.get('1');
    String tokenType = box.get('token_type', defaultValue: 'classic');
    info('Using $tokenType token for authentication');
    return GitHub(auth: Authentication.withToken(token));
  }

  void _ensureTokenType() {
    if (!box.get('authenticated', defaultValue: false)) {
      return;
    }

    String token = box.get('1', defaultValue: '');
    String tokenType = box.get('token_type', defaultValue: 'unknown');

    if (tokenType == 'unknown' && token.isNotEmpty) {
      _identifyAndStoreTokenType(token);
    }
  }

  void _identifyAndStoreTokenType(String token) {
    if (token.startsWith('github_pat_')) {
      box.put('token_type', 'fine_grained');
    } else if (token.startsWith('ghp_')) {
      box.put('token_type', 'personal');
    } else {
      box.put('token_type', 'classic');
    }
  }

  @override
  Widget build(BuildContext context) {
    AlembicTokens tokens = context.alembicTokens;

    return GlassShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const GlassDragStrip(height: 14),
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fade.value,
                      child: Transform.scale(
                        scale: _scale.value,
                        child: child,
                      ),
                    );
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: GlassPanel(
                      role: GlassPanelRole.control,
                      borderRadius: BorderRadius.circular(tokens.radiusLarge),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 22,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SizedBox(
                            width: 168,
                            height: 168,
                            child: GlassPanel(
                              role: GlassPanelRole.control,
                              padding: const EdgeInsets.all(0),
                              borderRadius: BorderRadius.circular(36),
                              child: Center(
                                child: SvgPicture.asset(
                                  'assets/icon.svg',
                                  width: 92,
                                  height: 92,
                                  colorFilter: ColorFilter.mode(
                                    tokens.textSecondary
                                        .withValues(alpha: 0.92),
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Alembic',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Preparing your workspace',
                            style: TextStyle(
                              color:
                                  tokens.textSecondary.withValues(alpha: 0.86),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const SizedBox(
                            width: 30,
                            height: 30,
                            child: CupertinoActivityIndicator(radius: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
