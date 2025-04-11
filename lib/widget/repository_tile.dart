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
  const RepositoryTile({super.key});

  @override
  State<RepositoryTile> createState() => _RepositoryTileState();
}

class _RepositoryTileState extends State<RepositoryTile>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    Widget buildArchivalIndicator(int days) {
      Color color;
      if (days > 20) {
        color = Colors.green;
      } else if (days >= 10) {
        color = Colors.yellow;
      } else if (days >= 5) {
        color = Colors.orange;
      } else {
        color = Colors.red;
      }

      return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: HoverCard(
            hoverBuilder: (context) {
              return SurfaceCard(
                child: Basic(
                  leading: Icon(Icons.calendar_clear_outline_ionic),
                  content: Text("$days days until archival"),
                ),
              ).ih.iw;
            },
            child: Text(
              '$days',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ));
    }

    super.build(context);

    return Pylon<ArcaneRepository>(
      value: ArcaneRepository(repository: context.repository),
      builder: (context) => context.arepository.state.build((state) =>
          ContextMenu(
              items: buildMenu(context, state),
              child: syncingRepositories
                  .map((i) =>
                      i.any((g) => g.fullName == context.repository.fullName))
                  .distinct()
                  .build((loading) => context.arepository
                      .streamWork()
                      .buildNullable(
                        (work) => ListTile(
                            subtitle: work?.isNotEmpty ?? false
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(),
                                      const Gap(4),
                                      Text(work!.join(", ")).xSmall(),
                                    ],
                                  )
                                : context.arepository.shouldBeSpecific()
                                    ? Text(context.repository.owner?.login ??
                                            "?")
                                        .xSmall()
                                    : null,
                            trailing: loading
                                ? const CircularProgressIndicator()
                                : context.arepository.state.build(
                                    (state) => switch (state) {
                                          RepoState.active =>
                                            FutureBuilder<int>(
                                              future: context.arepository
                                                  .daysUntilArchival,
                                              builder: (context, snapshot) {
                                                return Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (snapshot.hasData)
                                                      buildArchivalIndicator(
                                                          snapshot.data!)
                                                    else
                                                      const SizedBox(
                                                          width: 24,
                                                          height: 24),
                                                    Clickable(
                                                      child: const Icon(
                                                          Icons.folder_fill),
                                                      onPressed: () =>
                                                          open(context),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          RepoState.cloud =>
                                            const Icon(Icons.cloud),
                                          RepoState.archived =>
                                            const Icon(Icons.archive),
                                        },
                                    loading: const CircularProgressIndicator()),
                            onPressed: () => context.arepository
                                .open(context.github, context),
                            title: Text(context.repository.name)),
                      )))),
    );
  }

  void open(BuildContext context) {
    WindowUtil.hide();
    context.arepository.openInFinder().then((i) {
      update.add(update.value + 1);
    });
  }

  List<MenuItem> buildMenu(BuildContext context, RepoState state) => [
        MenuButton(
          onPressed: () => open(context),
          leading: const Icon(Icons.pencil),
          child: const Text("Open"),
        ),
        MenuButton(
          leading: const Icon(Icons.gear_six),
          onPressed: () => Arcane.push(context, const RepositorySettings()),
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
        const MenuDivider(),
        if (state == RepoState.active) ...[
          MenuButton(
              leading: const Icon(Icons.download),
              child: const Text("Pull"),
              onPressed: () =>
                  context.arepository.ensureRepositoryUpdated(context.github)),
          MenuButton(
              leading: const Icon(Icons.archive),
              onPressed: () => context.arepository.archive(),
              child: const Text("Archive")),
          MenuButton(
              leading: const Icon(Icons.trash),
              onPressed: () => DialogConfirm(
                  title: "Delete ${context.repository.fullName}?",
                  destructive: true,
                  confirmText: "Delete Project",
                  description:
                      "Are you sure you want to delete this repository from your active workspace? THERE COULD BE UNSTAGED OR UNPUSHED LOCAL CHANGES YOU WILL LOSE FOREVER!",
                  onConfirm: () =>
                      context.arepository.deleteRepository()).open(context),
              child: const Text("Delete")),
        ],
        if (state == RepoState.archived) ...[
          MenuButton(
              leading: const Icon(Icons.upload),
              onPressed: () => context.arepository.unarchive(context.github),
              child: const Text("Activate")),
          MenuButton(
              leading: const Icon(Icons.refresh_ionic),
              onPressed: () =>
                  context.arepository.updateArchive(context.github),
              child: const Text("Update Archive")),
          MenuButton(
              leading: const Icon(Icons.trash),
              onPressed: () => DialogConfirm(
                  title: "Delete Archive ${context.repository.fullName}?",
                  description:
                      "Are you sure you want to delete this archive? You will lose the image of this repository. THERE COULD BE LOCAL UNSTAGED OR UNPUSHED CHANGES IN THIS REPOSITORY ARCHIVE YOU COULD LOSE CHANGES FOREVER!",
                  destructive: true,
                  confirmText: "Delete Archive",
                  onConfirm: () =>
                      context.arepository.deleteRepository()).open(context),
              child: const Text("Delete Archive")),
        ],
        if (state == RepoState.cloud) ...[
          MenuButton(
              leading: const Icon(Icons.download),
              onPressed: () =>
                  context.arepository.ensureRepositoryActive(context.github),
              child: const Text("Clone")),
          MenuButton(
              leading: const Icon(Icons.archive),
              onPressed: () =>
                  context.arepository.archiveFromCloud(context.github),
              child: const Text("Archive")),
        ]
      ];

  @override
  bool get wantKeepAlive => true;
}
