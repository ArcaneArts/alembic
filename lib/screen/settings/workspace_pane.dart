import 'package:alembic/main.dart';
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
      onSelected: (String path) {
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
      onSelected: (String path) {
        setConfig(config..archiveDirectory = path);
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  void _updateArchiveDuration(String value) {
    int? days = int.tryParse(value);
    setConfig(config..daysToArchive = (days ?? 30).clamp(1, 3650));
  }

  @override
  Widget build(BuildContext context) {
    return AlembicSettingsPane(
      title: 'Workspace',
      subtitle: 'Repository storage paths and archive cadence.',
      children: <Widget>[
        AlembicSettingsActionRow(
          title: 'Workspace directory',
          description: 'Base directory used for active repositories.',
          value: config.workspaceDirectory,
          actionLabel: 'Change',
          onPressed: _pickWorkspaceDirectory,
        ),
        AlembicSettingsActionRow(
          title: 'Archive directory',
          description: 'Where Alembic stores archived repositories.',
          value: config.archiveDirectory,
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
      ],
    );
  }
}
