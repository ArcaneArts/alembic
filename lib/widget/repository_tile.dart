import 'package:alembic/util/extensions.dart';
import 'package:alembic/widget/link_menu.dart';
import 'package:arcane/arcane.dart';

class RepositoryTile extends StatelessWidget {
  RepositoryTile({super.key});

  @override
  Widget build(BuildContext context) => ContextMenu(
      items: buildMenu(context),
      child: ListTile(
        title: OverflowMarquee(child: Text(context.repository.name)),
        subtitle: context.repository.description.trim().isNotEmpty
            ? Text(context.repository.description)
            : null,
      ));

  List<MenuItem> buildMenu(BuildContext context) => [
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
}
