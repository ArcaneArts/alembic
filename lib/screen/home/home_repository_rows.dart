import 'package:alembic/core/arcane_repository.dart';
import 'package:alembic/core/repository_auth.dart';
import 'package:alembic/core/repository_runtime.dart';
import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:alembic/presentation/repository_action_catalog.dart';
import 'package:alembic/presentation/repository_action_model.dart';
import 'package:alembic/screen/home/home_actions.dart';
import 'package:alembic/screen/home/repository_auth_badge.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:alembic/util/archive_master.dart';
import 'package:alembic/util/git_accounts.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:alembic/widget/repository_tile_actions.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;
import 'package:github/github.dart';

typedef RepositoryPrimaryActionCallback = Future<void> Function({
  required Repository repository,
  required RepoState state,
});

typedef RepositoryActionCallback = Future<void> Function({
  required Repository repository,
  required RepoState state,
  required List<String> work,
  required RepositoryTileAction action,
});

class LocalRepositoryRow extends StatefulWidget {
  final Repository repository;
  final RepositoryRuntime runtime;
  final int revision;
  final RepositoryPrimaryActionCallback onPrimaryAction;
  final RepositoryActionCallback onRepositoryAction;
  final GitAccount? account;

  const LocalRepositoryRow({
    super.key,
    required this.repository,
    required this.runtime,
    required this.revision,
    required this.onPrimaryAction,
    required this.onRepositoryAction,
    required this.account,
  });

  @override
  State<LocalRepositoryRow> createState() => _LocalRepositoryRowState();
}

class _LocalRepositoryRowState extends State<LocalRepositoryRow> {
  static const RepositoryAuthInspector _authInspector =
      RepositoryAuthInspector();

  late Stream<List<String>> _workStream;
  late Future<int> _daysUntilArchival;
  late Future<RepoAuthInfo> _authInfo;

  @override
  void initState() {
    super.initState();
    _configureRepository();
  }

