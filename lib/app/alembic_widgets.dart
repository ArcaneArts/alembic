import 'package:alembic/app/alembic_tokens.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

enum AlembicSurfaceTone {
  panel,
  elevated,
  inset,
}

enum AlembicBadgeTone {
  primary,
  secondary,
  outline,
  destructive,
}

class AlembicDropdownOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const AlembicDropdownOption({
    required this.value,
    required this.label,
    this.icon,
  });
}

class AlembicSegmentedOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const AlembicSegmentedOption({
    required this.value,
    required this.label,
    this.icon,
  });
}

class AlembicSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final AlembicSurfaceTone tone;
  final BorderRadiusGeometry? borderRadius;

  const AlembicSurface({
    super.key,
    required this.child,
    this.padding = AlembicShadcnTokens.surfacePadding,
    this.tone = AlembicSurfaceTone.panel,
    this.borderRadius,
  });

  Color _fillFor(ThemeData theme) => switch (tone) {
        AlembicSurfaceTone.panel => theme.colorScheme.card,
        AlembicSurfaceTone.elevated => m.Color.alphaBlend(
            theme.colorScheme.secondary.withValues(alpha: 0.72),
            theme.colorScheme.card,
          ),
        AlembicSurfaceTone.inset => m.Color.alphaBlend(
            theme.colorScheme.background.withValues(alpha: 0.42),
            theme.colorScheme.card,
          ),
      };

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Card(
      padding: padding,
      filled: true,
      fillColor: _fillFor(theme),
      borderColor: theme.colorScheme.border,
      borderWidth: 1,
      borderRadius: borderRadius ??
          BorderRadius.circular(AlembicShadcnTokens.surfaceRadius),
      child: child,
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

class AlembicBadge extends StatelessWidget {
  final String label;
  final AlembicBadgeTone tone;

  const AlembicBadge({
    super.key,
    required this.label,
    this.tone = AlembicBadgeTone.outline,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color background = switch (tone) {
      AlembicBadgeTone.primary => m.Color.alphaBlend(
          theme.colorScheme.primary.withValues(alpha: 0.08),
          theme.colorScheme.secondary,
        ),
      AlembicBadgeTone.secondary => theme.colorScheme.secondary,
      AlembicBadgeTone.outline => theme.colorScheme.card,
      AlembicBadgeTone.destructive =>
        theme.colorScheme.destructive.withValues(alpha: 0.18),
    };
    Color foreground = switch (tone) {
      AlembicBadgeTone.primary => theme.colorScheme.foreground,
      AlembicBadgeTone.secondary => theme.colorScheme.foreground,
      AlembicBadgeTone.outline => theme.colorScheme.mutedForeground,
      AlembicBadgeTone.destructive => theme.colorScheme.destructive,
    };
    Color border = switch (tone) {
      AlembicBadgeTone.primary =>
        theme.colorScheme.primary.withValues(alpha: 0.24),
      AlembicBadgeTone.secondary => theme.colorScheme.border,
      AlembicBadgeTone.outline => theme.colorScheme.border,
      AlembicBadgeTone.destructive =>
        theme.colorScheme.destructive.withValues(alpha: 0.32),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AlembicShadcnTokens.badgeRadius),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: theme.typography.xSmall.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class AlembicToolbarButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool prominent;
  final bool destructive;
  final bool quiet;
  final bool compact;
  final bool iconOnly;
  final String? tooltip;

  const AlembicToolbarButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.prominent = false,
    this.destructive = false,
    this.quiet = false,
    this.compact = false,
    this.iconOnly = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = iconOnly
        ? m.Icon(
            leadingIcon ?? trailingIcon ?? m.Icons.circle,
            size: 16,
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (leadingIcon != null) ...<Widget>[
                m.Icon(leadingIcon, size: 15),
                const Gap(AlembicShadcnTokens.gapSm),
              ],
              Flexible(child: Text(label)),
              if (trailingIcon != null) ...<Widget>[
                const Gap(AlembicShadcnTokens.gapSm),
                m.Icon(trailingIcon, size: 15),
              ],
            ],
          );
    Widget button;

    if (prominent) {
      button = PrimaryButton(
        onPressed: onPressed,
        size: ButtonSize.small,
        density: compact ? ButtonDensity.compact : ButtonDensity.normal,
        child: child,
      );
    } else if (quiet) {
      button = GhostButton(
        onPressed: onPressed,
        size: ButtonSize.small,
        density: compact ? ButtonDensity.compact : ButtonDensity.normal,
        child: child,
      );
    } else if (destructive) {
      ThemeData theme = Theme.of(context);
      button = m.DefaultTextStyle.merge(
        style: m.TextStyle(color: theme.colorScheme.destructive),
        child: IconTheme.merge(
          data: m.IconThemeData(color: theme.colorScheme.destructive),
          child: OutlineButton(
            onPressed: onPressed,
            size: ButtonSize.small,
            density: compact ? ButtonDensity.compact : ButtonDensity.normal,
            child: child,
          ),
        ),
      );
    } else {
      button = OutlineButton(
        onPressed: onPressed,
        size: ButtonSize.small,
        density: compact ? ButtonDensity.compact : ButtonDensity.normal,
        child: child,
      );
    }

    if (tooltip == null && !iconOnly) {
      return button;
    }

    return m.Tooltip(
      message: tooltip ?? label,
      child: button,
    );
  }
}

class AlembicDropdownMenu<T> extends StatelessWidget {
  final String label;
  final List<AlembicDropdownOption<T>> items;
  final ValueChanged<T> onSelected;
  final IconData? leadingIcon;
  final IconData trailingIcon;
  final bool compact;
  final bool iconOnly;
  final String? tooltip;
  final AlignmentGeometry alignment;

  const AlembicDropdownMenu({
    super.key,
    required this.label,
    required this.items,
    required this.onSelected,
    this.leadingIcon,
    this.trailingIcon = m.Icons.unfold_more,
    this.compact = false,
    this.iconOnly = false,
    this.tooltip,
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    List<MenuItem> menu = <MenuItem>[
      for (AlembicDropdownOption<T> item in items)
        MenuButton(
          leading: item.icon == null ? null : m.Icon(item.icon, size: 16),
          onPressed: () => onSelected(item.value),
          child: Text(item.label),
        ),
    ];

    Widget button = OutlineButtonMenu(
      menu: menu,
      size: ButtonSize.small,
      density: compact ? ButtonDensity.compact : ButtonDensity.normal,
      alignment: alignment,
      leading: iconOnly || leadingIcon == null
          ? null
          : m.Icon(leadingIcon, size: 15),
      trailing: iconOnly ? null : m.Icon(trailingIcon, size: 15),
      child: iconOnly
          ? m.Icon(leadingIcon ?? trailingIcon, size: 16)
          : Text(label),
    );

    if (tooltip == null && !iconOnly) {
      return button;
    }

    return m.Tooltip(
      message: tooltip ?? label,
      child: button,
    );
  }
}

class AlembicSelect<T> extends StatelessWidget {
  final T value;
  final List<AlembicDropdownOption<T>> options;
  final ValueChanged<T> onChanged;
  final IconData? leadingIcon;
  final bool compact;

  const AlembicSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.leadingIcon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    String selectedLabel = '';
    for (AlembicDropdownOption<T> option in options) {
      if (option.value == value) {
        selectedLabel = option.label;
        break;
      }
    }

    return AlembicDropdownMenu<T>(
      label: selectedLabel,
      items: options,
      onSelected: onChanged,
      leadingIcon: leadingIcon,
      compact: compact,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.typography.large.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const Gap(4),
                Text(
                  subtitle!,
                  style: theme.typography.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class AlembicLabeledField extends StatelessWidget {
  final String label;
  final String? supportingText;
  final Widget child;

  const AlembicLabeledField({
    super.key,
    required this.label,
    required this.child,
    this.supportingText,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.typography.small.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (supportingText != null) ...<Widget>[
          const Gap(4),
          Text(
            supportingText!,
            style: theme.typography.xSmall.copyWith(
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ],
        const Gap(8),
        child,
      ],
    );
  }
}

class AlembicTextInput extends StatelessWidget {
  final m.TextEditingController? controller;
  final String placeholder;
  final bool obscureText;
  final int? maxLength;
  final m.TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? leading;
  final bool enabled;

  const AlembicTextInput({
    super.key,
    required this.placeholder,
    this.controller,
    this.obscureText = false,
    this.maxLength,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.leading,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return TextField(
      controller: controller,
      placeholder: Text(
        placeholder,
        style: theme.typography.small.copyWith(
          color: theme.colorScheme.mutedForeground,
        ),
      ),
      obscureText: obscureText,
      maxLength: maxLength,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: enabled,
      features: <InputFeature>[
        if (leading != null) InputFeature.leading(leading!),
      ],
    );
  }
}

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
    Color background = selected
        ? m.Color.alphaBlend(
            theme.colorScheme.secondary.withValues(alpha: 0.9),
            theme.colorScheme.card,
          )
        : m.Colors.transparent;
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
      child: Row(
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

class AlembicSidebarItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onPressed;
  final Widget? leading;
  final Widget? trailing;

  const AlembicSidebarItem({
    super.key,
    required this.title,
    this.subtitle,
    this.selected = false,
    this.onPressed,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => AlembicNavItem(
        title: title,
        subtitle: subtitle,
        selected: selected,
        onPressed: onPressed,
        leading: leading,
        trailing: trailing,
      );
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
      padding: const EdgeInsets.all(4),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
  Widget build(BuildContext context) {
    return AlembicSurface(
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
}
