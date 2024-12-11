import 'dart:async';

import 'package:alembic/main.dart';
import 'package:alembic/splash.dart';
import 'package:alembic/util/extensions.dart';
import 'package:alembic/widget/organization_section.dart';
import 'package:alembic/widget/personal_section.dart';
import 'package:arcane/arcane.dart';
import 'package:fast_log/fast_log.dart';
import 'package:github/github.dart';

class AlembicHome extends StatefulWidget {
  final GitHub github;

  const AlembicHome({super.key, required this.github});

  @override
  State<AlembicHome> createState() => _AlembicHomeState();
}

class _AlembicHomeState extends State<AlembicHome> {
  late Future<List<Repository>> allRepos;
  Map<Organization, List<Repository>> orgRepos = {};
  List<Repository> personalRepos = [];
  final BehaviorSubject<int> _fetching = BehaviorSubject.seeded(0);
  BehaviorSubject<String?> search = BehaviorSubject.seeded(null);
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    allRepos = _fetchAllRepos().catchError((e, es) {
      error(e);
      error(es);
      return <Repository>[];
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
  Widget build(BuildContext context) => SliverScreen(
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
          IconButtonMenu(icon: Icons.gear_six_fill, items: [
            MenuButton(
                leading: Icon(Icons.log_out_outline_ionic),
                child: const Text("Log Out"),
                onPressed: (_) => DialogConfirm(
                      title: "Log Out?",
                      description:
                          "Are you sure you want to log out? Your PAT will be deleted from this device.",
                      destructive: true,
                      onConfirm: () =>
                          box.deleteAll(["1", "authenticated"]).then((_) {
                        widget.github.dispose();
                        Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SplashScreen()),
                            (route) => false);
                      }),
                    ).open(context)),
            MenuButton(
                child: Text("Restart"),
                leading: Icon(Icons.refresh_ionic),
                onPressed: (_) => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SplashScreen()),
                    (route) => false))
          ])
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
            : PylonCluster(
                pylons: [
                    Pylon<Map<Organization, List<Repository>>>.data(
                        value: orgRepos),
                    Pylon<BehaviorSubject<String?>>.data(value: search)
                  ],
                builder: (context) => MultiSliver(
                      children: [
                        context.search.buildNullable((query) =>
                            Pylon<List<Repository>>(
                                key: ValueKey("personal.${query ?? ""}"),
                                value: personalRepos.filterBy(query),
                                builder: (context) => PersonalSection())),
                        ...orgRepos.keys
                            .sorted((a, b) =>
                                (a.login ?? "org").compareTo(b.login ?? "org"))
                            .withPylons((context) => OrganizationSection())
                      ],
                    )),
      ));
}

extension XStream<T> on Stream<T> {
  Stream<T> sip(Function(T) t) => map((i) {
        t(i);
        return i;
      });
}
