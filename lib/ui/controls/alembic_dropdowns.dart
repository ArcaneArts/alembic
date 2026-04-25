import 'package:alembic/ui/alembic_tokens.dart';
import 'package:alembic/ui/controls/alembic_control_frame.dart';
import 'package:alembic/ui/controls/alembic_models.dart';
import 'package:arcane/arcane.dart';
import 'package:arcane/generated/arcane_shadcn/shadcn_flutter.dart'
    show showDropdown;
import 'package:flutter/material.dart' as m;

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
    ButtonDensity density = iconOnly
        ? ButtonDensity.icon
        : (compact ? ButtonDensity.compact : ButtonDensity.normal);
    Widget trigger = iconOnly
        ? Center(child: m.Icon(leadingIcon ?? trailingIcon, size: 16))
        : Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
    Widget button = OutlineButton(
      onPressed: onPressed,
      size: ButtonSize.small,
      density: density,
      alignment: alignment,
      leading: iconOnly || leadingIcon == null
          ? null
          : m.Icon(leadingIcon, size: 15),
      trailing: iconOnly ? null : m.Icon(trailingIcon, size: 15),
      child: trigger,
    );
    return AlembicControlFrame(
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
                  leading: _leadingFor(item, theme),
                  trailing: _trailingFor(item, theme),
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

  Widget? _leadingFor(AlembicDropdownOption<T> item, ThemeData theme) {
    if (item.icon == null) {
      return null;
    }
    return IconTheme.merge(
      data: m.IconThemeData(
        color: item.destructive ? theme.colorScheme.destructive : null,
      ),
      child: m.Icon(item.icon, size: 15),
    );
  }

  Widget? _trailingFor(AlembicDropdownOption<T> item, ThemeData theme) {
    if (selectedValue != item.value) {
      return null;
    }
    return m.Icon(
      m.Icons.check,
      size: 14,
      color: item.destructive
          ? theme.colorScheme.destructive
          : theme.colorScheme.foreground,
    );
  }
}
