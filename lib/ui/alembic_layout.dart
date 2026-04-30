import 'package:alembic/ui/alembic_tokens.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

enum AlembicSurfaceTone {
  panel,
  elevated,
  inset,
  flat,
}

enum AlembicShellProfile {
  app,
  modal,
}

extension AlembicShellProfileValues on AlembicShellProfile {
  double get maxWidth => switch (this) {
        AlembicShellProfile.app => AlembicShadcnTokens.shellMaxWidth,
        AlembicShellProfile.modal => AlembicShadcnTokens.modalMaxWidth,
      };
}

class AlembicScaffold extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final AlembicShellProfile profile;

  const AlembicScaffold({
    super.key,
    required this.child,
    this.padding = AlembicShadcnTokens.shellPadding,
    this.profile = AlembicShellProfile.app,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color background = theme.colorScheme.background;
    bool isDark = theme.colorScheme.brightness == Brightness.dark;
    double highlightAlpha = isDark ? 0.055 : 0.018;
    double edgeAlpha = isDark ? 0.14 : 0.06;
    Color highlightColor = m.Color.alphaBlend(
      m.Colors.white.withValues(alpha: highlightAlpha),
      background,
    );
    Color edgeColor = isDark
        ? m.Colors.white.withValues(alpha: edgeAlpha)
        : m.Colors.black.withValues(alpha: edgeAlpha);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const <double>[0.0, 0.12, 1.0],
          colors: <Color>[
            highlightColor,
            background,
            background,
          ],
        ),
        border: Border(
          top: BorderSide(color: edgeColor, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: padding,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: profile.maxWidth,
              ),
              child: SizedBox.expand(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class AlembicSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final AlembicSurfaceTone tone;
  final BorderRadiusGeometry? borderRadius;
  final bool border;

  const AlembicSurface({
    super.key,
    required this.child,
    this.padding = AlembicShadcnTokens.surfacePadding,
    this.tone = AlembicSurfaceTone.panel,
    this.borderRadius,
    this.border = true,
  });

  Color _fillFor(ThemeData theme) => switch (tone) {
        AlembicSurfaceTone.panel => theme.colorScheme.card,
        AlembicSurfaceTone.elevated => m.Color.alphaBlend(
            theme.colorScheme.secondary.withValues(alpha: 0.58),
            theme.colorScheme.card,
          ),
        AlembicSurfaceTone.inset => m.Color.alphaBlend(
            theme.colorScheme.background.withValues(alpha: 0.5),
            theme.colorScheme.card,
          ),
        AlembicSurfaceTone.flat => theme.colorScheme.background,
      };

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _fillFor(theme),
        borderRadius: borderRadius ??
            BorderRadius.circular(AlembicShadcnTokens.surfaceRadius),
        border: border ? Border.all(color: theme.colorScheme.border) : null,
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class AlembicPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final AlembicSurfaceTone tone;

  const AlembicPanel({
    super.key,
    required this.child,
    this.padding = AlembicShadcnTokens.surfacePadding,
    this.tone = AlembicSurfaceTone.panel,
  });

  @override
  Widget build(BuildContext context) => AlembicSurface(
        padding: padding,
        tone: tone,
        child: child,
      );
}

class AlembicPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  const AlembicPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (leading != null) ...<Widget>[
          leading!,
          const Gap(AlembicShadcnTokens.gapMd),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.x2Large.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const Gap(AlembicShadcnTokens.gapXs),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          const Gap(AlembicShadcnTokens.gapMd),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: trailing!,
            ),
          ),
        ],
      ],
    );
  }
}

class AlembicSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const AlembicSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.medium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const Gap(AlembicShadcnTokens.gapXs),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          const Gap(AlembicShadcnTokens.gapMd),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: trailing!,
            ),
          ),
        ],
      ],
    );
  }
}

class AlembicIconTile extends StatelessWidget {
  final Widget child;
  final double size;

  const AlembicIconTile({
    super.key,
    required this.child,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary,
        borderRadius: BorderRadius.circular(AlembicShadcnTokens.controlRadius),
        border: Border.all(color: theme.colorScheme.border),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class AlembicEmptyState extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Widget? actions;

  const AlembicEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = m.Icons.search_off,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                m.Icon(
                  icon,
                  size: 28,
                  color: theme.colorScheme.mutedForeground,
                ),
                const Gap(AlembicShadcnTokens.gapMd),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.typography.large.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(AlembicShadcnTokens.gapSm),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: theme.typography.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
                if (actions != null) ...<Widget>[
                  const Gap(AlembicShadcnTokens.gapXl),
                  actions!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AlembicDialogCard extends StatelessWidget {
  final String title;
  final String description;
  final List<Widget> children;
  final List<Widget> actions;

  const AlembicDialogCard({
    super.key,
    required this.title,
    required this.description,
    this.children = const <Widget>[],
    this.actions = const <Widget>[],
  });

  @override
  Widget build(BuildContext context) => m.Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: AlembicPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AlembicSectionHeader(
                  title: title,
                  subtitle: description,
                ),
                if (children.isNotEmpty) ...<Widget>[
                  const Gap(AlembicShadcnTokens.gapXl),
                  ...children,
                ],
                if (actions.isNotEmpty) ...<Widget>[
                  const Gap(AlembicShadcnTokens.gapXl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}
