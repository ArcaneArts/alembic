import 'package:alembic/main.dart';
import 'package:alembic/util/clone_transport.dart';
import 'package:alembic/util/extensions.dart';
import 'package:alembic/util/git_signing.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:alembic/widget/glass_context_menu.dart';
import 'package:alembic/widget/glass_modal_overlay.dart';
import 'package:alembic/widget/glass_settings_sheet.dart';
import 'package:alembic/widget/glass_shell.dart';
import 'package:alembic/widget/glass_text_field.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

Future<void> showSettingsModal(BuildContext context) async {
  await showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x00000000),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, __) {
      return SafeArea(
        child: GlassModalOverlay(
          mode: GlassModalFocusMode.blurAndDim,
          blurSigmaMultiplier: 2.40,
          dimStrengthOverride: 0.04,
          whiteLiftStrengthOverride: 0.30,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 680,
              maxHeight: 720,
            ),
            child: const Settings(modal: true),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      CurvedAnimation fadeCurve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      CurvedAnimation scaleCurve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: fadeCurve,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.93, end: 1).animate(scaleCurve),
          child: child,
        ),
      );
    },
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
  late final TextEditingController _archiveDaysController;
  late final GitSigningManager _signingManager;
  late CloneTransportMode _cloneTransportMode;
  GitSigningStatus? _signingStatus;
  bool _signingBusy = false;

  @override
  void initState() {
    super.initState();
    _signingManager = const GitSigningManager();
    _cloneTransportMode = loadCloneTransportMode();
    _archiveDaysController = TextEditingController(
      text: '${config.daysToArchive}',
    );
    _refreshSigningStatus();
  }

  @override
  void dispose() {
    _archiveDaysController.dispose();
    super.dispose();
  }

  Future<void> _pickEditorTool() async {
    ApplicationTool? selected = await GlassContextMenu.show<ApplicationTool>(
      context,
      title: 'Editor Tool',
      actions: ApplicationTool.values.map((tool) {
        return GlassMenuAction<ApplicationTool>(
          value: tool,
          title: tool.displayName,
        );
      }).toList(),
    );
    if (selected == null) {
      return;
    }
    setConfig(config..editorTool = selected);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickGitTool() async {
    GitTool? selected = await GlassContextMenu.show<GitTool>(
      context,
      title: 'Git Tool',
      actions: GitTool.values.map((tool) {
        return GlassMenuAction<GitTool>(
          value: tool,
          title: tool.displayName,
        );
      }).toList(),
    );
    if (selected == null) {
      return;
    }
    setConfig(config..gitTool = selected);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickCloneTransport() async {
    CloneTransportMode? selected =
        await GlassContextMenu.show<CloneTransportMode>(
      context,
      title: 'Clone Transport',
      actions: CloneTransportMode.values.map((mode) {
        return GlassMenuAction<CloneTransportMode>(
          value: mode,
          title: mode.label,
        );
      }).toList(),
    );
    if (selected == null) {
      return;
    }
    await saveCloneTransportMode(selected);
    if (!mounted) {
      return;
    }
    setState(() {
      _cloneTransportMode = selected;
    });
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
      await showGlassInfoDialog(
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
      await showGlassInfoDialog(
        context,
        title: 'Commit Signing',
        message: status.label,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      await showGlassInfoDialog(
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

  @override
  Widget build(BuildContext context) {
    String commitSigningLabel = _signingBusy
        ? 'Configuring...'
        : (_signingStatus?.label ?? 'Checking...');

    Widget sheet = GlassSettingsSheetScaffold(
      title: 'Settings',
      subtitle: 'Application and workspace preferences',
      onClosePressed: () => Navigator.of(context).pop(),
      onFooterPressed: () => Navigator.of(context).pop(),
      footerLabel: 'Done',
      showDragStrip: !widget.modal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GlassSettingsSection(
            title: 'General',
            children: <Widget>[
              GlassSettingsToggleRow(
                label: 'Launch at Startup',
                supportingText: 'Add or remove Alembic from Login Items.',
                value: boxSettings.get('autolaunch', defaultValue: true),
                onChanged: (value) {
                  boxSettings.put('autolaunch', value);
                  if (value) {
                    launchAtStartup.enable();
                  } else {
                    launchAtStartup.disable();
                  }
                  setState(() {});
                },
              ),
              GlassSettingsToggleRow(
                label: 'Check for Updates on Launch',
                supportingText:
                    'Allow Alembic to check for updates every time it starts.',
                value: boxSettings.get('achup', defaultValue: true),
                onChanged: (value) {
                  boxSettings.put('achup', value);
                  setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          GlassSettingsSection(
            title: 'Workspace',
            children: <Widget>[
              GlassSettingsActionRow(
                label: 'Workspace Directory',
                value: config.workspaceDirectory,
                supportingText: 'Base directory used for active repositories.',
                onPressed: () => _selectDirectory(
                  initialDirectory: expandPath(config.workspaceDirectory),
                  dialogTitle: 'Select Workspace Directory',
                  onSelected: (path) {
                    setConfig(config..workspaceDirectory = path);
                    setState(() {});
                  },
                ),
              ),
              GlassSettingsActionRow(
                label: 'Archive Directory',
                value: config.archiveDirectory,
                supportingText: 'Where repository archives are stored.',
                onPressed: () => _selectDirectory(
                  initialDirectory: expandPath(config.archiveDirectory),
                  dialogTitle: 'Select Archive Directory',
                  onSelected: (path) {
                    setConfig(config..archiveDirectory = path);
                    setState(() {});
                  },
                ),
              ),
              GlassSettingsFieldRow(
                label: 'Archive Duration (Days)',
                supportingText:
                    'Automatically archive active repos after N days.',
                child: GlassTextField(
                  controller: _archiveDaysController,
                  placeholder: '30',
                  keyboardType: TextInputType.number,
                  prefix: const Icon(
                    CupertinoIcons.time,
                    size: 15,
                  ),
                  maxLength: 3,
                  onChanged: (value) {
                    int? days = int.tryParse(value);
                    setConfig(
                      config..daysToArchive = (days ?? 30).clamp(1, 3650),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GlassSettingsSection(
            title: 'Tools',
            children: <Widget>[
              GlassSettingsActionRow(
                label: 'Editor Tool',
                value:
                    (config.editorTool ?? ApplicationTool.intellij).displayName,
                supportingText: 'Default editor for opening repositories.',
                onPressed: _pickEditorTool,
              ),
              GlassSettingsActionRow(
                label: 'Git Tool',
                value: (config.gitTool ?? GitTool.gitkraken).displayName,
                supportingText: 'Default Git client integration.',
                onPressed: _pickGitTool,
              ),
              GlassSettingsActionRow(
                label: 'Clone Transport',
                value: _cloneTransportMode.label,
                supportingText: 'HTTPS or SSH for repository clone URLs.',
                onPressed: _pickCloneTransport,
              ),
              GlassSettingsActionRow(
                label: 'Commit Signing',
                value: commitSigningLabel,
                supportingText:
                    'Configure global intrinsic SSH commit signing.',
                onPressed: _configureCommitSigning,
              ),
            ],
          ),
          const SizedBox(height: 12),
          GlassSettingsSection(
            title: 'Diagnostics',
            children: <Widget>[
              GlassSettingsActionRow(
                label: 'Config Path',
                value: configPath,
                supportingText: 'Open Alembic local configuration directory.',
                onPressed: () => cmd('open', <String>[configPath]),
              ),
              GlassSettingsActionRow(
                label: 'View Logs',
                value: '$configPath/alembic.log',
                supportingText: 'Open the current Alembic log file.',
                onPressed: () =>
                    cmd('open', <String>['$configPath/alembic.log']),
              ),
            ],
          ),
        ],
      ),
    );

    if (widget.modal) {
      return sheet;
    }

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.transparent,
      child: GlassShell(
        safeArea: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
          child: sheet,
        ),
      ),
    );
  }
}
