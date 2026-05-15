import 'package:alembic/ui/alembic_controls.dart';
import 'package:alembic/ui/alembic_layout.dart';
import 'package:alembic/ui/alembic_tokens.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

class AlembicSettingsPane extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? trailing;

  const AlembicSettingsPane({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    List<Widget> rows = <Widget>[
      Padding(
        padding: const EdgeInsets.only(
          bottom: AlembicShadcnTokens.gapLg,
        ),
        child: AlembicSectionHeader(
          title: title,
          subtitle: subtitle,
          trailing: trailing,
        ),
      ),
    ];
    for (Widget child in children) {
      rows.add(
        m.Divider(
          height: 1,
          thickness: 1,
          color: theme.colorScheme.border,
        ),
      );
      rows.add(
        Padding(
          padding: AlembicShadcnTokens.rowPadding,
          child: child,
        ),
      );
    }
    return AlembicPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

class AlembicSettingsToggleRow extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const AlembicSettingsToggleRow({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => _AlembicSettingsBaseRow(
        title: title,
        description: description,
        trailing: Switch(
          value: value,
          onChanged: onChanged,
        ),
      );
}

class AlembicSettingsActionRow extends StatelessWidget {
  final String title;
  final String description;
  final String value;
  final String actionLabel;
  final VoidCallback? onPressed;

  const AlembicSettingsActionRow({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => _AlembicSettingsBaseRow(
        title: title,
        description: description,
        value: value,
        trailing: AlembicToolbarButton(
          onPressed: onPressed,
          label: actionLabel,
        ),
      );
}

class AlembicSettingsInfoRow extends StatelessWidget {
  final String title;
  final String description;
  final String value;

  const AlembicSettingsInfoRow({
    super.key,
    required this.title,
    required this.description,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => _AlembicSettingsBaseRow(
        title: title,
        description: description,
        trailing: Text(
          value,
          textAlign: TextAlign.end,
          style: Theme.of(context).typography.small.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      );
}

class AlembicSettingsMenuRow<T> extends StatelessWidget {
  final String title;
  final String description;
  final String valueLabel;
  final List<T> items;
  final ValueChanged<T> onSelected;
  final String Function(T item) itemLabel;

  const AlembicSettingsMenuRow({
    super.key,
    required this.title,
    required this.description,
    required this.valueLabel,
    required this.items,
    required this.onSelected,
    required this.itemLabel,
  });

  @override
  Widget build(BuildContext context) {
    List<AlembicDropdownOption<T>> options = <AlembicDropdownOption<T>>[
      for (T item in items)
        AlembicDropdownOption<T>(
          value: item,
          label: itemLabel(item),
        ),
    ];
    return _AlembicSettingsBaseRow(
      title: title,
      description: description,
      trailing: AlembicSelect<T>(
        value: items.firstWhere((T item) => itemLabel(item) == valueLabel),
        options: options,
        onChanged: onSelected,
      ),
    );
  }
}

class AlembicSettingsTextFieldRow extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const AlembicSettingsTextFieldRow({
    super.key,
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => _AlembicSettingsBaseRow(
        title: title,
        description: description,
        below: child,
      );
}

class _AlembicSettingsBaseRow extends StatelessWidget {
  final String title;
  final String description;
  final String? value;
  final Widget? trailing;
  final Widget? below;

  const _AlembicSettingsBaseRow({
    required this.title,
    required this.description,
    this.value,
    this.trailing,
    this.below,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment:
          below == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.typography.small.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Gap(AlembicShadcnTokens.gapXs),
              Text(
                description,
                style: theme.typography.xSmall.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
              if (value != null) ...<Widget>[
                const Gap(AlembicShadcnTokens.gapSm),
                Text(
                  value!,
                  style: theme.typography.small,
                ),
              ],
              if (below != null) ...<Widget>[
                const Gap(AlembicShadcnTokens.gapSm),
                below!,
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          const Gap(AlembicShadcnTokens.gapLg),
          trailing!,
        ],
      ],
    );
  }
}
