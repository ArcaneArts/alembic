import 'package:alembic/core/repository_runtime.dart';
import 'package:alembic/screen/home/home_repository_rows.dart';
import 'package:alembic/screen/home/home_tiles.dart';
import 'package:alembic/screen/home/home_view_filters.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:alembic/util/git_accounts.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;
import 'package:github/github.dart';

class HomeRepositoryBrowserPane extends StatefulWidget {
  final List<HomeRepositoryEntry> entries;
  final int totalCount;
  final RepositoryRuntime runtime;
  final int revision;
  final bool archiveEnabled;
  final HomeFilterState filters;
  final GitAccount? Function(Repository repository) accountForRepository;
  final bool Function(Repository repository) canForkRepository;
  final HomeEntryCallback onPrimaryAction;
  final HomeEntryActionCallback onRepositoryAction;
  final HomeEntryCallback onShowDetails;
  final Future<void> Function(List<HomeRepositoryEntry> entries)
      onCloneSelected;
  final VoidCallback onClearFilters;
  final VoidCallback onImportRepository;

  const HomeRepositoryBrowserPane({
    super.key,
    required this.entries,
    required this.totalCount,
    required this.runtime,
    required this.revision,
    required this.archiveEnabled,
    required this.filters,
    required this.accountForRepository,
    required this.canForkRepository,
    required this.onPrimaryAction,
    required this.onRepositoryAction,
    required this.onShowDetails,
    required this.onCloneSelected,
    required this.onClearFilters,
    required this.onImportRepository,
  });

  @override
  State<HomeRepositoryBrowserPane> createState() =>
      _HomeRepositoryBrowserPaneState();
}

class _HomeRepositoryBrowserPaneState extends State<HomeRepositoryBrowserPane> {
  static const String _repositoryListKeyPrefix = 'repository:';

  late final ScrollController _scrollController;
  final Set<String> _selectedKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeRepositoryBrowserPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pruneSelection();
  }

  String get _subtitle {
    if (widget.filters.hasActiveFilters) {
      int count = widget.entries.length;
      return '$count matching ${widget.totalCount} total';
    }
    return '${widget.totalCount} repositor${widget.totalCount == 1 ? 'y' : 'ies'}';
  }

  List<HomeRepositoryEntry> get _selectedEntries => widget.entries
      .where((entry) => _selectedKeys.contains(entry.lowerKey))
      .toList();

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: AlembicShadcnTokens.gapMd),
          child: AlembicSectionHeader(
            title: 'Repositories',
            subtitle: _subtitle,
            trailing: widget.entries.isEmpty
                ? null
                : _HeaderActions(
                    totalVisible: widget.entries.length,
                    selectedCount: _selectedEntries.length,
                    onSelectAll: _selectVisible,
                    onClearSelection: _clearSelection,
                    onCloneSelected: _cloneSelected,
                  ),
          ),
        ),
        m.Divider(
          height: 1,
          thickness: 1,
          color: theme.colorScheme.border,
        ),
        Expanded(
          child: widget.entries.isEmpty
              ? _EmptyBrowser(
                  hasActiveFilters: widget.filters.hasActiveFilters,
                  onClearFilters: widget.onClearFilters,
                  onImportRepository: widget.onImportRepository,
                )
              : _RepositoryList(
                  scrollController: _scrollController,
                  entries: widget.entries,
                  runtime: widget.runtime,
                  revision: widget.revision,
                  archiveEnabled: widget.archiveEnabled,
                  keyPrefix: _repositoryListKeyPrefix,
                  selectedKeys: _selectedKeys,
                  accountForRepository: widget.accountForRepository,
                  canForkRepository: widget.canForkRepository,
                  onPrimaryAction: widget.onPrimaryAction,
                  onRepositoryAction: widget.onRepositoryAction,
                  onShowDetails: widget.onShowDetails,
                  onSelectedChanged: _toggleSelection,
                ),
        ),
      ],
    );
  }

  void _toggleSelection(HomeRepositoryEntry entry, bool selected) {
    setState(() {
      if (selected) {
        _selectedKeys.add(entry.lowerKey);
      } else {
        _selectedKeys.remove(entry.lowerKey);
      }
    });
  }

  void _selectVisible() {
    setState(() {
      for (HomeRepositoryEntry entry in widget.entries) {
        _selectedKeys.add(entry.lowerKey);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedKeys.clear();
    });
  }

  Future<void> _cloneSelected() async {
    List<HomeRepositoryEntry> selected = _selectedEntries;
    if (selected.isEmpty) {
      return;
    }
    await widget.onCloneSelected(selected);
    if (!mounted) {
      return;
    }
    _clearSelection();
  }

  void _pruneSelection() {
    Set<String> visibleKeys = <String>{
      for (HomeRepositoryEntry entry in widget.entries) entry.lowerKey,
    };
    _selectedKeys.removeWhere((key) => !visibleKeys.contains(key));
  }
}

class _HeaderActions extends StatelessWidget {
  final int totalVisible;
  final int selectedCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onCloneSelected;