  @override
  void didUpdateWidget(covariant LocalRepositoryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository.fullName != widget.repository.fullName ||
        oldWidget.runtime != widget.runtime ||
        oldWidget.revision != widget.revision) {
      _configureRepository();
    }
  }

  void _configureRepository() {
    ArcaneRepository arcaneRepository = _arcaneRepository();
    _workStream = arcaneRepository.streamWork();
    _daysUntilArchival = arcaneRepository.daysUntilArchival;
    _authInfo = _authInspector.read(arcaneRepository);
  }

  ArcaneRepository _arcaneRepository() => ArcaneRepository(
        repository: widget.repository,
        runtime: widget.runtime,
        accountId: widget.account?.id,
      );

  void _onAuthBadgePressed() {
    widget.onRepositoryAction(
      repository: widget.repository,
      state: RepoState.active,
      work: const <String>[],
      action: RepositoryTileAction.changeAuth,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: _workStream,
      initialData: const <String>[],
      builder:
          (BuildContext context, AsyncSnapshot<List<String>> workSnapshot) {
        List<String> work = workSnapshot.data ?? const <String>[];
        return FutureBuilder<int>(
          future: _daysUntilArchival,
          builder: (BuildContext context, AsyncSnapshot<int> daysSnapshot) {
            int daysUntilArchive = daysSnapshot.data ?? config.daysToArchive;
            return AlembicListRow(
              title: widget.repository.name,
              subtitle: widget.repository.fullName,
              description: cleanRepositoryDescription(
                widget.repository.description,
              ),
              meta: _buildMeta(
                work: work,
                daysUntilArchive: daysUntilArchive,
              ),
              primaryAction: _buildPrimaryAction(),
              secondaryActions: _buildSecondaryActions(work: work),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildMeta({
    required List<String> work,
    required int daysUntilArchive,
  }) {
    bool enrolled = _isEnrolledInArchiveMaster();
    return <Widget>[
      AlembicMetaText(
        label: widget.repository.isPrivate == true ? 'Private' : 'Public',
      ),
      AlembicBadge(
        label:
            '$daysUntilArchive day${daysUntilArchive == 1 ? '' : 's'} to archive',
      ),
      _AuthBadgeFutureBuilder(
        future: _authInfo,
        onTap: _onAuthBadgePressed,
      ),
      if (enrolled) const ArchiveMasterBadge(),
      if (work.isNotEmpty) AlembicMetaText(label: work.join(' • ')),
    ];
  }

  Widget _buildPrimaryAction() => AlembicToolbarButton(
        label: 'Open',
        leadingIcon: RepoState.active.primaryActionIcon,
        onPressed: () => widget.onPrimaryAction(
          repository: widget.repository,
          state: RepoState.active,
        ),
        prominent: true,
      );

  Widget _buildSecondaryActions({required List<String> work}) {
    List<RepositoryActionModel> actions = _menuActions();
    return AlembicOverflowMenu<RepositoryTileAction>(
      label: 'Repository options',
      items: buildMenuOptions(actions),
      onSelected: (RepositoryTileAction action) => widget.onRepositoryAction(
        repository: widget.repository,
        state: RepoState.active,
        work: work,
        action: action,
      ),
    );
  }

  List<RepositoryActionModel> _menuActions() {
    List<RepositoryActionModel> stateActions =
        RepositoryActionCatalog.stateActions(RepoState.active);
    List<RepositoryActionModel> localActions =
        RepositoryActionCatalog.localActions(
      includeExplorer: true,
      explorerName: DesktopPlatformAdapter.instance.fileExplorerName,
    );
    bool enrolled = _isEnrolledInArchiveMaster();
    bool hasMasterClone = _arcaneRepository().isArchiveMasterSync;
    List<RepositoryActionModel> archiveMasterActions =
        RepositoryActionCatalog.archiveMasterActions(
      enrolled: enrolled,
      hasMasterClone: hasMasterClone,
      isActive: true,
    );
    return <RepositoryActionModel>[
      RepositoryActionCatalog.find(stateActions, RepositoryTileAction.pull),
      RepositoryActionCatalog.find(localActions, RepositoryTileAction.details),
      RepositoryActionCatalog.find(
          localActions, RepositoryTileAction.openFinder),
      RepositoryActionCatalog.find(localActions, RepositoryTileAction.settings),
      RepositoryActionCatalog.find(
          localActions, RepositoryTileAction.changeAuth),
      RepositoryActionCatalog.find(stateActions, RepositoryTileAction.archive),
      ...archiveMasterActions,
      ...RepositoryActionCatalog.githubActions(),
      RepositoryActionCatalog.find(
          stateActions, RepositoryTileAction.deleteRepository),
    ];
  }

  bool _isEnrolledInArchiveMaster() => isArchiveMasterRepository(
        widget.repository.owner?.login ?? '',
        widget.repository.name,
      );
}

class BrowseRepositoryRow extends StatefulWidget {
  final Repository repository;
  final RepositoryRuntime runtime;
  final int revision;
  final RepositoryPrimaryActionCallback onPrimaryAction;
  final RepositoryActionCallback onRepositoryAction;
  final bool Function(Repository repository) canForkRepository;
  final GitAccount? account;
  final bool selectable;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;

  const BrowseRepositoryRow({
    super.key,
    required this.repository,
    required this.runtime,
    required this.revision,
    required this.onPrimaryAction,
    required this.onRepositoryAction,
    required this.canForkRepository,
    required this.account,
    this.selectable = false,
    this.selected = false,
    this.onSelectedChanged,
  });

  @override
  State<BrowseRepositoryRow> createState() => _BrowseRepositoryRowState();
}

class _BrowseRepositoryRowState extends State<BrowseRepositoryRow> {
  static const RepositoryAuthInspector _authInspector =
      RepositoryAuthInspector();

  late Stream<List<RepositoryWork>> _workStream;
  late Future<RepoState> _state;
  late Future<RepoAuthInfo> _authInfo;

  @override
  void initState() {
    super.initState();
    _configureRepository();
  }

  @override
  void didUpdateWidget(covariant BrowseRepositoryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository.fullName != widget.repository.fullName ||
        oldWidget.runtime != widget.runtime ||
        oldWidget.revision != widget.revision) {
      _configureRepository();
    }
  }

  void _configureRepository() {
    ArcaneRepository arcaneRepository = _arcaneRepository();
    _workStream = arcaneRepository.streamWorkEntries();
    _state = arcaneRepository.state;
    _authInfo = _authInspector.read(arcaneRepository);
  }

  ArcaneRepository _arcaneRepository() => ArcaneRepository(
        repository: widget.repository,
        runtime: widget.runtime,
        accountId: widget.account?.id,
      );

  void _onAuthBadgePressed(RepoState state) {
    widget.onRepositoryAction(
      repository: widget.repository,
      state: state,
      work: const <String>[],
      action: RepositoryTileAction.changeAuth,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RepoState>(
      future: _state,
      builder: (BuildContext context, AsyncSnapshot<RepoState> stateSnapshot) {
        RepoState state = stateSnapshot.data ?? RepoState.cloud;
        return StreamBuilder<List<RepositoryWork>>(
          stream: _workStream,
          initialData: const <RepositoryWork>[],
          builder: (
            BuildContext context,
            AsyncSnapshot<List<RepositoryWork>> workSnapshot,
          ) {
            List<RepositoryWork> work =
                workSnapshot.data ?? const <RepositoryWork>[];
            List<String> workLabels = _workLabels(work);
            bool busy = work.isNotEmpty;
            return AlembicListRow(
              title: widget.repository.name,
              subtitle: widget.repository.fullName,
              description: cleanRepositoryDescription(
                widget.repository.description,
              ),
              leading: _buildSelectionToggle(),
              meta: _buildMeta(state: state, work: work),
              primaryAction: _buildPrimaryAction(
                state: state,
                work: work,
                busy: busy,
              ),
              secondaryActions: _buildSecondaryActions(
                state: state,
                work: workLabels,
              ),
            );
          },
        );
      },
    );
  }

  List<String> _workLabels(List<RepositoryWork> work) {
    return work.map((RepositoryWork item) => item.message).toList();
  }

  Widget? _buildSelectionToggle() {
    if (!widget.selectable) {
      return null;
    }
    return AlembicSelectionToggle(
      selected: widget.selected,
      onChanged: widget.onSelectedChanged,
      label: widget.selected
          ? 'Deselect ${widget.repository.fullName}'
          : 'Select ${widget.repository.fullName}',
    );
  }

  List<Widget> _buildMeta({
    required RepoState state,
    required List<RepositoryWork> work,
  }) {
    bool enrolled = _isEnrolledInArchiveMaster();
    RepositoryWork? primaryWork = _primaryWork(work);
    return <Widget>[
      RepoStateBadge(state: state),
      AlembicMetaText(
        label: widget.repository.isPrivate == true ? 'Private' : 'Public',
      ),
      _AuthBadgeFutureBuilder(
        future: _authInfo,
        onTap: () => _onAuthBadgePressed(state),
      ),
      if (enrolled) const ArchiveMasterBadge(),
      if (primaryWork != null) RepositoryWorkBadge(work: primaryWork),
    ];
  }

  Widget _buildPrimaryAction({
    required RepoState state,
    required List<RepositoryWork> work,
    required bool busy,
  }) =>
      AlembicToolbarButton(
        label: _primaryActionLabel(state: state, work: work),
        leadingIcon: busy ? null : state.primaryActionIcon,
        busy: busy,
        onPressed: busy
            ? null
            : () => widget.onPrimaryAction(
                  repository: widget.repository,
                  state: state,
                ),
        prominent: true,
      );

  String _primaryActionLabel({
    required RepoState state,
    required List<RepositoryWork> work,
  }) {
    RepositoryWork? cloneWork = _cloneWork(work);
    if (cloneWork != null) {
      return cloneWork.progress == null
          ? 'Cloning'
          : '${(cloneWork.progress! * 100).round()}%';
    }
    if (work.isNotEmpty) {
      return work.first.message;
    }
    return state.primaryActionLabel;
  }

  Widget _buildSecondaryActions({
    required RepoState state,
    required List<String> work,
  }) {
    List<RepositoryActionModel> actions = _menuActions(state);
    return Wrap(
      spacing: AlembicShadcnTokens.gapSm,
      runSpacing: AlembicShadcnTokens.gapSm,
      children: <Widget>[
        AlembicToolbarButton(
          label: 'Open on GitHub',
          leadingIcon: m.Icons.open_in_new,
          compact: true,
          iconOnly: true,
          tooltip: 'Open on GitHub',
          onPressed: () => widget.onRepositoryAction(
            repository: widget.repository,
            state: state,
            work: work,
            action: RepositoryTileAction.viewGithub,
          ),
        ),
        AlembicOverflowMenu<RepositoryTileAction>(
          label: 'Repository options',
          items: buildMenuOptions(actions),
          onSelected: (RepositoryTileAction action) =>
              widget.onRepositoryAction(
            repository: widget.repository,
            state: state,
            work: work,
            action: action,
          ),
        ),
      ],
    );
  }

  List<RepositoryActionModel> _menuActions(RepoState state) {
    List<RepositoryActionModel> stateActions =
        RepositoryActionCatalog.stateActions(state);
    List<RepositoryActionModel> linkActions =
        RepositoryActionCatalog.linkActions(
      canFork: widget.canForkRepository(widget.repository),
      explorerName: DesktopPlatformAdapter.instance.fileExplorerName,
      includeExplorer: state == RepoState.active,
    );
    bool enrolled = _isEnrolledInArchiveMaster();
    bool hasMasterClone = _arcaneRepository().isArchiveMasterSync;
    List<RepositoryActionModel> archiveMasterActions =
        RepositoryActionCatalog.archiveMasterActions(
      enrolled: enrolled,
      hasMasterClone: hasMasterClone,
      isActive: state == RepoState.active,
    );
    return <RepositoryActionModel>[
      ...stateActions.where((RepositoryActionModel model) {
        return model.action != RepositoryTileAction.clone &&
            model.action != RepositoryTileAction.activate;
      }),
      ...archiveMasterActions,
      ...linkActions.where((RepositoryActionModel model) {
        return model.action != RepositoryTileAction.viewGithub;
      }),
    ];
  }

  bool _isEnrolledInArchiveMaster() => isArchiveMasterRepository(
        widget.repository.owner?.login ?? '',
        widget.repository.name,
      );

  RepositoryWork? _primaryWork(List<RepositoryWork> work) {
    RepositoryWork? cloneWork = _cloneWork(work);
    if (cloneWork != null) {
      return cloneWork;
    }
    if (work.isEmpty) {
      return null;
    }
    return work.first;
  }

  RepositoryWork? _cloneWork(List<RepositoryWork> work) {
    for (RepositoryWork item in work) {
      if (item.kind == RepositoryWorkKind.clone) {
        return item;
      }
    }
    return null;
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary,
        borderRadius: BorderRadius.circular(AlembicShadcnTokens.badgeRadius),
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox.square(
            dimension: 11,
            child: m.CircularProgressIndicator(
              strokeWidth: 1.5,
              value: work.progress,
              backgroundColor: theme.colorScheme.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.foreground,
              ),
            ),
          ),
          const Gap(AlembicShadcnTokens.gapXs),
          Text(
            work.message,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.xSmall.copyWith(
              color: theme.colorScheme.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class RepoStateBadge extends StatelessWidget {
  final RepoState state;

  const RepoStateBadge({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    AlembicBadgeTone tone = switch (state) {
      RepoState.active => AlembicBadgeTone.secondary,
      RepoState.archived => AlembicBadgeTone.outline,
      RepoState.cloud => AlembicBadgeTone.outline,
    };
    return AlembicBadge(label: state.label, tone: tone);
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

class _AuthBadgeFutureBuilder extends StatelessWidget {
  final Future<RepoAuthInfo> future;
  final VoidCallback onTap;

  const _AuthBadgeFutureBuilder({
    required this.future,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RepoAuthInfo>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<RepoAuthInfo> snapshot) {
        final RepoAuthInfo? info = snapshot.data;
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
    final ThemeData theme = Theme.of(context);
    return m.Material(
      color: m.Colors.transparent,
      child: m.InkWell(
        onTap: onTap,
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

String? cleanRepositoryDescription(String? value) {
  String description = (value ?? '').trim();
  if (description.isEmpty) {
    return null;
  }
  return description;
}

List<AlembicDropdownOption<RepositoryTileAction>> buildMenuOptions(
  List<RepositoryActionModel> actions,
) =>
    <AlembicDropdownOption<RepositoryTileAction>>[
      for (RepositoryActionModel model in actions)
        AlembicDropdownOption<RepositoryTileAction>(
          value: model.action,
          label: model.label,
          icon: model.icon,
          destructive: model.destructive,
        ),
    ];
