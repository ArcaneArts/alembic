import 'package:alembic/util/extensions.dart';
import 'package:alembic/widget/repository_list.dart';
import 'package:arcane/arcane.dart';

class ActiveSection extends StatelessWidget {
  ActiveSection({super.key});

  @override
  Widget build(BuildContext context) => context.repositories.isEmpty
      ? const SliverToBoxAdapter()
      : BarSection(
          headerText: "Active",
          sliver: RepositoryListView(),
        );
}