  const _HeaderActions({
    required this.totalVisible,
    required this.selectedCount,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onCloneSelected,
  });

  @override
  Widget build(BuildContext context) {
    bool allSelected = selectedCount == totalVisible;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (selectedCount > 0) ...<Widget>[
          AlembicBadge(
            label: '$selectedCount selected',
            tone: AlembicBadgeTone.outline,
          ),
          const Gap(AlembicShadcnTokens.gapSm),
        ],
        AlembicToolbarButton(
          label: allSelected ? 'Clear' : 'Select all',
          leadingIcon: allSelected ? m.Icons.close : m.Icons.select_all,
          compact: true,
          onPressed: allSelected ? onClearSelection : onSelectAll,
        ),
        const Gap(AlembicShadcnTokens.gapSm),
        AlembicToolbarButton(
          label: 'Clone selected',
          leadingIcon: m.Icons.add_link,
          compact: true,
          prominent: selectedCount > 0,
          onPressed: selectedCount == 0 ? null : onCloneSelected,
        ),
      ],
    );
  }
}

class _EmptyBrowser extends StatelessWidget {
  final bool hasActiveFilters;
  final VoidCallback onClearFilters;
  final VoidCallback onImportRepository;

  const _EmptyBrowser({
    required this.hasActiveFilters,
    required this.onClearFilters,
    required this.onImportRepository,
  });

  @override
  Widget build(BuildContext context) {
    if (hasActiveFilters) {
      return HomeSidebarEmptyState(
        title: 'No repositories match',
        description: 'Try another search, state, or owner filter.',
        primaryLabel: 'Clear filters',
        onPrimaryPressed: onClearFilters,
      );
    }
    return HomeSidebarEmptyState(
      title: 'No repositories yet',
      description:
          'Use Clone Link to bring a repository into your workspace, or refresh to fetch from GitHub.',
      primaryLabel: 'Clone Link',
      onPrimaryPressed: onImportRepository,
    );
  }
}

class _RepositoryList extends StatelessWidget {
  final ScrollController scrollController;
  final List<HomeRepositoryEntry> entries;
  final RepositoryRuntime runtime;
  final int revision;
  final bool archiveEnabled;
  final String keyPrefix;
  final Set<String> selectedKeys;
  final GitAccount? Function(Repository repository) accountForRepository;
  final bool Function(Repository repository) canForkRepository;
  final HomeEntryCallback onPrimaryAction;
  final HomeEntryActionCallback onRepositoryAction;
  final HomeEntryCallback onShowDetails;
  final void Function(HomeRepositoryEntry entry, bool selected)
      onSelectedChanged;

  const _RepositoryList({
    required this.scrollController,
    required this.entries,
    required this.runtime,
    required this.revision,
    required this.archiveEnabled,
    required this.keyPrefix,
    required this.selectedKeys,
    required this.accountForRepository,
    required this.canForkRepository,
    required this.onPrimaryAction,
    required this.onRepositoryAction,
    required this.onShowDetails,
    required this.onSelectedChanged,
  });

  int? _findRepositoryIndex(m.Key key) {
    if (key is! m.ValueKey<String>) {
      return null;
    }
    String value = key.value;
    if (!value.startsWith(keyPrefix)) {
      return null;
    }
    String fullName = value.substring(keyPrefix.length);
    int repositoryIndex =
        entries.indexWhere((entry) => entry.lowerKey == fullName);
    return repositoryIndex < 0 ? null : repositoryIndex;
  }

  @override
  Widget build(BuildContext context) => m.Scrollbar(
        controller: scrollController,
        child: m.CustomScrollView(
          controller: scrollController,
          cacheExtent: AlembicShadcnTokens.listRowHeight * 8,
          slivers: <Widget>[
            m.SliverPadding(
              padding: const EdgeInsets.symmetric(
                vertical: AlembicShadcnTokens.gapSm,
              ),
              sliver: m.SliverList.builder(
                itemCount: entries.length,
                findChildIndexCallback: _findRepositoryIndex,
                itemBuilder: (context, index) {
                  HomeRepositoryEntry entry = entries[index];
                  return Padding(
                    key: m.ValueKey<String>('$keyPrefix${entry.lowerKey}'),
                    padding: EdgeInsets.only(
                      bottom: index == entries.length - 1
                          ? 0
                          : AlembicShadcnTokens.gapXs,
                    ),
                    child: HomeRepositoryRow(
                      entry: entry,
                      runtime: runtime,
                      revision: revision,
                      archiveEnabled: archiveEnabled,
                      account: accountForRepository(entry.repository),
                      canFork: canForkRepository(entry.repository),
                      selectable: true,
                      selected: selectedKeys.contains(entry.lowerKey),
                      onSelectedChanged: (selected) =>
                          onSelectedChanged(entry, selected),
                      onPrimaryAction: onPrimaryAction,
                      onAction: onRepositoryAction,
                      onShowDetails: onShowDetails,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
}
