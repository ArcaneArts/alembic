import 'package:alembic/util/extensions.dart';
import 'package:alembic/widget/link_menu.dart';
import 'package:alembic/widget/repository_list.dart';
import 'package:arcane/arcane.dart';

class PersonalSection extends StatelessWidget {
  const PersonalSection({super.key});

  @override
  Widget build(BuildContext context) => context.repositories.isEmpty
      ? const SliverToBoxAdapter()
      : BarSection(
          headerText: "Personal",
          sliver: RepositoryListView(),
          trailing: [
              IconButtonMenu(icon: Icons.dots_three_vertical, items: [
                linkMenu(
                    text: "New Repository",
                    url: "https://github.com/new",
                    icon: Icons.plus)
              ])
            ]);
}

// https://github.com/organizations/ArcaneArts/repositories/new
