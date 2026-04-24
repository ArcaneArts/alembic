import 'package:alembic/ui/alembic_layout.dart';
import 'package:alembic/ui/alembic_tokens.dart';
import 'package:arcane/arcane.dart';
import 'package:arcane/generated/arcane_shadcn/shadcn_flutter.dart'
    show showDropdown;
import 'package:flutter/material.dart' as m;

enum AlembicBadgeTone {
  primary,
  secondary,
  outline,
  destructive,
}

class AlembicActionItem<T> {
  final T value;
  final String label;
  final String? description;
  final IconData? icon;
  final bool prominent;
  final bool destructive;

  const AlembicActionItem({
    required this.value,
    required this.label,
    this.description,
    this.icon,
    this.prominent = false,
    this.destructive = false,
  });
}

class AlembicDropdownOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  final bool destructive;

  const AlembicDropdownOption({
    required this.value,
    required this.label,
    this.icon,
    this.destructive = false,
  });
}

class AlembicNavigationItem<T> {
  final T value;
  final String label;
  final IconData icon;
  final String? tooltip;

  const AlembicNavigationItem({
    required this.value,
    required this.label,
    required this.icon,
    this.tooltip,
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
          theme.colorScheme.primary.withValues(alpha: 0.1),
          theme.colorScheme.card,
        ),
      AlembicBadgeTone.secondary => theme.colorScheme.secondary,
      AlembicBadgeTone.outline => theme.colorScheme.card,
      AlembicBadgeTone.destructive =>
        theme.colorScheme.destructive.withValues(alpha: 0.16),
    };
    Color foreground = switch (tone) {
      AlembicBadgeTone.primary => theme.colorScheme.foreground,
      AlembicBadgeTone.secondary => theme.colorScheme.foreground,
      AlembicBadgeTone.outline => theme.colorScheme.mutedForeground,
      AlembicBadgeTone.destructive => theme.colorScheme.destructive,
    };
    Color border = switch (tone) {
      AlembicBadgeTone.primary =>
        theme.colorScheme.primary.withValues(alpha: 0.2),
      AlembicBadgeTone.secondary => theme.colorScheme.border,
      AlembicBadgeTone.outline => theme.colorScheme.border,
      AlembicBadgeTone.destructive =>
        theme.colorScheme.destructive.withValues(alpha: 0.32),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
  }) : assert(!iconOnly || leadingIcon != null || trailingIcon != null);

  @override
  Widget build(BuildContext context) {
    Widget content = iconOnly
        ? m.Icon(leadingIcon ?? trailingIcon ?? m.Icons.circle, size: 16)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (leadingIcon != null) ...<Widget>[
                m.Icon(leadingIcon, size: 15),
                const Gap(AlembicShadcnTokens.gapSm),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingIcon != null) ...<Widget>[
                const Gap(AlembicShadcnTokens.gapSm),
                m.Icon(trailingIcon, size: 15),
              ],
            ],
          );
    ButtonDensity density =
        compact ? ButtonDensity.compact : ButtonDensity.normal;
    Widget button = _buttonFor(
      context: context,
      content: content,
      density: density,
    );
    Widget sizedButton = _AlembicControlFrame(
      compact: compact,
      iconOnly: iconOnly,
      child: button,
    );
    if (tooltip == null && !iconOnly) {
      return sizedButton;
    }
    return m.Tooltip(
      message: tooltip ?? label,
      child: sizedButton,
    );
  }

  Widget _buttonFor({
    required BuildContext context,
    required Widget content,
    required ButtonDensity density,
  }) {
    if (prominent) {
      return PrimaryButton(
        onPressed: onPressed,
        size: ButtonSize.small,
        density: density,
        child: content,
      );
    }
    if (quiet) {
      return GhostButton(
        onPressed: onPressed,
        size: ButtonSize.small,
        density: density,
        child: content,
      );
    }
    if (!destructive) {
      return OutlineButton(
        onPressed: onPressed,
        size: ButtonSize.small,
        density: density,
        child: content,
      );
    }

    ThemeData theme = Theme.of(context);
    return m.DefaultTextStyle.merge(
      style: m.TextStyle(color: theme.colorScheme.destructive),
      child: IconTheme.merge(
        data: m.IconThemeData(color: theme.colorScheme.destructive),
        child: OutlineButton(
          onPressed: onPressed,
          size: ButtonSize.small,
          density: density,
          child: content,
        ),
      ),
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
  final T? selectedValue;

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
    this.selectedValue,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = Builder(
      builder: (BuildContext context) => _AlembicDropdownTrigger(
        label: label,
        onPressed: items.isEmpty ? null : () => _showMenu(context),
        leadingIcon: leadingIcon,
        trailingIcon: trailingIcon,
        compact: compact,
        iconOnly: iconOnly,
        alignment: alignment,
      ),
    );
    if (tooltip == null && !iconOnly) {
      return button;
    }
    return m.Tooltip(
      message: tooltip ?? label,
      child: button,
    );
  }

  void _showMenu(BuildContext context) {
    showDropdown<void>(
      context: context,
      widthConstraint: iconOnly
          ? PopoverConstraint.intrinsic
          : PopoverConstraint.anchorMinSize,
      heightConstraint: PopoverConstraint.intrinsic,
      anchorAlignment: Alignment.bottomLeft,
      alignment: Alignment.topLeft,
      offset: const Offset(0, AlembicShadcnTokens.gapXs),
      builder: (BuildContext context) => _AlembicDropdownPopup<T>(
        items: items,
        selectedValue: selectedValue,
        onSelected: onSelected,
      ),
    );
  }
}

