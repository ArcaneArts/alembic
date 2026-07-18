import 'dart:async';
import 'dart:io';

import 'package:alembic/app/alembic_dialogs.dart';
import 'package:alembic/app/alembic_theme.dart';
import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:alembic/screen/settings/settings_navigation.dart';
import 'package:alembic/screen/settings/settings_types.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:alembic/util/clone_transport.dart';
import 'package:alembic/util/git_signing.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:arcane/arcane.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' as m;

Future<void> showSettingsModal(
  BuildContext context, {
  SettingsPane initialPane = SettingsPane.general,
  VoidCallback? onLogout,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    m.MaterialPageRoute<void>(
      builder: (_) => Settings(
        initialPane: initialPane,
        onLogout: onLogout,
        modal: true,
      ),
    ),
  );
}

class Settings extends StatefulWidget {
  final bool modal;
  final SettingsPane initialPane;
  final VoidCallback? onLogout;

  const Settings({
    super.key,
    this.modal = false,
    this.initialPane = SettingsPane.general,
    this.onLogout,
  });

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> with m.WidgetsBindingObserver {
  static const double _sidebarWidth = 200;
  static const double _sidebarGap = 24;

  late final m.TextEditingController _archiveDaysController;
  late final GitSigningManager _signingManager;
  late CloneTransportMode _cloneTransportMode;
  GitSigningStatus? _signingStatus;
  bool _signingBusy = false;
  SettingsPane _pane = SettingsPane.general;

  static bool get _isFlutterTestEnvironment {
    if (const bool.fromEnvironment('FLUTTER_TEST')) {
      return true;
    }
    return m.WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
  }

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
    if (_isFlutterTestEnvironment) {
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
    String? pickerInitialDirectory =
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
    String resolvedPath =
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

    String? existingParent = _nearestExistingParentDirectory(resolvedPath);
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
      onLogout: widget.onLogout,
    );
    return m.Material(
      color: Theme.of(context).colorScheme.background,
      child: AlembicScaffold(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _SettingsHeader(
              onDone: () => Navigator.of(context).pop(),
            ),
            const Gap(AlembicShadcnTokens.gapXl),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: _sidebarWidth,
                    child: SettingsSidebar(
                      pane: _pane,
                      onSelected: _selectPane,
                    ),
                  ),
                  const Gap(_sidebarGap),
                  Expanded(
                    child: _SettingsBody(
                      content: content,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  final VoidCallback onDone;

  const _SettingsHeader({
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Settings',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.x2Large.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Gap(AlembicShadcnTokens.gapXs),
              Text(
                'Configure startup, workspace, accounts, and tooling.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.small.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const Gap(AlembicShadcnTokens.gapMd),
        AlembicToolbarButton(
          onPressed: onDone,
          label: 'Done',
        ),
      ],
    );
  }
}

class _SettingsBody extends StatelessWidget {
  static const double _paneMaxWidth = 680;

  final Widget content;

  const _SettingsBody({
    required this.content,
  });

  @override
  Widget build(BuildContext context) => m.ListView(
        padding: const EdgeInsets.only(bottom: AlembicShadcnTokens.gapXl),
        children: <Widget>[
          Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _paneMaxWidth),
              child: content,
            ),
          ),
        ],
      );
}
