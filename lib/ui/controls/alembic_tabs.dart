import 'package:alembic/ui/alembic_tokens.dart';
import 'package:alembic/ui/controls/alembic_models.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

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
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (AlembicNavigationItem<T> item in items)
            SizedBox(
              width: collapsed
                  ? AlembicShadcnTokens.tabIconWidth
                  : AlembicShadcnTokens.tabWidth,
              child: _AlembicTabButton<T>(
                item: item,
                selected: item.value == value,
                collapsed: collapsed,
                onPressed: () => onChanged(item.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlembicTabButton<T> extends StatelessWidget {
  final AlembicNavigationItem<T> item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onPressed;

  const _AlembicTabButton({
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color foreground = selected
        ? theme.colorScheme.foreground
        : theme.colorScheme.mutedForeground;
    Widget label = collapsed
        ? m.Icon(item.icon, size: 15, color: foreground)
        : _AlembicTabLabel(
            text: item.label,
            foreground: foreground,
            selected: selected,
            theme: theme,
          );
    Widget button = m.InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AlembicShadcnTokens.controlRadius - 1),
      child: Container(
        height: AlembicShadcnTokens.compactButtonHeight - 4,
        alignment: Alignment.center,
        decoration: _decorationFor(theme),
        child: label,
      ),
    );
    if (collapsed && item.tooltip != null) {
      return m.Tooltip(message: item.tooltip!, child: button);
    }
    return button;
  }

  BoxDecoration _decorationFor(ThemeData theme) {
    bool isDark = theme.colorScheme.brightness == Brightness.dark;
    Color selectedFill = theme.colorScheme.card;
    Color selectedBorder = theme.colorScheme.border;
    Color selectedShadow = isDark
        ? m.Colors.black.withValues(alpha: 0.30)
        : m.Colors.black.withValues(alpha: 0.08);
    return BoxDecoration(
      color: selected ? selectedFill : m.Colors.transparent,
      borderRadius:
          BorderRadius.circular(AlembicShadcnTokens.controlRadius - 1),
      border: selected
          ? Border.all(color: selectedBorder)
          : Border.all(color: m.Colors.transparent),
      boxShadow: selected
          ? <BoxShadow>[
              BoxShadow(
                color: selectedShadow,
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ]
          : const <BoxShadow>[],
    );
  }
}

class _AlembicTabLabel extends StatelessWidget {
  final String text;
  final Color foreground;
  final bool selected;
  final ThemeData theme;

  const _AlembicTabLabel({
    required this.text,
    required this.foreground,
    required this.selected,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.small.copyWith(
              color: foreground,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
