import 'package:alembic/core/arcane_repository.dart';
import 'package:alembic/core/repository_actions_controller.dart';
import 'package:alembic/core/repository_runtime.dart';
import 'package:alembic/screen/home/home_controller.dart';
import 'package:alembic/screen/home/home_view_filters.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

class HomeSidebarPanel extends StatelessWidget {
  static const int maxVisibleWorkEntries = 5;

  final RepositoryRuntime runtime;
  final RepositoryActionsController actionsController;
  final List<HomeRepositoryEntry> entries;
  final bool archiveEnabled;

  const HomeSidebarPanel({
    super.key,
    required this.runtime,
    required this.actionsController,
    required this.entries,
    required this.archiveEnabled,
  });

  int get _archiveDueSoonCount => entries
      .where((entry) =>
          entry.repoState == RepoState.active &&
          entry.daysUntilArchive <= HomeController.archiveDueSoonDays)
      .length;

  int get _activeCount =>
      entries.where((entry) => entry.repoState == RepoState.active).length;

  int get _cloudCount =>
      entries.where((entry) => entry.repoState == RepoState.cloud).length;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return AlembicPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _CloneFromUrlSection(actionsController: actionsController),
          const Gap(AlembicShadcnTokens.gapLg),
          m.Divider(
            height: 1,
            thickness: 1,
            color: theme.colorScheme.border,
          ),
          const Gap(AlembicShadcnTokens.gapLg),
          _ActivitySection(
            runtime: runtime,
            archiveEnabled: archiveEnabled,
            archiveDueSoonCount: _archiveDueSoonCount,
            activeCount: _activeCount,
            cloudCount: _cloudCount,
          ),
        ],
      ),
    );
  }
}

class HomeActivityStrip extends StatelessWidget {
  final RepositoryRuntime runtime;

