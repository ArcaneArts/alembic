import 'dart:async';
import 'dart:io';

import 'package:alembic/core/arcane_repository.dart';
import 'package:alembic/main.dart';
import 'package:alembic/screen/settings.dart';
import 'package:alembic/screen/splash.dart';
import 'package:alembic/util/extensions.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:alembic/util/semaphore.dart';
import 'package:alembic/widget/active_section.dart';
import 'package:alembic/widget/organization_section.dart';
import 'package:alembic/widget/personal_section.dart';
import 'package:arcane/arcane.dart';
import 'package:fast_log/fast_log.dart';
import 'package:flutter/foundation.dart';
import 'package:github/github.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

/// Global update trigger stream
final BehaviorSubject<int> update = BehaviorSubject.seeded(0);
List<Repository> active = [];
class AlembicHome extends StatefulWidget {
  final GitHub github;
  const AlembicHome({super.key, required this.github});
  @override
  State<AlembicHome> createState() => _AlembicHomeState();
}

class _AlembicHomeState extends State<AlembicHome> {
  late Future<List<Repository>> allRepos;
  final Map<Organization, List<Repository>> orgRepos = {};
  final List<Repository> personalRepos = [];
  final BehaviorSubject<int> _fetching = BehaviorSubject.seeded(0);
  final BehaviorSubject<String?> search = BehaviorSubject.seeded(null);
  final TextEditingController searchController = TextEditingController();
  final BehaviorSubject<double?> progress = BehaviorSubject.seeded(null);

  @override
  void initState() {
    active.clear();
    super.initState();
    allRepos = _fetchAllRepos()
        .catchError((e, es) {
      error(e);
      error(es);
      return <Repository>[];
    })
        .then(_processActiveRepos)
        .thenRun((_) => updateActive());
    allRepos.then((_) => updateAllRepositoryTokens());
    _scheduleStaleCheck();
    checkForUpdates(context);
  }

  @override
  void dispose() {
    _fetching.close();
    search.close();
    progress.close();
    searchController.dispose();
    super.dispose();
  }

  /// Process the list of repos to identify active ones
  Future<List<Repository>> _processActiveRepos(List<Repository> repos) async {
    final List<Future<void>> work = [];
    for (final Repository repo in repos) {
      final ArcaneRepository r = ArcaneRepository(repository: repo);
      if (active.any((a) => a.fullName == r.repository.fullName)) {
        continue;
      }
      work.add(r.isActive.then((isActive) {
        if (isActive) {
          active.add(repo);
        }
      }));
    }
    await Future.wait(work);
    return repos;
  }

  /// Schedule check for stale repositories
  void _scheduleStaleCheck() {
    Future.delayed(const Duration(milliseconds: 10000), () {
      for (final Repository repo in active) {
        verbose("Checking staleness of ${repo.fullName}");
        final ArcaneRepository r = ArcaneRepository(repository: repo);
        r.isStaleActive.then((stale) {
          if (stale) {
            warn("${repo.fullName} is stale, archiving");
            r.archive();
          }
        });
      }
    });
  }

  /// Update the list of active repositories
  void updateActive() {
    allRepos.then((repos) {
      active = repos
          .where((repo) => ArcaneRepository(repository: repo).isActiveSync)
          .toSet()
          .toList();
    });
  }

  /// Update GitHub tokens in all active repositories
  Future<void> updateAllRepositoryTokens() async {
    if (!box.containsKey("1")) return;
    final String latestToken = box.get("1");
    progress.add(0.0);
    final List<Repository> repositories = await allRepos;
    final int total = repositories.length;
    int current = 0;
    int updated = 0;
    for (final Repository repo in repositories) {
      final ArcaneRepository aRepo = ArcaneRepository(repository: repo);
      if (await aRepo.isActive) {
        final bool wasUpdated = await aRepo.checkAndUpdateToken(latestToken);
        if (wasUpdated) {
          updated++;
          success("Updated token for ${repo.fullName}");
        }
      }
      current++;
      progress.add(current / total);
    }
    progress.add(null);
    if (updated > 0) {
      TextToast("Updated tokens for $updated repositories").open(context);
    }
  }

