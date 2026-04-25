import 'package:alembic/ui/alembic_layout.dart';
import 'package:alembic/ui/alembic_tokens.dart';
import 'package:alembic/ui/controls/alembic_models.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

class AlembicNavItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onPressed;
  final Widget? leading;
  final Widget? trailing;

  const AlembicNavItem({
    super.key,
    required this.title,
    this.subtitle,
    this.selected = false,
    this.onPressed,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color background =
        selected ? theme.colorScheme.secondary : m.Colors.transparent;
    Color border = selected
        ? theme.colorScheme.border
        : theme.colorScheme.border.withValues(alpha: 0);
    Widget content = Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AlembicShadcnTokens.controlRadius),
        border: Border.all(color: border),
      ),
      padding: AlembicShadcnTokens.controlPadding,
      child: _NavItemContent(
        title: title,
        subtitle: subtitle,
        selected: selected,
        leading: leading,
        trailing: trailing,
        theme: theme,
      ),
    );
    return GhostButton(
      onPressed: onPressed,
      alignment: Alignment.centerLeft,
      density: ButtonDensity.compact,
      child: content,
    );
  }
}

class _NavItemContent extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final Widget? leading;
  final Widget? trailing;
  final ThemeData theme;

  const _NavItemContent({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.leading,
    required this.trailing,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
                style: theme.typography.small.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const Gap(2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.xSmall.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          const Gap(AlembicShadcnTokens.gapSm),
          trailing!,
        ],
      ],
    );
  }
}

class AlembicSegmentedControl<T> extends StatelessWidget {
  final T value;
  final List<AlembicSegmentedOption<T>> options;
  final ValueChanged<T> onChanged;

  const AlembicSegmentedControl({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary,
        borderRadius: BorderRadius.circular(AlembicShadcnTokens.controlRadius),
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Row(
        children: <Widget>[
          for (AlembicSegmentedOption<T> option in options)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _AlembicSegmentedButton<T>(
                  option: option,
                  selected: option.value == value,
                  onPressed: () => onChanged(option.value),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlembicSegmentedButton<T> extends StatelessWidget {
  final AlembicSegmentedOption<T> option;
  final bool selected;
  final VoidCallback onPressed;

  const _AlembicSegmentedButton({
    required this.option,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return m.InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AlembicShadcnTokens.controlRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.card : m.Colors.transparent,
          borderRadius:
              BorderRadius.circular(AlembicShadcnTokens.controlRadius),
          border: Border.all(
            color: selected
                ? theme.colorScheme.border
                : theme.colorScheme.border.withValues(alpha: 0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (option.icon != null) ...<Widget>[
              m.Icon(option.icon, size: 14),
              const Gap(6),
            ],
            Flexible(
              child: Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.small.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AlembicMenuChip extends StatelessWidget {
  final String label;
  final Widget? trailing;

  const AlembicMenuChip({
    super.key,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => AlembicSurface(
        padding: AlembicShadcnTokens.compactControlPadding,
        tone: AlembicSurfaceTone.inset,
        borderRadius: BorderRadius.circular(AlembicShadcnTokens.controlRadius),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: Theme.of(context).typography.small.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (trailing != null) ...<Widget>[
              const Gap(AlembicShadcnTokens.gapSm),
              trailing!,
            ],
          ],
        ),
      );
}
