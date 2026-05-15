import 'dart:async';
import 'dart:io';

import 'package:alembic/app/alembic_dialogs.dart';
import 'package:alembic/app/alembic_theme.dart';
import 'package:alembic/platform/desktop_platform_adapter.dart';
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

Future<void> showSettingsModal(
  BuildContext context, {
  SettingsPane initialPane = SettingsPane.general,
  List<SettingsQuickAction> quickActions = const <SettingsQuickAction>[],
  ValueChanged<SettingsQuickAction>? onQuickActionSelected,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    m.MaterialPageRoute<void>(
      builder: (_) => Settings(
        initialPane: initialPane,
        quickActions: quickActions,
        onQuickActionSelected: onQuickActionSelected,
        modal: true,
      ),
    ),
  );
}

class Settings extends StatefulWidget {
  final bool modal;
  final SettingsPane initialPane;
  final List<SettingsQuickAction> quickActions;
  final ValueChanged<SettingsQuickAction>? onQuickActionSelected;

  const Settings({
    super.key,
    this.modal = false,
    this.initialPane = SettingsPane.general,
    this.quickActions = const <SettingsQuickAction>[],
    this.onQuickActionSelected,
  });

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> with m.WidgetsBindingObserver {
  late final m.TextEditingController _archiveDaysController;
  late final GitSigningManager _signingManager;
  late CloneTransportMode _cloneTransportMode;
  GitSigningStatus? _signingStatus;
  bool _signingBusy = false;
  SettingsPane _pane = SettingsPane.general;

  @override
  void initState() {
    super.initState();
    m.WidgetsBinding.instance.addObserver(this);
    _pane = widget.initialPane;
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
    m.WidgetsBinding.instance.removeObserver(this);
    _archiveDaysController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(m.AppLifecycleState state) {
    if (state != m.AppLifecycleState.inactive &&
        state != m.AppLifecycleState.hidden &&
        state != m.AppLifecycleState.paused) {
      return;
    }
    if (_pane == SettingsPane.general || !mounted) {
      return;
    }
    setState(() {
      _pane = SettingsPane.general;
    });
  }

  Future<void> _selectDirectory({
    required String initialDirectory,
    required String dialogTitle,
    required ValueChanged<String> onSelected,
  }) async {
    final String? pickerInitialDirectory =
        _safeDirectoryPickerInitialPath(initialDirectory);
    try {
      String? selectedPath = await FilePicker.platform.getDirectoryPath(
        initialDirectory: pickerInitialDirectory,
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

  String? _safeDirectoryPickerInitialPath(String path) {
    final String resolvedPath =
        DesktopPlatformAdapter.instance.expandHomePath(path).trim();
    if (resolvedPath.isEmpty) {
      return null;
    }

    try {
      if (Directory(resolvedPath).existsSync()) {
        return Directory(resolvedPath).absolute.path;
      }
    } catch (_) {
      return null;
    }

    if (!DesktopPlatformAdapter.instance.isWindows) {
      return resolvedPath;
    }

    final String? existingParent =
        _nearestExistingParentDirectory(resolvedPath);
    return existingParent ??
        DesktopPlatformAdapter.instance.defaultHomeDirectory;
  }

  String? _nearestExistingParentDirectory(String path) {
    Directory directory = Directory(path).absolute;
    Directory? parent = directory.parent;

    while (parent != null && parent.path != directory.path) {
      try {
        if (parent.existsSync()) {
          return parent.path;
        }
      } catch (_) {
        return null;
      }
      directory = parent;
      parent = directory.parent;
    }

    return null;
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
    Widget navigation = SettingsNavigation(
      pane: _pane,
      onSelected: _selectPane,
    );
    Widget content = SettingsContent(
      pane: _pane,
      archiveDaysController: _archiveDaysController,
      cloneTransportMode: _cloneTransportMode,
      signingBusy: _signingBusy,
      signingStatus: _signingStatus,
      onSelectDirectory: _selectDirectory,
      onCloneTransportChanged: _onCloneTransportChanged,
      onConfigureCommitSigning: _configureCommitSigning,
      onThemeModeChanged: _setThemeMode,
    );
    return m.Scaffold(
      backgroundColor: m.Colors.transparent,
      body: AlembicScaffold(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AlembicPageHeader(
              title: 'Settings',
              subtitle: 'Configure startup, workspace, accounts, and tooling.',
              trailing: AlembicToolbarButton(
                onPressed: () => Navigator.of(context).pop(),
                label: 'Done',
              ),
            ),
            const Gap(AlembicShadcnTokens.gapLg),
            navigation,
            const Gap(AlembicShadcnTokens.gapLg),
            Expanded(
              child: _SettingsBody(
                content: content,
              ),
            ),
            if (widget.quickActions.isNotEmpty) ...<Widget>[
              const Gap(AlembicShadcnTokens.gapLg),
              SettingsQuickActions(
                actions: widget.quickActions,
                onSelected: widget.onQuickActionSelected,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  final Widget content;

  const _SettingsBody({
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return m.ListView(
      children: <Widget>[
        content,
      ],
    );
  }
}
