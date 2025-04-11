import 'package:alembic/util/extensions.dart';
import 'package:alembic/widget/repository_tile.dart';
import 'package:arcane/arcane.dart';
import 'package:github/github.dart';

class RepositoryListView extends StatelessWidget {
  const RepositoryListView({super.key});

  @override
  Widget build(BuildContext context) => SliverList.builder(
        itemBuilder: (context, i) => Pylon<Repository>(
          value: context.repositories[i],
          builder: (context) => RepositoryTile(),
        ),
        itemCount: context.repositories.length,
      );
}
