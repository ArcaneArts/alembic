import 'package:alembic/app/alembic_dialogs.dart';
import 'package:alembic/core/archive_master_service.dart';
import 'package:alembic/main.dart';
import 'package:alembic/screen/settings/settings_types.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:alembic/util/archive_master.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

class ArchiveMasterSettingsPane extends StatefulWidget {
  final SelectDirectoryCallback onSelectDirectory;

  const ArchiveMasterSettingsPane({
    super.key,
    required this.onSelectDirectory,
  });

  @override
  State<ArchiveMasterSettingsPane> createState() =>
      _ArchiveMasterSettingsPaneState();
}

class _ArchiveMasterSettingsPaneState extends State<ArchiveMasterSettingsPane> {
  late final m.TextEditingController _intervalController;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _intervalController = m.TextEditingController(
      text: '${config.archiveMasterIntervalMinutes}',
    );
  }

  @override
  void dispose() {
    _intervalController.dispose();
    super.dispose();
  }

  Future<void> _refreshNow() async {
    ArchiveMasterService? service = archiveMasterService;
    if (service == null) {
      await showAlembicInfoDialog(
        context,
        title: 'Archive Master Unavailable',
        message:
            'Archive Master service is not running yet. Open the home screen at least once and try again.',
      );
      return;
    }
    setState(() {
      _refreshing = true;
    });
    try {
      await service.runOnce(force: true);
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _pickDirectory() {
    return widget.onSelectDirectory(
      initialDirectory: expandPath(config.archiveMasterDirectory),
      dialogTitle: 'Select Archive Master Directory',
      onSelected: (String path) {
        setConfig(config..archiveMasterDirectory = path);
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  void _updateInterval(String value) {
    int? minutes = int.tryParse(value);
    setConfig(
      config
        ..archiveMasterIntervalMinutes = (minutes ?? 1440).clamp(5, 60 * 24 * 30),
    );
    archiveMasterService?.rescheduleAfterConfigChange();
  }

  String _trackedSummary() {
    List<ArchiveMasterTarget> targets = loadArchiveMasterTargets();
    int repos = targets
        .where((ArchiveMasterTarget target) =>
            target.kind == ArchiveMasterTargetKind.repository)
        .length;
    int orgs = targets
        .where((ArchiveMasterTarget target) =>
            target.kind == ArchiveMasterTargetKind.organization)
        .length;
    return '$repos repos • $orgs orgs';
  }

  @override
  Widget build(BuildContext context) {
    return AlembicSettingsPane(
      title: 'Archive Master',
      subtitle:
          'Keep selected repositories or organisations cloned and pulled on a schedule, never archived away.',
      trailing: AlembicToolbarButton(
        label: _refreshing ? 'Refreshing...' : 'Refresh now',
        leadingIcon: m.Icons.refresh,
        onPressed: _refreshing ? null : _refreshNow,
        prominent: true,
      ),
      children: <Widget>[
        AlembicSettingsActionRow(
          title: 'Archive Master directory',
          description:
              'Where Archive Master stores its always-up-to-date clones.',
          value: config.archiveMasterDirectory,
          actionLabel: 'Change',
          onPressed: _pickDirectory,
        ),
        AlembicSettingsTextFieldRow(
          title: 'Refresh interval (minutes)',
          description:
              'How often Archive Master should check for new commits and pull them. 60 = hourly, 1440 = daily.',
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: AlembicTextInput(
              controller: _intervalController,
              placeholder: '1440',
              keyboardType: m.TextInputType.number,
              maxLength: 6,
              onChanged: _updateInterval,
            ),
          ),
        ),
        AlembicSettingsInfoRow(
          title: 'Repositories tracked',
          description:
              'Add repositories from the Archive tab on the home screen.',
          value: _trackedSummary(),
        ),
      ],
    );
  }
}
