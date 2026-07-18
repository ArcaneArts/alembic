import 'package:alembic/core/arcane_repository.dart';
import 'package:alembic/core/repository_auth.dart';
import 'package:alembic/core/repository_runtime.dart';
import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:alembic/presentation/repository_action_catalog.dart';
import 'package:alembic/presentation/repository_action_model.dart';
import 'package:alembic/screen/home/home_actions.dart';
import 'package:alembic/screen/home/home_view_filters.dart';
import 'package:alembic/screen/home/repository_auth_badge.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:alembic/util/archive_master.dart';
import 'package:alembic/util/git_accounts.dart';
import 'package:alembic/widget/repository_tile_actions.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

typedef HomeEntryCallback = Future<void> Function(HomeRepositoryEntry entry);
typedef HomeEntryActionCallback = Future<void> Function(
  HomeRepositoryEntry entry,
  RepositoryTileAction action,
);

class HomeRepositoryMenu {
  const HomeRepositoryMenu._();

  static List<RepositoryActionModel> modelsFor({
    required RepoState state,
    required bool archiveEnabled,
    required bool canFork,
    required bool enrolled,
    required bool hasMasterClone,
    required String explorerName,
  }) {
    List<RepositoryActionModel> stateActions =
        RepositoryActionCatalog.stateActions(state);
    List<RepositoryActionModel> linkActions =
        RepositoryActionCatalog.linkActions(
      canFork: canFork,
      explorerName: explorerName,
      includeExplorer: state != RepoState.cloud,
    );
    List<RepositoryActionModel> masterActions =
        RepositoryActionCatalog.archiveMasterActions(
      enrolled: enrolled,
      hasMasterClone: hasMasterClone,
      isActive: state == RepoState.active,
    );
    return <RepositoryActionModel>[
      if (state == RepoState.active) ...<RepositoryActionModel>[
        RepositoryActionCatalog.find(stateActions, RepositoryTileAction.pull),
        if (archiveEnabled)
          RepositoryActionCatalog.find(
              stateActions, RepositoryTileAction.archive),
      ],
      if (state == RepoState.archived) ...<RepositoryActionModel>[
        RepositoryActionCatalog.find(
            stateActions, RepositoryTileAction.activate),
        if (archiveEnabled)
          RepositoryActionCatalog.find(
              stateActions, RepositoryTileAction.updateArchive),
      ],
      if (state == RepoState.cloud) ...<RepositoryActionModel>[
        RepositoryActionCatalog.find(stateActions, RepositoryTileAction.clone),
        if (archiveEnabled)
          RepositoryActionCatalog.find(
              stateActions, RepositoryTileAction.archiveFromCloud),
      ],
      RepositoryActionCatalog.find(linkActions, RepositoryTileAction.details),
      if (state != RepoState.cloud)
        RepositoryActionCatalog.find(
            linkActions, RepositoryTileAction.openFinder),
      RepositoryActionCatalog.find(
          linkActions, RepositoryTileAction.changeAuth),
      if (archiveEnabled) ...masterActions,
      RepositoryActionCatalog.find(
          linkActions, RepositoryTileAction.viewGithub),
      RepositoryActionCatalog.find(linkActions, RepositoryTileAction.issues),
      RepositoryActionCatalog.find(
          linkActions, RepositoryTileAction.pullRequests),
      RepositoryActionCatalog.find(linkActions, RepositoryTileAction.newIssue),
      RepositoryActionCatalog.find(
          linkActions, RepositoryTileAction.newPullRequest),
      if (canFork)
        RepositoryActionCatalog.find(linkActions, RepositoryTileAction.fork),
      if (state == RepoState.active)
        RepositoryActionCatalog.find(
            stateActions, RepositoryTileAction.deleteRepository),
      if (state == RepoState.archived)
        RepositoryActionCatalog.find(
            stateActions, RepositoryTileAction.deleteArchive),
    ];
  }

  static List<AlembicDropdownOption<RepositoryTileAction>> dropdownOptions(
    List<RepositoryActionModel> models,
  ) =>
      <AlembicDropdownOption<RepositoryTileAction>>[
        for (RepositoryActionModel model in models)
          AlembicDropdownOption<RepositoryTileAction>(
            value: model.action,
            label: model.label,
            icon: model.icon,
            destructive: model.destructive,
          ),
      ];
}

class HomeRepositoryRow extends StatefulWidget {
  final HomeRepositoryEntry entry;
  final RepositoryRuntime runtime;
  final int revision;
  final bool archiveEnabled;
  final GitAccount? account;
  final bool canFork;
  final bool selectable;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;
  final HomeEntryCallback onPrimaryAction;
  final HomeEntryActionCallback onAction;
  final HomeEntryCallback onShowDetails;

