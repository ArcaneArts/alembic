import 'package:alembic/core/arcane_repository.dart';
import 'package:alembic/core/repository_auth.dart';
import 'package:alembic/core/repository_runtime.dart';
import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:alembic/presentation/repository_action_catalog.dart';
import 'package:alembic/presentation/repository_action_model.dart';
import 'package:alembic/screen/home/home_actions.dart';
import 'package:alembic/screen/home/home_view_filters.dart';
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
  final HomeSelectionController? selection;
  final bool showSeparator;
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
    this.selection,
    this.showSeparator = true,
  });

  @override
  State<HomeRepositoryRow> createState() => _HomeRepositoryRowState();
}

class _HomeRepositoryRowState extends State<HomeRepositoryRow> {
  static const RepositoryAuthInspector _authInspector =
      RepositoryAuthInspector();

  static const Set<RepositoryTileAction> _archiveMasterActions =
      <RepositoryTileAction>{
    RepositoryTileAction.enrollArchiveMaster,
    RepositoryTileAction.refreshArchiveMaster,
    RepositoryTileAction.promoteArchiveMaster,
    RepositoryTileAction.unenrollArchiveMaster,
  };

  late Stream<List<RepositoryWork>> _workStream;
  late Future<RepoAuthInfo> _authInfo;
  late bool _hasMasterClone;
  bool _hovered = false;
  bool _selected = false;
  bool _selectionActive = false;

  @override
  void initState() {
    super.initState();
    _configureRepository();
    widget.selection?.addListener(_onSelectionChanged);
    _syncSelection();
  }

