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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AlembicSectionHeader(
            title: 'Preferences',
            subtitle: 'Configure desktop behavior and repository defaults.',
          ),
          const Gap(14),
          for (SettingsPane item in SettingsPane.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AlembicNavItem(
                title: item.title,
                subtitle: item.subtitle,
                selected: pane == item,
                leading: m.Icon(item.iconData, size: 16),
                onPressed: () => onSelected(item),
              ),
            ),
        ],
      ),
    );
  }
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