  const HomeRepositoryRow({
    super.key,
    required this.entry,
    required this.runtime,
    required this.revision,
    required this.archiveEnabled,
    required this.account,
    required this.canFork,
    required this.onPrimaryAction,
    required this.onAction,
    required this.onShowDetails,
    this.selectable = false,
    this.selected = false,
    this.onSelectedChanged,
  });

  @override
  State<HomeRepositoryRow> createState() => _HomeRepositoryRowState();
}

class _HomeRepositoryRowState extends State<HomeRepositoryRow> {
  static const RepositoryAuthInspector _authInspector =
      RepositoryAuthInspector();

  late Stream<List<RepositoryWork>> _workStream;
  late Future<RepoAuthInfo> _authInfo;
  late bool _hasMasterClone;

  @override
  void initState() {
    super.initState();
    _configureRepository();
  }

  @override
  void didUpdateWidget(covariant HomeRepositoryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.fullName != widget.entry.fullName ||
        oldWidget.runtime != widget.runtime ||
        oldWidget.revision != widget.revision) {
      _configureRepository();
    }
  }

  void _configureRepository() {
    ArcaneRepository arcaneRepository = _arcaneRepository();
    _workStream = widget.runtime.streamWorkEntries(widget.entry.repository);
    _authInfo = _authInspector.read(arcaneRepository);
    _hasMasterClone = arcaneRepository.isArchiveMasterSync;
  }

  ArcaneRepository _arcaneRepository() => ArcaneRepository(
        repository: widget.entry.repository,
        runtime: widget.runtime,
        accountId: widget.account?.id,
      );

  bool get _enrolled => isArchiveMasterRepository(
        widget.entry.repository.owner?.login ?? '',
        widget.entry.repository.name,
      );

  List<RepositoryActionModel> get _menuModels => HomeRepositoryMenu.modelsFor(
        state: widget.entry.repoState,
        archiveEnabled: widget.archiveEnabled,
        canFork: widget.canFork,
        enrolled: _enrolled,
        hasMasterClone: _hasMasterClone,
        explorerName: DesktopPlatformAdapter.instance.fileExplorerName,
      );

  void _onAuthBadgePressed() {
    widget.onAction(widget.entry, RepositoryTileAction.changeAuth);
  }

  String _primaryActionLabel(List<RepositoryWork> work) {
    RepositoryWork? cloneWork = _cloneWork(work);
    if (cloneWork != null) {
      return cloneWork.progress == null
          ? 'Cloning'
          : '${(cloneWork.progress! * 100).round()}%';
    }
    if (work.isNotEmpty) {
      return work.first.message;
    }
    return widget.entry.repoState.primaryActionLabel;
  }

  RepositoryWork? _primaryWork(List<RepositoryWork> work) {
    RepositoryWork? cloneWork = _cloneWork(work);
    if (cloneWork != null) {
      return cloneWork;
    }
    return work.isEmpty ? null : work.first;
  }

  RepositoryWork? _cloneWork(List<RepositoryWork> work) {
    for (RepositoryWork item in work) {
      if (item.kind == RepositoryWorkKind.clone) {
        return item;
      }
    }
    return null;
  }

  List<MenuItem> _contextMenuItems(List<RepositoryActionModel> models) {
    List<RepositoryActionModel> masterModels = models
        .where((model) => _archiveMasterActions.contains(model.action))
        .toList();
    List<RepositoryActionModel> destructiveModels = models
        .where((model) =>
            model.destructive && !_archiveMasterActions.contains(model.action))
        .toList();
    List<RepositoryActionModel> plainModels = models
        .where((model) =>
            !model.destructive && !_archiveMasterActions.contains(model.action))
        .toList();
    return <MenuItem>[
      MenuButton(
        leading: Icon(widget.entry.repoState.primaryActionIcon, size: 14),
        onPressed: () => widget.onPrimaryAction(widget.entry),
        child: Text(widget.entry.repoState.primaryActionLabel),
      ),
      const MenuDivider(),
      for (RepositoryActionModel model in plainModels)
        MenuButton(
          leading: Icon(model.icon, size: 14),
          onPressed: () => widget.onAction(widget.entry, model.action),
          child: Text(model.label),
        ),
      if (masterModels.isNotEmpty)
        MenuButton(
          leading: const Icon(m.Icons.cloud_sync_outlined, size: 14),
          subMenu: <MenuItem>[
            for (RepositoryActionModel model in masterModels)
              MenuButton(
                leading: Icon(model.icon, size: 14),
                onPressed: () => widget.onAction(widget.entry, model.action),
                child: Text(model.label),
              ),
          ],
          child: const Text('Archive Master'),
        ),
      if (destructiveModels.isNotEmpty) ...<MenuItem>[
        const MenuDivider(),
        for (RepositoryActionModel model in destructiveModels)
          MenuButton(
            leading: Icon(model.icon, size: 14),
            onPressed: () => widget.onAction(widget.entry, model.action),
            child: Text(model.label),
          ),
      ],
    ];
  }

  static const Set<RepositoryTileAction> _archiveMasterActions =
      <RepositoryTileAction>{
    RepositoryTileAction.enrollArchiveMaster,
    RepositoryTileAction.refreshArchiveMaster,
    RepositoryTileAction.promoteArchiveMaster,
    RepositoryTileAction.unenrollArchiveMaster,
  };

  @override
  Widget build(BuildContext context) {
    List<RepositoryActionModel> models = _menuModels;
    return ContextMenu(
      items: _contextMenuItems(models),
      child: GestureDetector(
        onDoubleTap: () => widget.onShowDetails(widget.entry),
        child: StreamBuilder<List<RepositoryWork>>(
          stream: _workStream,
          initialData: const <RepositoryWork>[],
          builder: (context, workSnapshot) {
            List<RepositoryWork> work =
                workSnapshot.data ?? const <RepositoryWork>[];
            bool busy = work.isNotEmpty;
            return _RepositoryRowSurface(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  if (widget.selectable) ...<Widget>[
                    SizedBox.square(
                      dimension: 20,
                      child: AlembicSelectionToggle(
                        selected: widget.selected,
                        onChanged: widget.onSelectedChanged,
                        label: widget.selected
                            ? 'Deselect ${widget.entry.fullName}'
                            : 'Select ${widget.entry.fullName}',
                      ),
                    ),
                    const Gap(AlembicShadcnTokens.gapMd),
                  ],
                  Expanded(
                    child: _RepositoryRowCopy(
                      title: widget.entry.repository.name,
                      subtitle: widget.entry.fullName,
                      description:
                          widget.entry.dto.description.cleanedDescription,
                      meta: <Widget>[
                        RepoStateBadge(
                          state: widget.entry.repoState,
                          syncing: widget.entry.syncing,
                        ),
                        AlembicMetaText(
                          label:
                              widget.entry.dto.isPrivate ? 'Private' : 'Public',
                        ),
                        if (widget.archiveEnabled &&
                            widget.entry.repoState == RepoState.active &&
                            widget.entry.daysUntilArchive <= 30)
                          ArchiveCountdownBadge(
                            days: widget.entry.daysUntilArchive,
                          ),
                        if (widget.entry.dto.isArchived)
                          const AlembicBadge(
                            label: 'GitHub archived',
                            tone: AlembicBadgeTone.outline,
                          ),
                        RepositoryAuthBadgeLoader(
                          future: _authInfo,
                          onTap: _onAuthBadgePressed,
                        ),
                        if (_enrolled) const ArchiveMasterBadge(),
                        if (_primaryWork(work) != null)
                          RepositoryWorkBadge(work: _primaryWork(work)!),
                      ],
                    ),
                  ),
                  const Gap(AlembicShadcnTokens.gapLg),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: AlembicToolbarButton(
                          label: _primaryActionLabel(work),
                          leadingIcon: busy
                              ? null
                              : widget.entry.repoState.primaryActionIcon,
                          busy: busy,
                          compact: true,
                          onPressed: busy
                              ? null
                              : () => widget.onPrimaryAction(widget.entry),
                          prominent: true,
                        ),
                      ),
                      const Gap(6),
                      AlembicOverflowMenu<RepositoryTileAction>(
                        label: 'Repository options',
                        items: HomeRepositoryMenu.dropdownOptions(models),
                        onSelected: (action) =>
                            widget.onAction(widget.entry, action),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RepositoryRowSurface extends StatefulWidget {
  final Widget child;

  const _RepositoryRowSurface({
    required this.child,
  });

  @override
  State<_RepositoryRowSurface> createState() => _RepositoryRowSurfaceState();
}

class _RepositoryRowSurfaceState extends State<_RepositoryRowSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color fill = _hovered
        ? m.Color.alphaBlend(
            theme.colorScheme.secondary.withValues(alpha: 0.35),
            theme.colorScheme.card,
          )
        : theme.colorScheme.card;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AlembicShadcnTokens.gapLg,
          vertical: AlembicShadcnTokens.gapLg,
        ),
        decoration: BoxDecoration(
          color: fill,
          borderRadius:
              BorderRadius.circular(AlembicShadcnTokens.surfaceRadius),
          border: Border.all(color: theme.colorScheme.border),
        ),
        child: widget.child,
      ),
    );
  }
}

class _RepositoryRowCopy extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? description;
  final List<Widget> meta;

  const _RepositoryRowCopy({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.small.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Gap(2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.xSmall.copyWith(
            color: theme.colorScheme.mutedForeground,
          ),
        ),
        const Gap(AlembicShadcnTokens.gapXs),
        SizedBox(
          height: AlembicShadcnTokens.listDescriptionLineHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              description ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.xSmall.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          ),
        ),
        const Gap(6),
        Wrap(
          spacing: AlembicShadcnTokens.gapSm,
          runSpacing: AlembicShadcnTokens.gapXs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: meta,
        ),
      ],
    );
  }
}

