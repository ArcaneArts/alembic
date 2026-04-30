import 'package:alembic/core/repository_runtime.dart';
import 'package:alembic/presentation/home_view_state.dart';
import 'package:alembic/screen/home/home_repository_rows.dart';
import 'package:alembic/screen/home/home_tiles.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:alembic/util/git_accounts.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;
import 'package:github/github.dart';

class HomeRepositoryBrowserPane extends StatefulWidget {
  final HomeSelectionState selection;
  final RepositoryRuntime runtime;
  final int revision;
  final String? searchQuery;
  final List<Repository> repositories;
  final VoidCallback onImportRepository;
  final VoidCallback onOpenSettings;
  final RepositoryPrimaryActionCallback onPrimaryAction;
  final RepositoryActionCallback onRepositoryAction;
  final Future<void> Function(List<Repository> repositories) onCloneSelected;
  final bool Function(Repository repository) canForkRepository;
  final GitAccount? Function(Repository repository) accountForRepository;
  final bool archiveMasterRunning;

  const HomeRepositoryBrowserPane({
    super.key,
    required this.selection,
    required this.runtime,
    required this.revision,
    required this.searchQuery,
    required this.repositories,
    required this.onImportRepository,
    required this.onOpenSettings,
    required this.onPrimaryAction,
    required this.onRepositoryAction,
    required this.onCloneSelected,
    required this.canForkRepository,
    required this.accountForRepository,
    required this.archiveMasterRunning,
  });

  @override
  State<HomeRepositoryBrowserPane> createState() =>
      _HomeRepositoryBrowserPaneState();
}

class _HomeRepositoryBrowserPaneState extends State<HomeRepositoryBrowserPane> {
  static const String _repositoryListKeyPrefix = 'repository:';

  late final ScrollController _scrollController;
  final Set<String> _selectedRepositoryKeys = <String>{};

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

  bool get _isProjects => widget.selection.tab == HomeTab.active;

  bool get _isArchiveMaster => widget.selection.tab == HomeTab.archiveMaster;

  bool get _selectionEnabled =>
      widget.selection.tab == HomeTab.personal ||
      widget.selection.tab == HomeTab.organizations;

  int get _selectedCount => _selectedRepositories().length;

  String get _title => switch (widget.selection.tab) {
        HomeTab.active => 'Projects',
        HomeTab.personal => 'Mine',
        HomeTab.organizations =>
          widget.selection.organizationFilter.organizationLogin ??
              'Organizations',
        HomeTab.archiveMaster => 'Archive Master',
      };

  String get _subtitle {
    String? query = widget.searchQuery;
    if (query != null && query.trim().isNotEmpty) {
      int count = widget.repositories.length;
      return '$count match${count == 1 ? '' : 'es'}';
    }
    return switch (widget.selection.tab) {
      HomeTab.active => 'Local repositories in your workspace.',
      HomeTab.personal => 'Repositories from your account.',
      HomeTab.organizations => _organizationSubtitle(),
      HomeTab.archiveMaster => widget.archiveMasterRunning
          ? 'Archive Master is refreshing repositories now...'
          : 'Repositories tracked and pulled by Archive Master on a schedule.',
    };
  }

  String _organizationSubtitle() {
    String? selected = widget.selection.organizationFilter.organizationLogin;
    if (selected == null) {
      return 'Repositories across your organizations.';
    }
    return 'Repositories from $selected.';
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    int count = widget.repositories.length;
    String countLabel = '$count repositor${count == 1 ? 'y' : 'ies'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: AlembicShadcnTokens.rowPadding,
          child: AlembicSectionHeader(
            title: _title,
            subtitle: _subtitle,
            trailing: _buildHeaderActions(countLabel),
          ),
        ),
        m.Divider(
          height: 1,
          thickness: 1,
          color: theme.colorScheme.border,
        ),
        Expanded(
          child:
              widget.repositories.isEmpty ? _buildEmptyState() : _buildList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() => HomeSidebarEmptyState(
        title: _emptyTitle(),
        description: _emptyDescription(),
        primaryLabel: _isArchiveMaster ? 'Open Settings' : 'Clone Link',
        onPrimaryPressed: _isArchiveMaster
            ? widget.onOpenSettings
            : widget.onImportRepository,
        secondaryLabel: _isProjects ? 'Settings' : null,
        onSecondaryPressed: _isProjects ? widget.onOpenSettings : null,
      );

  Widget _buildHeaderActions(String countLabel) {
    if (!_selectionEnabled || widget.repositories.isEmpty) {
      return AlembicBadge(
        label: countLabel,
        tone: AlembicBadgeTone.outline,
      );
    }

    int selectedCount = _selectedCount;
    bool allSelected = selectedCount == widget.repositories.length;
    return Wrap(
      spacing: AlembicShadcnTokens.gapSm,
      runSpacing: AlembicShadcnTokens.gapSm,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        AlembicBadge(
          label: selectedCount == 0 ? countLabel : '$selectedCount selected',
          tone: AlembicBadgeTone.outline,
        ),
        AlembicToolbarButton(
          label: allSelected ? 'Clear' : 'Select all',
          leadingIcon: allSelected ? m.Icons.close : m.Icons.select_all,
          compact: true,
          onPressed: allSelected ? _clearSelection : _selectVisible,
        ),
        AlembicToolbarButton(
          label: 'Clone selected',
          leadingIcon: m.Icons.add_link,
          compact: true,
          prominent: selectedCount > 0,
          onPressed: selectedCount == 0 ? null : _cloneSelected,
        ),
      ],
    );
  }

