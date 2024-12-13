import 'package:alembic/core/arcane_repository.dart';
import 'package:alembic/screen/home.dart';
import 'package:alembic/screen/repository_settings.dart';
import 'package:alembic/util/extensions.dart';
import 'package:alembic/util/window.dart';
import 'package:alembic/widget/link_menu.dart';
import 'package:arcane/arcane.dart';
import 'package:github/github.dart';

BehaviorSubject<List<Repository>> syncingRepositories =
    BehaviorSubject.seeded([]);

class RepositoryTile extends StatefulWidget {
  RepositoryTile({super.key});

  @override
  State<RepositoryTile> createState() => _RepositoryTileState();
}

class _RepositoryTileState extends State<RepositoryTile>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Pylon<ArcaneRepository>(
      value: ArcaneRepository(repository: context.repository),
      builder: (context) => ContextMenu(
          items: buildMenu(context),
          child: syncingRepositories
              .map((i) =>
                  i.any((g) => g.fullName == context.repository.fullName))
              .distinct()
              .build((loading) => ListTile(
                    trailing: loading
                        ? const CircularProgressIndicator()
                        : context.arepository.state.build(
                            (state) => switch (state) {
                                  RepoState.active => Clickable(
                                      child: const Icon(Icons.folder_fill),
                                      onPressed: () => context.arepository
                                          .openInFinder()
                                          .then((i) {
                                        updateActiveSection
                                            .add(updateActiveSection.value + 1);
                                        WindowUtil.hide();
                                      }),
                                    ),
                                  RepoState.cloud => const Icon(Icons.cloud),
                                  RepoState.archived =>
                                    const Icon(Icons.archive),
                                },
                            loading: const CircularProgressIndicator()),
                    onPressed: () => context.arepository.open(context.github),
                    title:
                        OverflowMarquee(child: Text(context.repository.name)),
                  ))),
    );
  }

  List<MenuItem> buildMenu(BuildContext context) => [
        MenuButton(
          leading: const Icon(Icons.gear_six),
          onPressed: (_) => Arcane.push(context, const RepositorySettings()),
          child: const Text("Configure"),
        ),
        const MenuDivider(),
        linkMenu(
            text: "View on Github",
            url:
                "https://github.com/${context.repository.owner?.login}/${context.repository.name}",
            icon: Icons.open_ionic),
        linkMenu(
            text: "Issues",
            url:
                "https://github.com/${context.repository.owner?.login}/${context.repository.name}/issues",
            icon: Icons.open_ionic),
        linkMenu(
            text: "Pull Requests",
            url:
                "https://github.com/${context.repository.owner?.login}/${context.repository.name}/pulls",
            icon: Icons.open_ionic),
        const MenuDivider(),
        linkMenu(
            text: "New Issue",
            url:
                "https://github.com/${context.repository.owner?.login}/${context.repository.name}/issues/new",
            icon: Icons.plus),
        linkMenu(
            text: "New Pull Request",
            url:
                "https://github.com/${context.repository.owner?.login}/${context.repository.name}/compare",
            icon: Icons.plus),
      ];

  @override
  bool get wantKeepAlive => true;
}
