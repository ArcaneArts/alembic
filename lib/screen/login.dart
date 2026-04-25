import 'package:alembic/core/token_validator.dart';
import 'package:alembic/screen/splash.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:alembic/util/git_accounts.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;
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

  late final m.TextEditingController _tokenController;
  late final FocusNode _tokenFocusNode;
  bool _isTokenValid = false;
  bool _isSubmitting = false;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _tokenController = m.TextEditingController();
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
    final String text = _tokenController.text.trim();
    final bool isValid = text.isNotEmpty &&
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

  String _detectTokenType(String token) => detectTokenType(token);

  Future<void> _doLogin(String? providedToken) async {
    if (_isSubmitting) {
      return;
    }

    final String token = (providedToken ?? _tokenController.text).trim();
    setState(() {
      _isSubmitting = true;
      _validationMessage = null;
    });

    final TokenValidationResult validationResult =
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

    final String tokenType = _detectTokenType(token);
    final String suggestedName = (validationResult.login ?? '').trim().isEmpty
        ? 'Account ${loadGitAccounts().length + 1}'
        : validationResult.login!.trim();
    await addGitAccount(
      name: suggestedName,
      token: token,
      tokenType: tokenType,
      login: validationResult.login,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    Navigator.of(context).pushAndRemoveUntil(
      m.MaterialPageRoute<void>(builder: widget.nextScreenBuilder),
      (_) => false,
    );
  }

  Future<void> _openTokenCreationPage() {
    return launchUrlString(_tokenCreationUrl);
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Widget marketingPanel = AlembicPanel(
      padding: AlembicShadcnTokens.shellPadding,
      tone: AlembicSurfaceTone.elevated,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AlembicBadge(
            label: 'Alembic desktop',
            tone: AlembicBadgeTone.secondary,
          ),
          const Gap(AlembicShadcnTokens.gapLg),
          Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(
                    AlembicShadcnTokens.controlRadius,
                  ),
                  border: Border.all(color: theme.colorScheme.border),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/login.svg',
                    width: 24,
                    height: 24,
                    colorFilter: m.ColorFilter.mode(
                      theme.colorScheme.foreground,
                      m.BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const Gap(AlembicShadcnTokens.gapLg),
              Expanded(
                child: Text(
                  'Connect GitHub with a clean local workspace.',
                  style: theme.typography.x2Large.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Gap(AlembicShadcnTokens.gapLg),
          Text(
            'Alembic manages active clones, archives idle repositories, and keeps your tooling one click away.',
            style: theme.typography.small.copyWith(
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
    Widget signInPanel = AlembicPanel(
      padding: AlembicShadcnTokens.shellPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Sign in',
            style: theme.typography.x2Large.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(8),
          Text(
            'Paste a GitHub personal access token to unlock repository sync.',
            style: theme.typography.small.copyWith(
              color: theme.colorScheme.mutedForeground,
            ),
          ),
          const Gap(AlembicShadcnTokens.gapLg),
          AlembicLabeledField(
            label: 'Personal access token',
            supportingText:
                'Alembic validates the token before saving it in encrypted local storage.',
            child: AlembicTextInput(
              controller: _tokenController,
              placeholder: 'github_pat_... or ghp_...',
              obscureText: true,
              leading: const m.Icon(m.Icons.vpn_key, size: 16),
              onSubmitted: _isTokenValid && !_isSubmitting ? _doLogin : null,
            ),
          ),
          const Gap(10),
          Text(
            _validationMessage ??
                (_isTokenValid
                    ? 'Token format looks valid.'
                    : 'Supported formats: github_pat_..., ghp_..., or a 40-character classic token.'),
            style: theme.typography.xSmall.copyWith(
              color: _validationMessage == null
                  ? theme.colorScheme.mutedForeground
                  : theme.colorScheme.destructive,
            ),
          ),
          const Gap(AlembicShadcnTokens.gapLg),
          Row(
            children: <Widget>[
              Expanded(
                child: AlembicToolbarButton(
                  onPressed: _openTokenCreationPage,
                  label: 'Create token',
                ),
              ),
              const Gap(AlembicShadcnTokens.gapMd),
              Expanded(
                child: AlembicToolbarButton(
                  onPressed: _isTokenValid && !_isSubmitting
                      ? () => _doLogin(null)
                      : null,
                  label: _isSubmitting ? 'Validating...' : 'Continue',
                  prominent: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return AlembicScaffold(
      child: m.SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            marketingPanel,
            const Gap(AlembicShadcnTokens.gapLg),
            signInPanel,
          ],
        ),
      ),
    );
  }
}
