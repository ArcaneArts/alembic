import 'package:alembic/core/arcane_repository.dart';
import 'package:alembic/core/repository_runtime.dart';
import 'package:alembic/main.dart';
import 'package:alembic/screen/repository_settings.dart';
import 'package:alembic/theme/alembic_tokens.dart';
import 'package:alembic/util/window.dart';
import 'package:alembic/widget/glass_context_menu.dart';
import 'package:alembic/widget/glass_icon_button.dart';
import 'package:alembic/widget/repository_tile_actions.dart';
import 'package:alembic/widget/glass_panel.dart';
import 'package:flutter/cupertino.dart';
import 'package:github/github.dart';
import 'package:url_launcher/url_launcher_string.dart';

enum _RepoMenuAction {
  details,
  openFinder,
  settings,
  viewGithub,
  issues,
  pullRequests,
  newIssue,
  newPullRequest,
  pull,
  archive,
  delete,
  activate,
  updateArchive,
  deleteArchive,
  clone,
  archiveFromCloud,
  fork,
}

class RepositoryTile extends StatefulWidget {
  final Repository repository;
  final GitHub github;
  final RepositoryRuntime runtime;
  final VoidCallback? onChanged;

  const RepositoryTile({
    super.key,
    required this.repository,
    required this.github,
    required this.runtime,
    this.onChanged,
  });

  @override
  State<RepositoryTile> createState() => _RepositoryTileState();
}

