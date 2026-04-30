import 'dart:async';

import 'package:alembic/app/alembic_dialogs.dart';
import 'package:alembic/core/account_registry.dart';
import 'package:alembic/core/arcane_repository.dart';
import 'package:alembic/core/archive_master_service.dart';
import 'package:alembic/core/repository_runtime.dart';
import 'package:alembic/main.dart';
import 'package:alembic/presentation/home_view_state.dart';
import 'package:alembic/screen/home/home_actions.dart';
import 'package:alembic/screen/home/home_bulk_actions.dart';
import 'package:alembic/screen/home/home_controller.dart';
import 'package:alembic/screen/home/home_menu_handler.dart';
import 'package:alembic/screen/home/home_repository_browser.dart';
import 'package:alembic/screen/home/home_repository_importer.dart';
import 'package:alembic/screen/home/home_repository_operations.dart';
import 'package:alembic/screen/home/home_session.dart';
import 'package:alembic/screen/home/home_tiles.dart';
import 'package:alembic/screen/home/home_top_bar.dart';
import 'package:alembic/screen/home/home_update_checker.dart';
import 'package:alembic/screen/settings.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:alembic/widget/repository_tile_actions.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;
import 'package:github/github.dart';

class AlembicHome extends StatefulWidget {
  final AccountRegistry registry;
  final RepositoryRuntime runtime;
  final ArchiveMasterService archiveMasterService;

  const AlembicHome({
    super.key,
    required this.registry,
    required this.runtime,
    required this.archiveMasterService,
  });

  @override
  State<AlembicHome> createState() => _AlembicHomeState();
}

class _AlembicHomeState extends State<AlembicHome> {
  static const String _lastHomeTabSettingsKey = 'last_home_tab';

  late Future<List<Repository>> _allRepositories;
  late final HomeController _controller;
  late final HomeBulkActionsCoordinator _bulkActions;
  late final HomeSessionGuard _session;
  late final HomeRepositoryImporter _importer;
  late final HomeTopMenuHandler _menuHandler;
  late final m.TextEditingController _searchController;
  final HomeUpdateChecker _updateChecker = const HomeUpdateChecker();
  StreamSubscription<int>? _runtimeSubscription;
  StreamSubscription<bool>? _archiveMasterRunningSubscription;
  HomeSelectionState _selection = const HomeSelectionState.initial();
  String? _searchQuery;
  int _repositoryRevision = 0;
  bool _archiveMasterRunning = false;

  @override
  void initState() {
    super.initState();
    _searchController = m.TextEditingController();
    _controller = HomeController(
      registry: widget.registry,
      runtime: widget.runtime,
    );
    _session = HomeSessionGuard(
      controller: _controller,
      registry: widget.registry,
    );
    _bulkActions = HomeBulkActionsCoordinator(
      controller: _controller,
      runtime: widget.runtime,
      getAllRepositories: () => _allRepositories,
      onChanged: _refreshState,
    );
    _importer = HomeRepositoryImporter(
      controller: _controller,
      onReload: _reloadRepositories,
      onTabSelected: _setActiveTab,
    );
    _menuHandler = HomeTopMenuHandler(
      bulkActions: _bulkActions,
      session: _session,
      updateChecker: _updateChecker,
    );
    _selection = HomeSelectionState.initial().copyWith(
      tab: _restoreLastHomeTab(),
    );
    _allRepositories = _controller.initialize(updateTokens: false);
    _allRepositories.then(
      (List<Repository> _) => _showTokenUpdateSummaryIfNeeded(),
    );
    _runtimeSubscription = widget.runtime.changed.stream.listen((_) {
      if (!mounted) {
        return;
      }
      _repositoryRevision++;
      setState(() {});
    });
    _archiveMasterRunningSubscription =
        widget.archiveMasterService.isRunning.stream.listen((bool running) {
      if (!mounted) {
        return;
      }
      setState(() {
        _archiveMasterRunning = running;
      });
    });
    setArchiveMasterService(widget.archiveMasterService);
    widget.archiveMasterService.start();
    _scheduleTokenMigrationPrompt();
    unawaited(_updateChecker.check(context: context, force: false));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _runtimeSubscription?.cancel();
    _archiveMasterRunningSubscription?.cancel();
    unawaited(_controller.dispose());
    if (identical(archiveMasterService, widget.archiveMasterService)) {
      setArchiveMasterService(null);
    }
    unawaited(widget.archiveMasterService.dispose());
    super.dispose();
  }

  void _refreshState() {
    if (mounted) {
      setState(() {});
    }
  }

  HomeTab _restoreLastHomeTab() {
    String storedTab = boxSettings.get(
      _lastHomeTabSettingsKey,
      defaultValue: HomeTab.active.name,
    );
    for (HomeTab tab in HomeTab.values) {
      if (tab.name == storedTab) {
        return tab;
      }
    }
    return HomeTab.active;
  }

  void _selectHomeTab(HomeTab tab) {
    if (tab == _selection.tab) {
      return;
    }
    HomeSelectionState nextSelection = _selection.copyWith(
      tab: tab,
      organizationFilter: tab == HomeTab.organizations
          ? _selection.organizationFilter
          : const OrganizationFilter.all(),
    );
    setState(() {
      _selection = nextSelection;
    });
    boxSettings.put(_lastHomeTabSettingsKey, tab.name);
  }

  void _setActiveTab(HomeTab tab) {
    setState(() {
      _selection = _selection.copyWith(tab: tab);
    });
  }

