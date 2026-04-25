import 'package:alembic/main.dart';
import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:arcane/arcane.dart';

class DiagnosticsSettingsPane extends StatelessWidget {
  const DiagnosticsSettingsPane({super.key});

  @override
  Widget build(BuildContext context) {
    DesktopPlatformAdapter adapter = DesktopPlatformAdapter.instance;
    return AlembicSettingsPane(
      title: 'Diagnostics',
      subtitle: 'Inspect config storage and runtime files.',
      children: <Widget>[
        AlembicSettingsActionRow(
          title: 'Config path',
          description: 'Open the Alembic local configuration directory.',
          value: configPath,
          actionLabel: 'Open',
          onPressed: () => adapter.openInFileExplorer(configPath),
        ),
        AlembicSettingsActionRow(
          title: 'Log file',
          description: 'Open the current Alembic log file.',
          value: '$configPath/alembic.log',
          actionLabel: 'Open',
          onPressed: () => adapter.openPath('$configPath/alembic.log'),
        ),
      ],
    );
  }
}