  /// Fetch all repositories from GitHub
  Future<List<Repository>> _fetchAllRepos() async {
    personalRepos.clear();
    orgRepos.clear();
    final Map<String, List<Repository>> ownerRepos = {};
    final Map<String, Organization> ownerOrgs = {};
    try {
      final List<Repository> repos = await listRepositoriesAggressive(type: 'all').toList();
      for (final Repository repo in repos) {
        final String ownerLogin = repo.owner?.login ?? "unknown";
        if (!ownerRepos.containsKey(ownerLogin)) {
          ownerRepos[ownerLogin] = [];
          ownerOrgs[ownerLogin] = Organization()..login = ownerLogin;
          orgRepos[ownerOrgs[ownerLogin]!] = [];
        }
        ownerRepos[ownerLogin]!.add(repo);
        orgRepos[ownerOrgs[ownerLogin]!]!.add(repo);

        _fetching.add(_fetching.value + 1);
      }
      return repos;
    } catch (e, stack) {
      error("Error in _fetchAllRepos: $e");
      error(stack.toString());
      return [];
    }
  }

  /// Stream repositories with increased page size
  Stream<Repository> listRepositoriesAggressive({
    String type = 'all',
    String sort = 'full_name',
    String direction = 'asc'
  }) {
    final params = <String, dynamic>{
      'type': type,
      'sort': sort,
      'direction': direction,
      'per_page': 100
    };
    return PaginationHelper(widget.github)
        .objects<Map<String, dynamic>, Repository>(
      'GET',
      '/user/repos',
      Repository.fromJson,
      params: params,
    );
  }

  /// Check for app updates
  Future<bool> checkForUpdates(BuildContext context, {bool force = false}) async {
    if (!force) {
      if (kDebugMode || kProfileMode) return false;
      if (!boxSettings.get("achup", defaultValue: true)) return false;
    }

    try {
      final response = await http.get(Uri.parse(
          'https://raw.githubusercontent.com/ArcaneArts/alembic/refs/heads/main/version'));
      if (response.statusCode == 200) {
        final String liveVersion = response.body.trim();
        final PackageInfo inf = await PackageInfo.fromPlatform();
        final String currentVersion = inf.version.trim();
        if (liveVersion != currentVersion) {
          success('A new version is available! Live: $liveVersion, Current: $currentVersion');
          _showUpdateDialog(liveVersion);
          return true;
        } else {
          info('The app is up to date (version: $currentVersion)');
        }
      } else {
        error('Failed to fetch version file. Status code: ${response.statusCode}');
      }
    } catch (e) {
      error('Error checking for updates: $e');
    }
    return false;
  }

  /// Show update dialog for new version
  void _showUpdateDialog(String liveVersion) {
    DialogConfirm(
      title: "Alembic $liveVersion Available",
      description: "A new version of Alembic is available. Would you like to download it?",
      confirmText: "Download",
      onConfirm: () => _downloadUpdate(liveVersion),
    ).open(context);
  }

  /// Download and install update
  Future<void> _downloadUpdate(String liveVersion) async {
    TextToast("Downloading Alembic $liveVersion").open(context);

    final String url = "https://github.com/ArcaneArts/alembic/raw/refs/heads/main/dist/$liveVersion/alembic-$liveVersion+$liveVersion-macos.dmg";
    final String path = "${(await getTemporaryDirectory()).absolute.path}/Alembic/alembic-$liveVersion+$liveVersion-macos.dmg"
        .replaceAll("//", "/");
    File(path).absolute.parent.createSync(recursive: true);
    verbose("Downloading $url to $path");
    final http.Request request = http.Request('GET', Uri.parse(url));
    final http.StreamedResponse streamedResponse = await http.Client().send(request);
    final IOSink file = File(path).openWrite();
    await streamedResponse.stream.pipe(file);
    await file.close();
    await cmd("open", [path]);
    warn("Shutting down alembic so the new version can be installed");
    await windowManager.destroy();
    exit(0);
  }

  /// Execute a bulk operation on repositories
  Future<void> _executeBulkOperation(
      Iterable<Repository> repos,
      Future<void> Function(ArcaneRepository) operation
      ) async {
    progress.add(0);
    await repos
        .map((repo) => () => operation(ArcaneRepository(repository: repo)))
        .waitSemaphore(4, progress: (value) {
      setState(() {
        progress.add(value);
      });
    });
    progress.add(null);
  }

