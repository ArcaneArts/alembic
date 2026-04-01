import 'package:alembic/app/alembic_dialogs.dart';
import 'package:alembic/app/alembic_scaffold.dart';
import 'package:alembic/app/alembic_theme.dart';
import 'package:alembic/app/alembic_tokens.dart';
import 'package:alembic/app/alembic_widgets.dart';
import 'package:alembic/main.dart';
import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:alembic/util/clone_transport.dart';
import 'package:alembic/util/environment.dart';
import 'package:alembic/util/extensions.dart';
import 'package:alembic/util/git_signing.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:alembic/util/window.dart';
import 'package:arcane/arcane.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' as m;
import 'package:launch_at_startup/launch_at_startup.dart';

Future<void> showSettingsModal(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    m.MaterialPageRoute<void>(builder: (_) => const Settings()),
  );
}

enum _SettingsPane {
  general,
  workspace,
  tools,
  diagnostics,
}

extension _SettingsPaneValues on _SettingsPane {
  String get title => switch (this) {
        _SettingsPane.general => 'General',
        _SettingsPane.workspace => 'Workspace',
        _SettingsPane.tools => 'Tools',
        _SettingsPane.diagnostics => 'Diagnostics',
      };

  String get subtitle => switch (this) {
        _SettingsPane.general => 'Startup behavior, theme, and updates',
        _SettingsPane.workspace => 'Directories and archive retention',
        _SettingsPane.tools => 'Editors, Git clients, and signing',
        _SettingsPane.diagnostics => 'Storage paths and runtime files',
      };
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
  _SettingsPane _pane = _SettingsPane.general;

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
      _refreshSigningStatus();
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