class RepoStateBadge extends StatelessWidget {
  final RepoState state;
  final bool syncing;

  const RepoStateBadge({
    super.key,
    required this.state,
    this.syncing = false,
  });

  @override
  Widget build(BuildContext context) {
    if (syncing) {
      return const AlembicBadge(
        label: 'Syncing',
        tone: AlembicBadgeTone.primary,
      );
    }
    AlembicBadgeTone tone = switch (state) {
      RepoState.active => AlembicBadgeTone.secondary,
      RepoState.archived => AlembicBadgeTone.outline,
      RepoState.cloud => AlembicBadgeTone.outline,
    };
    return AlembicBadge(label: state.label, tone: tone);
  }
}

class ArchiveCountdownBadge extends StatelessWidget {
  static const m.Color urgentColor = m.Color(0xFFE8930C);

  final int days;

  const ArchiveCountdownBadge({
    super.key,
    required this.days,
  });

  String get _label => switch (days) {
        <= 0 => 'Archive due',
        1 => '1d to archive',
        _ => '${days}d to archive',
      };

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    bool urgent = days <= 3;
    Color foreground = urgent ? urgentColor : theme.colorScheme.mutedForeground;
    Color background = urgent
        ? m.Color.alphaBlend(
            urgentColor.withValues(alpha: 0.12),
            theme.colorScheme.card,
          )
        : theme.colorScheme.card;
    Color border =
        urgent ? urgentColor.withValues(alpha: 0.4) : theme.colorScheme.border;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AlembicShadcnTokens.badgeRadius),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          m.Icon(m.Icons.archive_outlined, size: 11, color: foreground),
          const Gap(4),
          Text(
            _label,
            style: theme.typography.xSmall.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class RepositoryWorkBadge extends StatelessWidget {
  final RepositoryWork work;

  const RepositoryWorkBadge({
    super.key,
    required this.work,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 168),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary,
          borderRadius: BorderRadius.circular(AlembicShadcnTokens.badgeRadius),
          border: Border.all(color: theme.colorScheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AlembicProgressMark(
              value: work.progress,
              size: 11,
            ),
            const Gap(AlembicShadcnTokens.gapXs),
            Flexible(
              child: Text(
                work.message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.xSmall.copyWith(
                  color: theme.colorScheme.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ArchiveMasterBadge extends StatelessWidget {
  const ArchiveMasterBadge({super.key});

  @override
  Widget build(BuildContext context) => const AlembicBadge(
        label: 'Archive Master',
        tone: AlembicBadgeTone.secondary,
      );
}

class RepositoryAuthBadgeLoader extends StatelessWidget {
  final Future<RepoAuthInfo> future;
  final VoidCallback onTap;

  const RepositoryAuthBadgeLoader({
    super.key,
    required this.future,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RepoAuthInfo>(
      future: future,
      builder: (context, snapshot) {
        RepoAuthInfo? info = snapshot.data;
        if (info == null) {
          return _AuthBadgePlaceholder(onTap: onTap);
        }
        return RepositoryAuthBadge(info: info, onTap: onTap);
      },
    );
  }
}

class _AuthBadgePlaceholder extends StatelessWidget {
  final VoidCallback onTap;

  const _AuthBadgePlaceholder({required this.onTap});

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return m.Material(
      color: m.Colors.transparent,
      child: m.InkWell(
        onTap: onTap,
        canRequestFocus: false,
        borderRadius: BorderRadius.circular(AlembicShadcnTokens.badgeRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: theme.colorScheme.card,
            borderRadius:
                BorderRadius.circular(AlembicShadcnTokens.badgeRadius),
            border: Border.all(color: theme.colorScheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              m.Icon(
                m.Icons.vpn_key_outlined,
                size: 11,
                color: theme.colorScheme.mutedForeground,
              ),
              const Gap(4),
              Text(
                'Auth',
                style: theme.typography.xSmall.copyWith(
                  color: theme.colorScheme.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension RepositoryDescriptionClean on String {
  String? get cleanedDescription {
    String description = trim();
    return description.isEmpty ? null : description;
  }
}