  @override
  Widget build(BuildContext context) => Pylon<GitHub>(
    value: widget.github,
    builder: (context) => SliverScreen(
      header: _buildHeader(context),
      sliver: _buildRepositoryList(),
    ),
  );

  /// Build the app header with search and menu
  Widget _buildHeader(BuildContext context) => Bar(
    key: const ValueKey("header"),
    titleText: "Alembic",
    trailing: [
      SearchBox(
        leading: Icon(Icons.search_ionic),
        controller: searchController,
        placeholder: Text("Search Repositories"),
        key: const ValueKey("search"),
        onChanged: (value) {
          search.add(value.trim().isEmpty ? null : value.trim());
        },
      ),
      _buildProgressIndicatorAndMenu(context),
    ],
  );

  /// Build either progress indicator or settings menu
  Widget _buildProgressIndicatorAndMenu(BuildContext context) => update.stream
      .map((i) => active)
      .build((i) {
    updateActive();
    return progress.distinct().buildNullable(
          (prog) => prog != null
          ? CircularProgressIndicator(
        size: 26,
        animated: true,
        value: prog,
      )
          : _buildSettingsMenu(context),
    );
  });

  /// Build the repository list view
  Widget _buildRepositoryList() => FutureBuilder<List<Repository>>(
    future: allRepos,
    builder: (context, snapshot) => !snapshot.hasData
        ? _buildLoadingIndicator()
        : update.build(
          (i) => _buildRepositorySections(context),
      loading: const SliverFillRemaining(
          child: Center(
            child: SizedBox(
                height: 48,
                width: 48,
                child: CircularProgressIndicator()
            ),
          )
      ),
    ),
  );

