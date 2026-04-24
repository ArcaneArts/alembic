import 'dart:async';
import 'dart:io';

import 'package:alembic/app/alembic_dialogs.dart';
import 'package:alembic/core/arcane_repository.dart';
import 'package:alembic/core/repository_runtime.dart';
import 'package:alembic/main.dart';
import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:alembic/presentation/home_view_state.dart';
import 'package:alembic/presentation/repository_action_catalog.dart';
import 'package:alembic/presentation/repository_action_model.dart';
import 'package:alembic/screen/home/home_controller.dart';
import 'package:alembic/screen/login.dart';
import 'package:alembic/screen/repository_settings.dart';
import 'package:alembic/screen/settings.dart';
import 'package:alembic/screen/splash.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:alembic/util/extensions.dart';
import 'package:alembic/util/repository_catalog.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:alembic/util/window.dart';
import 'package:alembic/widget/repository_tile_actions.dart';
import 'package:arcane/arcane.dart';
import 'package:fast_log/fast_log.dart';
import 'package:flutter/material.dart' as m;
import 'package:github/github.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';

enum _BulkAction {
  pullActive,
  archiveActive,
  updateArchives,
  activateArchives,
  activateEverything,
}

enum _TopMenuAction {
  workspaceFolder,
  archivesFolder,
  bulkActions,
  checkUpdates,
  restart,
  logout,
}

extension _BulkActionValues on _BulkAction {
  String get label => switch (this) {
        _BulkAction.pullActive => 'Pull active repositories',
        _BulkAction.archiveActive => 'Archive active repositories',
        _BulkAction.updateArchives => 'Refresh archived snapshots',
        _BulkAction.activateArchives => 'Reactivate archived repositories',
        _BulkAction.activateEverything => 'Activate every repository',
      };

  String get description => switch (this) {
        _BulkAction.pullActive =>
          'Run `git pull` across every currently active repository.',
        _BulkAction.archiveActive =>
          'Archive every active repository into local Alembic storage.',
        _BulkAction.updateArchives =>
          'Unarchive, pull, and re-compress every archived repository.',
        _BulkAction.activateArchives =>
          'Restore archived repositories back into the workspace.',
        _BulkAction.activateEverything =>
          'Clone or restore every visible repository into the workspace.',
      };
}

extension _TopMenuActionValues on _TopMenuAction {
  String get label => switch (this) {
        _TopMenuAction.workspaceFolder => 'Open workspace folder',
        _TopMenuAction.archivesFolder => 'Open archives folder',
        _TopMenuAction.bulkActions => 'Bulk actions',
        _TopMenuAction.checkUpdates => 'Check for updates',
        _TopMenuAction.restart => 'Restart app',
        _TopMenuAction.logout => 'Log out',
      };

  IconData get icon => switch (this) {
        _TopMenuAction.workspaceFolder => m.Icons.folder_open,
        _TopMenuAction.archivesFolder => m.Icons.archive_outlined,
        _TopMenuAction.bulkActions =>
          m.Icons.playlist_add_check_circle_outlined,
        _TopMenuAction.checkUpdates => m.Icons.system_update_alt,
        _TopMenuAction.restart => m.Icons.restart_alt,
        _TopMenuAction.logout => m.Icons.logout,
      };
}

extension _RepoStateValues on RepoState {
  String get label => switch (this) {
        RepoState.active => 'Local',
        RepoState.archived => 'Archived',
        RepoState.cloud => 'Remote',
      };

  String get primaryActionLabel => switch (this) {
        RepoState.active => 'Open',
        RepoState.archived => 'Activate',
        RepoState.cloud => 'Clone',
      };

  IconData get primaryActionIcon => switch (this) {
        RepoState.active => m.Icons.folder_open,
        RepoState.archived => m.Icons.unarchive_outlined,
        RepoState.cloud => m.Icons.add_link,
      };
}

class AlembicHome extends StatefulWidget {
  final GitHub github;
  final RepositoryRuntime runtime;

  const AlembicHome({
    super.key,
    required this.github,
    required this.runtime,
  });

  @override
  State<AlembicHome> createState() => _AlembicHomeState();
}

class _AlembicHomeState extends State<AlembicHome> {
  late Future<List<Repository>> allRepos;
  late final HomeController _controller;
  late final m.TextEditingController searchController;
  StreamSubscription<int>? _runtimeSubscription;
  HomeSelectionState _selection = const HomeSelectionState.initial();
  String? _searchQuery;
  int _repositoryRevision = 0;

  Map<Organization, List<Repository>> get orgRepos => _controller.orgRepos;

  List<Repository> get personalRepos => _controller.personalRepos;

  List<Repository> get active => widget.runtime.activeRepositories;

  BehaviorSubject<int> get fetching => _controller.fetching;

  BehaviorSubject<double?> get progress => _controller.progress;

  @override
  void initState() {
    super.initState();
    searchController = m.TextEditingController();
    _controller = HomeController(
      github: widget.github,
      runtime: widget.runtime,
    );
    _selection = HomeSelectionState.initial().copyWith(
      tab: _restoreLastHomeTab(),
    );
    allRepos = _controller.initialize(updateTokens: false);
    allRepos.then((List<Repository> _) => _showTokenUpdateSummaryIfNeeded());
    _runtimeSubscription = widget.runtime.changed.stream.listen((_) {
      if (mounted) {
        _repositoryRevision++;
        setState(() {});
      }
    });
    _scheduleTokenMigrationPrompt();
    unawaited(checkForUpdates(force: false));
  }

  @override
  void dispose() {
    searchController.dispose();
    _runtimeSubscription?.cancel();
    unawaited(_controller.dispose());
    super.dispose();
  }

  HomeTab _restoreLastHomeTab() {
    String storedTab =
        boxSettings.get('last_home_tab', defaultValue: HomeTab.active.name);
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
    boxSettings.put('last_home_tab', tab.name);
  }

  void _selectOrganizationFilter(OrganizationFilter filter) {
    setState(() {
      _selection = _selection.copyWith(
        organizationFilter: filter,
      );
    });
  }

