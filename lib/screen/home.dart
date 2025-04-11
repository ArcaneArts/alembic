import 'dart:async';
import 'dart:io';

import 'package:alembic/core/arcane_repository.dart';
import 'package:alembic/main.dart';
import 'package:alembic/screen/settings.dart';
import 'package:alembic/screen/splash.dart';
import 'package:alembic/util/extensions.dart';
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

BehaviorSubject<int> update = BehaviorSubject.seeded(0);

class AlembicHome extends StatefulWidget {
  final GitHub github;

  const AlembicHome({super.key, required this.github});

  @override
  State<AlembicHome> createState() => _AlembicHomeState();
}

List<Repository> active = [];

class _AlembicHomeState extends State<AlembicHome> {
  late Future<List<Repository>> allRepos;
  Map<Organization, List<Repository>> orgRepos = {};
  List<Repository> personalRepos = [];
  final BehaviorSubject<int> _fetching = BehaviorSubject.seeded(0);
  BehaviorSubject<String?> search = BehaviorSubject.seeded(null);
  TextEditingController searchController = TextEditingController();
  BehaviorSubject<double?> progress = BehaviorSubject.seeded(null);
  Future<void> updateAllRepositoryTokens() async {
    if (!box.containsKey("1")) return;

    String latestToken = box.get("1");
    progress.add(0.0);

    List<Repository> repositories = await allRepos;
    int total = repositories.length;
    int current = 0;
    int updated = 0;

    for (var repo in repositories) {
      ArcaneRepository aRepo = ArcaneRepository(repository: repo);
      if (await aRepo.isActive) {
        bool wasUpdated = await aRepo.checkAndUpdateToken(latestToken);
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

  Future<bool> checkForUpdates(BuildContext context,
      {bool force = false}) async {
    if (!force) {
      if (kDebugMode || kProfileMode) return false;
      if (!boxSettings.get("achup", defaultValue: true)) return false;
    }




    try {
      final response = await http.get(Uri.parse(
          'https://raw.githubusercontent.com/ArcaneArts/alembic/refs/heads/main/version'));
      if (response.statusCode == 200) {
        String liveVersion = response.body.trim(); // e.g. "1.0.2+3"
        PackageInfo inf = await PackageInfo.fromPlatform();
        String currentVersion = inf.version.trim(); // e.g. "1.0.2+3"

        if (liveVersion != currentVersion) {
          success(
              'A new version is available! Live version: $liveVersion, Current: $currentVersion');
          DialogConfirm(
            title: "Alembic $liveVersion Available",
            description:
                "A new version of Alembic is available. Would you like to download it?",
            confirmText: "Download",
            onConfirm: () async {
              TextToast("Downloading Alembic $liveVersion").open(context);
              String url =
                  "https://github.com/ArcaneArts/alembic/raw/refs/heads/main/dist/$liveVersion/alembic-$liveVersion+$liveVersion-macos.dmg";
              String path =
                  "${(await getTemporaryDirectory()).absolute.path}/Alembic/alembic-$liveVersion+$liveVersion-macos.dmg"
                      .replaceAll("//", "/");
              File(path).absolute.parent.createSync(recursive: true);
              verbose("Downloading $url to $path");
              http.Request request = http.Request('GET', Uri.parse(url));
              http.StreamedResponse streamedResponse =
                  await http.Client().send(request);
              IOSink file = File(path).openWrite();
              await streamedResponse.stream.pipe(file);
              await file.close();
              await cmd("open", [path]);
              warn("Shutting down alembic so the new version can be installed");
              windowManager.destroy().then((_) => exit(0));
            },
          ).open(context);
          return true;
        } else {
          info('The app is up to date (version: $currentVersion)');
        }
      } else {
        error(
            'Failed to fetch version file from GitHub. Status code: ${response.statusCode}');
      }
    } catch (e) {
      error('Error checking for updates: $e');
    }

    return false;
  }

  @override
  void initState() {
    active.clear();
    super.initState();
    allRepos = _fetchAllRepos().catchError((e, es) {
      error(e);
      error(es);
      return <Repository>[];
    }).then((r) {
      List<Future> work = [];
      for (Repository i in r) {
        ArcaneRepository r = ArcaneRepository(repository: i);

        if (active.any((i) => i.fullName == r.repository.fullName)) {
          continue;
        }

        work.add(r.isActive.then((g) {
          if (g) {
            active.add(i);
          }
        }));
      }

      return Future.wait(work).then((_) => r);
    }).thenRun((i) {
      updateActive();
    });

    // Add token check after repositories are loaded
    allRepos.then((_) {
      updateAllRepositoryTokens();
    });

    Future.delayed(const Duration(milliseconds: 10000), () {
      for (Repository i in active) {
        verbose("Checking staleness of ${i.fullName}");
        ArcaneRepository r = ArcaneRepository(repository: i);
        r.isStaleActive.then((stale) {
          if (stale) {
            warn("${i.fullName} is stale, archiving");
            r.archive();
          }
        });
      }
    });
    checkForUpdates(context);
  }
  @override
  void dispose() {
    _fetching.close();
    search.close();
    super.dispose();
  }

  Future<List<Repository>> _fetchAllRepos() async {
    // Clear existing collections to prevent duplication
    personalRepos.clear();
    orgRepos.clear();

    List<Repository> allRepositories = [];

    try {
      // First, fetch all organizations
      List<Organization> organizations = await widget.github.organizations
          .list()
          .where((org) => org.login != null)
          .toList();

      // Initialize organization map
      for (var org in organizations) {
        orgRepos[org] = <Repository>[];
      }

      // Fetch personal repositories
      List<Repository> personalList = await listRepositoriesAggressive(type: 'all').toList();
      for (var repo in personalList) {
        // Check if repository belongs to user or to an organization
        String? ownerLogin = repo.owner?.login;
        bool isOrgRepo = false;

        for (var org in organizations) {
          if (org.login == ownerLogin) {
            // This is an org repo
            orgRepos[org]!.add(repo);
            isOrgRepo = true;
            break;
          }
        }

        // If not an org repo, it's a personal repo
        if (!isOrgRepo) {
          personalRepos.add(repo);
        }

        allRepositories.add(repo);
        _fetching.add(_fetching.value + 1);
      }

      // For completeness, also fetch repositories directly from organizations
      // to ensure we get all repositories
      for (var org in organizations) {
        List<Repository> orgList = await listOrganizationRepositoriesAggressive(org.login!).toList();
        for (var repo in orgList) {
          // Only add if not already added
          if (!allRepositories.any((r) => r.fullName == repo.fullName)) {
            orgRepos[org]!.add(repo);
            allRepositories.add(repo);
            _fetching.add(_fetching.value + 1);
          }
        }
      }

      return allRepositories;
    } catch (e, stack) {
      error("Error fetching repositories: $e");
      error(stack);
      return [];
    }
  }

  Stream<Repository> listOrganizationRepositoriesAggressive(String org,
      {String type = 'all'}) {
    ArgumentError.checkNotNull(org);
    final params = <String, dynamic>{'type': type, "per_page": 100};

    return PaginationHelper(widget.github)
        .objects<Map<String, dynamic>, Repository>(
      'GET',
      '/orgs/$org/repos',
      Repository.fromJson,
      params: params,
    );
  }

  void updateActive() {
    allRepos.then((i) {
      active = i
          .where((i) => ArcaneRepository(repository: i).isActiveSync)
          .toSet()
          .toList();
    });
  }

  Stream<Repository> listRepositoriesAggressive({
    String type = 'all',
    String sort = 'full_name',
    String direction = 'asc'}) {
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

  @override
  Widget build(BuildContext context) => Pylon<GitHub>(
      value: widget.github,
      builder: (context) => SliverScreen(
          header: Bar(
            key: const ValueKey("header"),
            titleText: "Alembic",
            trailing: [
              SearchBox(
                leading: Icon(Icons.search_ionic),
                controller: searchController,
                placeholder: "Search Repositories",
                key: const ValueKey("search"),
                onChanged: (s) {
                  search.add(s.trim() == "" ? null : s.trim());
                },
              ),
              update.stream.map((i) => active).build((i) {
                updateActive();
                return progress.distinct().buildNullable((prog) => prog != null
                    ? CircularProgressIndicator(
                        size: 26,
                        animated: true,
                        value: prog,
                      )
                    : IconButtonMenu(icon: Icons.gear_six_fill, items: [
                        if (Directory(expandPath(config.workspaceDirectory))
                            .existsSync())
                          MenuButton(
                            leading: const Icon(Icons.folder),
                            onPressed: () => cmd('open', [
                              Directory(expandPath(config.workspaceDirectory))
                                  .absolute
                                  .path
                            ]),
                            child: const Text("Workspace Folder"),
                          ),
                        if (Directory(expandPath(config.archiveDirectory) +
                                "/archives".replaceAll("//", "/"))
                            .existsSync())
                          MenuButton(
                            leading: const Icon(Icons.folder),
                            onPressed: () => cmd('open', [
                              Directory(expandPath(config.archiveDirectory) +
                                      "/archives".replaceAll("//", "/"))
                                  .absolute
                                  .path
                            ]),
                            child: const Text("Archives Folder"),
                          ),
                        MenuButton(
                            subMenu: [
                              if (active.isNotEmpty)
                                MenuButton(
                                  leading:
                                      const Icon(Icons.code_download_ionic),
                                  onPressed: () {
                                    progress.add(0);
                                    active
                                        .map((i) => () =>
                                            ArcaneRepository(repository: i)
                                                .ensureRepositoryUpdated(
                                                    context.github))
                                        .waitSemaphore(4, progress: (i) {
                                      setState(() {
                                        progress.add(i);
                                      });
                                    }).then((g) {
                                      progress.add(null);
                                    });
                                  },
                                  child: const Text("Pull Active"),
                                ),
                              if (active.isNotEmpty)
                                MenuButton(
                                  leading: const Icon(Icons.archive_box),
                                  onPressed: () {
                                    progress.add(0);
                                    active
                                        .map((i) => () =>
                                            ArcaneRepository(repository: i)
                                                .archive())
                                        .waitSemaphore(4, progress: (i) {
                                      setState(() {
                                        progress.add(i);
                                      });
                                    }).then((g) {
                                      progress.add(null);
                                    });
                                  },
                                  child: const Text("Archive Active"),
                                ),
                              MenuButton(
                                leading: const Icon(Icons.refresh_ionic),
                                onPressed: () {
                                  progress.add(0);
                                  allRepos.then((g) => g
                                          .where((i) =>
                                              ArcaneRepository(repository: i)
                                                  .isArchivedSync)
                                          .map((i) => () => ArcaneRepository(
                                                  repository: i)
                                              .updateArchive(context.github))
                                          .waitSemaphore(4, progress: (i) {
                                        setState(() {
                                          progress.add(i);
                                        });
                                      }).then((g) {
                                        progress.add(null);
                                      }));
                                },
                                child: const Text("Update Archives"),
                              ),
                              MenuButton(
                                leading: const Icon(Icons.upload),
                                onPressed: () {
                                  progress.add(0);
                                  allRepos.then((g) => g
                                          .where((i) =>
                                              ArcaneRepository(repository: i)
                                                  .isArchivedSync)
                                          .map((i) => () =>
                                              ArcaneRepository(repository: i)
                                                  .unarchive(context.github,
                                                      waitForPull: true))
                                          .waitSemaphore(4, progress: (i) {
                                        setState(() {
                                          progress.add(i);
                                        });
                                      }).then((g) {
                                        progress.add(null);
                                      }));
                                },
                                child: const Text("Activate Archives"),
                              ),
                              MenuButton(
                                leading: const Icon(Icons.refresh_ionic),
                                onPressed: () {
                                  progress.add(0);
                                  allRepos.then((g) => g
                                          .map((i) => () =>
                                              ArcaneRepository(repository: i)
                                                  .ensureRepositoryActive(
                                                      context.github))
                                          .waitSemaphore(4, progress: (i) {
                                        setState(() {
                                          progress.add(i);
                                        });
                                      }).then((g) {
                                        progress.add(null);
                                      }));
                                },
                                child: const Text("Activate Everything"),
                              ),
                            ],
                            leading: Icon(Icons.list),
                            child: Text("Bulk Actions")),
                        const MenuDivider(),
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
                                  (route) => false);
                        }),
                      ).open(context)),
                        MenuButton(
                            leading: const Icon(Icons.refresh_ionic),
                            onPressed: () => Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const SplashScreen()),
                                (route) => false),
                            child: const Text("Restart")),
                        MenuButton(
                          leading: const Icon(Icons.gear_six),
                          onPressed: () => Arcane.push(context, Settings()),
                          child: const Text("Settings"),
                        ),
                        MenuDivider(),
                        MenuButton(
                          leading: const Icon(Icons.arrow_circle_up),
                          onPressed: () => checkForUpdates(context).then((g) {
                            if (!g) {
                              TextToast(
                                "Alembic is up to date!\n\nIf there really is an update, switch to a vpn or different network to propagate the cache faster.",
                                showDuration: 5.seconds,
                              ).open(context);
                            }
                          }),
                          child: const Text("Check for Updates"),
                        )
                      ]));
              })
            ],
          ),
          sliver: FutureBuilder<List<Repository>>(
            future: allRepos,
            builder: (context, snap) => !snap.hasData
                ? SliverFillRemaining(
                    child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          size: 48,
                        ),
                        const Gap(32),
                        _fetching.build((i) => Text("Fetching $i Projects")),
                      ],
                    ),
                  ))
                : update.build(
                    (i) => PylonCluster(
                            pylons: [
                              Pylon<Map<Organization, List<Repository>>>.data(
                                  value: orgRepos),
                              Pylon<BehaviorSubject<String?>>.data(
                                  value: search)
                            ],
                            builder: (context) => MultiSliver(
                                  children: [
                                    context.search.buildNullable((query) =>
                                        Pylon<List<Repository>>(
                                            key: ValueKey(
                                                "active.${query ?? ""}"),
                                            value: active
                                                .filterBy(query)
                                                .sorted((b, a) =>
                                                    (getRepoConfig(a)
                                                                .lastOpen ??
                                                            0)
                                                        .compareTo(
                                                            getRepoConfig(b)
                                                                    .lastOpen ??
                                                                0)),
                                            builder: (context) =>
                                                ActiveSection())),
                                    context.search.buildNullable((query) =>
                                        Pylon<List<Repository>>(
                                            key: ValueKey(
                                                "personal.${query ?? ""}"),
                                            value:
                                                personalRepos.filterBy(query),
                                            builder: (context) =>
                                                PersonalSection())),
                                    ...orgRepos.keys
                                        .sorted((a, b) => (a.login ?? "org")
                                            .compareTo(b.login ?? "org"))
                                        .withPylons(
                                            (context) => OrganizationSection())
                                  ],
                                )),
                    loading: const SliverFillRemaining(
                        child: Center(
                      child: SizedBox(
                          height: 48,
                          width: 48,
                          child: CircularProgressIndicator()),
                    ))),
          )));
}

extension XStream<T> on Stream<T> {
  Stream<T> sip(Function(T) t) => map((i) {
        t(i);
        return i;
      });
}
