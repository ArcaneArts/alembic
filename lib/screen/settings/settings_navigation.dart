import 'package:alembic/screen/settings/accounts_pane.dart';
import 'package:alembic/screen/settings/archive_master_pane.dart';
import 'package:alembic/screen/settings/diagnostics_pane.dart';
import 'package:alembic/screen/settings/general_pane.dart';
import 'package:alembic/screen/settings/settings_types.dart';
import 'package:alembic/screen/settings/tools_pane.dart';
import 'package:alembic/screen/settings/workspace_pane.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:alembic/util/clone_transport.dart';
import 'package:alembic/util/git_signing.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

class SettingsNavigation extends StatelessWidget {
  final SettingsPane pane;
  final ValueChanged<SettingsPane> onSelected;

  const SettingsNavigation({
    super.key,
    required this.pane,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlembicPanel(
      padding: AlembicShadcnTokens.compactSurfacePadding,
      tone: AlembicSurfaceTone.elevated,
      child: AlembicTabs<SettingsPane>(
        value: pane,
        collapsed: true,
        expanded: true,
        items: <AlembicNavigationItem<SettingsPane>>[
          for (SettingsPane item in SettingsPane.values)
            AlembicNavigationItem<SettingsPane>(
              value: item,
              label: item.title,
              icon: item.iconData,
              tooltip: item.title,
            ),
        ],
        onChanged: onSelected,
      ),
    );
  }
}

class SettingsQuickActions extends StatelessWidget {
  final List<SettingsQuickAction> actions;
  final ValueChanged<SettingsQuickAction>? onSelected;

  const SettingsQuickActions({
    super.key,
    required this.actions,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = constraints.maxWidth < 760 ? 3 : actions.length;
        return AlembicPanel(
          padding: AlembicShadcnTokens.compactSurfacePadding,
          tone: AlembicSurfaceTone.elevated,
          child: _SettingsQuickActionGrid(
            actions: actions,
            columns: columns,
            onSelected: onSelected,
          ),
        );
      },
    );
  }
}

class _SettingsQuickActionGrid extends StatelessWidget {
  final List<SettingsQuickAction> actions;
  final int columns;
  final ValueChanged<SettingsQuickAction>? onSelected;

  const _SettingsQuickActionGrid({
    required this.actions,
    required this.columns,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    int rowCount = (actions.length / columns).ceil();
    return Column(
      children: <Widget>[
        for (int row = 0; row < rowCount; row++) ...<Widget>[
          _SettingsQuickActionRow(
            actions: actions
                .skip(row * columns)
                .take(columns)
                .toList(growable: false),
            columns: columns,
            onSelected: onSelected,
          ),
          if (row < rowCount - 1) const Gap(AlembicShadcnTokens.gapXs),
        ],
      ],
    );
  }
}

class _SettingsQuickActionRow extends StatelessWidget {
  final List<SettingsQuickAction> actions;
  final int columns;
  final ValueChanged<SettingsQuickAction>? onSelected;

  const _SettingsQuickActionRow({
    required this.actions,
    required this.columns,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int index = 0; index < columns; index++) ...<Widget>[
          Expanded(
            child: index < actions.length
                ? _SettingsQuickActionButton(
                    action: actions[index],
                    onSelected: onSelected,
                  )
                : const SizedBox.shrink(),
          ),
          if (index < columns - 1) const Gap(AlembicShadcnTokens.gapXs),
        ],
      ],
    );
  }
}

class _SettingsQuickActionButton extends StatelessWidget {
  final SettingsQuickAction action;
  final ValueChanged<SettingsQuickAction>? onSelected;

  const _SettingsQuickActionButton({
    required this.action,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => AlembicToolbarButton(
        label: action.compactTitle,
        leadingIcon: action.iconData,
        compact: true,
        smallLabel: true,
        tooltip: action.title,
        onPressed: onSelected == null ? null : () => onSelected!(action),
      );
}

class SettingsContent extends StatelessWidget {
  final SettingsPane pane;
  final m.TextEditingController archiveDaysController;
  final CloneTransportMode cloneTransportMode;
  final bool signingBusy;
  final GitSigningStatus? signingStatus;
  final SelectDirectoryCallback onSelectDirectory;
  final ValueChanged<CloneTransportMode> onCloneTransportChanged;
  final Future<void> Function() onConfigureCommitSigning;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const SettingsContent({
    super.key,
    required this.pane,
    required this.archiveDaysController,
    required this.cloneTransportMode,
    required this.signingBusy,
    required this.signingStatus,
    required this.onSelectDirectory,
    required this.onCloneTransportChanged,
    required this.onConfigureCommitSigning,
    required this.onThemeModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return switch (pane) {
      SettingsPane.general => GeneralSettingsPane(
          onThemeModeChanged: onThemeModeChanged,
        ),
      SettingsPane.workspace => WorkspaceSettingsPane(
          archiveDaysController: archiveDaysController,
          onSelectDirectory: onSelectDirectory,
        ),
      SettingsPane.accounts => const AccountsSettingsPane(),
      SettingsPane.archiveMaster => ArchiveMasterSettingsPane(
          onSelectDirectory: onSelectDirectory,
        ),
      SettingsPane.tools => ToolsSettingsPane(
          cloneTransportMode: cloneTransportMode,
          signingBusy: signingBusy,
          signingStatus: signingStatus,
          onCloneTransportChanged: onCloneTransportChanged,
          onConfigureCommitSigning: onConfigureCommitSigning,
        ),
      SettingsPane.diagnostics => const DiagnosticsSettingsPane(),
    };
  }
}