  /// Build loading indicator when repositories are being fetched
  Widget _buildLoadingIndicator() => SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircularProgressIndicator(size: 48),
            const Gap(32),
            _fetching.build((i) => Text("Fetching $i Projects")),
          ],
        ),
      )
  );

  /// Build the repository sections (active, personal, organizations)
  Widget _buildRepositorySections(BuildContext context) => PylonCluster(
    pylons: [
      Pylon<Map<Organization, List<Repository>>>.data(value: orgRepos),
      Pylon<BehaviorSubject<String?>>.data(value: search)
    ],
    builder: (context) => MultiSliver(
      children: [
        _buildActiveSection(context),
        _buildPersonalSection(context),
        ..._buildOrganizationSections(context),
      ],
    ),
  );

  /// Build the active repositories section
  Widget _buildActiveSection(BuildContext context) => context.search.buildNullable(
          (query) => Pylon<List<Repository>>(
        key: ValueKey("active.${query ?? ""}"),
        value: active
            .filterBy(query)
            .sorted((b, a) => (getRepoConfig(a).lastOpen ?? 0)
            .compareTo(getRepoConfig(b).lastOpen ?? 0)),
        builder: (context) => ActiveSection(),
      )
  );

  /// Build the personal repositories section
  Widget _buildPersonalSection(BuildContext context) => context.search.buildNullable(
          (query) => Pylon<List<Repository>>(
        key: ValueKey("personal.${query ?? ""}"),
        value: personalRepos.filterBy(query),
        builder: (context) => PersonalSection(),
      )
  );

  /// Build the organization sections
  List<Widget> _buildOrganizationSections(BuildContext context) => orgRepos.keys
      .sorted((a, b) => (a.login ?? "org").compareTo(b.login ?? "org"))
      .withPylons((context) => OrganizationSection());

  /// Build the settings menu
  Widget _buildSettingsMenu(BuildContext context) => IconButtonMenu(
    icon: Icons.gear_six_fill,
    items: [
      ..._buildFolderMenuItems(),
      ..._buildBulkActionsMenuItem(context),
      const MenuDivider(),
      ..._buildAuthMenuItems(context),
      ..._buildAppMenuItems(context),
    ],
  );

  /// Build folder menu items
  List<MenuItem> _buildFolderMenuItems() {
    final List<MenuItem> items = [];
    if (Directory(expandPath(config.workspaceDirectory)).existsSync()) {
      items.add(
        MenuButton(
          leading: const Icon(Icons.folder),
          onPressed: () => cmd('open', [
            Directory(expandPath(config.workspaceDirectory)).absolute.path
          ]),
          child: const Text("Workspace Folder"),
        ),
      );
    }
    final String archivePath = expandPath(config.archiveDirectory) +
        "/archives".replaceAll("//", "/");
    if (Directory(archivePath).existsSync()) {
      items.add(
        MenuButton(
          leading: const Icon(Icons.folder),
          onPressed: () => cmd('open', [Directory(archivePath).absolute.path]),
          child: const Text("Archives Folder"),
        ),
      );
    }
    return items;
  }

  /// Build bulk actions menu item
  List<MenuItem> _buildBulkActionsMenuItem(BuildContext context) => [
    MenuButton(
      subMenu: _buildBulkActionSubMenu(context),
      leading: Icon(Icons.list),
      child: Text("Bulk Actions"),
    ),
  ];

  /// Build bulk actions submenu
  List<MenuItem> _buildBulkActionSubMenu(BuildContext context) {
    final List<MenuItem> items = [];
    if (active.isNotEmpty) {
      items.add(
        MenuButton(
          leading: const Icon(Icons.code_download_ionic),
          onPressed: () => _executeBulkOperation(
              active,
                  (repo) => repo.ensureRepositoryUpdated(context.github)
          ),
          child: const Text("Pull Active"),
        ),
      );
      items.add(
        MenuButton(
          leading: const Icon(Icons.archive_box),
          onPressed: () => _executeBulkOperation(
              active,
                  (repo) => repo.archive()
          ),
          child: const Text("Archive Active"),
        ),
      );
    }

    items.addAll([
      MenuButton(
        leading: const Icon(Icons.refresh_ionic),
        onPressed: () => allRepos.then((repos) => _executeBulkOperation(
            repos.where((repo) => ArcaneRepository(repository: repo).isArchivedSync),
                (repo) => repo.updateArchive(context.github)
        )),
        child: const Text("Update Archives"),
      ),
      MenuButton(
        leading: const Icon(Icons.upload),
        onPressed: () => allRepos.then((repos) => _executeBulkOperation(
            repos.where((repo) => ArcaneRepository(repository: repo).isArchivedSync),
                (repo) => repo.unarchive(context.github, waitForPull: true)
        )),
        child: const Text("Activate Archives"),
      ),
      MenuButton(
        leading: const Icon(Icons.refresh_ionic),
        onPressed: () => allRepos.then((repos) => _executeBulkOperation(
            repos,
                (repo) => repo.ensureRepositoryActive(context.github)
        )),
        child: const Text("Activate Everything"),
      ),
    ]);
    return items;
  }

  /// Build authentication-related menu items
  List<MenuItem> _buildAuthMenuItems(BuildContext context) => [
    MenuButton(
        leading: const Icon(Icons.log_out_outline_ionic),
        child: const Text("Log Out"),
        onPressed: () => DialogConfirm(
          title: "Log Out?",
          description: "Are you sure you want to log out? Your token will be deleted from this device.",
          destructive: true,
          onConfirm: () => box.deleteAll(["1", "authenticated", "token_type"]).then((_) {
            widget.github.dispose();
            Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const SplashScreen()),
                    (route) => false
            );
          }),
        ).open(context)
    ),
    MenuButton(
        leading: const Icon(Icons.refresh_ionic),
        onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const SplashScreen()),
                (route) => false
        ),
        child: const Text("Restart")
    ),
  ];

  /// Build application-related menu items
  List<MenuItem> _buildAppMenuItems(BuildContext context) => [
    MenuButton(
      leading: const Icon(Icons.gear_six),
      onPressed: () => Arcane.push(context, Settings()),
      child: const Text("Settings"),
    ),
    const MenuDivider(),
    MenuButton(
      leading: const Icon(Icons.arrow_circle_up),
      onPressed: () => checkForUpdates(context, force: true).then((updated) {
        if (!updated) {
          TextToast(
            "Alembic is up to date!\n\nIf there really is an update, switch to a vpn or different network to propagate the cache faster.",
            showDuration: 5.seconds,
          ).open(context);
        }
      }),
      child: const Text("Check for Updates"),
    ),
  ];
}

extension XStream<T> on Stream<T> {
  Stream<T> sip(Function(T) callback) => map((value) {
    callback(value);
    return value;
  });
}