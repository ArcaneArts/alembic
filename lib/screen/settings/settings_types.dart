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
