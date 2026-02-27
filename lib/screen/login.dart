import 'package:alembic/main.dart';
import 'package:alembic/core/token_validator.dart';
import 'package:alembic/screen/splash.dart';
import 'package:alembic/theme/alembic_motion.dart';
import 'package:alembic/theme/alembic_tokens.dart';
import 'package:alembic/widget/glass_button.dart';
import 'package:alembic/widget/glass_drag_strip.dart';
import 'package:alembic/widget/glass_panel.dart';
import 'package:alembic/widget/glass_shell.dart';
import 'package:alembic/widget/glass_text_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher_string.dart';

Widget _defaultLoginSuccessRoute(BuildContext context) => const SplashScreen();

class LoginScreen extends StatefulWidget {
  final TokenValidator tokenValidator;
  final WidgetBuilder nextScreenBuilder;

  const LoginScreen({
    super.key,
    this.tokenValidator = const TokenValidator(),
    this.nextScreenBuilder = _defaultLoginSuccessRoute,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _tokenCreationUrl =
      'https://github.com/settings/tokens/new?scopes=repo,read:org,admin:org';

  late TextEditingController _tokenController;
  late FocusNode _tokenFocusNode;
  bool _isTokenValid = false;
  bool _isSubmitting = false;
  String? _validationMessage;

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

  void _validateToken() {
    String text = _tokenController.text.trim();
    bool isValid = text.isNotEmpty &&
        (text.startsWith('github_pat_') ||
            text.startsWith('ghp_') ||
            (text.length == 40 && RegExp(r'^[a-f0-9]+$').hasMatch(text)));

    if (isValid == _isTokenValid && _validationMessage == null) {
      return;
    }

    setState(() {
      _isTokenValid = isValid;
      _validationMessage = null;
    });
  }

  String _detectTokenType(String token) {
    if (token.startsWith('github_pat_')) {
      return 'fine_grained';
    }
    if (token.startsWith('ghp_')) {
      return 'personal';
    }
    return 'classic';
  }

  Future<void> _doLogin(String? providedToken) async {
    if (_isSubmitting) {
      return;
    }

    String token = (providedToken ?? _tokenController.text).trim();
    setState(() {
      _isSubmitting = true;
      _validationMessage = null;
    });

    TokenValidationResult validationResult =
        await widget.tokenValidator.validate(token);
    if (!validationResult.isValid) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _validationMessage = validationResult.message;
      });
      return;
    }

    String tokenType = _detectTokenType(token);

    await box.put('1', token);
    await box.put('token_type', tokenType);
    await box.put('authenticated', true);

    if (!mounted) {
      return;
    }
    setState(() {
      _isSubmitting = false;
    });

    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute<void>(
        builder: widget.nextScreenBuilder,
      ),
      (_) => false,
    );
  }

  Future<void> _openTokenCreationPage() async {
    await launchUrlString(_tokenCreationUrl);
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
            const GlassDragStrip(height: 15),
            Expanded(
              child: Center(
                child: AnimatedContainer(
                  duration: AlembicMotion.panel,
                  curve: AlembicMotion.emphasized,
                  width: 520,
                  constraints: const BoxConstraints(maxWidth: 560),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: GlassPanel(
                    role: GlassPanelRole.control,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 24),
                    borderRadius: BorderRadius.circular(tokens.radiusLarge),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            SvgPicture.asset(
                              'assets/login.svg',
                              width: 48,
                              height: 48,
                              colorFilter: ColorFilter.mode(
                                tokens.textSecondary.withValues(alpha: 0.92),
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Connect GitHub',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Use a Personal Access Token to unlock your repository workspace.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: tokens.textSecondary
                                          .withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        GlassTextField(
                          controller: _tokenController,
                          focusNode: _tokenFocusNode,
                          placeholder: 'github_pat_... or classic token',
                          obscureText: true,
                          onSubmitted:
                              _isTokenValid && !_isSubmitting ? _doLogin : null,
                          prefix: Icon(
                            CupertinoIcons.lock_fill,
                            size: 15,
                            color: tokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedDefaultTextStyle(
                          duration: AlembicMotion.content,
                          curve: AlembicMotion.standard,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _validationMessage == null
                                ? (_isTokenValid
                                    ? tokens.textSecondary
                                    : tokens.textSecondary
                                        .withValues(alpha: 0.72))
                                : CupertinoColors.systemRed
                                    .resolveFrom(context),
                          ),
                          child: Text(
                            _validationMessage ??
                                (_isTokenValid
                                    ? 'Token format looks valid.'
                                    : 'Supported: github_pat_..., ghp_..., or 40-char classic token.'),
                          ),
                        ),
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            bool compact = constraints.maxWidth < 480;
                            if (compact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  GlassButton(
                                    label: 'Create New Token',
                                    onPressed: _openTokenCreationPage,
                                    kind: GlassButtonKind.secondary,
                                  ),
                                  const SizedBox(height: 8),
                                  GlassButton(
                                    label: _isSubmitting
                                        ? 'Validating...'
                                        : 'Continue',
                                    onPressed: _isTokenValid && !_isSubmitting
                                        ? () => _doLogin(null)
                                        : null,
                                    kind: GlassButtonKind.primary,
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: <Widget>[
                                Expanded(
                                  child: GlassButton(
                                    label: 'Create New Token',
                                    onPressed: _openTokenCreationPage,
                                    kind: GlassButtonKind.secondary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: GlassButton(
                                    label: _isSubmitting
                                        ? 'Validating...'
                                        : 'Continue',
                                    onPressed: _isTokenValid && !_isSubmitting
                                        ? () => _doLogin(null)
                                        : null,
                                    kind: GlassButtonKind.primary,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
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