  String _emptyTitle() {
    if (_isProjects) {
      return 'No projects';
    }
    if (_isArchiveMaster) {
      return 'No archive master targets';
    }
    return 'Nothing found';
  }

  String _emptyDescription() {
    if (_isArchiveMaster) {
      return 'Open Settings → Archive Master to enroll repositories or organizations and let Alembic keep them up to date.';
    }
    if (_isProjects) {
      return 'Use Clone Link, or browse Mine and Orgs to bring repositories into your workspace.';
    }
    return 'Try another search or change the organization filter.';
  }

  Widget _buildList() => m.Scrollbar(
        controller: _scrollController,
        child: m.CustomScrollView(
          controller: _scrollController,
          cacheExtent: AlembicShadcnTokens.listRowHeight * 8,
          slivers: <Widget>[
            m.SliverPadding(
              padding: const EdgeInsets.symmetric(
                vertical: AlembicShadcnTokens.gapSm,
              ),
              sliver: m.SliverList.separated(
                itemCount: widget.repositories.length,
                findItemIndexCallback: _findRepositoryIndex,
                separatorBuilder: (BuildContext context, int index) {
                  return const SizedBox(
                    height: AlembicShadcnTokens.gapXs,
                  );
                },
                itemBuilder: _buildRepositoryRow,
              ),
            ),
          ],
        ),
      );

  int? _findRepositoryIndex(m.Key key) {
    if (key is! m.ValueKey<String>) {
      return null;
    }
    String value = key.value;
    if (!value.startsWith(_repositoryListKeyPrefix)) {
      return null;
    }
    String fullName = value.substring(_repositoryListKeyPrefix.length);
    int repositoryIndex = widget.repositories.indexWhere(
      (Repository repository) {
        return repository.fullName.toLowerCase() == fullName;
      },
    );
    if (repositoryIndex < 0) {
      return null;
    }
    return repositoryIndex;
  }

  Widget _buildRepositoryRow(BuildContext context, int index) {
    Repository repository = widget.repositories[index];
    m.ValueKey<String> key = m.ValueKey<String>(
      '$_repositoryListKeyPrefix${repository.fullName.toLowerCase()}',
    );
    GitAccount? account = widget.accountForRepository(repository);
    if (_isProjects) {
      return LocalRepositoryRow(
        key: key,
        repository: repository,
        runtime: widget.runtime,
        revision: widget.revision,
        onPrimaryAction: widget.onPrimaryAction,
        onRepositoryAction: widget.onRepositoryAction,
        account: account,
      );
    }
    return BrowseRepositoryRow(
      key: key,
      repository: repository,
      runtime: widget.runtime,
      revision: widget.revision,
      onPrimaryAction: widget.onPrimaryAction,
      onRepositoryAction: widget.onRepositoryAction,
      canForkRepository: widget.canForkRepository,
      account: account,
      selectable: _selectionEnabled,
      selected: _selectedRepositoryKeys.contains(_repositoryKey(repository)),
      onSelectedChanged: (bool selected) => _toggleRepositorySelection(
        repository,
        selected,
      ),
    );
  }

  void _toggleRepositorySelection(Repository repository, bool selected) {
    String key = _repositoryKey(repository);
    setState(() {
      if (selected) {
        _selectedRepositoryKeys.add(key);
      } else {
        _selectedRepositoryKeys.remove(key);
      }
    });
  }

  void _selectVisible() {
    setState(() {
      for (Repository repository in widget.repositories) {
        _selectedRepositoryKeys.add(_repositoryKey(repository));
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedRepositoryKeys.clear();
    });
  }

  Future<void> _cloneSelected() async {
    List<Repository> selected = _selectedRepositories();
    if (selected.isEmpty) {
      return;
    }
    await widget.onCloneSelected(selected);
    if (!mounted) {
      return;
    }
    _clearSelection();
  }

  List<Repository> _selectedRepositories() {
    List<Repository> selected = <Repository>[];
    for (Repository repository in widget.repositories) {
      if (_selectedRepositoryKeys.contains(_repositoryKey(repository))) {
        selected.add(repository);
      }
    }
    return selected;
  }

  void _pruneSelection() {
    Set<String> visibleKeys = <String>{
      for (Repository repository in widget.repositories)
        _repositoryKey(repository),
    };
    _selectedRepositoryKeys.removeWhere(
      (String key) => !visibleKeys.contains(key),
    );
  }

  String _repositoryKey(Repository repository) =>
      repository.fullName.toLowerCase();
}
