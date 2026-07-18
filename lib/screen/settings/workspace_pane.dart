import 'package:alembic/main.dart';
import 'package:alembic/screen/settings/settings_rows.dart';
import 'package:alembic/screen/settings/settings_types.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

class WorkspaceSettingsPane extends StatefulWidget {
  final m.TextEditingController archiveDaysController;
  final SelectDirectoryCallback onSelectDirectory;

  const WorkspaceSettingsPane({
    super.key,
    required this.archiveDaysController,
    required this.onSelectDirectory,
  });

  @override
  State<WorkspaceSettingsPane> createState() => _WorkspaceSettingsPaneState();
}

class _WorkspaceSettingsPaneState extends State<WorkspaceSettingsPane> {
  Future<void> _pickWorkspaceDirectory() {
    return widget.onSelectDirectory(
      initialDirectory: expandPath(config.workspaceDirectory),
      dialogTitle: 'Select Workspace Directory',
      onSelected: (path) {
        setConfig(config..workspaceDirectory = path);
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Future<void> _pickArchiveDirectory() {
    return widget.onSelectDirectory(
      initialDirectory: expandPath(config.archiveDirectory),
      dialogTitle: 'Select Archive Directory',
      onSelected: (path) {
        setConfig(config..archiveDirectory = path);
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Future<void> _pickArchiveMasterDirectory() {
    return widget.onSelectDirectory(
      initialDirectory: expandPath(config.archiveMasterDirectory),
      dialogTitle: 'Select Archive Master Directory',
      onSelected: (path) {
        setConfig(config..archiveMasterDirectory = path);
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  void _setArchiveEnabled(bool value) {
    setConfig(config..archiveEnabled = value);
    if (mounted) {
      setState(() {});
    }
  }

  void _updateArchiveDuration(String value) {
    int? days = int.tryParse(value);
    setConfig(config..daysToArchive = (days ?? 30).clamp(1, 3650));
  }

  @override
  Widget build(BuildContext context) {
    bool archiveEnabled = config.archiveEnabled;
    return AlembicSettingsPane(
      title: 'Workspace',
      subtitle: 'Repository storage paths and archive cadence.',
      children: <Widget>[
        SettingsPathRow(
          title: 'Workspace directory',
          description: 'Base directory used for active repositories. '
              'Default: ${config.defaultWorkspaceDirectory}',
          path: config.workspaceDirectory,
          actionLabel: 'Change',
          onPressed: _pickWorkspaceDirectory,
        ),
        AlembicSettingsToggleRow(
          title: 'Archive repositories',
          description:
              'Master switch for archiving. When off, Alembic never archives repositories and hides archive controls.',
          value: archiveEnabled,
          onChanged: _setArchiveEnabled,
        ),
        if (archiveEnabled) ...<Widget>[
          SettingsPathRow(
            title: 'Archive directory',
            description: 'Where Alembic stores archived repositories. '
                'Default: ${config.defaultArchiveDirectory}',
            path: config.archiveDirectory,
            actionLabel: 'Change',
            onPressed: _pickArchiveDirectory,
          ),
          AlembicSettingsTextFieldRow(
            title: 'Archive duration (days)',
            description:
                'Automatically archive active repositories after this many inactive days.',
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: AlembicTextInput(
                controller: widget.archiveDaysController,
                placeholder: '30',
                keyboardType: m.TextInputType.number,
                maxLength: 4,
                onChanged: _updateArchiveDuration,
              ),
            ),
          ),
          SettingsPathRow(
            title: 'Archive Master directory',
            description:
                'Where Archive Master keeps its always-up-to-date clones. '
                'Default: ${config.defaultArchiveMasterDirectory}',
            path: config.archiveMasterDirectory,
            actionLabel: 'Change',
            onPressed: _pickArchiveMasterDirectory,
          ),
        ],
      ],
    );
  }
}
