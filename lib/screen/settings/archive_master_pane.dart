import 'package:alembic/app/alembic_dialogs.dart';
import 'package:alembic/core/archive_master_service.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:alembic/util/archive_master.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

class ArchiveMasterSettingsPane extends StatefulWidget {
  const ArchiveMasterSettingsPane({super.key});

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
        message: 'Archive Master service is not running. Restart Alembic and '
            'try again.',
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

  Future<void> _saveInterval() async {
    int? minutes = int.tryParse(_intervalController.text.trim());
    if (minutes == null || minutes <= 0) {
      await showAlembicInfoDialog(
        context,
        title: 'Invalid Interval',
        message: 'Enter a whole number of minutes greater than zero.',
      );
      return;
    }
    int clamped = minutes.clamp(5, 60 * 24 * 30);
    setConfig(config..archiveMasterIntervalMinutes = clamped);
    archiveMasterService?.rescheduleAfterConfigChange();
    _intervalController.text = '$clamped';
    if (mounted) {
      setState(() {});
    }
  }

  String _trackedSummary() {
    List<ArchiveMasterTarget> targets = loadArchiveMasterTargets();
    int repos = targets
        .where((target) => target.kind == ArchiveMasterTargetKind.repository)
        .length;
    int orgs = targets
        .where((target) => target.kind == ArchiveMasterTargetKind.organization)
        .length;
    return '$repos repos • $orgs orgs';
  }

  @override
  Widget build(BuildContext context) {
    if (!config.archiveEnabled) {
      return const AlembicSettingsPane(
        title: 'Archive Master',
        subtitle:
            'Keep selected repositories or organisations cloned and pulled on a schedule, never archived away.',
        children: <Widget>[
          AlembicSettingsInfoRow(
            title: 'Archive is off',
            description:
                'Enable "Archive repositories" in the Workspace pane to use Archive Master.',
            value: '',
          ),
        ],
      );
    }
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
        AlembicSettingsTextFieldRow(
          title: 'Refresh interval (minutes)',
          description:
              'How often Archive Master should check for new commits and pull them. 60 = hourly, 1440 = daily.',
          child: Row(
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: AlembicTextInput(
                  controller: _intervalController,
                  placeholder: '1440',
                  keyboardType: m.TextInputType.number,
                  maxLength: 6,
                  onSubmitted: (_) => _saveInterval(),
                ),
              ),
              const Gap(AlembicShadcnTokens.gapSm),
              AlembicToolbarButton(
                label: 'Save',
                onPressed: _saveInterval,
                compact: true,
              ),
            ],
          ),
        ),
        AlembicSettingsInfoRow(
          title: 'Repositories tracked',
          description:
              'Add repositories from the Archive Master menu on the home screen.',
          value: _trackedSummary(),
        ),
      ],
    );
  }
}
