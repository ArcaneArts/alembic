import 'package:flutter/material.dart' as m;
import 'package:flutter/widgets.dart';

typedef SelectDirectoryCallback = Future<void> Function({
  required String initialDirectory,
  required String dialogTitle,
  required ValueChanged<String> onSelected,
});

enum SettingsPane {
  general,
  workspace,
  accounts,
  archiveMaster,
  tools,
  diagnostics,
}

enum SettingsQuickAction {
  workspaceFolder,
  archivesFolder,
  bulkActions,
  checkUpdates,
  restart,
  logout,
}

extension SettingsPaneValues on SettingsPane {
  String get title => switch (this) {
        SettingsPane.general => 'General',
        SettingsPane.workspace => 'Workspace',
        SettingsPane.accounts => 'Accounts',
        SettingsPane.archiveMaster => 'Archive Master',
        SettingsPane.tools => 'Tools',
        SettingsPane.diagnostics => 'Diagnostics',
      };

  String get subtitle => switch (this) {
        SettingsPane.general => 'Startup behavior, theme, and updates',
        SettingsPane.workspace => 'Directories and archive retention',
        SettingsPane.accounts =>
          'Manage GitHub tokens, signing identities, and account labels',
        SettingsPane.archiveMaster =>
          'Always-up-to-date repository archives synced on a schedule',
        SettingsPane.tools => 'Editors, Git clients, and signing',
        SettingsPane.diagnostics => 'Storage paths and runtime files',
      };

  IconData get iconData => switch (this) {
        SettingsPane.general => m.Icons.tune,
        SettingsPane.workspace => m.Icons.folder_open_outlined,
        SettingsPane.accounts => m.Icons.manage_accounts_outlined,
        SettingsPane.archiveMaster => m.Icons.workspaces_outlined,
        SettingsPane.tools => m.Icons.handyman_outlined,
        SettingsPane.diagnostics => m.Icons.data_object,
      };
}

extension SettingsQuickActionValues on SettingsQuickAction {
  String get title => switch (this) {
        SettingsQuickAction.workspaceFolder => 'Open workspace folder',
        SettingsQuickAction.archivesFolder => 'Open archives folder',
        SettingsQuickAction.bulkActions => 'Bulk actions',
        SettingsQuickAction.checkUpdates => 'Check for updates',
        SettingsQuickAction.restart => 'Restart app',
        SettingsQuickAction.logout => 'Log out',
      };

  String get compactTitle => switch (this) {
        SettingsQuickAction.workspaceFolder => 'Workspace',
        SettingsQuickAction.archivesFolder => 'Archives',
        SettingsQuickAction.bulkActions => 'Bulk',
        SettingsQuickAction.checkUpdates => 'Updates',
        SettingsQuickAction.restart => 'Restart',
        SettingsQuickAction.logout => 'Log out',
      };

  String get subtitle => switch (this) {
        SettingsQuickAction.workspaceFolder =>
          'Open the local folder where active repositories are stored',
        SettingsQuickAction.archivesFolder =>
          'Open the local folder where archived snapshots are stored',
        SettingsQuickAction.bulkActions =>
          'Run pull, archive, restore, or clone operations across repositories',
        SettingsQuickAction.checkUpdates =>
          'Look for a newer Alembic release now',
        SettingsQuickAction.restart =>
          'Return to the startup screen and reload the app session',
        SettingsQuickAction.logout => 'Sign out of the current Alembic session',
      };

  IconData get iconData => switch (this) {
        SettingsQuickAction.workspaceFolder => m.Icons.folder_open,
        SettingsQuickAction.archivesFolder => m.Icons.archive_outlined,
        SettingsQuickAction.bulkActions =>
          m.Icons.playlist_add_check_circle_outlined,
        SettingsQuickAction.checkUpdates => m.Icons.system_update_alt,
        SettingsQuickAction.restart => m.Icons.restart_alt,
        SettingsQuickAction.logout => m.Icons.logout,
      };
}