  @override
  Widget build(BuildContext context) {
    return m.Scaffold(
      backgroundColor: m.Colors.transparent,
      body: AlembicScaffold(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            bool stacked = constraints.maxWidth < 960;
            Widget navigation = _SettingsNavigation(
              pane: _pane,
              onSelected: (_SettingsPane pane) {
                setState(() {
                  _pane = pane;
                });
              },
            );
            Widget content = _SettingsContent(
              pane: _pane,
              archiveDaysController: _archiveDaysController,
              cloneTransportMode: _cloneTransportMode,
              signingBusy: _signingBusy,
              signingStatus: _signingStatus,
              onSelectDirectory: _selectDirectory,
              onCloneTransportChanged: (CloneTransportMode mode) async {
                await saveCloneTransportMode(mode);
                if (mounted) {
                  setState(() {
                    _cloneTransportMode = mode;
                  });
                }
              },
              onConfigureCommitSigning: _configureCommitSigning,
              onThemeModeChanged: _setThemeMode,
            );

            if (!stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Settings',
                          style: Theme.of(context).typography.x2Large.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      AlembicToolbarButton(
                        onPressed: () => Navigator.of(context).pop(),
                        label: 'Done',
                      ),
                    ],
                  ),
                  const Gap(AlembicShadcnTokens.gapLg),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(width: 300, child: navigation),
                        const Gap(AlembicShadcnTokens.gapLg),
                        Expanded(child: content),
                      ],
                    ),
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Settings',
                        style: Theme.of(context).typography.x2Large.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    AlembicToolbarButton(
                      onPressed: () => Navigator.of(context).pop(),
                      label: 'Done',
                    ),
                  ],
                ),
                const Gap(AlembicShadcnTokens.gapLg),
                Expanded(
                  child: m.ListView(
                    children: <Widget>[
                      navigation,
                      const Gap(AlembicShadcnTokens.gapLg),
                      SizedBox(
                        height: (constraints.maxHeight * 0.9)
                            .clamp(440, 980)
                            .toDouble(),
                        child: content,
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

class _SettingsNavigation extends StatelessWidget {
  final _SettingsPane pane;
  final ValueChanged<_SettingsPane> onSelected;

  const _SettingsNavigation({
    required this.pane,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlembicPanel(
      padding: AlembicShadcnTokens.compactSurfacePadding,
      tone: AlembicSurfaceTone.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AlembicSectionHeader(
            title: 'Preferences',
            subtitle: 'Configure desktop behavior and repository defaults.',
          ),
          const Gap(14),
          ..._SettingsPane.values.map((_SettingsPane item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AlembicSidebarItem(
                title: item.title,
                subtitle: item.subtitle,
                selected: pane == item,
                leading: m.Icon(
                  switch (item) {
                    _SettingsPane.general => m.Icons.tune,
                    _SettingsPane.workspace => m.Icons.folder_open_outlined,
                    _SettingsPane.tools => m.Icons.handyman_outlined,
                    _SettingsPane.diagnostics => m.Icons.data_object,
                  },
                  size: 16,
                ),
                onPressed: () => onSelected(item),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  final _SettingsPane pane;
  final m.TextEditingController archiveDaysController;
  final CloneTransportMode cloneTransportMode;
  final bool signingBusy;
  final GitSigningStatus? signingStatus;
  final Future<void> Function({
    required String initialDirectory,
    required String dialogTitle,
    required ValueChanged<String> onSelected,
  }) onSelectDirectory;
  final ValueChanged<CloneTransportMode> onCloneTransportChanged;
  final Future<void> Function() onConfigureCommitSigning;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const _SettingsContent({
    required this.pane,
    required this.archiveDaysController,
    required this.cloneTransportMode,
    required this.signingBusy,
    required this.signingStatus,
    required this.onSelectDirectory,
    required this.onCloneTransportChanged,
    required this.onConfigureCommitSigning,
    required this.onThemeModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (pane == _SettingsPane.general) {
      return _GeneralPane(onThemeModeChanged: onThemeModeChanged);
    }
    if (pane == _SettingsPane.workspace) {
      return _WorkspacePane(
        archiveDaysController: archiveDaysController,
        onSelectDirectory: onSelectDirectory,
      );
    }
    if (pane == _SettingsPane.tools) {
      return _ToolsPane(
        cloneTransportMode: cloneTransportMode,
        signingBusy: signingBusy,
        signingStatus: signingStatus,
        onCloneTransportChanged: onCloneTransportChanged,
        onConfigureCommitSigning: onConfigureCommitSigning,
      );
    }
    return const _DiagnosticsPane();
  }
}

class _GeneralPane extends StatelessWidget {
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const _GeneralPane({
    required this.onThemeModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    bool launchAtStartupEnabled =
        boxSettings.get('autolaunch', defaultValue: true);
    bool updateOnLaunch = boxSettings.get('achup', defaultValue: true);
    bool hideOnBlur = boxSettings.get(
      'hide_on_blur',
      defaultValue: DesktopPlatformAdapter.instance.isMacOS,
    );
    bool startHidden = boxSettings.get(
      'start_hidden',
      defaultValue: DesktopPlatformAdapter.instance.isMacOS,
    );
    ThemeMode themeMode = loadAlembicThemeMode();

    return AlembicPanel(
      child: m.ListView(
        children: <Widget>[
          const AlembicSectionHeader(
            title: 'General',
            subtitle: 'Global startup, tray behavior, and appearance.',
          ),
          const Gap(AlembicShadcnTokens.gapLg),
          _SettingsToggleRow(
            title: 'Launch at startup',
            description: 'Add or remove Alembic from desktop startup.',
            value: launchAtStartupEnabled,
            onChanged: (bool value) {
              boxSettings.put('autolaunch', value);
              if (value) {
                launchAtStartup.enable();
              } else {
                launchAtStartup.disable();
              }
              (context as Element).markNeedsBuild();
            },
          ),
          const Divider(),
          _SettingsToggleRow(
            title: 'Check for updates on launch',
            description: 'Allow Alembic to check release metadata on startup.',
            value: updateOnLaunch,
            onChanged: (bool value) {
              boxSettings.put('achup', value);
              (context as Element).markNeedsBuild();
            },
          ),
          const Divider(),
          _SettingsToggleRow(
            title: 'Hide window on blur',
            description: 'Dismiss the desktop shell when focus leaves the app.',
            value: hideOnBlur,
            onChanged: (bool value) async {
              await WindowUtil.setHideOnBlur(value);
              (context as Element).markNeedsBuild();
            },
          ),
          const Divider(),
          _SettingsToggleRow(
            title: 'Start hidden in tray',
            description: 'Launch Alembic hidden until the tray icon is used.',
            value: startHidden,
            onChanged: (bool value) async {
              await WindowUtil.setStartHidden(value);
              (context as Element).markNeedsBuild();
            },
          ),
          const Divider(),
          _SettingsMenuRow<ThemeMode>(
            title: 'Theme mode',
            description: 'Choose the desktop appearance mode.',
            valueLabel: switch (themeMode) {
              ThemeMode.system => 'System',
              ThemeMode.light => 'Light',
              ThemeMode.dark => 'Dark',
            },
            items: ThemeMode.values,
            itemLabel: (ThemeMode mode) => switch (mode) {
              ThemeMode.system => 'System',
              ThemeMode.light => 'Light',
              ThemeMode.dark => 'Dark',
            },
            onSelected: onThemeModeChanged,
          ),
          const Divider(),
          _SettingsInfoRow(
            title: 'Desktop platform',
            description:
                'Alembic adapts file explorer, updater, and launch flows by platform.',
            value: DesktopPlatformAdapter.instance.currentPlatform.name,
          ),
        ],
      ),
    );
  }
}

class _WorkspacePane extends StatelessWidget {
  final m.TextEditingController archiveDaysController;
  final Future<void> Function({
    required String initialDirectory,
    required String dialogTitle,
    required ValueChanged<String> onSelected,
  }) onSelectDirectory;

  const _WorkspacePane({
    required this.archiveDaysController,
    required this.onSelectDirectory,
  });

  @override
  Widget build(BuildContext context) {
    return AlembicPanel(
      child: m.ListView(
        children: <Widget>[
          const AlembicSectionHeader(
            title: 'Workspace',
            subtitle: 'Repository storage paths and archive cadence.',
          ),
          const Gap(AlembicShadcnTokens.gapLg),
          _SettingsActionRow(
            title: 'Workspace directory',
            description: 'Base directory used for active repositories.',
            value: config.workspaceDirectory,
            actionLabel: 'Change',
            onPressed: () => onSelectDirectory(
              initialDirectory: expandPath(config.workspaceDirectory),
              dialogTitle: 'Select Workspace Directory',
              onSelected: (String path) {
                setConfig(config..workspaceDirectory = path);
                (context as Element).markNeedsBuild();
              },
            ),
          ),
          const Divider(),
          _SettingsActionRow(
            title: 'Archive directory',
            description: 'Where Alembic stores archived repositories.',
            value: config.archiveDirectory,
            actionLabel: 'Change',
            onPressed: () => onSelectDirectory(
              initialDirectory: expandPath(config.archiveDirectory),
              dialogTitle: 'Select Archive Directory',
              onSelected: (String path) {
                setConfig(config..archiveDirectory = path);
                (context as Element).markNeedsBuild();
              },
            ),
          ),
          const Divider(),
          AlembicLabeledField(
            label: 'Archive duration (days)',
            supportingText:
                'Automatically archive active repositories after this many inactive days.',
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: AlembicTextInput(
                controller: archiveDaysController,
                placeholder: '30',
                keyboardType: m.TextInputType.number,
                maxLength: 4,
                onChanged: (String value) {
                  int? days = int.tryParse(value);
                  setConfig(
                    config..daysToArchive = (days ?? 30).clamp(1, 3650),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolsPane extends StatelessWidget {
  final CloneTransportMode cloneTransportMode;
  final bool signingBusy;
  final GitSigningStatus? signingStatus;
  final ValueChanged<CloneTransportMode> onCloneTransportChanged;
  final Future<void> Function() onConfigureCommitSigning;

  const _ToolsPane({
    required this.cloneTransportMode,
    required this.signingBusy,
    required this.signingStatus,
    required this.onCloneTransportChanged,
    required this.onConfigureCommitSigning,
  });

  @override
  Widget build(BuildContext context) {
    String commitSigningLabel = signingBusy
        ? 'Configuring...'
        : (signingStatus?.label ?? 'Checking...');

    return AlembicPanel(
      child: m.ListView(
        children: <Widget>[
          const AlembicSectionHeader(
            title: 'Tools',
            subtitle: 'Editor launchers, Git clients, and signing defaults.',
          ),
          const Gap(AlembicShadcnTokens.gapLg),
          _SettingsMenuRow<ApplicationTool>(
            title: 'Editor tool',
            description: 'Default editor for opening repositories.',
            valueLabel:
                (config.editorTool ?? ApplicationTool.intellij).displayName,
            items: XApplicationTool.supportedTools,
            itemLabel: (ApplicationTool tool) => tool.displayName,
            onSelected: (ApplicationTool tool) {
              setConfig(config..editorTool = tool);
              (context as Element).markNeedsBuild();
            },
          ),
          const Divider(),
          _SettingsMenuRow<GitTool>(
            title: 'Git tool',
            description: 'Default Git client for repository launch actions.',
            valueLabel: (config.gitTool ?? GitTool.gitkraken).displayName,
            items: XGitTool.supportedTools,
            itemLabel: (GitTool tool) => tool.displayName,
            onSelected: (GitTool tool) {
              setConfig(config..gitTool = tool);
              (context as Element).markNeedsBuild();
            },
          ),
          const Divider(),
          _SettingsMenuRow<CloneTransportMode>(
            title: 'Clone transport',
            description:
                'Preferred transport when Alembic clones repositories.',
            valueLabel: cloneTransportMode.label,
            items: CloneTransportMode.values,
            itemLabel: (CloneTransportMode mode) => mode.label,
            onSelected: onCloneTransportChanged,
          ),
          const Divider(),
          _SettingsActionRow(
            title: 'Commit signing',
            description: 'Configure global intrinsic SSH commit signing.',
            value: commitSigningLabel,
            actionLabel: signingBusy ? 'Working...' : 'Configure',
            onPressed: signingBusy ? null : onConfigureCommitSigning,
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsPane extends StatelessWidget {
  const _DiagnosticsPane();

  @override
  Widget build(BuildContext context) {
    DesktopPlatformAdapter adapter = DesktopPlatformAdapter.instance;
    return AlembicPanel(
      child: m.ListView(
        children: <Widget>[
          const AlembicSectionHeader(
            title: 'Diagnostics',
            subtitle: 'Inspect config storage and runtime files.',
          ),
          const Gap(AlembicShadcnTokens.gapLg),
          _SettingsActionRow(
            title: 'Config path',
            description: 'Open the Alembic local configuration directory.',
            value: configPath,
            actionLabel: 'Open',
            onPressed: () => adapter.openInFileExplorer(configPath),
          ),
          const Divider(),
          _SettingsActionRow(
            title: 'Log file',
            description: 'Open the current Alembic log file.',
            value: '$configPath/alembic.log',
            actionLabel: 'Open',
            onPressed: () => adapter.openPath('$configPath/alembic.log'),
          ),
        ],
      ),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleRow({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).typography.small.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Gap(4),
              Text(
                description,
                style: Theme.of(context).typography.xSmall.copyWith(
                      color: Theme.of(context).colorScheme.mutedForeground,
                    ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  final String title;
  final String description;
  final String value;
  final String actionLabel;
  final VoidCallback? onPressed;

  const _SettingsActionRow({
    required this.title,
    required this.description,
    required this.value,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).typography.small.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Gap(4),
              Text(
                description,
                style: Theme.of(context).typography.xSmall.copyWith(
                      color: Theme.of(context).colorScheme.mutedForeground,
                    ),
              ),
              const Gap(8),
              Text(
                value,
                style: Theme.of(context).typography.small,
              ),
            ],
          ),
        ),
        const Gap(12),
        AlembicToolbarButton(
          onPressed: onPressed,
          label: actionLabel,
        ),
      ],
    );
  }
}

class _SettingsMenuRow<T> extends StatelessWidget {
  final String title;
  final String description;
  final String valueLabel;
  final List<T> items;
  final ValueChanged<T> onSelected;
  final String Function(T item) itemLabel;

  const _SettingsMenuRow({
    required this.title,
    required this.description,
    required this.valueLabel,
    required this.items,
    required this.onSelected,
    required this.itemLabel,
  });

  @override
  Widget build(BuildContext context) {
    List<AlembicDropdownOption<T>> options = <AlembicDropdownOption<T>>[
      for (T item in items)
        AlembicDropdownOption<T>(
          value: item,
          label: itemLabel(item),
        ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).typography.small.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Gap(4),
              Text(
                description,
                style: Theme.of(context).typography.xSmall.copyWith(
                      color: Theme.of(context).colorScheme.mutedForeground,
                    ),
              ),
            ],
          ),
        ),
        const Gap(12),
        AlembicSelect<T>(
          value: items.firstWhere((T item) => itemLabel(item) == valueLabel),
          options: options,
          onChanged: onSelected,
        ),
      ],
    );
  }
}

class _SettingsInfoRow extends StatelessWidget {
  final String title;
  final String description;
  final String value;

  const _SettingsInfoRow({
    required this.title,
    required this.description,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).typography.small.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Gap(4),
              Text(
                description,
                style: Theme.of(context).typography.xSmall.copyWith(
                      color: Theme.of(context).colorScheme.mutedForeground,
                    ),
              ),
            ],
          ),
        ),
        const Gap(12),
        Text(
          value,
          style: Theme.of(context).typography.small.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
