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
import 'package:github/github.dart';

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
  }

  @override
  void dispose() {
    _fetching.close();
    search.close();
    super.dispose();
  }

  Future<List<Repository>> _fetchAllRepos() async => (await Future.wait([
        listRepositoriesAggressive().sip((i) => personalRepos.add(i)),
        ...(await widget.github.organizations
                .list()
                .where((i) => i.login != null)
                .sip((i) => orgRepos[i] = <Repository>[])
                .toList())
            .map((i) => listOrganizationRepositoriesAggressive(i.login!)
                .sip((j) => orgRepos[i]!.add(j)))
      ].map((i) => i.sip((j) => _fetching.add(_fetching.value + 1)).toList())))
          .expand((i) => i)
          .toList();

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

  Stream<Repository> listRepositoriesAggressive(
      {String type = 'owner',
      String sort = 'full_name',
      String direction = 'asc'}) {
    final params = <String, dynamic>{
      'type': type,
      'sort': sort,
      'direction': direction,
      "per_page": 100,
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
                            onPressed: (_) => cmd('open', [
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
                            onPressed: (_) => cmd('open', [
                              Directory(expandPath(config.archiveDirectory) +
                                      "/archives".replaceAll("//", "/"))
                                  .absolute
                                  .path
                            ]),
                            child: const Text("Archives Folder"),
                          ),
                        MenuButton(
                            child: Text("Bulk Actions"),
                            subMenu: [
                              if (active.isNotEmpty)
                                MenuButton(
                                  leading:
                                      const Icon(Icons.code_download_ionic),
                                  onPressed: (_) {
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
                                  onPressed: (_) {
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
                                onPressed: (_) {
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
                                onPressed: (_) {
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
                                onPressed: (_) {
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
                            leading: Icon(Icons.list)),
                        const MenuDivider(),
                        MenuButton(
                            leading: const Icon(Icons.log_out_outline_ionic),
                            child: const Text("Log Out"),
                            onPressed: (_) => DialogConfirm(
                                  title: "Log Out?",
                                  description:
                                      "Are you sure you want to log out? Your PAT will be deleted from this device.",
                                  destructive: true,
                                  onConfirm: () => box.deleteAll(
                                      ["1", "authenticated"]).then((_) {
                                    widget.github.dispose();
                                    Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const SplashScreen()),
                                        (route) => false);
                                  }),
                                ).open(context)),
                        MenuButton(
                            leading: const Icon(Icons.refresh_ionic),
                            onPressed: (_) => Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const SplashScreen()),
                                (route) => false),
                            child: const Text("Restart")),
                        MenuButton(
                          leading: const Icon(Icons.gear_six),
                          onPressed: (_) => Arcane.push(context, Settings()),
                          child: const Text("Settings"),
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
                    loading: SliverFillRemaining(
                        child: const CircularProgressIndicator().iw.ih)),
          )));
}

extension XStream<T> on Stream<T> {
  Stream<T> sip(Function(T) t) => map((i) {
        t(i);
        return i;
      });
}
