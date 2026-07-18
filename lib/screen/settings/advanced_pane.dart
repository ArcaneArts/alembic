import 'dart:async';

import 'package:alembic/app/about_dialog.dart';
import 'package:alembic/main.dart';
import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:alembic/platform/macos_tray_service.dart';
import 'package:alembic/screen/diagnostics_console.dart';
import 'package:alembic/screen/settings/settings_rows.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:alembic/util/window.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

class AdvancedSettingsPane extends StatelessWidget {
  const AdvancedSettingsPane({super.key});

  Future<void> _recreateTrayIcon() async {
    if (DesktopPlatformAdapter.instance.isMacOS) {
      await MacOSTrayService.instance.recreate(activate: false);
      return;
    }
    await WindowUtil.initSystemTray();
  }

  void _openDiagnosticsConsole(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      m.MaterialPageRoute<void>(
        builder: (_) => const DiagnosticsConsoleScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    DesktopPlatformAdapter adapter = DesktopPlatformAdapter.instance;
    return AlembicSettingsPane(
      title: 'Advanced',
      subtitle: 'Recovery tools, data folder access, and app info.',
      children: <Widget>[
        AlembicSettingsActionRow(
          title: 'Recreate tray icon',
          description:
              'Rebuild the system tray icon if it disappeared or stopped responding.',
          value: '',
          actionLabel: 'Recreate',
          onPressed: () => unawaited(_recreateTrayIcon()),
        ),
        AlembicSettingsActionRow(
          title: 'Restart Alembic',
          description:
              'Quit the current process and relaunch Alembic immediately.',
          value: '',
          actionLabel: 'Restart',
          onPressed: () => unawaited(WindowUtil.restart()),
        ),
        SettingsPathRow(
          title: 'Data folder',
          description: 'Where Alembic stores configuration, tokens, and logs.',
          path: configPath,
          actionLabel: 'Reveal in ${adapter.fileExplorerName}',
          onPressed: () => adapter.openInFileExplorer(configPath),
        ),
        AlembicSettingsActionRow(
          title: 'Diagnostics console',
          description:
              'Live stream of runtime events with level and text filters. Also reachable from the Diagnostics pane.',
          value: '',
          actionLabel: 'Open',
          onPressed: () => _openDiagnosticsConsole(context),
        ),
        AlembicSettingsActionRow(
          title: 'About Alembic',
          description: 'Version, build number, and copyright.',
          value: 'Alembic ${packageInfo.version} (${packageInfo.buildNumber})',
          actionLabel: 'About',
          onPressed: () => unawaited(showAboutAlembicDialog(context)),
        ),
      ],
    );
  }
}
