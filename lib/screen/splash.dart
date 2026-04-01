import 'package:alembic/app/alembic_scaffold.dart';
import 'package:alembic/app/alembic_tokens.dart';
import 'package:alembic/app/alembic_widgets.dart';
import 'package:alembic/core/repository_runtime.dart';
import 'package:alembic/main.dart';
import 'package:alembic/screen/home.dart';
import 'package:alembic/screen/login.dart';
import 'package:arcane/arcane.dart';
import 'package:fast_log/fast_log.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:github/github.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final m.AnimationController _controller;
  late final m.Animation<double> _fade;
  late final m.Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _controller = m.AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = m.CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slide = m.Tween<double>(begin: 18, end: 0).animate(
      m.CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
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
        m.MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
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
        m.MaterialPageRoute<void>(
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
    final String token = box.get('1');
    final String tokenType = box.get('token_type', defaultValue: 'classic');
    info('Using $tokenType token for authentication');
    return GitHub(auth: Authentication.withToken(token));
  }

  void _ensureTokenType() {
    if (!box.get('authenticated', defaultValue: false)) {
      return;
    }

    final String token = box.get('1', defaultValue: '');
    String tokenType = box.get('token_type', defaultValue: 'unknown');
    if (tokenType == 'unknown' && token.isNotEmpty) {
      if (token.startsWith('github_pat_')) {
        tokenType = 'fine_grained';
      } else if (token.startsWith('ghp_')) {
        tokenType = 'personal';
      } else {
        tokenType = 'classic';
      }
      box.put('token_type', tokenType);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlembicScaffold(
      child: Center(
        child: m.AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            return Opacity(
              opacity: _fade.value,
              child: Transform.translate(
                offset: Offset(0, _slide.value),
                child: child,
              ),
            );
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: AlembicPanel(
              padding: AlembicShadcnTokens.shellPadding,
              tone: AlembicSurfaceTone.elevated,
              child: Row(
                children: <Widget>[
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      borderRadius: BorderRadius.circular(
                        AlembicShadcnTokens.controlRadius,
                      ),
                      border: Border.all(color: theme.colorScheme.border),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/icon.svg',
                        width: 42,
                        height: 42,
                        colorFilter: m.ColorFilter.mode(
                          theme.colorScheme.foreground,
                          m.BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const Gap(AlembicShadcnTokens.gapLg),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const AlembicBadge(
                          label: 'Workspace bootstrap',
                          tone: AlembicBadgeTone.secondary,
                        ),
                        const Gap(AlembicShadcnTokens.gapMd),
                        Text(
                          'Preparing Alembic',
                          style: theme.typography.x3Large.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Gap(8),
                        Text(
                          'Loading credentials, repository state, and desktop services.',
                          style: theme.typography.small.copyWith(
                            color: theme.colorScheme.mutedForeground,
                          ),
                        ),
                        const Gap(AlembicShadcnTokens.gapLg),
                        const m.LinearProgressIndicator(minHeight: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
