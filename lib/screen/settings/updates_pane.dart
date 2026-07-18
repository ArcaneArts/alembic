import 'dart:async';

import 'package:alembic/core/update_status.dart';
import 'package:alembic/main.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;
import 'package:url_launcher/url_launcher.dart';

class UpdatesSettingsPane extends StatelessWidget {
  const UpdatesSettingsPane({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<UpdateSnapshot>(
        stream: updateController.stream,
        initialData: updateController.value,
        builder: (context, snapshot) => _UpdatesPaneContent(
          snapshot: snapshot.data ?? updateController.value,
        ),
      );
}

class _UpdatesPaneContent extends StatelessWidget {
  final UpdateSnapshot snapshot;

  const _UpdatesPaneContent({
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) => AlembicSettingsPane(
        title: 'Updates',
        subtitle:
            'Alembic never interrupts you about updates. When one is available, an amber dot appears on this tab and nothing else happens until you act.',
        children: <Widget>[
          _UpdateStatusCard(snapshot: snapshot),
          AlembicSettingsToggleRow(
            title: 'Automatic update checks',
            description:
                'Check release metadata once shortly after launch. Never interrupts your work.',
            value: snapshot.autoCheckEnabled,
            onChanged: (value) =>
                unawaited(updateController.setAutoCheck(value)),
          ),
        ],
      );
}

class _UpdateStatusCard extends StatelessWidget {
  static const m.Color _amber = m.Color(0xFFF0A32E);
  static const m.Color _green = m.Color(0xFF4C9E5F);

  final UpdateSnapshot snapshot;

  const _UpdateStatusCard({
    required this.snapshot,
  });

  IconData _iconFor() => switch (snapshot.status) {
        UpdateStatus.updateAvailable ||
        UpdateStatus.downloading =>
          m.Icons.circle,
        UpdateStatus.checking => m.Icons.sync,
        UpdateStatus.error => m.Icons.warning_amber_rounded,
        UpdateStatus.upToDate => m.Icons.check_circle_outline,
        UpdateStatus.idle => m.Icons.info_outline,
      };

  m.Color _iconColorFor(ThemeData theme) => switch (snapshot.status) {
        UpdateStatus.updateAvailable || UpdateStatus.downloading => _amber,
        UpdateStatus.checking => theme.colorScheme.mutedForeground,
        UpdateStatus.error => theme.colorScheme.destructive,
        UpdateStatus.upToDate => _green,
        UpdateStatus.idle => theme.colorScheme.mutedForeground,
      };

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    String? errorMessage = snapshot.errorMessage;
    return AlembicSurface(
      tone: AlembicSurfaceTone.inset,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: m.Icon(
                  _iconFor(),
                  size: 16,
                  color: _iconColorFor(theme),
                ),
              ),
              const Gap(AlembicShadcnTokens.gapMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      snapshot.statusTitle,
                      style: theme.typography.small.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(AlembicShadcnTokens.gapXs),
                    Text(
                      snapshot.statusDetail,
                      style: theme.typography.xSmall.copyWith(
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                    if (snapshot.status ==
                        UpdateStatus.downloading) ...<Widget>[
                      const Gap(AlembicShadcnTokens.gapSm),
                      AlembicProgressBar(
                        value: snapshot.downloadProgress,
                        height: 4,
                      ),
                    ],
                    if (snapshot.status == UpdateStatus.error &&
                        errorMessage != null) ...<Widget>[
                      const Gap(AlembicShadcnTokens.gapSm),
                      Text(
                        errorMessage,
                        style: theme.typography.xSmall.copyWith(
                          color: theme.colorScheme.destructive,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Gap(AlembicShadcnTokens.gapMd),
          _UpdateActionsRow(snapshot: snapshot),
        ],
      ),
    );
  }
}

class _UpdateActionsRow extends StatelessWidget {
  final UpdateSnapshot snapshot;

  const _UpdateActionsRow({
    required this.snapshot,
  });

  bool get _busy =>
      snapshot.status == UpdateStatus.checking ||
      snapshot.status == UpdateStatus.downloading;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.end,
        spacing: AlembicShadcnTokens.gapSm,
        runSpacing: AlembicShadcnTokens.gapSm,
        children: <Widget>[
          if (snapshot.updateAvailable)
            AlembicToolbarButton(
              label: 'Update Now',
              leadingIcon: m.Icons.system_update_alt,
              prominent: true,
              compact: true,
              busy: snapshot.status == UpdateStatus.downloading,
              onPressed: snapshot.status == UpdateStatus.updateAvailable
                  ? () => unawaited(updateController.install())
                  : null,
            ),
          AlembicToolbarButton(
            label: 'Check Now',
            leadingIcon: m.Icons.refresh,
            compact: true,
            onPressed:
                _busy ? null : () => unawaited(updateController.checkNow()),
          ),
          AlembicToolbarButton(
            label: 'Release page',
            trailingIcon: m.Icons.open_in_new,
            compact: true,
            onPressed: () =>
                unawaited(launchUrl(Uri.parse(snapshot.releaseUrl))),
          ),
        ],
      );
}

extension _UpdateSnapshotPresentation on UpdateSnapshot {
  String get statusTitle => switch (status) {
        UpdateStatus.updateAvailable => 'Update available',
        UpdateStatus.downloading => 'Downloading update...',
        UpdateStatus.checking => 'Checking for updates...',
        UpdateStatus.error => 'Update check failed',
        UpdateStatus.upToDate => 'Up to date',
        UpdateStatus.idle => 'Alembic $currentVersion',
      };

  String get statusDetail => switch (status) {
        UpdateStatus.updateAvailable =>
          _joinDetail('$currentVersion to ${latestVersion ?? 'newer version'}'),
        UpdateStatus.downloading =>
          'Installing ${latestVersion ?? 'update'} - $_progressPercent%',
        UpdateStatus.checking => 'Contacting GitHub...',
        UpdateStatus.error => _joinDetail('Alembic $currentVersion'),
        UpdateStatus.upToDate => _joinDetail('Alembic $currentVersion'),
        UpdateStatus.idle => autoCheckEnabled
            ? 'A check will run shortly after launch.'
            : 'Automatic checks are off. Use Check Now.',
      };

  int get _progressPercent => ((downloadProgress ?? 0) * 100).round();

  String get _lastCheckedLabel {
    int? ms = lastCheckedMs;
    if (ms == null) {
      return '';
    }
    DateTime at = DateTime.fromMillisecondsSinceEpoch(ms);
    String month = at.month.toString().padLeft(2, '0');
    String day = at.day.toString().padLeft(2, '0');
    String hour = at.hour.toString().padLeft(2, '0');
    String minute = at.minute.toString().padLeft(2, '0');
    return 'checked ${at.year}-$month-$day $hour:$minute';
  }

  String _joinDetail(String base) {
    String checked = _lastCheckedLabel;
    if (checked.isEmpty) {
      return base;
    }
    return '$base - $checked';
  }
}