  void _selectOrganizationFilter(OrganizationFilter filter) {
    setState(() {
      _selection = _selection.copyWith(organizationFilter: filter);
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      String query = value.trim();
      _searchQuery = query.isEmpty ? null : query;
    });
  }

  Future<void> _reloadRepositories({bool updateTokens = false}) async {
    await _controller.reloadRepositories(updateTokens: false);
    _allRepositories = _controller.allRepos;
    if (updateTokens) {
      await _showTokenUpdateSummaryIfNeeded();
    }
    if (mounted) {
      _repositoryRevision++;
      setState(() {});
    }
  }

  Future<void> _showTokenUpdateSummaryIfNeeded() async {
    int updated = await _controller.updateAllRepositoryTokens();
    if (updated > 0 && mounted) {
      await showAlembicInfoDialog(
        context,
        title: 'Token Update',
        message: 'Updated tokens for $updated repositories.',
      );
    }
  }

  void _scheduleTokenMigrationPrompt() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await _session.promptTokenMigrationIfNeeded(context);
    });
  }

  Future<void> _dispatchRepositoryAction({
    required Repository repository,
    required RepoState state,
    required List<String> work,
    required RepositoryTileAction action,
  }) async {
    String owner = repository.owner?.login ?? 'unknown';
    String baseUrl = 'https://github.com/$owner/${repository.name}';
    const RepositoryTileActionDispatcher dispatcher =
        RepositoryTileActionDispatcher();
    HomeRepositoryOperations operations = HomeRepositoryOperations(
      context: context,
      repository: repository,
      arcaneRepository: _controller.repositoryFor(repository),
      github: _controller.githubForRepository(repository),
      runtime: widget.runtime,
      state: state,
      work: work,
      onChanged: () => _reloadRepositories(),
    );
    await dispatcher.dispatch(
      action: action,
      operations: operations,
      baseUrl: baseUrl,
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openPrimaryRepositoryAction({
    required Repository repository,
    required RepoState state,
  }) async {
    GitHub gitHub = _controller.githubForRepository(repository);
    ArcaneRepository arcaneRepository = _controller.repositoryFor(repository);
    if (state == RepoState.active) {
      await arcaneRepository.open(gitHub, context);
      await _reloadRepositories();
      return;
    }
    if (state == RepoState.archived) {
      await arcaneRepository.unarchive(gitHub, waitForPull: true);
      await _reloadRepositories();
      return;
    }
    await arcaneRepository.ensureRepositoryActive(gitHub);
    await _reloadRepositories();
  }

  Future<void> _cloneSelectedRepositories(List<Repository> repositories) async {
    await _bulkActions.executeOperation(
      repositories,
      (ArcaneRepository repository) => repository.ensureRepositoryActive(
        _controller.githubForRepository(repository.repository),
      ),
      label: 'Cloning selected repositories',
    );
    await _reloadRepositories();
  }

  void _openSettings() {
    unawaited(showSettingsModal(context));
  }

  void _openImport() {
    unawaited(_importer.import(context));
  }

  void _openTopMenuAction(HomeTopMenuAction action) {
    unawaited(_menuHandler.handle(context, action));
  }

  @override
  Widget build(BuildContext context) {
    return m.Scaffold(
      backgroundColor: m.Colors.transparent,
      body: AlembicScaffold(
        child: FutureBuilder<List<Repository>>(
          future: _allRepositories,
          builder: (
            BuildContext context,
            AsyncSnapshot<List<Repository>> snapshot,
          ) {
            if (!snapshot.hasData) {
              return HomeLoadingState(fetching: _controller.fetching);
            }
            List<Repository> allRepositories = snapshot.data!;
            List<Repository> visibleRepositories =
                _controller.repositoriesForSelection(
              selection: _selection,
              query: _searchQuery,
              all: allRepositories,
            );
            return _buildHomeLayout(visibleRepositories);
          },
        ),
      ),
    );
  }

  Widget _buildHomeLayout(List<Repository> visibleRepositories) {
    ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HomeTopBar(
          selection: _selection,
          progress: _controller.progress,
          progressLabel: _controller.progressLabel,
          searchController: _searchController,
          organizationLogins: _controller.organizationLogins(),
          topMenuActions: _menuHandler.availableActions(),
          onOpenSettings: _openSettings,
          onSearchChanged: _onSearchChanged,
          onTabSelected: _selectHomeTab,
          onOrganizationFilterSelected: _selectOrganizationFilter,
          onImportRepository: _openImport,
          onTopMenuSelected: _openTopMenuAction,
        ),
        const Gap(AlembicShadcnTokens.gapMd),
        m.Divider(
          height: 1,
          thickness: 1,
          color: theme.colorScheme.border,
        ),
        const Gap(AlembicShadcnTokens.gapSm),
        Expanded(
          child: HomeRepositoryBrowserPane(
            selection: _selection,
            runtime: widget.runtime,
            revision: _repositoryRevision,
            searchQuery: _searchQuery,
            repositories: visibleRepositories,
            onImportRepository: _openImport,
            onOpenSettings: _openSettings,
            onPrimaryAction: _openPrimaryRepositoryAction,
            onRepositoryAction: _dispatchRepositoryAction,
            onCloneSelected: _cloneSelectedRepositories,
            canForkRepository: _controller.canForkRepository,
            accountForRepository: _controller.accountForRepository,
            archiveMasterRunning: _archiveMasterRunning,
          ),
        ),
      ],
    );
  }
}