  void _showProjects() {
    setState(() {
      _selection = _selection.copyWith(
        tab: HomeTab.active,
      );
    });
  }

  Future<void> _reloadRepositories({bool updateTokens = false}) async {
    await _controller.reloadRepositories(updateTokens: false);
    allRepos = _controller.allRepos;
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

  ArcaneRepository _repositoryFor(Repository repository) {
    return _controller.repositoryFor(repository);
  }

  Future<Repository?> _resolveRepositoryRef(RepositoryRef ref) {
    return _controller.resolveRepositoryRef(ref);
  }

  Repository? _localFallbackRepository(RepositoryRef ref) {
    return _controller.localFallbackRepository(ref);
  }

  void _scheduleTokenMigrationPrompt() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      bool shouldPrompt =
          await _controller.consumeClassicTokenMigrationPrompt();
      if (!shouldPrompt || !mounted) {
        return;
      }
      bool confirmed = await showAlembicConfirmDialog(
        context,
        title: 'GitHub Token Update Recommended',
        description:
            "GitHub is deprecating classic tokens. We recommend using a fine-grained token with 'repo' and 'read:org'.",
        confirmText: 'Update Token',
        cancelText: 'Continue',
      );
      if (!confirmed) {
        return;
      }
      await _clearTokenAndNavigateToLogin();
    });
  }

  Future<void> _clearTokenAndNavigateToLogin() async {
    await box.deleteAll(<String>['1', 'authenticated', 'token_type']);
    if (!mounted) {
      return;
    }
    widget.github.dispose();
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      m.MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<bool> checkForUpdates({required bool force}) async {
    if (!force) {
      if (boxSettings.get('achup', defaultValue: true) != true) {
        return false;
      }
    }

    try {
      http.Response response = await http.get(
        Uri.parse(
          'https://raw.githubusercontent.com/ArcaneArts/alembic/refs/heads/main/version',
        ),
      );
      if (response.statusCode != 200) {
        error('Failed to fetch version file. Status: ${response.statusCode}');
        return false;
      }

      String liveVersion = response.body.trim();
      String currentVersion = packageInfo.version.trim();
      if (liveVersion == currentVersion) {
        info('The app is up to date (version: $currentVersion)');
        return false;
      }

      if (!mounted) {
        return true;
      }
      bool confirmed = await showAlembicConfirmDialog(
        context,
        title: 'Alembic $liveVersion Available',
        description:
            'A new version is available for ${DesktopPlatformAdapter.instance.currentPlatform.name}. Download it now?',
        confirmText: 'Download',
        cancelText: 'Later',
      );
      if (!confirmed) {
        return true;
      }
      await _downloadUpdate(liveVersion);
      return true;
    } catch (e) {
      error('Error checking for updates: $e');
      return false;
    }
  }

  Future<void> _downloadUpdate(String liveVersion) async {
    DesktopPlatformAdapter adapter = DesktopPlatformAdapter.instance;
    String temporaryDirectory = (await getTemporaryDirectory()).absolute.path;
    String path = adapter.updateDownloadPath(
      temporaryDirectory: temporaryDirectory,
      version: liveVersion,
    );
    String url = adapter.updateDownloadUrl(liveVersion);

    await File(path).absolute.parent.create(recursive: true);
    verbose('Downloading $url to $path');

    http.Request request = http.Request('GET', Uri.parse(url));
    http.StreamedResponse streamedResponse = await http.Client().send(request);
    IOSink sink = File(path).openWrite();
    await streamedResponse.stream.pipe(sink);
    await sink.close();

    await adapter.launchDownloadedUpdate(path);
    warn('Shutting down Alembic so the update can be installed');
    await windowManager.destroy();
    exit(0);
  }

  Future<void> _executeBulkOperation(
    Iterable<Repository> repositories,
    Future<void> Function(ArcaneRepository repository) operation,
  ) async {
    await _controller.executeBulkOperation(repositories, operation);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _executeBulkAction(_BulkAction action) async {
    if (action == _BulkAction.pullActive) {
      await _executeBulkOperation(
        active,
        (ArcaneRepository repository) =>
            repository.ensureRepositoryUpdated(widget.github),
      );
      return;
    }

    if (action == _BulkAction.archiveActive) {
      await _executeBulkOperation(
        active,
        (ArcaneRepository repository) => repository.archive(),
      );
      return;
    }

    List<Repository> repositories = await allRepos;
    if (action == _BulkAction.updateArchives) {
      await _executeBulkOperation(
        repositories.where(
          (Repository repository) => _repositoryFor(repository).isArchivedSync,
        ),
        (ArcaneRepository repository) =>
            repository.updateArchive(widget.github),
      );
      return;
    }

    if (action == _BulkAction.activateArchives) {
      await _executeBulkOperation(
        repositories.where(
          (Repository repository) => _repositoryFor(repository).isArchivedSync,
        ),
        (ArcaneRepository repository) =>
            repository.unarchive(widget.github, waitForPull: true),
      );
      return;
    }

    await _executeBulkOperation(
      repositories,
      (ArcaneRepository repository) =>
          repository.ensureRepositoryActive(widget.github),
    );
  }

  Future<void> _showBulkActionsDialog() async {
    List<_BulkAction> actions = <_BulkAction>[
      if (active.isNotEmpty) _BulkAction.pullActive,
      if (active.isNotEmpty) _BulkAction.archiveActive,
      _BulkAction.updateArchives,
      _BulkAction.activateArchives,
      _BulkAction.activateEverything,
    ];

    _BulkAction? selected = await m.showDialog<_BulkAction>(
      context: context,
      builder: (BuildContext dialogContext) {
        return m.Dialog(
          child: AlembicPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const AlembicSectionHeader(
                  title: 'Bulk Actions',
                  subtitle: 'Run repository operations across larger sets.',
                ),
                const Gap(AlembicShadcnTokens.gapLg),
                ...actions.map((action) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: AlembicShadcnTokens.gapSm,
                    ),
                    child: _BulkActionTile(
                      action: action,
                      onPressed: () => Navigator.of(dialogContext).pop(action),
                    ),
                  );
                }),
                const Gap(8),
                Align(
                  alignment: Alignment.centerRight,
                  child: AlembicToolbarButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    label: 'Close',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }
    await _executeBulkAction(selected);
  }

  Future<void> _handleTopMenuSelection(_TopMenuAction action) async {
    DesktopPlatformAdapter adapter = DesktopPlatformAdapter.instance;
    String workspacePath = expandPath(config.workspaceDirectory);
    String archivePath =
        '${expandPath(config.archiveDirectory)}/archives'.replaceAll('//', '/');

    if (action == _TopMenuAction.workspaceFolder) {
      await adapter.openInFileExplorer(Directory(workspacePath).absolute.path);
      return;
    }

    if (action == _TopMenuAction.archivesFolder) {
      await adapter.openInFileExplorer(Directory(archivePath).absolute.path);
      return;
    }

    if (action == _TopMenuAction.bulkActions) {
      await _showBulkActionsDialog();
      return;
    }

    if (action == _TopMenuAction.checkUpdates) {
      bool updated = await checkForUpdates(force: true);
      if (!updated && mounted) {
        await showAlembicInfoDialog(
          context,
          title: 'No Updates',
          message:
              'Alembic is already up to date. If a release is expected, try again later.',
        );
      }
      return;
    }

    if (action == _TopMenuAction.restart) {
      if (!mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        m.MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
        (_) => false,
      );
      return;
    }

    bool confirmed = await showAlembicConfirmDialog(
      context,
      title: 'Log out?',
      description: 'Your token will be deleted from this device. Continue?',
      confirmText: 'Log Out',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    await box.deleteAll(<String>['1', 'authenticated', 'token_type']);
    if (!mounted) {
      return;
    }
    widget.github.dispose();
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      m.MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  Future<void> _importRepository() async {
    String? rawInput = await showAlembicInputDialog(
      context,
      title: 'Clone Repository Link',
      description: 'Paste a GitHub URL or owner/repo value.',
      placeholder: 'https://github.com/owner/repo or owner/repo',
      confirmText: 'Clone',
    );
    if (rawInput == null || rawInput.trim().isEmpty) {
      return;
    }

    RepositoryRef? ref = parseRepositoryRef(rawInput);
    if (ref == null) {
      if (!mounted) {
        return;
      }
      await showAlembicInfoDialog(
        context,
        title: 'Invalid Repository',
        message: 'Enter a valid GitHub repository URL or owner/repo value.',
      );
      return;
    }

    await addManualRepoRef(ref);
    await _reloadRepositories();
    Repository? resolved =
        await _resolveRepositoryRef(ref) ?? _localFallbackRepository(ref);

    if (!mounted) {
      return;
    }
    if (resolved == null) {
      await showAlembicInfoDialog(
        context,
        title: 'Repository Saved',
        message:
            'Saved ${ref.fullName}. Metadata is unavailable right now, but the repository remains in your catalog.',
      );
      return;
    }

    bool cloneNow = await showAlembicConfirmDialog(
      context,
      title: 'Clone ${resolved.fullName}?',
      description: 'The repository has been saved. Clone it now?',
      confirmText: 'Clone',
      cancelText: 'Later',
    );
    if (!cloneNow) {
      return;
    }

    ArcaneRepository repository = _repositoryFor(resolved);
    try {
      await repository.ensureRepositoryActive(widget.github);
      await _reloadRepositories();
      _showProjects();
    } catch (e) {
      if (!mounted) {
        return;
      }
      await showAlembicInfoDialog(
        context,
        title: 'Clone Failed',
        message: '$e',
      );
    }
  }

  List<Repository> _repositoriesForCurrentSelection(
    List<Repository> allRepositories,
  ) =>
      switch (_selection.tab) {
        HomeTab.active => _sortedProjects(allRepositories, _searchQuery),
        HomeTab.personal => _sortedPersonal(_searchQuery),
        HomeTab.organizations => _organizationRepositories(_searchQuery),
      };

  List<Repository> _sortedProjects(
    List<Repository> allRepositories,
    String? query,
  ) {
    List<Repository> repositories = allRepositories
        .where((Repository repo) {
          return _repositoryFor(repo).isActiveSync;
        })
        .toList()
        .filterBy(query);
    repositories.sort((Repository a, Repository b) {
      int lastOpenComparison = (getRepoConfig(b).lastOpen ?? 0)
          .compareTo(getRepoConfig(a).lastOpen ?? 0);
      if (lastOpenComparison != 0) {
        return lastOpenComparison;
      }
      return a.fullName.compareTo(b.fullName);
    });
    return repositories;
  }

  List<Repository> _sortedPersonal(String? query) {
    List<Repository> repositories = <Repository>[
      ...personalRepos.filterBy(query)
    ];
    repositories.sort(
      (Repository a, Repository b) => a.fullName.compareTo(b.fullName),
    );
    return repositories;
  }

  List<Repository> _organizationRepositories(String? query) {
    if (_selection.organizationFilter.isAll) {
      List<Organization> organizations = orgRepos.keys.toList()
        ..sort((Organization a, Organization b) {
          return (a.login ?? '').compareTo(b.login ?? '');
        });
      List<Repository> repositories = <Repository>[];
      for (Organization organization in organizations) {
        repositories.addAll(orgRepos[organization]!.filterBy(query));
      }
      return repositories;
    }

    String? selectedLogin = _selection.organizationFilter.organizationLogin;
    if (selectedLogin == null) {
      return <Repository>[];
    }

    for (Organization organization in orgRepos.keys) {
      String login = organization.login ?? '';
      if (login == selectedLogin) {
        return orgRepos[organization]!.filterBy(query);
      }
    }

    return <Repository>[];
  }

  List<String> _organizationLogins() {
    List<String> logins = <String>[];
    for (Organization organization in orgRepos.keys) {
      String login = organization.login ?? 'unknown';
      logins.add(login);
    }
    logins.sort();
    return logins;
  }

  bool _canForkRepository(Repository repository) {
    String currentLogin =
        (boxSettings.get('current_user_login', defaultValue: '') as String)
            .trim()
            .toLowerCase();
    String ownerLogin = (repository.owner?.login ?? '').trim().toLowerCase();
    return ownerLogin.isNotEmpty &&
        currentLogin.isNotEmpty &&
        ownerLogin != currentLogin;
  }

  Future<void> _dispatchRepositoryAction({
    required Repository repository,
    required RepoState state,
    required List<String> work,
    required RepositoryTileAction action,
  }) async {
    String owner = repository.owner?.login ?? 'unknown';
    String baseUrl = 'https://github.com/$owner/${repository.name}';
    RepositoryTileActionDispatcher dispatcher =
        const RepositoryTileActionDispatcher();
    _HomeRepositoryOperations operations = _HomeRepositoryOperations(
      context: context,
      repository: repository,
      arcaneRepository: _repositoryFor(repository),
      github: widget.github,
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
    ArcaneRepository arcaneRepository = _repositoryFor(repository);
    if (state == RepoState.active) {
      await arcaneRepository.open(widget.github, context);
      await _reloadRepositories();
      return;
    }

    if (state == RepoState.archived) {
      await arcaneRepository.unarchive(widget.github, waitForPull: true);
      await _reloadRepositories();
      return;
    }

    await arcaneRepository.ensureRepositoryActive(widget.github);
    await _reloadRepositories();
  }

  @override
  Widget build(BuildContext context) {
    return m.Scaffold(
      backgroundColor: m.Colors.transparent,
      body: AlembicScaffold(
        child: FutureBuilder<List<Repository>>(
          future: allRepos,
          builder:
              (BuildContext context, AsyncSnapshot<List<Repository>> snapshot) {
            if (!snapshot.hasData) {
              return _LoadingState(fetching: fetching);
            }

            List<Repository> allRepositories = snapshot.data!;
            List<Repository> visibleRepositories =
                _repositoriesForCurrentSelection(allRepositories);

            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                List<_TopMenuAction> topMenuActions = _buildTopMenuActions();
                Widget topBar = _HomeTopBar(
                  selection: _selection,
                  progress: progress,
                  searchController: searchController,
                  organizationLogins: _organizationLogins(),
                  topMenuActions: topMenuActions,
                  onOpenSettings: () => unawaited(showSettingsModal(context)),
                  onSearchChanged: (String value) {
                    setState(() {
                      String query = value.trim();
                      _searchQuery = query.isEmpty ? null : query;
                    });
                  },
                  onTabSelected: _selectHomeTab,
                  onOrganizationFilterSelected: _selectOrganizationFilter,
                  onImportRepository: () => unawaited(_importRepository()),
                  onTopMenuSelected: (action) =>
                      unawaited(_handleTopMenuSelection(action)),
                );
                Widget content = _RepositoryBrowserPane(
                  selection: _selection,
                  runtime: widget.runtime,
                  revision: _repositoryRevision,
                  searchQuery: _searchQuery,
                  repositories: visibleRepositories,
                  onImportRepository: () => unawaited(_importRepository()),
                  onOpenSettings: () => unawaited(showSettingsModal(context)),
                  onPrimaryAction: _openPrimaryRepositoryAction,
                  onRepositoryAction: _dispatchRepositoryAction,
                  canForkRepository: _canForkRepository,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    topBar,
                    const Gap(AlembicShadcnTokens.gapMd),
                    Expanded(child: content),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<_TopMenuAction> _buildTopMenuActions() {
    String workspacePath = expandPath(config.workspaceDirectory);
    String archivePath =
        '${expandPath(config.archiveDirectory)}/archives'.replaceAll('//', '/');

    return <_TopMenuAction>[
      if (Directory(workspacePath).existsSync()) _TopMenuAction.workspaceFolder,
      if (Directory(archivePath).existsSync()) _TopMenuAction.archivesFolder,
      _TopMenuAction.bulkActions,
      _TopMenuAction.checkUpdates,
      _TopMenuAction.restart,
      _TopMenuAction.logout,
    ];
  }
}

class _HomeTopBar extends StatelessWidget {
  final HomeSelectionState selection;
  final BehaviorSubject<double?> progress;
  final m.TextEditingController searchController;
  final List<String> organizationLogins;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<HomeTab> onTabSelected;
  final ValueChanged<OrganizationFilter> onOrganizationFilterSelected;
  final VoidCallback onOpenSettings;
  final VoidCallback onImportRepository;
  final List<_TopMenuAction> topMenuActions;
  final ValueChanged<_TopMenuAction> onTopMenuSelected;

  const _HomeTopBar({
    required this.selection,
    required this.progress,
    required this.searchController,
    required this.organizationLogins,
    required this.onSearchChanged,
    required this.onTabSelected,
    required this.onOrganizationFilterSelected,
    required this.onOpenSettings,
    required this.onImportRepository,
    required this.topMenuActions,
    required this.onTopMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    List<AlembicDropdownOption<_TopMenuAction>> menuOptions =
        <AlembicDropdownOption<_TopMenuAction>>[
      for (_TopMenuAction action in topMenuActions)
        AlembicDropdownOption<_TopMenuAction>(
          value: action,
          label: action.label,
          icon: action.icon,
        ),
    ];
    String selectedOrganization =
        selection.organizationFilter.organizationLogin ?? '__all__';
    List<AlembicDropdownOption<String>> organizationOptions =
        <AlembicDropdownOption<String>>[
      const AlembicDropdownOption<String>(
        value: '__all__',
        label: 'All organizations',
      ),
      for (String organization in organizationLogins)
        AlembicDropdownOption<String>(
          value: organization,
          label: organization,
        ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        bool collapseToIcons = constraints.maxWidth < 420;
        Widget navigation = AlembicTabs<HomeTab>(
          value: selection.tab,
          onChanged: onTabSelected,
          collapsed: collapseToIcons,
          items: const <AlembicNavigationItem<HomeTab>>[
            AlembicNavigationItem<HomeTab>(
              value: HomeTab.active,
              label: 'Local',
              icon: m.Icons.folder_open,
              tooltip: 'Local',
            ),
            AlembicNavigationItem<HomeTab>(
              value: HomeTab.personal,
              label: 'Personal',
              icon: m.Icons.person_outline,
              tooltip: 'Personal',
            ),
            AlembicNavigationItem<HomeTab>(
              value: HomeTab.organizations,
              label: 'Teams',
              icon: m.Icons.apartment_outlined,
              tooltip: 'Teams',
            ),
          ],
        );
        Widget searchField = AlembicTextInput(
          controller: searchController,
          placeholder: 'Search repositories',
          leading: const m.Icon(m.Icons.search, size: 16),
          onChanged: onSearchChanged,
        );
        Widget organizationField = AlembicSelect<String>(
          value: selectedOrganization,
          options: organizationOptions,
          onChanged: (String value) {
            if (value == '__all__') {
              onOrganizationFilterSelected(const OrganizationFilter.all());
              return;
            }
            onOrganizationFilterSelected(
              OrganizationFilter.organization(value),
            );
          },
          leadingIcon: m.Icons.apartment_outlined,
          compact: false,
        );
        Widget appActions = Wrap(
          spacing: AlembicShadcnTokens.gapSm,
          runSpacing: AlembicShadcnTokens.gapSm,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            SizedBox(
              width: collapseToIcons
                  ? AlembicShadcnTokens.commandIconWidth
                  : AlembicShadcnTokens.commandButtonWidth,
              child: AlembicToolbarButton(
                label: 'Clone',
                leadingIcon: m.Icons.add_link,
                onPressed: onImportRepository,
                prominent: true,
                iconOnly: collapseToIcons,
                tooltip: 'Clone repository',
              ),
            ),
            SizedBox(
              width: AlembicShadcnTokens.commandIconWidth,
              child: AlembicToolbarButton(
                label: 'Settings',
                leadingIcon: m.Icons.tune,
                onPressed: onOpenSettings,
                iconOnly: true,
                tooltip: 'Settings',
              ),
            ),
            SizedBox(
              width: AlembicShadcnTokens.commandIconWidth,
              child: AlembicOverflowMenu<_TopMenuAction>(
                label: 'More options',
                items: menuOptions,
                onSelected: onTopMenuSelected,
              ),
            ),
          ],
        );
        Widget searchRow = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            searchField,
            if (selection.tab == HomeTab.organizations) ...<Widget>[
              const Gap(AlembicShadcnTokens.gapSm),
              organizationField,
            ],
          ],
        );
        Widget progressBar = StreamBuilder<double?>(
          stream: progress.stream,
          initialData: progress.valueOrNull,
          builder: (BuildContext context, AsyncSnapshot<double?> snapshot) {
            double? value = snapshot.data;
            if (value == null) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: AlembicShadcnTokens.gapMd),
              child: _HeaderProgressBar(value: value),
            );
          },
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const Expanded(
                  child: _RailBrand(compact: true),
                ),
                const Gap(AlembicShadcnTokens.gapMd),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: appActions,
                  ),
                ),
              ],
            ),
            const Gap(AlembicShadcnTokens.gapMd),
            Align(
              alignment: Alignment.centerLeft,
              child: navigation,
            ),
            const Gap(AlembicShadcnTokens.gapMd),
            searchRow,
            progressBar,
          ],
        );
      },
    );
  }
}

class _RepositoryBrowserPane extends StatefulWidget {
  final HomeSelectionState selection;
  final RepositoryRuntime runtime;
  final int revision;
  final String? searchQuery;
  final List<Repository> repositories;
  final VoidCallback onImportRepository;
  final VoidCallback onOpenSettings;
  final Future<void> Function({
    required Repository repository,
    required RepoState state,
  }) onPrimaryAction;
  final Future<void> Function({
    required Repository repository,
    required RepoState state,
    required List<String> work,
    required RepositoryTileAction action,
  }) onRepositoryAction;
  final bool Function(Repository repository) canForkRepository;

  const _RepositoryBrowserPane({
    required this.selection,
    required this.runtime,
    required this.revision,
    required this.searchQuery,
    required this.repositories,
    required this.onImportRepository,
    required this.onOpenSettings,
    required this.onPrimaryAction,
    required this.onRepositoryAction,
    required this.canForkRepository,
  });

  @override
  State<_RepositoryBrowserPane> createState() => _RepositoryBrowserPaneState();
}

class _RepositoryBrowserPaneState extends State<_RepositoryBrowserPane> {
  static const String _repositoryListKeyPrefix = 'repository:';

  late final ScrollController _scrollController;

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

  bool get _isProjects => widget.selection.tab == HomeTab.active;

  String get _title => switch (widget.selection.tab) {
        HomeTab.active => 'Projects',
        HomeTab.personal => 'Mine',
        HomeTab.organizations =>
          widget.selection.organizationFilter.organizationLogin ??
              'Organizations',
      };

  String get _subtitle {
    if (widget.searchQuery != null && widget.searchQuery!.trim().isNotEmpty) {
      return '${widget.repositories.length} match${widget.repositories.length == 1 ? '' : 'es'}';
    }
    return switch (widget.selection.tab) {
      HomeTab.active => 'Local repositories in your workspace.',
      HomeTab.personal => 'Repositories from your account.',
      HomeTab.organizations => widget
                  .selection.organizationFilter.organizationLogin ==
              null
          ? 'Repositories across your organizations.'
          : 'Repositories from ${widget.selection.organizationFilter.organizationLogin}.',
    };
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: AlembicShadcnTokens.rowPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _title,
                      style: theme.typography.medium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      _subtitle,
                      style: theme.typography.xSmall.copyWith(
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${widget.repositories.length} repositories',
                style: theme.typography.xSmall.copyWith(
                  color: theme.colorScheme.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        m.Divider(
          height: 1,
          thickness: 1,
          color: theme.colorScheme.border,
        ),
        Expanded(
          child: widget.repositories.isEmpty
              ? _SidebarEmptyState(
                  title: _isProjects ? 'No projects' : 'Nothing found',
                  description: _isProjects
                      ? 'Use Clone Link, or browse Mine and Orgs to bring repositories into your workspace.'
                      : 'Try another search or change the organization filter.',
                  primaryLabel: 'Clone Link',
                  onPrimaryPressed: widget.onImportRepository,
                  secondaryLabel: _isProjects ? 'Settings' : null,
                  onSecondaryPressed:
                      _isProjects ? widget.onOpenSettings : null,
                )
              : m.Scrollbar(
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
                          findItemIndexCallback: (key) {
                            if (key is! m.ValueKey<String>) {
                              return null;
                            }
                            String value = key.value;
                            if (!value.startsWith(_repositoryListKeyPrefix)) {
                              return null;
                            }
                            String fullName = value.substring(
                              _repositoryListKeyPrefix.length,
                            );
                            int repositoryIndex =
                                widget.repositories.indexWhere(
                              (Repository repository) {
                                return repository.fullName.toLowerCase() ==
                                    fullName;
                              },
                            );
                            if (repositoryIndex < 0) {
                              return null;
                            }
                            return repositoryIndex;
                          },
                          separatorBuilder: (BuildContext context, int index) {
                            return const SizedBox(
                              height: AlembicShadcnTokens.gapXs,
                            );
                          },
                          itemBuilder: (BuildContext context, int index) {
                            Repository repository = widget.repositories[index];
                            m.ValueKey<String> key = m.ValueKey<String>(
                              '$_repositoryListKeyPrefix${repository.fullName.toLowerCase()}',
                            );
                            if (_isProjects) {
                              return _LocalRepositoryRow(
                                key: key,
                                repository: repository,
                                runtime: widget.runtime,
                                revision: widget.revision,
                                onPrimaryAction: widget.onPrimaryAction,
                                onRepositoryAction: widget.onRepositoryAction,
                              );
                            }
                            return _BrowseRepositoryRow(
                              key: key,
                              repository: repository,
                              runtime: widget.runtime,
                              revision: widget.revision,
                              onPrimaryAction: widget.onPrimaryAction,
                              onRepositoryAction: widget.onRepositoryAction,
                              canForkRepository: widget.canForkRepository,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _LocalRepositoryRow extends StatefulWidget {
  final Repository repository;
  final RepositoryRuntime runtime;
  final int revision;
  final Future<void> Function({
    required Repository repository,
    required RepoState state,
  }) onPrimaryAction;
  final Future<void> Function({
    required Repository repository,
    required RepoState state,
    required List<String> work,
    required RepositoryTileAction action,
  }) onRepositoryAction;

  const _LocalRepositoryRow({
    super.key,
    required this.repository,
    required this.runtime,
    required this.revision,
    required this.onPrimaryAction,
    required this.onRepositoryAction,
  });

  @override
  State<_LocalRepositoryRow> createState() => _LocalRepositoryRowState();
}

class _LocalRepositoryRowState extends State<_LocalRepositoryRow> {
  late Stream<List<String>> _workStream;
  late Future<int> _daysUntilArchival;

  @override
  void initState() {
    super.initState();
    _configureRepository();
  }

  @override
  void didUpdateWidget(covariant _LocalRepositoryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository.fullName != widget.repository.fullName ||
        oldWidget.runtime != widget.runtime ||
        oldWidget.revision != widget.revision) {
      _configureRepository();
    }
  }

  void _configureRepository() {
    ArcaneRepository arcaneRepository = ArcaneRepository(
      repository: widget.repository,
      runtime: widget.runtime,
    );
    _workStream = arcaneRepository.streamWork();
    _daysUntilArchival = arcaneRepository.daysUntilArchival;
  }

  @override
  Widget build(BuildContext context) {
    List<RepositoryActionModel> stateActions =
        RepositoryActionCatalog.stateActions(RepoState.active);
    List<RepositoryActionModel> localActions =
        RepositoryActionCatalog.localActions(
      includeExplorer: true,
      explorerName: DesktopPlatformAdapter.instance.fileExplorerName,
    );
    List<RepositoryActionModel> menuActions = <RepositoryActionModel>[
      RepositoryActionCatalog.find(stateActions, RepositoryTileAction.pull),
      RepositoryActionCatalog.find(localActions, RepositoryTileAction.details),
      RepositoryActionCatalog.find(
          localActions, RepositoryTileAction.openFinder),
      RepositoryActionCatalog.find(localActions, RepositoryTileAction.settings),
      RepositoryActionCatalog.find(stateActions, RepositoryTileAction.archive),
      ...RepositoryActionCatalog.githubActions(),
      RepositoryActionCatalog.find(
          stateActions, RepositoryTileAction.deleteRepository),
    ];

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
              description: _cleanDescription(widget.repository.description),
              meta: <Widget>[
                AlembicMetaText(
                  label: widget.repository.isPrivate == true
                      ? 'Private'
                      : 'Public',
                ),
                AlembicBadge(
                  label:
                      '$daysUntilArchive day${daysUntilArchive == 1 ? '' : 's'} to archive',
                ),
                if (work.isNotEmpty)
                  AlembicMetaText(
                    label: work.join(' • '),
                  ),
              ],
              primaryAction: AlembicToolbarButton(
                label: 'Open',
                leadingIcon: RepoState.active.primaryActionIcon,
                onPressed: () => widget.onPrimaryAction(
                  repository: widget.repository,
                  state: RepoState.active,
                ),
                prominent: true,
              ),
              secondaryActions: AlembicOverflowMenu<RepositoryTileAction>(
                label: 'Repository options',
                items: _menuOptions(menuActions),
                onSelected: (RepositoryTileAction action) =>
                    widget.onRepositoryAction(
                  repository: widget.repository,
                  state: RepoState.active,
                  work: work,
                  action: action,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _BrowseRepositoryRow extends StatefulWidget {
  final Repository repository;
  final RepositoryRuntime runtime;
  final int revision;
  final Future<void> Function({
    required Repository repository,
    required RepoState state,
  }) onPrimaryAction;
  final Future<void> Function({
    required Repository repository,
    required RepoState state,
    required List<String> work,
    required RepositoryTileAction action,
  }) onRepositoryAction;
  final bool Function(Repository repository) canForkRepository;

  const _BrowseRepositoryRow({
    super.key,
    required this.repository,
    required this.runtime,
    required this.revision,
    required this.onPrimaryAction,
    required this.onRepositoryAction,
    required this.canForkRepository,
  });

  @override
  State<_BrowseRepositoryRow> createState() => _BrowseRepositoryRowState();
}

class _BrowseRepositoryRowState extends State<_BrowseRepositoryRow> {
  late Stream<List<String>> _workStream;
  late Future<RepoState> _state;

  @override
  void initState() {
    super.initState();
    _configureRepository();
  }

  @override
  void didUpdateWidget(covariant _BrowseRepositoryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository.fullName != widget.repository.fullName ||
        oldWidget.runtime != widget.runtime ||
        oldWidget.revision != widget.revision) {
      _configureRepository();
    }
  }

  void _configureRepository() {
    ArcaneRepository arcaneRepository = ArcaneRepository(
      repository: widget.repository,
      runtime: widget.runtime,
    );
    _workStream = arcaneRepository.streamWork();
    _state = arcaneRepository.state;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RepoState>(
      future: _state,
      builder: (BuildContext context, AsyncSnapshot<RepoState> stateSnapshot) {
        RepoState state = stateSnapshot.data ?? RepoState.cloud;
        List<RepositoryActionModel> stateActions =
            RepositoryActionCatalog.stateActions(state);
        List<RepositoryActionModel> linkActions =
            RepositoryActionCatalog.linkActions(
          canFork: widget.canForkRepository(widget.repository),
          explorerName: DesktopPlatformAdapter.instance.fileExplorerName,
          includeExplorer: state == RepoState.active,
        );
        List<RepositoryActionModel> menuActions = <RepositoryActionModel>[
          ...stateActions.where((RepositoryActionModel model) {
            return model.action != RepositoryTileAction.clone &&
                model.action != RepositoryTileAction.activate;
          }),
          ...linkActions.where((RepositoryActionModel model) {
            return model.action != RepositoryTileAction.viewGithub;
          }),
        ];

        return StreamBuilder<List<String>>(
          stream: _workStream,
          initialData: const <String>[],
          builder:
              (BuildContext context, AsyncSnapshot<List<String>> workSnapshot) {
            List<String> work = workSnapshot.data ?? const <String>[];
            return AlembicListRow(
              title: widget.repository.name,
              subtitle: widget.repository.fullName,
              description: _cleanDescription(widget.repository.description),
              meta: <Widget>[
                _RepoStateBadge(state: state),
                AlembicMetaText(
                  label: widget.repository.isPrivate == true
                      ? 'Private'
                      : 'Public',
                ),
                if (work.isNotEmpty)
                  AlembicMetaText(
                    label: work.join(' • '),
                  ),
              ],
              primaryAction: AlembicToolbarButton(
                label: state.primaryActionLabel,
                leadingIcon: state.primaryActionIcon,
                onPressed: () => widget.onPrimaryAction(
                  repository: widget.repository,
                  state: state,
                ),
                prominent: true,
              ),
              secondaryActions: Wrap(
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
                    items: _menuOptions(menuActions),
                    onSelected: (RepositoryTileAction action) =>
                        widget.onRepositoryAction(
                      repository: widget.repository,
                      state: state,
                      work: work,
                      action: action,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

String? _cleanDescription(String? value) {
  String description = (value ?? '').trim();
  if (description.isEmpty) {
    return null;
  }
  return description;
}

List<AlembicDropdownOption<RepositoryTileAction>> _menuOptions(
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

class _RailBrand extends StatelessWidget {
  final bool compact;

  const _RailBrand({
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Text title = Text(
      'Alembic',
      style: theme.typography.small.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
    Text version = Text(
      packageInfo.version,
      style: theme.typography.xSmall.copyWith(
        color: theme.colorScheme.mutedForeground,
        fontWeight: FontWeight.w600,
      ),
    );

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _RailBrandGlyph(compact: true),
          const Gap(10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              title,
              const Gap(AlembicShadcnTokens.gapSm),
              version,
            ],
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _RailBrandGlyph(compact: compact),
        const Gap(AlembicShadcnTokens.gapMd),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            title,
            const Gap(2),
            Text(
              'Desktop workspace',
              style: theme.typography.xSmall.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
        if (compact) ...<Widget>[
          const Gap(AlembicShadcnTokens.gapMd),
          version,
        ],
      ],
    );
  }
}

class _RailBrandGlyph extends StatelessWidget {
  final bool compact;

  const _RailBrandGlyph({
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Container(
      width: compact ? 30 : 34,
      height: compact ? 30 : 34,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary,
        borderRadius: BorderRadius.circular(AlembicShadcnTokens.controlRadius),
        border: Border.all(color: theme.colorScheme.border),
      ),
      alignment: Alignment.center,
      child: m.Icon(
        m.Icons.auto_awesome_motion_outlined,
        size: compact ? 15 : 18,
        color: theme.colorScheme.foreground,
      ),
    );
  }
}

class _HeaderProgressBar extends StatelessWidget {
  final double value;

  const _HeaderProgressBar({
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AlembicShadcnTokens.badgeRadius),
      child: m.LinearProgressIndicator(
        minHeight: 3,
        value: value == 0 ? null : value,
        backgroundColor: theme.colorScheme.secondary,
        valueColor: AlwaysStoppedAnimation<Color>(
          theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _RepoStateBadge extends StatelessWidget {
  final RepoState state;

  const _RepoStateBadge({
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

class _ActionTile extends StatelessWidget {
  final String label;
  final String? description;
  final VoidCallback onPressed;
  final bool prominent;

  const _ActionTile({
    required this.label,
    this.description,
    required this.onPressed,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color background =
        prominent ? theme.colorScheme.secondary : theme.colorScheme.background;
    Color border = theme.colorScheme.border;
    Color titleColor = theme.colorScheme.foreground;

    return m.InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AlembicShadcnTokens.controlRadius),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: background,
          borderRadius:
              BorderRadius.circular(AlembicShadcnTokens.controlRadius),
          border: Border.all(color: border),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: theme.typography.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  if (description != null) ...<Widget>[
                    const Gap(4),
                    Text(
                      description!,
                      style: theme.typography.xSmall.copyWith(
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Gap(AlembicShadcnTokens.gapMd),
            m.Icon(
              m.Icons.arrow_forward,
              size: 16,
              color: titleColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _BulkActionTile extends StatelessWidget {
  final _BulkAction action;
  final VoidCallback onPressed;

  const _BulkActionTile({
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return _ActionTile(
      label: action.label,
      description: action.description,
      onPressed: onPressed,
      prominent: action == _BulkAction.pullActive ||
          action == _BulkAction.activateEverything,
    );
  }
}

class _SidebarEmptyState extends StatelessWidget {
  final String title;
  final String description;
  final String? primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;

  const _SidebarEmptyState({
    required this.title,
    required this.description,
    this.primaryLabel,
    this.onPrimaryPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return m.SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            m.Icon(
              m.Icons.search_off,
              size: 28,
              color: theme.colorScheme.mutedForeground,
            ),
            const Gap(10),
            Text(
              title,
              style: theme.typography.large.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Gap(6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.typography.small.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
            ),
            if (primaryLabel != null || secondaryLabel != null) ...<Widget>[
              const Gap(AlembicShadcnTokens.gapLg),
              Wrap(
                spacing: AlembicShadcnTokens.gapSm,
                runSpacing: AlembicShadcnTokens.gapSm,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  if (secondaryLabel != null)
                    AlembicToolbarButton(
                      label: secondaryLabel!,
                      onPressed: onSecondaryPressed,
                    ),
                  if (primaryLabel != null)
                    AlembicToolbarButton(
                      label: primaryLabel!,
                      onPressed: onPrimaryPressed,
                      prominent: true,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  final BehaviorSubject<int> fetching;

  const _LoadingState({
    required this.fetching,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AlembicPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                width: 28,
                height: 28,
                child: m.CircularProgressIndicator(strokeWidth: 2.6),
              ),
              const Gap(18),
              Text(
                'Loading repositories',
                style: theme.typography.large.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(8),
              StreamBuilder<int>(
                stream: fetching.stream,
                initialData: fetching.valueOrNull ?? 0,
                builder:
                    (BuildContext context, AsyncSnapshot<int> fetchSnapshot) {
                  int count = fetchSnapshot.data ?? 0;
                  return Text(
                    count > 0
                        ? 'Indexed $count repositories so far.'
                        : 'Connecting to GitHub and building the repository catalog.',
                    textAlign: TextAlign.center,
                    style: theme.typography.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeRepositoryOperations implements RepositoryTileActionOperations {
  final BuildContext context;
  final Repository repository;
  final ArcaneRepository arcaneRepository;
  final GitHub github;
  final RepositoryRuntime runtime;
  final RepoState state;
  final List<String> work;
  final Future<void> Function() onChanged;

  const _HomeRepositoryOperations({
    required this.context,
    required this.repository,
    required this.arcaneRepository,
    required this.github,
    required this.runtime,
    required this.state,
    required this.work,
    required this.onChanged,
  });

  @override
  Future<void> showDetails() async {
    String owner = repository.owner?.login ?? 'unknown';
    String workLabel = work.isEmpty ? 'None' : work.join(', ');
    List<String> lines = <String>[
      'State: ${state.label}',
      'Owner: $owner',
      'Work: $workLabel',
      'Workspace: ${arcaneRepository.repoPath}',
      'Archive: ${arcaneRepository.imagePath}',
    ];
    if (state == RepoState.active) {
      int daysUntilArchive = await arcaneRepository.daysUntilArchival;
      lines.add('Auto-archive in: $daysUntilArchive day(s)');
    }
    if (!context.mounted) {
      return;
    }
    await showAlembicInfoDialog(
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
    await onChanged();
  }

  @override
  Future<void> openSettings() =>
      showRepositorySettingsModal(context, repository);

  @override
  Future<void> openExternalUrl(String url) => launchUrlString(url);

  @override
  Future<void> pull() async {
    await arcaneRepository.ensureRepositoryUpdated(github);
    await onChanged();
  }

  @override
  Future<void> archive() async {
    await arcaneRepository.archive();
    await onChanged();
  }

  @override
  Future<void> deleteRepository() async {
    await arcaneRepository.deleteRepository();
    await onChanged();
  }

  @override
  Future<void> activate() async {
    await arcaneRepository.unarchive(github);
    await onChanged();
  }

  @override
  Future<void> updateArchive() async {
    await arcaneRepository.updateArchive(github);
    await onChanged();
  }

  @override
  Future<void> deleteArchive() async {
    await arcaneRepository.deleteArchive();
    await onChanged();
  }

  @override
  Future<void> cloneRepository() async {
    await arcaneRepository.ensureRepositoryActive(github);
    await onChanged();
  }

  @override
  Future<void> archiveFromCloud() async {
    await arcaneRepository.archiveFromCloud(github);
    await onChanged();
  }

  @override
  Future<void> forkAndClone() async {
    try {
      await arcaneRepository.forkAndClone(github);
      await onChanged();
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      await showAlembicInfoDialog(
        context,
        title: 'Fork Failed',
        message: '$e',
      );
    }
  }

  @override
  Future<bool> confirmDeleteRepository() {
    return showAlembicConfirmDialog(
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
    return showAlembicConfirmDialog(
      context,
      title: 'Delete archive ${repository.fullName}?',
      description:
          'Delete this archived image from local storage. Any unsynced local changes inside the archive will be lost.',
      confirmText: 'Delete Archive',
      destructive: true,
    );
  }
}
