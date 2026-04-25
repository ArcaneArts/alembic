import 'package:alembic/app/alembic_theme.dart';
import 'package:alembic/main.dart';
import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:alembic/util/window.dart';
import 'package:arcane/arcane.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

class GeneralSettingsPane extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const GeneralSettingsPane({
    super.key,
    required this.onThemeModeChanged,
  });

  @override
  State<GeneralSettingsPane> createState() => _GeneralSettingsPaneState();
}

class _GeneralSettingsPaneState extends State<GeneralSettingsPane> {
  bool get _launchAtStartupEnabled =>
      boxSettings.get('autolaunch', defaultValue: true);
  bool get _updateOnLaunch => boxSettings.get('achup', defaultValue: true);
  bool get _hideOnBlur => boxSettings.get(
        'hide_on_blur',
        defaultValue: DesktopPlatformAdapter.instance.isMacOS,
      );
  bool get _startHidden => boxSettings.get(
        'start_hidden',
        defaultValue: DesktopPlatformAdapter.instance.isMacOS,
      );

  Future<void> _setLaunchAtStartup(bool value) async {
    await boxSettings.put('autolaunch', value);
    if (value) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _setUpdateOnLaunch(bool value) async {
    await boxSettings.put('achup', value);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _setHideOnBlur(bool value) async {
    await WindowUtil.setHideOnBlur(value);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _setStartHidden(bool value) async {
    await WindowUtil.setStartHidden(value);
    if (mounted) {
      setState(() {});
    }
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  @override
  Widget build(BuildContext context) {
    ThemeMode themeMode = loadAlembicThemeMode();
    return AlembicSettingsPane(
      title: 'General',
      subtitle: 'Global startup, tray behavior, and appearance.',
      children: <Widget>[
        AlembicSettingsToggleRow(
          title: 'Launch at startup',
          description: 'Add or remove Alembic from desktop startup.',
          value: _launchAtStartupEnabled,
          onChanged: _setLaunchAtStartup,
        ),
        AlembicSettingsToggleRow(
          title: 'Check for updates on launch',
          description: 'Allow Alembic to check release metadata on startup.',
          value: _updateOnLaunch,
          onChanged: _setUpdateOnLaunch,
        ),
        AlembicSettingsToggleRow(
          title: 'Hide window on blur',
          description: 'Dismiss the desktop shell when focus leaves the app.',
          value: _hideOnBlur,
          onChanged: _setHideOnBlur,
        ),
        AlembicSettingsToggleRow(
          title: 'Start hidden in tray',
          description: 'Launch Alembic hidden until the tray icon is used.',
          value: _startHidden,
          onChanged: _setStartHidden,
        ),
        AlembicSettingsMenuRow<ThemeMode>(
          title: 'Theme mode',
          description: 'Choose the desktop appearance mode.',
          valueLabel: _themeLabel(themeMode),
          items: ThemeMode.values,
          itemLabel: _themeLabel,
          onSelected: widget.onThemeModeChanged,
        ),
        AlembicSettingsInfoRow(
          title: 'Desktop platform',
          description:
              'Alembic adapts file explorer, updater, and launch flows by platform.',
          value: DesktopPlatformAdapter.instance.currentPlatform.name,
        ),
      ],
    );
  }
}
