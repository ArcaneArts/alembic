import 'package:alembic/core/repository_runtime.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:arcane/arcane.dart';

class HomeActivityStrip extends StatelessWidget {
  final RepositoryRuntime runtime;

  const HomeActivityStrip({
    super.key,
    required this.runtime,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return StreamBuilder<List<RepositoryWork>>(
      stream: runtime.repoWork.stream,
      initialData: runtime.repoWork.valueOrNull ?? const <RepositoryWork>[],
      builder: (context, snapshot) {
        List<RepositoryWork> work = snapshot.data ?? const <RepositoryWork>[];
        if (work.isEmpty) {
          return const SizedBox.shrink();
        }
        RepositoryWork first = work.first;
        return Padding(
          padding: const EdgeInsets.only(bottom: AlembicShadcnTokens.gapSm),
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(
              horizontal: AlembicShadcnTokens.gapMd,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.card,
              borderRadius:
                  BorderRadius.circular(AlembicShadcnTokens.controlRadius),
              border: Border.all(color: theme.colorScheme.border),
            ),
            child: Row(
              children: <Widget>[
                AlembicProgressMark(value: first.progress, size: 12),
                const Gap(AlembicShadcnTokens.gapSm),
                Text(
                  'Activity: ${work.length} task${work.length == 1 ? '' : 's'} running',
                  style: theme.typography.xSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(AlembicShadcnTokens.gapSm),
                Expanded(
                  child: Text(
                    '${first.repository.fullName} · ${first.message}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.xSmall.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
