import 'dart:async';

import 'package:alembic/app/alembic_dialogs.dart';
import 'package:alembic/app/alembic_theme.dart';
import 'package:alembic/screen/settings/settings_navigation.dart';
import 'package:alembic/screen/settings/settings_types.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:alembic/util/clone_transport.dart';
import 'package:alembic/util/environment.dart';
import 'package:alembic/util/git_signing.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:arcane/arcane.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' as m;

Future<void> showSettingsModal(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    m.MaterialPageRoute<void>(builder: (_) => const Settings()),
  );
}

class Settings extends StatefulWidget {
  final bool modal;

  const Settings({
    super.key,
    this.modal = false,
  });

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  late final m.TextEditingController _archiveDaysController;
  late final GitSigningManager _signingManager;
  late CloneTransportMode _cloneTransportMode;
  GitSigningStatus? _signingStatus;
  bool _signingBusy = false;
  SettingsPane _pane = SettingsPane.general;

  @override
  void initState() {
    super.initState();
    _signingManager = const GitSigningManager();
    _cloneTransportMode = loadCloneTransportMode();
    _archiveDaysController = m.TextEditingController(
      text: '${config.daysToArchive}',
    );
    if (alembicIsFlutterTestEnvironment()) {
      _signingStatus = const GitSigningStatus(
        commitSigningEnabled: false,
        signingFormat: null,
        signingKey: null,
      );
    } else {
      unawaited(_refreshSigningStatus());
    }
  }

  @override
  void dispose() {
    _archiveDaysController.dispose();
    super.dispose();
  }

  Future<void> _selectDirectory({
    required String initialDirectory,
    required String dialogTitle,
    required ValueChanged<String> onSelected,
  }) async {
    try {
      String? selectedPath = await FilePicker.platform.getDirectoryPath(
        initialDirectory: initialDirectory,
        dialogTitle: dialogTitle,
      );
      String? compressedPath = compressPath(selectedPath);
      if (compressedPath != null) {
        onSelected(compressedPath);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      await showAlembicInfoDialog(
        context,
        title: 'Directory Error',
        message: 'Error selecting directory: $e',
      );
    }
  }

  Future<void> _refreshSigningStatus() async {
    try {
      GitSigningStatus status = await _signingManager.inspectGlobalSigning();
      if (!mounted) {
        return;
      }
      setState(() {
        _signingStatus = status;
      });
    } catch (_) {}
  }

  Future<void> _configureCommitSigning() async {
    if (_signingBusy) {
      return;
    }
    setState(() {
      _signingBusy = true;
    });
    try {
      GitSigningStatus status =
          await _signingManager.ensureGlobalIntrinsicSigning();
      if (!mounted) {
        return;
      }
      setState(() {
        _signingStatus = status;
      });
      await showAlembicInfoDialog(
        context,
        title: 'Commit Signing',
        message: status.label,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await showAlembicInfoDialog(
        context,
        title: 'Commit Signing Failed',
        message: '$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _signingBusy = false;
        });
      }
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    await saveAlembicThemeMode(mode);
    Arcane.app.setTheme(buildAlembicTheme());
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _onCloneTransportChanged(CloneTransportMode mode) async {
    await saveCloneTransportMode(mode);
    if (mounted) {
      setState(() {
        _cloneTransportMode = mode;
      });
    }
  }

  void _selectPane(SettingsPane pane) {
    setState(() {
      _pane = pane;
    });
  }

  @override
  Widget build(BuildContext context) {
    return m.Scaffold(
      backgroundColor: m.Colors.transparent,
      body: AlembicScaffold(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AlembicPageHeader(
                  title: 'Settings',
                  subtitle:
                      'Configure startup, workspace, accounts, and tooling.',
                  trailing: AlembicToolbarButton(
                    onPressed: () => Navigator.of(context).pop(),
                    label: 'Done',
                  ),
                ),
                const Gap(AlembicShadcnTokens.gapLg),
                Expanded(
                  child: m.ListView(
                    children: <Widget>[
                      SettingsNavigation(
                        pane: _pane,
                        onSelected: _selectPane,
                      ),
                      const Gap(AlembicShadcnTokens.gapLg),
                      SizedBox(
                        height: (constraints.maxHeight * 0.9)
                            .clamp(440, 980)
                            .toDouble(),
                        child: SettingsContent(
                          pane: _pane,
                          archiveDaysController: _archiveDaysController,
                          cloneTransportMode: _cloneTransportMode,
                          signingBusy: _signingBusy,
                          signingStatus: _signingStatus,
                          onSelectDirectory: _selectDirectory,
                          onCloneTransportChanged: _onCloneTransportChanged,
                          onConfigureCommitSigning: _configureCommitSigning,
                          onThemeModeChanged: _setThemeMode,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
