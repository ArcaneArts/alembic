import 'package:alembic/screen/home/home_actions.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

class HomeActionTile extends StatelessWidget {
  final String label;
  final String? description;
  final VoidCallback onPressed;
  final bool prominent;

  const HomeActionTile({
    super.key,
    required this.label,
    this.description,
    required this.onPressed,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color background =
        prominent ? theme.colorScheme.secondary : theme.colorScheme.background;
    Color border = theme.colorScheme.border;
    Color titleColor = theme.colorScheme.foreground;

    return m.InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AlembicShadcnTokens.controlRadius),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: background,
          borderRadius:
              BorderRadius.circular(AlembicShadcnTokens.controlRadius),
          border: Border.all(color: border),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: theme.typography.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  if (description != null) ...<Widget>[
                    const Gap(4),
                    Text(
                      description!,
                      style: theme.typography.xSmall.copyWith(
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Gap(AlembicShadcnTokens.gapMd),
            m.Icon(
              m.Icons.arrow_forward,
              size: 16,
              color: titleColor,
            ),
          ],
        ),
      ),
    );
  }
}

class HomeBulkActionTile extends StatelessWidget {
  final HomeBulkAction action;
  final VoidCallback onPressed;

  const HomeBulkActionTile({
    super.key,
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => HomeActionTile(
        label: action.label,
        description: action.description,
        onPressed: onPressed,
        prominent: action.prominent,
      );
}

class HomeSidebarEmptyState extends StatelessWidget {
  final String title;
  final String description;
  final String? primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;

  const HomeSidebarEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.primaryLabel,
    this.onPrimaryPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return m.SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            m.Icon(
              m.Icons.search_off,
              size: 28,
              color: theme.colorScheme.mutedForeground,
            ),
            const Gap(10),
            Text(
              title,
              style: theme.typography.large.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Gap(6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.typography.small.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
            ),
            if (primaryLabel != null || secondaryLabel != null) ...<Widget>[
              const Gap(AlembicShadcnTokens.gapLg),
              Wrap(
                spacing: AlembicShadcnTokens.gapSm,
                runSpacing: AlembicShadcnTokens.gapSm,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  if (secondaryLabel != null)
                    AlembicToolbarButton(
                      label: secondaryLabel!,
                      onPressed: onSecondaryPressed,
                    ),
                  if (primaryLabel != null)
                    AlembicToolbarButton(
                      label: primaryLabel!,
                      onPressed: onPrimaryPressed,
                      prominent: true,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class HomeLoadingState extends StatelessWidget {
  final BehaviorSubject<int> fetching;

  const HomeLoadingState({
    super.key,
    required this.fetching,
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
              const SizedBox(
                width: 28,
                height: 28,
                child: m.CircularProgressIndicator(strokeWidth: 2.6),
              ),
              const Gap(18),
              Text(
                'Loading repositories',
                style: theme.typography.large.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(8),
              StreamBuilder<int>(
                stream: fetching.stream,
                initialData: fetching.valueOrNull ?? 0,
                builder:
                    (BuildContext context, AsyncSnapshot<int> fetchSnapshot) {
                  int count = fetchSnapshot.data ?? 0;
                  return Text(
                    count > 0
                        ? 'Indexed $count repositories so far.'
                        : 'Connecting to GitHub and building the repository catalog.',
                    textAlign: TextAlign.center,
                    style: theme.typography.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
