import 'package:alembic/domain/repository_dto.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;
import 'package:url_launcher/url_launcher_string.dart';

const String alembicGenerateTokenUrl =
    'https://github.com/settings/tokens/new?scopes=repo,read:org&description=Alembic';

extension HomeListStatePhaseCopy on RepositoryListState {
  String get phaseTitle => switch (phase) {
        'preparing' => 'Preparing',
        'resolving_account' => 'Resolving account',
        'connecting' => 'Connecting to GitHub',
        'requesting_page' => 'Fetching page $pageNumber',
        'requesting_pages' => 'Fetching pages',
        'page_complete' => 'Loading more',
        'merging_local' => 'Merging local repositories',
        'rate_limited' => 'Rate limited',
        _ => 'Loading repositories',
      };

  String get phaseSubtitle =>
      endpoint.trim().isNotEmpty ? endpoint : 'Attempt $attempt';
}

class HomeWelcomeState extends StatelessWidget {
  final VoidCallback onConnect;

  const HomeWelcomeState({
    super.key,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Center(
      child: m.SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: AlembicPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                m.Icon(
                  m.Icons.water_drop_outlined,
                  size: 44,
                  color: theme.colorScheme.foreground,
                ),
                const Gap(AlembicShadcnTokens.gapLg),
                Text(
                  'Welcome to Alembic',
                  style: theme.typography.x2Large.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(AlembicShadcnTokens.gapSm),
                Text(
                  'Connect a GitHub personal access token to browse, clone, '
                  'and archive your repositories from the menu bar.',
                  textAlign: TextAlign.center,
                  style: theme.typography.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
                const Gap(AlembicShadcnTokens.gapXl),
                AlembicToolbarButton(
                  label: 'Connect with Personal Access Token',
                  leadingIcon: m.Icons.vpn_key_outlined,
                  onPressed: onConnect,
                  prominent: true,
                ),
                const Gap(AlembicShadcnTokens.gapSm),
                AlembicToolbarButton(
                  label: 'Generate new token on GitHub',
                  leadingIcon: m.Icons.open_in_new,
                  quiet: true,
                  onPressed: () => launchUrlString(alembicGenerateTokenUrl),
                ),
                const Gap(AlembicShadcnTokens.gapXl),
                Text(
                  'REQUIRED SCOPES',
                  style: theme.typography.xSmall.copyWith(
                    color: theme.colorScheme.mutedForeground,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const Gap(AlembicShadcnTokens.gapSm),
                const Wrap(
                  spacing: AlembicShadcnTokens.gapSm,
                  children: <Widget>[
                    AlembicBadge(
                      label: 'repo',
                      tone: AlembicBadgeTone.secondary,
                    ),
                    AlembicBadge(
                      label: 'read:org',
                      tone: AlembicBadgeTone.secondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeLoadingState extends StatelessWidget {
  final RepositoryListState listState;

  const HomeLoadingState({
    super.key,
    required this.listState,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AlembicPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const AlembicProgressMark(size: 22),
              const Gap(AlembicShadcnTokens.gapXl),
              Text(
                listState.phaseTitle,
                style: theme.typography.large.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(8),
              Text(
                listState.phaseSubtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.xSmall.copyWith(
                  color: theme.colorScheme.mutedForeground,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              const Gap(4),
              Text(
                '${listState.fetchedCount} repositories fetched',
                style: theme.typography.xSmall.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeErrorState extends StatelessWidget {
  final RepositoryListState listState;
  final VoidCallback onRetry;
  final VoidCallback onSignInAgain;

  const HomeErrorState({
    super.key,
    required this.listState,
    required this.onRetry,
    required this.onSignInAgain,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    String? errorCode = listState.errorCode;
    return Center(
      child: m.SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: AlembicPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                m.Icon(
                  m.Icons.warning_amber_outlined,
                  size: 32,
                  color: theme.colorScheme.destructive,
                ),
                const Gap(AlembicShadcnTokens.gapLg),
                Text(
                  'Could not load repositories',
                  style: theme.typography.large.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(AlembicShadcnTokens.gapSm),
                Text(
                  listState.errorMessage ?? 'Unknown error.',
                  textAlign: TextAlign.center,
                  style: theme.typography.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
                if (errorCode != null &&
                    errorCode.trim().isNotEmpty) ...<Widget>[
                  const Gap(AlembicShadcnTokens.gapSm),
                  AlembicBadge(
                    label: errorCode,
                    tone: AlembicBadgeTone.outline,
                  ),
                ],
                const Gap(AlembicShadcnTokens.gapXl),
                Wrap(
                  spacing: AlembicShadcnTokens.gapSm,
                  runSpacing: AlembicShadcnTokens.gapSm,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    AlembicToolbarButton(
                      label: 'Sign in again',
                      onPressed: onSignInAgain,
                    ),
                    AlembicToolbarButton(
                      label: 'Retry',
                      leadingIcon: m.Icons.refresh,
                      onPressed: onRetry,
                      prominent: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeEmptyState extends StatelessWidget {
  final String? accountLogin;
  final VoidCallback onRefresh;

  const HomeEmptyState({
    super.key,
    required this.accountLogin,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    String login = (accountLogin ?? '').trim();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AlembicPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              m.Icon(
                m.Icons.inbox_outlined,
                size: 30,
                color: theme.colorScheme.mutedForeground,
              ),
              const Gap(AlembicShadcnTokens.gapLg),
              Text(
                login.isEmpty
                    ? 'No repositories yet'
                    : '@$login has no repositories',
                style: theme.typography.large.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(AlembicShadcnTokens.gapSm),
              Text(
                'Repositories you can access will appear here after a refresh.',
                textAlign: TextAlign.center,
                style: theme.typography.small.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
              const Gap(AlembicShadcnTokens.gapXl),
              AlembicToolbarButton(
                label: 'Refresh',
                leadingIcon: m.Icons.refresh,
                onPressed: onRefresh,
                prominent: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeRefreshErrorNotice extends StatelessWidget {
  final RepositoryListState listState;
  final VoidCallback onRetry;

  const HomeRefreshErrorNotice({
    super.key,
    required this.listState,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    String message = (listState.errorMessage ?? '').trim();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AlembicShadcnTokens.gapMd,
        vertical: AlembicShadcnTokens.gapSm,
      ),
      decoration: BoxDecoration(
        color: m.Color.alphaBlend(
          theme.colorScheme.destructive.withValues(alpha: 0.1),
          theme.colorScheme.card,
        ),
        borderRadius: BorderRadius.circular(AlembicShadcnTokens.controlRadius),
        border: Border.all(
          color: theme.colorScheme.destructive.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: <Widget>[
          m.Icon(
            m.Icons.warning_amber_outlined,
            size: 16,
            color: theme.colorScheme.destructive,
          ),
          const Gap(AlembicShadcnTokens.gapSm),
          Expanded(
            child: Text(
              message.isEmpty
                  ? 'The last refresh failed. Showing previously loaded repositories.'
                  : 'Refresh failed: $message Showing previously loaded repositories.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.xSmall.copyWith(
                color: theme.colorScheme.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Gap(AlembicShadcnTokens.gapSm),
          AlembicToolbarButton(
            label: 'Retry',
            compact: true,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class HomeRateLimitNotice extends StatelessWidget {
  final RepositoryListState listState;
  final VoidCallback onRetry;

  const HomeRateLimitNotice({
    super.key,
    required this.listState,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AlembicShadcnTokens.gapMd,
        vertical: AlembicShadcnTokens.gapSm,
      ),
      decoration: BoxDecoration(
        color: m.Color.alphaBlend(
          const m.Color(0xFFE8930C).withValues(alpha: 0.12),
          theme.colorScheme.card,
        ),
        borderRadius: BorderRadius.circular(AlembicShadcnTokens.controlRadius),
        border: Border.all(
          color: const m.Color(0xFFE8930C).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: <Widget>[
          const m.Icon(
            m.Icons.speed_outlined,
            size: 16,
            color: m.Color(0xFFE8930C),
          ),
          const Gap(AlembicShadcnTokens.gapSm),
          Expanded(
            child: Text(
              'GitHub rate limit reached. Showing '
              '${listState.fetchedCount} fetched repositories; retry after the '
              'limit resets.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.xSmall.copyWith(
                color: theme.colorScheme.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Gap(AlembicShadcnTokens.gapSm),
          AlembicToolbarButton(
            label: 'Retry',
            compact: true,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