  @override
  void didUpdateWidget(covariant HomeRepositoryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.fullName != widget.entry.fullName ||
        oldWidget.runtime != widget.runtime ||
        oldWidget.revision != widget.revision) {
      _configureRepository();
    }
    if (oldWidget.selection != widget.selection) {
      oldWidget.selection?.removeListener(_onSelectionChanged);
      widget.selection?.addListener(_onSelectionChanged);
    }
    _syncSelection();
  }

  @override
  void dispose() {
    widget.selection?.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _syncSelection() {
    _selected = widget.selection?.isSelected(widget.entry.lowerKey) ?? false;
    _selectionActive = widget.selection?.active ?? false;
  }

  void _onSelectionChanged() {
    bool selected =
        widget.selection?.isSelected(widget.entry.lowerKey) ?? false;
    bool active = widget.selection?.active ?? false;
    if (selected == _selected && active == _selectionActive) {
      return;
    }
    setState(() {
      _selected = selected;
      _selectionActive = active;
    });
  }

  void _toggleSelection() {
    widget.selection?.toggle(widget.entry.lowerKey, !_selected);
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

  void _onAuthWarningPressed() {
    widget.onAction(widget.entry, RepositoryTileAction.changeAuth);
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

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    List<RepositoryActionModel> models = _menuModels;
    bool selectable = widget.selection != null;
    return ContextMenu(
      items: _contextMenuItems(models),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: StreamBuilder<List<RepositoryWork>>(
          stream: _workStream,
          initialData: const <RepositoryWork>[],
          builder: (context, workSnapshot) {
            List<RepositoryWork> work =
                workSnapshot.data ?? const <RepositoryWork>[];
            RepositoryWork? activeWork = _primaryWork(work);
            bool busy = work.isNotEmpty;
            bool selectionVisible =
                selectable && (_hovered || _selectionActive);
            String? description =
                widget.entry.dto.description.cleanedDescription;
            return Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: _hovered
                    ? m.Color.alphaBlend(
                        theme.colorScheme.secondary.withValues(alpha: 0.5),
                        theme.colorScheme.background,
                      )
                    : theme.colorScheme.background,
                border: widget.showSeparator
                    ? Border(
                        bottom: BorderSide(color: theme.colorScheme.border),
                      )
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  if (selectable)
                    _RowSelectionSlot(
                      visible: selectionVisible,
                      selected: _selected,
                      fullName: widget.entry.fullName,
                      onPressed: _toggleSelection,
                    ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onDoubleTap: () => widget.onShowDetails(widget.entry),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _RowTitleLine(
                            entry: widget.entry,
                            account: widget.account,
                            enrolled: _enrolled,
                            archiveEnabled: widget.archiveEnabled,
                            authInfo: _authInfo,
                            onAuthPressed: _onAuthWarningPressed,
                          ),
                          if (description != null) ...<Widget>[
                            const Gap(2),
                            Text(
                              description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.xSmall.copyWith(
                                color: theme.colorScheme.mutedForeground,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Gap(AlembicShadcnTokens.gapSm),
                  _RowTrailing(
                    work: activeWork,
                    controlsVisible: !busy && (_hovered || _selectionActive),
                    state: widget.entry.repoState,
                    options: HomeRepositoryMenu.dropdownOptions(models),
                    onPrimaryPressed: () =>
                        widget.onPrimaryAction(widget.entry),
                    onActionSelected: (action) =>
                        widget.onAction(widget.entry, action),
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

class _RowSelectionSlot extends StatelessWidget {
  final bool visible;
  final bool selected;
  final String fullName;
  final VoidCallback onPressed;

  const _RowSelectionSlot({
    required this.visible,
    required this.selected,
    required this.fullName,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 24,
        child: visible
            ? Align(
                alignment: Alignment.centerLeft,
                child: _RowCheckbox(
                  selected: selected,
                  label: selected ? 'Deselect $fullName' : 'Select $fullName',
                  onPressed: onPressed,
                ),
              )
            : null,
      );
}

class _RowCheckbox extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onPressed;

  const _RowCheckbox({
    required this.selected,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return m.Tooltip(
      message: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color:
                  selected ? theme.colorScheme.primary : theme.colorScheme.card,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.input,
              ),
            ),
            child: selected
                ? m.Icon(
                    m.Icons.check,
                    size: 12,
                    color: theme.colorScheme.primaryForeground,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _RowTitleLine extends StatelessWidget {
  static const m.Color urgentColor = m.Color(0xFFE8930C);

  final HomeRepositoryEntry entry;
  final GitAccount? account;
  final bool enrolled;
  final bool archiveEnabled;
  final Future<RepoAuthInfo> authInfo;
  final VoidCallback onAuthPressed;

  const _RowTitleLine({
    required this.entry,
    required this.account,
    required this.enrolled,
    required this.archiveEnabled,
    required this.authInfo,
    required this.onAuthPressed,
  });

  bool get _showAccountChip {
    GitAccount? current = account;
    if (current == null) {
      return false;
    }
    String? primaryId = loadPrimaryGitAccountId();
    return primaryId != null && current.id != primaryId;
  }

  bool get _showCountdown =>
      archiveEnabled &&
      entry.repoState == RepoState.active &&
      entry.daysUntilArchive <= 30;

  String get _countdownLabel => switch (entry.daysUntilArchive) {
        <= 0 => 'archive due',
        1 => '1d to archive',
        _ => '${entry.daysUntilArchive}d to archive',
      };

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Flexible(
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '${entry.dto.owner}/',
                  style: theme.typography.xSmall.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
                TextSpan(
                  text: entry.dto.name,
                  style: theme.typography.small.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (entry.dto.isPrivate) ...<Widget>[
          const Gap(6),
          m.Tooltip(
            message: 'Private repository',
            child: m.Icon(
              m.Icons.lock_outline,
              size: 11,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ],
        const Gap(AlembicShadcnTokens.gapSm),
        _RowStateMark(state: entry.repoState, syncing: entry.syncing),
        if (_showCountdown) ...<Widget>[
          const Gap(AlembicShadcnTokens.gapSm),
          Text(
            _countdownLabel,
            style: theme.typography.xSmall.copyWith(
              color: entry.daysUntilArchive <= 3
                  ? urgentColor
                  : theme.colorScheme.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (entry.dto.isArchived) ...<Widget>[
          const Gap(AlembicShadcnTokens.gapSm),
          const _MicroBadge(label: 'GH ARCHIVED'),
        ],
        if (_showAccountChip) ...<Widget>[
          const Gap(AlembicShadcnTokens.gapSm),
          _MicroBadge(label: account?.name ?? ''),
        ],
        if (enrolled) ...<Widget>[
          const Gap(AlembicShadcnTokens.gapSm),
          m.Tooltip(
            message: 'Archive Master',
            child: m.Icon(
              m.Icons.cloud_sync_outlined,
              size: 11,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ],
        _RowAuthWarning(authInfo: authInfo, onPressed: onAuthPressed),
      ],
    );
  }
}

class _RowStateMark extends StatelessWidget {
  static const m.Color localColor = m.Color(0xFF16A34A);
  static const m.Color archivedColor = m.Color(0xFF2563EB);
  static const m.Color syncingColor = m.Color(0xFFE8930C);

  final RepoState state;
  final bool syncing;

  const _RowStateMark({
    required this.state,
    required this.syncing,
  });

  String get _word => syncing
      ? 'Syncing'
      : switch (state) {
          RepoState.active => 'Local',
          RepoState.archived => 'Archived',
          RepoState.cloud => 'Cloud',
        };

  m.Color _dotColor(ThemeData theme) => syncing
      ? syncingColor
      : switch (state) {
          RepoState.active => localColor,
          RepoState.archived => archivedColor,
          RepoState.cloud => theme.colorScheme.mutedForeground,
        };

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: _dotColor(theme),
            shape: BoxShape.circle,
          ),
        ),
        const Gap(4),
        Text(
          _word,
          style: theme.typography.xSmall.copyWith(
            color: theme.colorScheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _MicroBadge extends StatelessWidget {
  final String label;

  const _MicroBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.typography.xSmall.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: theme.colorScheme.mutedForeground,
        ),
      ),
    );
  }
}

class _RowAuthWarning extends StatelessWidget {
  final Future<RepoAuthInfo> authInfo;
  final VoidCallback onPressed;

  const _RowAuthWarning({
    required this.authInfo,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<RepoAuthInfo>(
        future: authInfo,
        builder: (context, snapshot) {
          RepoAuthInfo? info = snapshot.data;
          if (info == null || !info.tokenMismatch) {
            return const SizedBox.shrink();
          }
          ThemeData theme = Theme.of(context);
          return Padding(
            padding: const EdgeInsets.only(left: AlembicShadcnTokens.gapSm),
            child: m.Tooltip(
              message:
                  'Token does not match any saved account. Click to change.',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPressed,
                  child: m.Icon(
                    m.Icons.vpn_key_outlined,
                    size: 12,
                    color: theme.colorScheme.destructive,
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class _RowTrailing extends StatelessWidget {
  static const double reservedWidth = 164;

  final RepositoryWork? work;
  final bool controlsVisible;
  final RepoState state;
  final List<AlembicDropdownOption<RepositoryTileAction>> options;
  final VoidCallback onPrimaryPressed;
  final ValueChanged<RepositoryTileAction> onActionSelected;

  const _RowTrailing({
    required this.work,
    required this.controlsVisible,
    required this.state,
    required this.options,
    required this.onPrimaryPressed,
    required this.onActionSelected,
  });

  String get _workLabel {
    RepositoryWork? current = work;
    if (current == null) {
      return '';
    }
    double? progress = current.progress;
    return progress == null
        ? current.message
        : '${current.message} ${(progress * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    RepositoryWork? current = work;
    if (current != null) {
      return SizedBox(
        width: reservedWidth,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            AlembicProgressMark(value: current.progress, size: 11),
            const Gap(6),
            Flexible(
              child: Text(
                _workLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
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
    return SizedBox(
      width: reservedWidth,
      child: IgnorePointer(
        ignoring: !controlsVisible,
        child: Opacity(
          opacity: controlsVisible ? 1 : 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _RowActionButton(
                label: state.primaryActionLabel,
                icon: state.primaryActionIcon,
                onPressed: onPrimaryPressed,
              ),
              const Gap(6),
              _RowOverflowButton(
                options: options,
                onSelected: onActionSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _RowActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return m.Material(
      color: m.Colors.transparent,
      child: m.InkWell(
        onTap: onPressed,
        canRequestFocus: false,
        borderRadius: BorderRadius.circular(AlembicShadcnTokens.controlRadius),
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.card,
            borderRadius:
                BorderRadius.circular(AlembicShadcnTokens.controlRadius),
            border: Border.all(color: theme.colorScheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              m.Icon(icon, size: 12, color: theme.colorScheme.foreground),
              const Gap(4),
              Text(
                label,
                style: theme.typography.xSmall.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowOverflowButton extends StatelessWidget {
  final List<AlembicDropdownOption<RepositoryTileAction>> options;
  final ValueChanged<RepositoryTileAction> onSelected;

  const _RowOverflowButton({
    required this.options,
    required this.onSelected,
  });

  Future<void> _showOptions(BuildContext context) async {
    ThemeData theme = Theme.of(context);
    RenderBox anchor = context.findRenderObject()! as RenderBox;
    RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    Offset topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    RelativeRect position = RelativeRect.fromRect(
      Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy + anchor.size.height + AlembicShadcnTokens.gapXs,
        anchor.size.width,
        1,
      ),
      Offset.zero & overlay.size,
    );
    RepositoryTileAction? selected = await m.showMenu<RepositoryTileAction>(
      context: context,
      position: position,
      color: theme.colorScheme.popover,
      surfaceTintColor: m.Colors.transparent,
      elevation: 0,
      constraints: const BoxConstraints(
        minWidth: 176,
        maxWidth: 300,
        maxHeight: AlembicShadcnTokens.dropdownMenuMaxHeight,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AlembicShadcnTokens.controlRadius),
        side: BorderSide(color: theme.colorScheme.border),
      ),
      items: <m.PopupMenuEntry<RepositoryTileAction>>[
        for (AlembicDropdownOption<RepositoryTileAction> option in options)
          m.PopupMenuItem<RepositoryTileAction>(
            value: option.value,
            padding: EdgeInsets.zero,
            height: 30,
            child: _RowOverflowItem(option: option),
          ),
      ],
    );
    if (selected != null && context.mounted) {
      onSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return m.Tooltip(
      message: 'Repository options',
      child: m.Material(
        color: m.Colors.transparent,
        child: Builder(
          builder: (context) => m.InkWell(
            onTap: () => _showOptions(context),
            canRequestFocus: false,
            borderRadius:
                BorderRadius.circular(AlembicShadcnTokens.controlRadius),
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.card,
                borderRadius:
                    BorderRadius.circular(AlembicShadcnTokens.controlRadius),
                border: Border.all(color: theme.colorScheme.border),
              ),
              child: m.Icon(
                m.Icons.more_horiz,
                size: 14,
                color: theme.colorScheme.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RowOverflowItem extends StatelessWidget {
  final AlembicDropdownOption<RepositoryTileAction> option;

  const _RowOverflowItem({required this.option});

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    m.Color foreground = option.destructive
        ? theme.colorScheme.destructive
        : theme.colorScheme.foreground;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: Row(
        children: <Widget>[
          if (option.icon != null) ...<Widget>[
            m.Icon(option.icon, size: 14, color: foreground),
            const Gap(AlembicShadcnTokens.gapSm),
          ],
          Expanded(
            child: Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.xSmall.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension RepoAuthMismatch on RepoAuthInfo {
  bool get tokenMismatch =>
      transport == RepoAuthTransport.httpsToken &&
      !tokenMatchesAccount &&
      isCloned;
}

extension RepositoryDescriptionClean on String {
  String? get cleanedDescription {
    String description = trim();
    return description.isEmpty ? null : description;
  }
}