  const HomeActivityStrip({
    super.key,
    required this.runtime,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return StreamBuilder<List<RepositoryWork>>(
      stream: runtime.repoWork.stream,
      initialData: runtime.repoWork.valueOrNull ?? const <RepositoryWork>[],
      builder: (context, snapshot) {
        List<RepositoryWork> work = snapshot.data ?? const <RepositoryWork>[];
        if (work.isEmpty) {
          return const SizedBox.shrink();
        }
        RepositoryWork first = work.first;
        return Padding(
          padding: const EdgeInsets.only(bottom: AlembicShadcnTokens.gapSm),
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(
              horizontal: AlembicShadcnTokens.gapMd,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.card,
              borderRadius:
                  BorderRadius.circular(AlembicShadcnTokens.controlRadius),
              border: Border.all(color: theme.colorScheme.border),
            ),
            child: Row(
              children: <Widget>[
                AlembicProgressMark(value: first.progress, size: 12),
                const Gap(AlembicShadcnTokens.gapSm),
                Text(
                  'Activity: ${work.length} task${work.length == 1 ? '' : 's'} running',
                  style: theme.typography.xSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(AlembicShadcnTokens.gapSm),
                Expanded(
                  child: Text(
                    '${first.repository.fullName} · ${first.message}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.xSmall.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CloneFromUrlSection extends StatefulWidget {
  final RepositoryActionsController actionsController;

  const _CloneFromUrlSection({
    required this.actionsController,
  });

  @override
  State<_CloneFromUrlSection> createState() => _CloneFromUrlSectionState();
}

class _CloneFromUrlSectionState extends State<_CloneFromUrlSection> {
  late final m.TextEditingController _urlController;
  bool _cloning = false;
  String? _errorMessage;
  bool _cloneSucceeded = false;

  @override
  void initState() {
    super.initState();
    _urlController = m.TextEditingController();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _clone() async {
    String url = _urlController.text.trim();
    if (url.isEmpty || _cloning) {
      return;
    }
    setState(() {
      _cloning = true;
      _errorMessage = null;
      _cloneSucceeded = false;
    });
    WorkspaceOperationResult result =
        await widget.actionsController.cloneFromUrl(url);
    if (!mounted) {
      return;
    }
    setState(() {
      _cloning = false;
      if (result.ok) {
        _cloneSucceeded = true;
        _urlController.clear();
      } else {
        _errorMessage = result.error ?? 'Clone failed.';
      }
    });
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const AlembicSectionHeader(title: 'Clone from URL'),
          const Gap(AlembicShadcnTokens.gapSm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: _CloneUrlField(
                  controller: _urlController,
                  enabled: !_cloning,
                  onSubmitted: _clone,
                ),
              ),
              const Gap(AlembicShadcnTokens.gapSm),
              AlembicToolbarButton(
                label: 'Clone',
                leadingIcon: m.Icons.add_link,
                iconOnly: true,
                busy: _cloning,
                tooltip: 'Clone to workspace',
                onPressed: _cloning ? null : _clone,
              ),
            ],
          ),
          _CloneStatusLine(
            cloning: _cloning,
            errorMessage: _errorMessage,
            succeeded: _cloneSucceeded,
          ),
        ],
      );
}

class _CloneStatusLine extends StatelessWidget {
  static const m.Color successColor = m.Color(0xFF16A34A);

  final bool cloning;
  final String? errorMessage;
  final bool succeeded;

  const _CloneStatusLine({
    required this.cloning,
    required this.errorMessage,
    required this.succeeded,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    if (cloning) {
      return Padding(
        padding: const EdgeInsets.only(top: AlembicShadcnTokens.gapSm),
        child: Row(
          children: <Widget>[
            const AlembicProgressMark(size: 11),
            const Gap(AlembicShadcnTokens.gapXs),
            Expanded(
              child: Text(
                'Cloning repository...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.xSmall.copyWith(
                  color: theme.colorScheme.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.only(top: AlembicShadcnTokens.gapSm),
        child: Text(
          errorMessage!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.xSmall.copyWith(
            color: theme.colorScheme.destructive,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    if (succeeded) {
      return Padding(
        padding: const EdgeInsets.only(top: AlembicShadcnTokens.gapSm),
        child: Text(
          'Cloned successfully',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.xSmall.copyWith(
            color: successColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _CloneUrlField extends StatelessWidget {
  final m.TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmitted;

  const _CloneUrlField({
    required this.controller,
    required this.enabled,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    m.OutlineInputBorder border = m.OutlineInputBorder(
      borderRadius: m.BorderRadius.circular(AlembicShadcnTokens.controlRadius),
      borderSide: m.BorderSide(color: theme.colorScheme.border),
      gapPadding: 0,
    );
    m.OutlineInputBorder activeBorder = m.OutlineInputBorder(
      borderRadius: m.BorderRadius.circular(AlembicShadcnTokens.controlRadius),
      borderSide: m.BorderSide(color: theme.colorScheme.ring),
      gapPadding: 0,
    );
    m.TextStyle monoStyle = theme.typography.mono.copyWith(
      fontSize: 12,
      color: enabled
          ? theme.colorScheme.foreground
          : theme.colorScheme.mutedForeground,
    );
    return SizedBox(
      height: AlembicShadcnTokens.controlHeight,
      child: m.TextField(
        controller: controller,
        enabled: enabled,
        maxLines: 1,
        onSubmitted: (_) => onSubmitted(),
        style: monoStyle,
        cursorColor: theme.colorScheme.foreground,
        textAlignVertical: m.TextAlignVertical.center,
        textInputAction: m.TextInputAction.done,
        decoration: m.InputDecoration(
          hintText: 'https://github.com/owner/repo.git',
          hintStyle: theme.typography.mono.copyWith(
            fontSize: 12,
            color: theme.colorScheme.mutedForeground,
          ),
          filled: true,
          fillColor: enabled ? theme.colorScheme.card : theme.colorScheme.muted,
          isDense: true,
          contentPadding: const m.EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: activeBorder,
          disabledBorder: border,
          errorBorder: border,
          focusedErrorBorder: activeBorder,
        ),
      ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  final RepositoryRuntime runtime;
  final bool archiveEnabled;
  final int archiveDueSoonCount;
  final int activeCount;
  final int cloudCount;

  const _ActivitySection({
    required this.runtime,
    required this.archiveEnabled,
    required this.archiveDueSoonCount,
    required this.activeCount,
    required this.cloudCount,
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<List<RepositoryWork>>(
        stream: runtime.repoWork.stream,
        initialData: runtime.repoWork.valueOrNull ?? const <RepositoryWork>[],
        builder: (context, snapshot) {
          List<RepositoryWork> work = snapshot.data ?? const <RepositoryWork>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AlembicSectionHeader(
                title: 'Activity',
                subtitle: work.isEmpty
                    ? 'Idle'
                    : '${work.length} task${work.length == 1 ? '' : 's'} running',
              ),
              const Gap(AlembicShadcnTokens.gapMd),
              if (work.isEmpty)
                _IdleSummary(
                  archiveEnabled: archiveEnabled,
                  archiveDueSoonCount: archiveDueSoonCount,
                  activeCount: activeCount,
                  cloudCount: cloudCount,
                )
              else
                _WorkList(work: work),
            ],
          );
        },
      );
}

class _IdleSummary extends StatelessWidget {
  final bool archiveEnabled;
  final int archiveDueSoonCount;
  final int activeCount;
  final int cloudCount;

  const _IdleSummary({
    required this.archiveEnabled,
    required this.archiveDueSoonCount,
    required this.activeCount,
    required this.cloudCount,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _SummaryRow(
          icon: m.Icons.archive_outlined,
          label: 'Archive',
          value: archiveEnabled ? '$archiveDueSoonCount' : 'Off',
          detail: archiveEnabled ? 'due soon' : 'disabled',
          color: archiveEnabled && archiveDueSoonCount > 0
              ? const m.Color(0xFFE8930C)
              : theme.colorScheme.mutedForeground,
        ),
        const Gap(AlembicShadcnTokens.gapSm),
        _SummaryRow(
          icon: m.Icons.folder_open,
          label: 'Local',
          value: '$activeCount',
          detail: 'ready to open',
          color: const m.Color(0xFF16A34A),
        ),
        const Gap(AlembicShadcnTokens.gapSm),
        _SummaryRow(
          icon: m.Icons.cloud_outlined,
          label: 'Cloud',
          value: '$cloudCount',
          detail: 'not cloned',
          color: theme.colorScheme.mutedForeground,
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color color;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        m.Icon(icon, size: 14, color: color),
        const Gap(AlembicShadcnTokens.gapSm),
        Expanded(
          child: Text(
            label,
            style: theme.typography.small.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: theme.typography.small.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        const Gap(AlembicShadcnTokens.gapXs),
        Text(
          detail,
          style: theme.typography.xSmall.copyWith(
            color: theme.colorScheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _WorkList extends StatelessWidget {
  final List<RepositoryWork> work;

  const _WorkList({required this.work});

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    List<RepositoryWork> visible =
        work.take(HomeSidebarPanel.maxVisibleWorkEntries).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (RepositoryWork item in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: AlembicShadcnTokens.gapSm),
            child: Row(
              children: <Widget>[
                AlembicProgressMark(value: item.progress, size: 12),
                const Gap(AlembicShadcnTokens.gapSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.repository.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.xSmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        item.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.xSmall.copyWith(
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (work.length > visible.length)
          Text(
            '+${work.length - visible.length} more',
            style: theme.typography.xSmall.copyWith(
              color: theme.colorScheme.mutedForeground,
            ),
          ),
      ],
    );
  }
}
