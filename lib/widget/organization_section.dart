import 'package:alembic/util/extensions.dart';
import 'package:alembic/widget/link_menu.dart';
import 'package:alembic/widget/repository_list.dart';
import 'package:arcane/arcane.dart';
import 'package:github/github.dart';

class OrganizationSection extends StatelessWidget {
  OrganizationSection({super.key});

  @override
  Widget build(BuildContext context) =>
      context.search.buildNullable((query) => Pylon<List<Repository>>(
            key: ValueKey("org.${context.organization.login}.${query ?? ""}"),
            value: context.organizations[context.organization]!.filterBy(query),
            builder: (context) => context.repositories.isEmpty
                ? const SliverToBoxAdapter()
                : BarSection(
                    trailing: [
                        IconButtonMenu(icon: Icons.dots_three_vertical, items: [
                          linkMenu(
                              text: "New Repository",
                              url:
                                  "https://github.com/organizations/${context.organization.login}/repositories/new",
                              icon: Icons.plus)
                        ])
                      ],
                    headerText: context.organization.login,
                    sliver: RepositoryListView()),
          ));
}