class _RepositoryTileState extends State<RepositoryTile>
    with AutomaticKeepAliveClientMixin {
  late final ArcaneRepository _repository;
  bool _hovered = false;
  late final Future<int> _daysUntilArchiveFuture;

  @override
  void initState() {
    super.initState();
    _repository = ArcaneRepository(
      repository: widget.repository,
      runtime: widget.runtime,
    );
    _daysUntilArchiveFuture = _repository.daysUntilArchival;
  }

  Future<void> _openRepository() async {
    await _repository.open(widget.github, context);
    widget.onChanged?.call();
  }

  Future<void> _runPrimaryAction(RepoState state) async {
    switch (state) {
      case RepoState.active:
        await _repository.ensureRepositoryUpdated(widget.github);
      case RepoState.archived:
        await _repository.unarchive(widget.github);
      case RepoState.cloud:
        await _repository.ensureRepositoryActive(widget.github);
    }
    widget.onChanged?.call();
  }

  Future<void> _showMenu(RepoState state, List<String> work) async {
    String owner = widget.repository.owner?.login ?? 'unknown';
    String name = widget.repository.name;
    String base = 'https://github.com/$owner/$name';

    List<GlassMenuAction<_RepoMenuAction>> actions =
        <GlassMenuAction<_RepoMenuAction>>[
      const GlassMenuAction<_RepoMenuAction>(
        value: _RepoMenuAction.details,
        title: 'Repository Details',
      ),
      const GlassMenuAction<_RepoMenuAction>(
        value: _RepoMenuAction.openFinder,
        title: 'Open in Finder',
      ),
      const GlassMenuAction<_RepoMenuAction>(
        value: _RepoMenuAction.settings,
        title: 'Repository Settings',
      ),
      const GlassMenuAction<_RepoMenuAction>(
        value: _RepoMenuAction.viewGithub,
        title: 'View on GitHub',
      ),
      const GlassMenuAction<_RepoMenuAction>(
        value: _RepoMenuAction.issues,
        title: 'Issues',
      ),
      const GlassMenuAction<_RepoMenuAction>(
        value: _RepoMenuAction.pullRequests,
        title: 'Pull Requests',
      ),
      const GlassMenuAction<_RepoMenuAction>(
        value: _RepoMenuAction.newIssue,
        title: 'New Issue',
      ),
      const GlassMenuAction<_RepoMenuAction>(
        value: _RepoMenuAction.newPullRequest,
        title: 'New Pull Request',
      ),
      if (_canForkRepository())
        const GlassMenuAction<_RepoMenuAction>(
          value: _RepoMenuAction.fork,
          title: 'Fork and Clone',
        ),
    ];

    switch (state) {
      case RepoState.active:
        actions.addAll(<GlassMenuAction<_RepoMenuAction>>[
          const GlassMenuAction<_RepoMenuAction>(
            value: _RepoMenuAction.pull,
            title: 'Pull',
          ),
          const GlassMenuAction<_RepoMenuAction>(
            value: _RepoMenuAction.archive,
            title: 'Archive',
          ),
          const GlassMenuAction<_RepoMenuAction>(
            value: _RepoMenuAction.delete,
            title: 'Delete',
            destructive: true,
          ),
        ]);
        break;
      case RepoState.archived:
        actions.addAll(<GlassMenuAction<_RepoMenuAction>>[
          const GlassMenuAction<_RepoMenuAction>(
            value: _RepoMenuAction.activate,
            title: 'Activate',
          ),
          const GlassMenuAction<_RepoMenuAction>(
            value: _RepoMenuAction.updateArchive,
            title: 'Update Archive',
          ),
          const GlassMenuAction<_RepoMenuAction>(
            value: _RepoMenuAction.deleteArchive,
            title: 'Delete Archive',
            destructive: true,
          ),
        ]);
        break;
      case RepoState.cloud:
        actions.addAll(<GlassMenuAction<_RepoMenuAction>>[
          const GlassMenuAction<_RepoMenuAction>(
            value: _RepoMenuAction.clone,
            title: 'Clone',
          ),
          const GlassMenuAction<_RepoMenuAction>(
            value: _RepoMenuAction.archiveFromCloud,
            title: 'Archive',
          ),
        ]);
        break;
    }

    _RepoMenuAction? selected = await GlassContextMenu.show<_RepoMenuAction>(
      context,
      title: widget.repository.fullName,
      actions: actions,
    );

    if (selected == null || !mounted) {
      return;
    }

    RepositoryTileAction? action = _mapMenuAction(selected);
    if (action == null) {
      return;
    }

    RepositoryTileActionOperations operations = _RepositoryTileOperations(
      context: context,
      repository: widget.repository,
      arcaneRepository: _repository,
      github: widget.github,
      runtime: widget.runtime,
      state: state,
      work: work,
      onChanged: widget.onChanged,
    );
    RepositoryTileActionDispatcher dispatcher =
        const RepositoryTileActionDispatcher();
    await dispatcher.dispatch(
      action: action,
      operations: operations,
      baseUrl: base,
    );
  }

  RepositoryTileAction? _mapMenuAction(_RepoMenuAction action) {
    return switch (action) {
      _RepoMenuAction.details => RepositoryTileAction.details,
      _RepoMenuAction.openFinder => RepositoryTileAction.openFinder,
      _RepoMenuAction.settings => RepositoryTileAction.settings,
      _RepoMenuAction.viewGithub => RepositoryTileAction.viewGithub,
      _RepoMenuAction.issues => RepositoryTileAction.issues,
      _RepoMenuAction.pullRequests => RepositoryTileAction.pullRequests,
      _RepoMenuAction.newIssue => RepositoryTileAction.newIssue,
      _RepoMenuAction.newPullRequest => RepositoryTileAction.newPullRequest,
      _RepoMenuAction.pull => RepositoryTileAction.pull,
      _RepoMenuAction.archive => RepositoryTileAction.archive,
      _RepoMenuAction.delete => RepositoryTileAction.deleteRepository,
      _RepoMenuAction.activate => RepositoryTileAction.activate,
      _RepoMenuAction.updateArchive => RepositoryTileAction.updateArchive,
      _RepoMenuAction.deleteArchive => RepositoryTileAction.deleteArchive,
      _RepoMenuAction.clone => RepositoryTileAction.clone,
      _RepoMenuAction.archiveFromCloud => RepositoryTileAction.archiveFromCloud,
      _RepoMenuAction.fork => RepositoryTileAction.fork,
    };
  }

  bool _canForkRepository() {
    final String currentLogin =
        (boxSettings.get('current_user_login', defaultValue: '') as String)
            .trim()
            .toLowerCase();
    final String ownerLogin =
        (widget.repository.owner?.login ?? '').trim().toLowerCase();
    return ownerLogin.isNotEmpty &&
        currentLogin.isNotEmpty &&
        ownerLogin != currentLogin;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    AlembicTokens tokens = context.alembicTokens;

    return FutureBuilder<RepoState>(
      future: _repository.state,
      builder: (context, stateSnapshot) {
        RepoState state = stateSnapshot.data ?? RepoState.cloud;
        return StreamBuilder<List<Repository>>(
          stream: widget.runtime.syncingRepositories.stream,
          initialData: widget.runtime.syncingRepositories.value,
          builder: (context, syncingSnapshot) {
            bool syncing = (syncingSnapshot.data ?? <Repository>[])
                .any((repo) => repo.fullName == widget.repository.fullName);
            return StreamBuilder<List<String>>(
              stream: _repository.streamWork(),
              initialData: const <String>[],
              builder: (context, workSnapshot) {
                List<String> work = workSnapshot.data ?? const <String>[];
                bool showLoading = syncing || work.isNotEmpty;
                BorderRadius rowRadius =
                    BorderRadius.circular(tokens.radiusMedium);

                Widget details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.repository.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.repository.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary.withValues(alpha: 0.84),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (state == RepoState.active)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: FutureBuilder<int>(
                          future: _daysUntilArchiveFuture,
                          builder: (context, daysSnapshot) {
                            int? days = daysSnapshot.data;
                            String label = days == null
                                ? 'Auto-archive schedule active'
                                : 'Auto-archive in ${days.clamp(0, 999)} day${days == 1 ? '' : 's'}';
                            return Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.textSecondary
                                    .withValues(alpha: 0.72),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hovered = true),
                    onExit: (_) => setState(() => _hovered = false),
                    child: AnimatedScale(
                      scale: _hovered ? 1.004 : 1,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      child: ClipRRect(
                        borderRadius: rowRadius,
                        child: _buildRowSurface(
                          tokens: tokens,
                          rowRadius: rowRadius,
                          details: details,
                          showLoading: showLoading,
                          state: state,
                          work: work,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  IconData _primaryActionIcon(RepoState state) {
    return switch (state) {
      RepoState.active => CupertinoIcons.arrow_down,
      RepoState.archived => CupertinoIcons.arrow_up,
      RepoState.cloud => CupertinoIcons.cloud_download,
    };
  }

  String _primaryActionTooltip(RepoState state) {
    return switch (state) {
      RepoState.active => 'Pull',
      RepoState.archived => 'Activate archive',
      RepoState.cloud => 'Clone repository',
    };
  }

  Widget _buildRowSurface({
    required AlembicTokens tokens,
    required BorderRadius rowRadius,
    required Widget details,
    required bool showLoading,
    required RepoState state,
    required List<String> work,
  }) {
    double rowHeight = state == RepoState.active ? 80 : 64;
    Widget rowContent = Column(
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openRepository,
                child: details,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (showLoading)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: CupertinoActivityIndicator(
                      radius: 7,
                    ),
                  ),
                _QuickActionButton(
                  icon: _primaryActionIcon(state),
                  onPressed: () => _runPrimaryAction(state),
                  tooltip: _primaryActionTooltip(state),
                ),
                const SizedBox(width: 6),
                _QuickActionButton(
                  icon: CupertinoIcons.ellipsis_circle,
                  onPressed: () => _showMenu(state, work),
                  tooltip: 'More actions',
                ),
              ],
            ),
          ],
        ),
      ],
    );

    Widget baseSurface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: rowRadius,
        color: CupertinoColors.transparent,
        border: Border.all(
          color: tokens.stroke.withValues(alpha: _hovered ? 0.20 : 0.08),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 6),
        child: rowContent,
      ),
    );

    Widget hoverLensSurface = GlassPanel(
      role: GlassPanelRole.overlay,
      liveLens: true,
      borderRadius: rowRadius,
      fillColor: tokens.overlayFill.withValues(alpha: 0.26),
      padding: EdgeInsets.zero,
      child: const SizedBox.expand(),
    );

    return SizedBox(
      height: rowHeight,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          baseSurface,
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _hovered ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: hoverLensSurface,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _RepositoryTileOperations implements RepositoryTileActionOperations {
  final BuildContext context;
  final Repository repository;
  final ArcaneRepository arcaneRepository;
  final GitHub github;
  final RepositoryRuntime runtime;
  final RepoState state;
  final List<String> work;
  final VoidCallback? onChanged;

  const _RepositoryTileOperations({
    required this.context,
    required this.repository,
    required this.arcaneRepository,
    required this.github,
    required this.runtime,
    required this.state,
    required this.work,
    required this.onChanged,
  });

  String _stateLabel() {
    return switch (state) {
      RepoState.active => 'Active',
      RepoState.archived => 'Archived',
      RepoState.cloud => 'Cloud',
    };
  }

  @override
  Future<void> showDetails() async {
    String owner = repository.owner?.login ?? 'unknown';
    String stateLabel = _stateLabel();
    String workLabel = work.isEmpty ? 'None' : work.join(', ');
    List<String> lines = <String>[
      'State: $stateLabel',
      'Owner: $owner',
      'Work: $workLabel',
      'Workspace: ${arcaneRepository.repoPath}',
    ];
    if (state == RepoState.active) {
      int daysUntilArchive = await arcaneRepository.daysUntilArchival;
      lines.add('Auto-archive in: $daysUntilArchive day(s)');
    }
    if (!context.mounted) {
      return;
    }
    await showGlassInfoDialog(
      context,
      title: repository.fullName,
      message: lines.join('\n'),
    );
  }

  @override
  Future<void> openInFinder() async {
    await WindowUtil.hide();
    await arcaneRepository.openInFinder();
    runtime.notifyChanged();
    onChanged?.call();
  }

  @override
  Future<void> openSettings() async {
    await showRepositorySettingsModal(context, repository);
  }

  @override
  Future<void> openExternalUrl(String url) async {
    await launchUrlString(url);
  }

  @override
  Future<void> pull() async {
    await arcaneRepository.ensureRepositoryUpdated(github);
    onChanged?.call();
  }

  @override
  Future<void> archive() async {
    await arcaneRepository.archive();
    onChanged?.call();
  }

  @override
  Future<void> deleteRepository() async {
    await arcaneRepository.deleteRepository();
    onChanged?.call();
  }

  @override
  Future<void> activate() async {
    await arcaneRepository.unarchive(github);
    onChanged?.call();
  }

  @override
  Future<void> updateArchive() async {
    await arcaneRepository.updateArchive(github);
    onChanged?.call();
  }

  @override
  Future<void> deleteArchive() async {
    await arcaneRepository.deleteArchive();
    onChanged?.call();
  }

  @override
  Future<void> cloneRepository() async {
    await arcaneRepository.ensureRepositoryActive(github);
    onChanged?.call();
  }

  @override
  Future<void> archiveFromCloud() async {
    await arcaneRepository.archiveFromCloud(github);
    onChanged?.call();
  }

  @override
  Future<void> forkAndClone() async {
    try {
      await arcaneRepository.forkAndClone(github);
      onChanged?.call();
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      await showGlassInfoDialog(
        context,
        title: 'Fork Failed',
        message: '$e',
      );
    }
  }

  @override
  Future<bool> confirmDeleteRepository() {
    return showGlassConfirmDialog(
      context,
      title: 'Delete ${repository.fullName}?',
      description:
          'Delete this repository from local workspace. Unstaged or unpushed changes can be lost forever.',
      confirmText: 'Delete',
      destructive: true,
    );
  }

  @override
  Future<bool> confirmDeleteArchive() {
    return showGlassConfirmDialog(
      context,
      title: 'Delete archive ${repository.fullName}?',
      description:
          'Delete this archived image from local storage. Any unsynced local changes inside the archive will be lost.',
      confirmText: 'Delete Archive',
      destructive: true,
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _QuickActionButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(
      icon: icon,
      onPressed: onPressed,
      semanticLabel: tooltip,
      size: 32,
    );
  }
}
