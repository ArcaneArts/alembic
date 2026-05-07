import 'package:alembic/ui/alembic_tokens.dart';
import 'package:alembic/ui/controls/alembic_control_frame.dart';
import 'package:alembic/ui/controls/alembic_models.dart';
import 'package:arcane/arcane.dart';
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

  Future<void> _showMenu(BuildContext context) async {
    ThemeData theme = Theme.of(context);
    T? selected = await m.showMenu<T>(
      context: context,
      position: _menuPosition(context),
      color: theme.colorScheme.popover,
      surfaceTintColor: m.Colors.transparent,
      elevation: 0,
      constraints: _menuConstraints(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AlembicShadcnTokens.controlRadius),
        side: BorderSide(color: theme.colorScheme.border),
      ),
      items: <m.PopupMenuEntry<T>>[
        for (AlembicDropdownOption<T> item in items)
          m.PopupMenuItem<T>(
            value: item.value,
            padding: EdgeInsets.zero,
            height: 34,
            child: _AlembicDropdownItem<T>(
              item: item,
              selected: selectedValue == item.value,
            ),
          ),
      ],
    );
    if (selected != null && context.mounted) {
      onSelected(selected);
    }
  }

  RelativeRect _menuPosition(BuildContext context) {
    RenderBox anchor = context.findRenderObject()! as RenderBox;
    RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    Offset topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    double width = _safeDimension(anchor.size.width, fallback: 1);
    double height = _safeDimension(anchor.size.height, fallback: 0);
    Rect target = Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy + height + AlembicShadcnTokens.gapXs,
      width,
      1,
    );
    return RelativeRect.fromRect(target, Offset.zero & overlay.size);
  }

  BoxConstraints _menuConstraints(BuildContext context) {
    RenderBox anchor = context.findRenderObject()! as RenderBox;
    double anchorWidth = _safeDimension(
      anchor.size.width,
      fallback: AlembicShadcnTokens.buttonMinWidth,
    );
    double minWidth = iconOnly ? 176 : anchorWidth;
    if (minWidth < AlembicShadcnTokens.buttonMinWidth) {
      minWidth = AlembicShadcnTokens.buttonMinWidth;
    }
    double overlayWidth = _safeDimension(
      MediaQuery.maybeSizeOf(context)?.width ?? 0,
      fallback: 0,
    );
    double cap = overlayWidth > 16 ? overlayWidth - 16 : 360;
    if (minWidth > cap) {
      minWidth = cap;
    }
    double maxWidth = minWidth > 360.0 ? minWidth : 360.0;
    if (maxWidth > cap) {
      maxWidth = cap;
    }
    if (maxWidth < minWidth) {
      maxWidth = minWidth;
    }
    return BoxConstraints(
      minWidth: minWidth,
      maxWidth: maxWidth,
      maxHeight: AlembicShadcnTokens.dropdownMenuMaxHeight,
    );
  }

  double _safeDimension(double value, {required double fallback}) {
    if (value.isNaN || value.isInfinite || value <= 0) {
      return fallback;
    }
    return value;
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
    ThemeData theme = Theme.of(context);
    Widget button = m.Material(
      color: m.Colors.transparent,
      child: m.InkWell(
        onTap: onPressed,
        canRequestFocus: false,
        borderRadius: BorderRadius.circular(AlembicShadcnTokens.controlRadius),
        child: Container(
          height: iconOnly
              ? AlembicShadcnTokens.iconButtonSize
              : compact
                  ? AlembicShadcnTokens.compactButtonHeight
                  : AlembicShadcnTokens.buttonHeight,
          alignment: alignment,
          padding: iconOnly
              ? EdgeInsets.zero
              : compact
                  ? AlembicShadcnTokens.compactControlPadding
                  : AlembicShadcnTokens.controlPadding,
          decoration: BoxDecoration(
            color: theme.colorScheme.card,
            borderRadius:
                BorderRadius.circular(AlembicShadcnTokens.controlRadius),
            border: Border.all(color: theme.colorScheme.border),
          ),
          child: iconOnly
              ? m.Icon(leadingIcon ?? trailingIcon, size: 16)
              : _AlembicDropdownTriggerLabel(
                  label: label,
                  leadingIcon: leadingIcon,
                  trailingIcon: trailingIcon,
                ),
        ),
      ),
    );
    return AlembicControlFrame(
      compact: compact,
      iconOnly: iconOnly,
      child: button,
    );
  }
}

class _AlembicDropdownTriggerLabel extends StatelessWidget {
  final String label;
  final IconData? leadingIcon;
  final IconData trailingIcon;

  const _AlembicDropdownTriggerLabel({
    required this.label,
    required this.leadingIcon,
    required this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
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
            style: theme.typography.small.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Gap(AlembicShadcnTokens.gapSm),
        m.Icon(trailingIcon, size: 15),
      ],
    );
  }
}

class _AlembicDropdownItem<T> extends StatelessWidget {
  final AlembicDropdownOption<T> item;
  final bool selected;

  const _AlembicDropdownItem({
    required this.item,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    m.Color foreground = item.destructive
        ? theme.colorScheme.destructive
        : theme.colorScheme.foreground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? theme.colorScheme.secondary : m.Colors.transparent,
        borderRadius: BorderRadius.circular(AlembicShadcnTokens.controlRadius),
      ),
      child: Row(
        children: <Widget>[
          if (item.icon != null) ...<Widget>[
            m.Icon(item.icon, size: 15, color: foreground),
            const Gap(AlembicShadcnTokens.gapSm),
          ],
          Expanded(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.small.copyWith(
                color: foreground,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
          if (selected) ...<Widget>[
            const Gap(AlembicShadcnTokens.gapSm),
            m.Icon(m.Icons.check, size: 14, color: foreground),
          ],
        ],
      ),
    );
  }
}
