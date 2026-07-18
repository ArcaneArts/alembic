import 'package:flutter/material.dart' as m;
import 'package:flutter/widgets.dart';

typedef SelectDirectoryCallback = Future<void> Function({
  required String initialDirectory,
  required String dialogTitle,
  required ValueChanged<String> onSelected,
});

enum SettingsPane {
  general,
  updates,
  workspace,
  tools,
  archiveMaster,
  accounts,
  advanced,
  diagnostics,
}

extension SettingsPaneValues on SettingsPane {
  String get title => switch (this) {
        SettingsPane.general => 'General',
        SettingsPane.updates => 'Updates',
        SettingsPane.workspace => 'Workspace',
        SettingsPane.tools => 'Tools',
        SettingsPane.archiveMaster => 'Archive Master',
        SettingsPane.accounts => 'Accounts',
        SettingsPane.advanced => 'Advanced',
        SettingsPane.diagnostics => 'Diagnostics',
      };

  String get subtitle => switch (this) {
        SettingsPane.general => 'Startup behavior, theme, and tray',
        SettingsPane.updates => 'Non-intrusive release checks and installs',
        SettingsPane.workspace => 'Directories and archive retention',
        SettingsPane.tools => 'Editors, Git clients, and signing',
        SettingsPane.archiveMaster =>
          'Always-up-to-date repository archives synced on a schedule',
        SettingsPane.accounts =>
          'Manage GitHub tokens, signing identities, and account labels',
        SettingsPane.advanced =>
          'Tray icon recovery, data folder access, and app info',
        SettingsPane.diagnostics =>
          'Storage paths, boot context, and the live console',
      };

  IconData get iconData => switch (this) {
        SettingsPane.general => m.Icons.tune,
        SettingsPane.updates => m.Icons.system_update_alt,
        SettingsPane.workspace => m.Icons.folder_open_outlined,
        SettingsPane.tools => m.Icons.handyman_outlined,
        SettingsPane.archiveMaster => m.Icons.workspaces_outlined,
        SettingsPane.accounts => m.Icons.manage_accounts_outlined,
        SettingsPane.advanced => m.Icons.build_circle_outlined,
        SettingsPane.diagnostics => m.Icons.data_object,
      };
}
