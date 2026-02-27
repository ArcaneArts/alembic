import 'dart:async';
import 'dart:io';

import 'package:alembic/core/arcane_repository.dart';
import 'package:alembic/core/repository_runtime.dart';
import 'package:alembic/main.dart';
import 'package:alembic/presentation/home_view_state.dart';
import 'package:alembic/screen/home/home_controller.dart';
import 'package:alembic/screen/login.dart';
import 'package:alembic/screen/settings.dart';
import 'package:alembic/screen/splash.dart';
import 'package:alembic/theme/alembic_motion.dart';
import 'package:alembic/theme/alembic_tokens.dart';
import 'package:alembic/util/extensions.dart';
import 'package:alembic/util/repository_catalog.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:alembic/widget/glass_context_menu.dart';
import 'package:alembic/widget/glass_drag_strip.dart';
import 'package:alembic/widget/glass_icon_button.dart';
import 'package:alembic/widget/glass_modal_overlay.dart';
import 'package:alembic/widget/glass_panel.dart';
import 'package:alembic/widget/glass_segmented_control.dart';
import 'package:alembic/widget/glass_shell.dart';
import 'package:alembic/widget/glass_text_field.dart';
import 'package:alembic/widget/glass_button.dart';
import 'package:alembic/widget/repository_tile.dart';
import 'package:fast_log/fast_log.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:github/github.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
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
  importRepository,
  bulkActions,
  settings,
  checkUpdates,
  restart,
  logout,
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
  final TextEditingController searchController = TextEditingController();
  final ScrollController _organizationScrollController = ScrollController();
  StreamSubscription<int>? _runtimeSubscription;
  String? _searchQuery;

  Map<Organization, List<Repository>> get orgRepos => _controller.orgRepos;

  List<Repository> get personalRepos => _controller.personalRepos;

  List<Repository> get active => widget.runtime.activeRepositories;

  BehaviorSubject<int> get fetching => _controller.fetching;

  BehaviorSubject<double?> get progress => _controller.progress;

  HomeTab selectedTab = HomeTab.active;
  OrganizationFilter organizationFilter = const OrganizationFilter.all();

  Future<void> _reloadRepositories({bool updateTokens = false}) async {
    await _controller.reloadRepositories(updateTokens: false);
    allRepos = _controller.allRepos;
    if (updateTokens) {
      await _showTokenUpdateSummaryIfNeeded();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showTokenUpdateSummaryIfNeeded() async {
    int updated = await _controller.updateAllRepositoryTokens();
    if (updated > 0 && mounted) {
      await showGlassInfoDialog(
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

  @override
  void initState() {
    super.initState();
    _controller = HomeController(
      github: widget.github,
      runtime: widget.runtime,
    );
    _restoreLastHomeTab();
    allRepos = _controller.initialize(updateTokens: false);
    allRepos.then((List<Repository> _) => _showTokenUpdateSummaryIfNeeded());
    _runtimeSubscription = widget.runtime.changed.stream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
    _scheduleTokenMigrationPrompt();
    checkForUpdates(context);
  }

  @override
  void dispose() {
    searchController.dispose();
    _organizationScrollController.dispose();
    _runtimeSubscription?.cancel();
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _restoreLastHomeTab() {
    String storedTab =
        boxSettings.get('last_home_tab', defaultValue: HomeTab.active.name);
    HomeTab restoredTab = HomeTab.active;
    for (HomeTab tab in HomeTab.values) {
      if (tab.name == storedTab) {
        restoredTab = tab;
      }
    }
    selectedTab = restoredTab;
  }

  void _selectHomeTab(HomeTab tab) {
    if (tab == selectedTab) {
      return;
    }

    setState(() {
      selectedTab = tab;
      if (tab != HomeTab.organizations) {
        organizationFilter = const OrganizationFilter.all();
      }
    });

    boxSettings.put('last_home_tab', tab.name);
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
      bool confirmed = await showGlassConfirmDialog(
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
      CupertinoPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<bool> checkForUpdates(BuildContext context,
      {bool force = false}) async {
    if (!force) {
      if (kDebugMode || kProfileMode) {
        return false;
      }
      if (!boxSettings.get("achup", defaultValue: true)) {
        return false;
      }
    }

    try {
      http.Response response = await http.get(
        Uri.parse(
          'https://raw.githubusercontent.com/ArcaneArts/alembic/refs/heads/main/version',
        ),
      );

      if (response.statusCode == 200) {
        String liveVersion = response.body.trim();
        PackageInfo packageInfo = await PackageInfo.fromPlatform();
        String currentVersion = packageInfo.version.trim();

        if (liveVersion != currentVersion) {
          success(
            'A new version is available! Live: $liveVersion, Current: $currentVersion',
          );
          await _showUpdateDialog(liveVersion);
          return true;
        }

        info('The app is up to date (version: $currentVersion)');
      } else {
        error(
          'Failed to fetch version file. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      error('Error checking for updates: $e');
    }

    return false;
  }

  Future<void> _showUpdateDialog(String liveVersion) async {
    bool confirmed = await showGlassConfirmDialog(
      context,
      title: "Alembic $liveVersion Available",
      description: "A new version of Alembic is available. Download it now?",
      confirmText: "Download",
      cancelText: "Later",
    );
    if (!confirmed) {
      return;
    }
    await _downloadUpdate(liveVersion);
  }

  Future<void> _downloadUpdate(String liveVersion) async {
    String url =
        "https://github.com/ArcaneArts/alembic/raw/refs/heads/main/dist/$liveVersion/alembic-$liveVersion+$liveVersion-macos.dmg";
    String path =
        "${(await getTemporaryDirectory()).absolute.path}/Alembic/alembic-$liveVersion+$liveVersion-macos.dmg"
            .replaceAll("//", "/");

    File(path).absolute.parent.createSync(recursive: true);
    verbose("Downloading $url to $path");

    http.Request request = http.Request('GET', Uri.parse(url));
    http.StreamedResponse streamedResponse = await http.Client().send(request);
    IOSink file = File(path).openWrite();

    await streamedResponse.stream.pipe(file);
    await file.close();
    await cmd("open", <String>[path]);

    warn("Shutting down alembic so the new version can be installed");
    await windowManager.destroy();
    exit(0);
  }

  Future<void> _executeBulkOperation(
    Iterable<Repository> repos,
    Future<void> Function(ArcaneRepository) operation,
  ) async {
    await _controller.executeBulkOperation(repos, operation);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showBulkActions() async {
    List<GlassMenuAction<_BulkAction>> actions = <GlassMenuAction<_BulkAction>>[
      if (active.isNotEmpty)
        const GlassMenuAction<_BulkAction>(
          value: _BulkAction.pullActive,
          title: 'Pull Active',
        ),
      if (active.isNotEmpty)
        const GlassMenuAction<_BulkAction>(
          value: _BulkAction.archiveActive,
          title: 'Archive Active',
        ),
      const GlassMenuAction<_BulkAction>(
        value: _BulkAction.updateArchives,
        title: 'Update Archives',
      ),
      const GlassMenuAction<_BulkAction>(
        value: _BulkAction.activateArchives,
        title: 'Activate Archives',
      ),
      const GlassMenuAction<_BulkAction>(
        value: _BulkAction.activateEverything,
        title: 'Activate Everything',
      ),
    ];

    _BulkAction? selected = await GlassContextMenu.show<_BulkAction>(
      context,
      title: 'Bulk Actions',
      actions: actions,
    );

    if (selected == null) {
      return;
    }

    switch (selected) {
      case _BulkAction.pullActive:
        await _executeBulkOperation(
          active,
          (repo) => repo.ensureRepositoryUpdated(widget.github),
        );
        break;
      case _BulkAction.archiveActive:
        await _executeBulkOperation(
          active,
          (repo) => repo.archive(),
        );
        break;
      case _BulkAction.updateArchives:
        List<Repository> repos = await allRepos;
        await _executeBulkOperation(
          repos.where(
            (Repository repo) => _repositoryFor(repo).isArchivedSync,
          ),
          (ArcaneRepository repo) => repo.updateArchive(widget.github),
        );
        break;
      case _BulkAction.activateArchives:
        List<Repository> repos = await allRepos;
        await _executeBulkOperation(
          repos.where(
            (Repository repo) => _repositoryFor(repo).isArchivedSync,
          ),
          (ArcaneRepository repo) =>
              repo.unarchive(widget.github, waitForPull: true),
        );
        break;
      case _BulkAction.activateEverything:
        List<Repository> repos = await allRepos;
        await _executeBulkOperation(
          repos,
          (ArcaneRepository repo) => repo.ensureRepositoryActive(widget.github),
        );
        break;
    }
  }

  Future<void> _showTopMenu() async {
    String workspacePath = expandPath(config.workspaceDirectory);
    String archivePath =
        '${expandPath(config.archiveDirectory)}/archives'.replaceAll('//', '/');

    List<GlassMenuAction<_TopMenuAction>> actions =
        <GlassMenuAction<_TopMenuAction>>[
      if (Directory(workspacePath).existsSync())
        const GlassMenuAction<_TopMenuAction>(
          value: _TopMenuAction.workspaceFolder,
          title: 'Workspace Folder',
        ),
      if (Directory(archivePath).existsSync())
        const GlassMenuAction<_TopMenuAction>(
          value: _TopMenuAction.archivesFolder,
          title: 'Archives Folder',
        ),
      const GlassMenuAction<_TopMenuAction>(
        value: _TopMenuAction.importRepository,
        title: 'Import Repository',
      ),
      const GlassMenuAction<_TopMenuAction>(
        value: _TopMenuAction.bulkActions,
        title: 'Bulk Actions',
      ),
      const GlassMenuAction<_TopMenuAction>(
        value: _TopMenuAction.settings,
        title: 'Settings',
      ),
      const GlassMenuAction<_TopMenuAction>(
        value: _TopMenuAction.checkUpdates,
        title: 'Check for Updates',
      ),
      const GlassMenuAction<_TopMenuAction>(
        value: _TopMenuAction.restart,
        title: 'Restart',
      ),
      const GlassMenuAction<_TopMenuAction>(
        value: _TopMenuAction.logout,
        title: 'Log Out',
        destructive: true,
      ),
    ];

    _TopMenuAction? selected = await GlassContextMenu.show<_TopMenuAction>(
      context,
      title: 'Alembic',
      actions: actions,
    );

    if (selected == null || !mounted) {
      return;
    }

    switch (selected) {
      case _TopMenuAction.workspaceFolder:
        await cmd('open', <String>[Directory(workspacePath).absolute.path]);
        break;
      case _TopMenuAction.archivesFolder:
        await cmd('open', <String>[Directory(archivePath).absolute.path]);
        break;
      case _TopMenuAction.importRepository:
        await _importRepository();
        break;
      case _TopMenuAction.bulkActions:
        await _showBulkActions();
        break;
      case _TopMenuAction.settings:
        await showSettingsModal(context);
        break;
      case _TopMenuAction.checkUpdates:
        bool updated = await checkForUpdates(context, force: true);
        if (!updated && mounted) {
          await showGlassInfoDialog(
            context,
            title: 'No Updates',
            message:
                'Alembic is up to date. If an update is expected, try again later.',
          );
        }
        break;
      case _TopMenuAction.restart:
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          CupertinoPageRoute<void>(builder: (_) => const SplashScreen()),
          (_) => false,
        );
        break;
      case _TopMenuAction.logout:
        bool confirmed = await showGlassConfirmDialog(
          context,
          title: 'Log Out?',
          description: 'Your token will be deleted from this device. Continue?',
          confirmText: 'Log Out',
          destructive: true,
        );
        if (!confirmed) {
          return;
        }
        await box.deleteAll(<String>["1", "authenticated", "token_type"]);
        if (!mounted) {
          return;
        }
        widget.github.dispose();
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          CupertinoPageRoute<void>(builder: (_) => const SplashScreen()),
          (_) => false,
        );
        break;
    }
  }

  Future<void> _importRepository() async {
    final String? rawInput = await _promptRepositoryInput();
    if (rawInput == null || rawInput.trim().isEmpty) {
      return;
    }

    final RepositoryRef? ref = parseRepositoryRef(rawInput);
    if (ref == null) {
      if (!mounted) {
        return;
      }
      await showGlassInfoDialog(
        context,
        title: 'Invalid Repository',
        message: 'Enter a valid GitHub repository URL or owner/repo value.',
      );
      return;
    }

    await addManualRepoRef(ref);
    await _reloadRepositories();
    final Repository? resolved =
        await _resolveRepositoryRef(ref) ?? _localFallbackRepository(ref);

    if (!mounted) {
      return;
    }
    if (resolved == null) {
      await showGlassInfoDialog(
        context,
        title: 'Repository Saved',
        message:
            'Saved ${ref.fullName}. Metadata is unavailable right now, but the repository stays in your catalog.',
      );
      return;
    }

    final bool cloneNow = await showGlassConfirmDialog(
      context,
      title: 'Clone ${resolved.fullName}?',
      description: 'The repository has been imported. Clone it now?',
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
    } catch (e) {
      if (!mounted) {
        return;
      }
      await showGlassInfoDialog(
        context,
        title: 'Clone Failed',
        message: '$e',
      );
    }
  }

  Future<String?> _promptRepositoryInput() async {
    final TextEditingController controller = TextEditingController();
    String? value;
    await showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: const Color(0x00000000),
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (dialogContext, _, __) {
        return SafeArea(
          child: GlassModalOverlay(
            mode: GlassModalFocusMode.blurAndDim,
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: GlassPanel(
                role: GlassPanelRole.overlay,
                borderRadius: BorderRadius.circular(
                  dialogContext.alembicTokens.radiusLarge,
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Import Repository',
                      style: TextStyle(
                        color: dialogContext.alembicTokens.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Paste a GitHub URL or owner/repo.',
                      style: TextStyle(
                        color: dialogContext.alembicTokens.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GlassTextField(
                      controller: controller,
                      placeholder:
                          'https://github.com/owner/repo or owner/repo',
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: GlassButton(
                            label: 'Cancel',
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            kind: GlassButtonKind.secondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GlassButton(
                            label: 'Import',
                            onPressed: () {
                              value = controller.text.trim();
                              Navigator.of(dialogContext).pop();
                            },
                            kind: GlassButtonKind.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final CurvedAnimation curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(opacity: curved, child: child);
      },
    );
    controller.dispose();
    return value;
  }

  List<Repository> _repositoriesForCurrentTab() {
    String? query = _searchQuery;
    return switch (selectedTab) {
      HomeTab.active => _sortedActive(query),
      HomeTab.personal => _sortedPersonal(query),
      HomeTab.organizations => _organizationRepositories(query),
    };
  }

  List<Repository> _sortedActive(String? query) {
    List<Repository> repos = <Repository>[...active.filterBy(query)];
    repos.sort(
      (a, b) => (getRepoConfig(b).lastOpen ?? 0).compareTo(
        getRepoConfig(a).lastOpen ?? 0,
      ),
    );
    return repos;
  }

  List<Repository> _sortedPersonal(String? query) {
    List<Repository> repos = <Repository>[...personalRepos.filterBy(query)];
    repos.sort((a, b) => a.fullName.compareTo(b.fullName));
    return repos;
  }

  List<Repository> _organizationRepositories(String? query) {
    if (organizationFilter.isAll) {
      List<Organization> organizations = orgRepos.keys.toList()
        ..sort((a, b) => (a.login ?? '').compareTo(b.login ?? ''));
      List<Repository> repos = <Repository>[];
      for (Organization org in organizations) {
        repos.addAll(orgRepos[org]!.filterBy(query));
      }
      return repos;
    }

    String? selectedLogin = organizationFilter.organizationLogin;
    if (selectedLogin == null) {
      return <Repository>[];
    }

    for (Organization org in orgRepos.keys) {
      String login = org.login ?? '';
      if (login == selectedLogin) {
        return orgRepos[org]!.filterBy(query);
      }
    }

    return <Repository>[];
  }

  List<String> _organizationLogins() {
    List<String> logins = <String>[];
    for (Organization org in orgRepos.keys) {
      String login = org.login ?? 'unknown';
      logins.add(login);
    }
    logins.sort();
    return logins;
  }

  @override
  Widget build(BuildContext context) {
    AlembicTokens tokens = context.alembicTokens;

    return GlassShell(
      child: FutureBuilder<List<Repository>>(
        future: allRepos,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _LoadingState(fetching: fetching);
          }

          List<Repository> repositories = _repositoriesForCurrentTab();

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const GlassDragStrip(height: 15),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Alembic',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            'Repository cockpit',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StreamBuilder<double?>(
                      stream: progress.stream,
                      initialData: progress.valueOrNull,
                      builder: (context, progSnapshot) {
                        double? prog = progSnapshot.data;
                        if (prog != null) {
                          return GlassPanel(
                            role: GlassPanelRole.inline,
                            borderRadius: BorderRadius.circular(13),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const CupertinoActivityIndicator(radius: 7),
                                const SizedBox(width: 6),
                                Text(
                                  '${(prog * 100).round()}%',
                                  style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.9, end: 1.0),
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutBack,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Opacity(
                                opacity: value.clamp(0.0, 1.0),
                                child: child,
                              ),
                            );
                          },
                          child: GlassIconButton(
                            icon: CupertinoIcons.ellipsis_circle,
                            size: 34,
                            semanticLabel: 'Open menu',
                            onPressed: _showTopMenu,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GlassTextField(
                  controller: searchController,
                  placeholder: 'Search repositories',
                  prefix: Icon(
                    CupertinoIcons.search,
                    size: 14,
                    color: tokens.textSecondary,
                  ),
                  onChanged: (value) {
                    setState(() {
                      String query = value.trim();
                      _searchQuery = query.isEmpty ? null : query;
                    });
                  },
                ),
                const SizedBox(height: 8),
                GlassSegmentedControl<HomeTab>(
                  value: selectedTab,
                  onChanged: _selectHomeTab,
                  segments: const <GlassSegment<HomeTab>>[
                    GlassSegment<HomeTab>(
                      value: HomeTab.active,
                      label: 'Active',
                    ),
                    GlassSegment<HomeTab>(
                      value: HomeTab.personal,
                      label: 'Personal',
                    ),
                    GlassSegment<HomeTab>(
                      value: HomeTab.organizations,
                      label: 'Organizations',
                    ),
                  ],
                ),
                AnimatedSwitcher(
                  duration: AlembicMotion.chip,
                  switchInCurve: AlembicMotion.standard,
                  switchOutCurve: AlembicMotion.exit,
                  child: selectedTab == HomeTab.organizations
                      ? Padding(
                          key: const ValueKey<String>('org_filters'),
                          padding: const EdgeInsets.only(top: 6),
                          child: SizedBox(
                            height: 34,
                            child: Listener(
                              onPointerSignal: (signal) {
                                if (signal is! PointerScrollEvent ||
                                    !_organizationScrollController.hasClients) {
                                  return;
                                }
                                ScrollPosition position =
                                    _organizationScrollController.position;
                                double delta = signal.scrollDelta.dx.abs() >
                                        signal.scrollDelta.dy.abs()
                                    ? signal.scrollDelta.dx
                                    : signal.scrollDelta.dy;
                                double nextOffset = (position.pixels + delta)
                                    .clamp(
                                      position.minScrollExtent,
                                      position.maxScrollExtent,
                                    )
                                    .toDouble();
                                _organizationScrollController
                                    .jumpTo(nextOffset);
                              },
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onHorizontalDragUpdate: (details) {
                                  if (!_organizationScrollController
                                      .hasClients) {
                                    return;
                                  }
                                  ScrollPosition position =
                                      _organizationScrollController.position;
                                  double nextOffset =
                                      (position.pixels - details.delta.dx)
                                          .clamp(
                                            position.minScrollExtent,
                                            position.maxScrollExtent,
                                          )
                                          .toDouble();
                                  _organizationScrollController
                                      .jumpTo(nextOffset);
                                },
                                child: ListView(
                                  controller: _organizationScrollController,
                                  primary: false,
                                  scrollDirection: Axis.horizontal,
                                  dragStartBehavior: DragStartBehavior.down,
                                  physics: const BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics(),
                                  ),
                                  children: <Widget>[
                                    _OrganizationFilterChip(
                                      label: 'All organizations',
                                      selected: organizationFilter.isAll,
                                      onPressed: () => setState(
                                        () => organizationFilter =
                                            const OrganizationFilter.all(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ..._organizationLogins().map((org) {
                                      bool selected = organizationFilter
                                              .organizationLogin ==
                                          org;
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: _OrganizationFilterChip(
                                          label: org,
                                          selected: selected,
                                          onPressed: () => setState(
                                            () => organizationFilter =
                                                OrganizationFilter.organization(
                                                    org),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(
                          key: ValueKey<String>('no_org_filters'),
                        ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: repositories.isEmpty
                      ? _EmptyRepositoryState(tab: selectedTab)
                      : ListView.builder(
                          itemCount: repositories.length,
                          padding: const EdgeInsets.only(bottom: 4),
                          itemBuilder: (context, index) {
                            return RepositoryTile(
                              repository: repositories[index],
                              github: widget.github,
                              runtime: widget.runtime,
                              onChanged: () {
                                _reloadRepositories();
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OrganizationFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _OrganizationFilterChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    AlembicTokens tokens = context.alembicTokens;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: AlembicMotion.chip,
        curve: AlembicMotion.standard,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? tokens.controlFill.withValues(alpha: 0.2)
              : tokens.inlineFill.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected
                ? tokens.textPrimary
                : tokens.textSecondary.withValues(alpha: 0.86),
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _EmptyRepositoryState extends StatelessWidget {
  final HomeTab tab;

  const _EmptyRepositoryState({
    required this.tab,
  });

  @override
  Widget build(BuildContext context) {
    AlembicTokens tokens = context.alembicTokens;
    IconData icon = switch (tab) {
      HomeTab.active => CupertinoIcons.bolt_fill,
      HomeTab.personal => CupertinoIcons.person,
      HomeTab.organizations => CupertinoIcons.person_3,
    };
    String title = switch (tab) {
      HomeTab.active => 'No active repositories',
      HomeTab.personal => 'No personal repositories',
      HomeTab.organizations => 'No organization repositories',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 28,
              color: tokens.textSecondary.withValues(alpha: 0.76),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search or switching tabs.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tokens.textSecondary.withValues(alpha: 0.85),
              ),
            ),
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
    AlembicTokens tokens = context.alembicTokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CupertinoActivityIndicator(radius: 16),
          const SizedBox(height: 20),
          StreamBuilder<int>(
            stream: fetching.stream,
            initialData: fetching.value,
            builder: (context, snapshot) {
              return Text(
                'Fetching ${snapshot.data ?? 0} repositories',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