class AlembicOverflowMenu<T> extends StatelessWidget {
  final String label;
  final List<AlembicDropdownOption<T>> items;
  final ValueChanged<T> onSelected;
  final bool compact;

  const AlembicOverflowMenu({
    super.key,
    required this.label,
    required this.items,
    required this.onSelected,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) => AlembicDropdownMenu<T>(
        label: label,
        items: items,
        onSelected: onSelected,
        leadingIcon: m.Icons.more_horiz,
        compact: compact,
        iconOnly: true,
        tooltip: label,
        alignment: Alignment.center,
      );
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
      selectedValue: value,
    );
  }
}

class _AlembicDropdownTrigger extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;
  final IconData trailingIcon;
  final bool compact;
  final bool iconOnly;
  final AlignmentGeometry alignment;

  const _AlembicDropdownTrigger({
    required this.label,
    required this.onPressed,
    required this.leadingIcon,
    required this.trailingIcon,
    required this.compact,
    required this.iconOnly,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    ButtonDensity density =
        compact ? ButtonDensity.compact : ButtonDensity.normal;
    Widget button = OutlineButton(
      onPressed: onPressed,
      size: ButtonSize.small,
      density: density,
      alignment: alignment,
      leading: iconOnly || leadingIcon == null
          ? null
          : m.Icon(leadingIcon, size: 15),
      trailing: iconOnly ? null : m.Icon(trailingIcon, size: 15),
      child: iconOnly
          ? m.Icon(leadingIcon ?? trailingIcon, size: 16)
          : Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );
    return _AlembicControlFrame(
      compact: compact,
      iconOnly: iconOnly,
      child: button,
    );
  }
}

class _AlembicDropdownItemLabel extends StatelessWidget {
  final String label;
  final bool selected;
  final bool destructive;

  const _AlembicDropdownItemLabel({
    required this.label,
    required this.selected,
    required this.destructive,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.typography.small.copyWith(
        color: destructive ? theme.colorScheme.destructive : null,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
      ),
    );
  }
}

class _AlembicDropdownPopup<T> extends StatelessWidget {
  final List<AlembicDropdownOption<T>> items;
  final T? selectedValue;
  final ValueChanged<T> onSelected;

  const _AlembicDropdownPopup({
    required this.items,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return ComponentTheme<MenuPopupTheme>(
      data: MenuPopupTheme(
        surfaceOpacity: 1,
        surfaceBlur: 0,
        padding: const EdgeInsets.all(4),
        fillColor: theme.colorScheme.popover,
        borderColor: theme.colorScheme.border,
        borderRadius: BorderRadius.circular(AlembicShadcnTokens.controlRadius),
      ),
      child: ComponentTheme<MenuTheme>(
        data: const MenuTheme(itemPadding: EdgeInsets.zero),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: AlembicShadcnTokens.dropdownMenuMaxHeight,
          ),
          child: DropdownMenu(
            surfaceOpacity: 1,
            surfaceBlur: 0,
            children: <MenuItem>[
              for (AlembicDropdownOption<T> item in items)
                MenuButton(
                  key: m.ValueKey<String>('dropdown:${item.label}'),
                  leading: item.icon == null
                      ? null
                      : IconTheme.merge(
                          data: m.IconThemeData(
                            color: item.destructive
                                ? theme.colorScheme.destructive
                                : null,
                          ),
                          child: m.Icon(item.icon, size: 15),
                        ),
                  trailing: selectedValue == item.value
                      ? m.Icon(
                          m.Icons.check,
                          size: 14,
                          color: item.destructive
                              ? theme.colorScheme.destructive
                              : theme.colorScheme.foreground,
                        )
                      : null,
                  onPressed: () => onSelected(item.value),
                  child: _AlembicDropdownItemLabel(
                    label: item.label,
                    selected: selectedValue == item.value,
                    destructive: item.destructive,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlembicControlFrame extends StatelessWidget {
  final bool compact;
  final bool iconOnly;
  final Widget child;

  const _AlembicControlFrame({
    required this.compact,
    required this.iconOnly,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      double size = compact
          ? AlembicShadcnTokens.compactIconButtonSize
          : AlembicShadcnTokens.iconButtonSize;
      return SizedBox.square(
        dimension: size,
        child: child,
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: compact
            ? AlembicShadcnTokens.compactButtonMinWidth
            : AlembicShadcnTokens.buttonMinWidth,
        minHeight: compact
            ? AlembicShadcnTokens.compactButtonHeight
            : AlembicShadcnTokens.buttonHeight,
      ),
      child: child,
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
          const Gap(AlembicShadcnTokens.gapXs),
          Text(
            supportingText!,
            style: theme.typography.xSmall.copyWith(
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ],
        const Gap(AlembicShadcnTokens.gapSm),
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

class AlembicTabs<T> extends StatelessWidget {
  final T value;
  final List<AlembicNavigationItem<T>> items;
  final ValueChanged<T> onChanged;
  final bool collapsed;

  const AlembicTabs({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.collapsed = false,
  });

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AlembicShadcnTokens.gapSm,
        runSpacing: AlembicShadcnTokens.gapSm,
        children: <Widget>[
          for (AlembicNavigationItem<T> item in items)
            SizedBox(
              width: collapsed
                  ? AlembicShadcnTokens.tabIconWidth
                  : AlembicShadcnTokens.tabWidth,
              child: AlembicToolbarButton(
                label: item.label,
                leadingIcon: collapsed ? item.icon : null,
                onPressed: () => onChanged(item.value),
                prominent: item.value == value,
                iconOnly: collapsed,
                tooltip: collapsed ? item.tooltip ?? item.label : null,
              ),
            ),
        ],
      );
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
