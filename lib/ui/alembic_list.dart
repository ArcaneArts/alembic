import 'package:alembic/ui/alembic_layout.dart';
import 'package:alembic/ui/alembic_tokens.dart';
import 'package:arcane/arcane.dart';

class AlembicListRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? description;
  final Widget? leading;
  final List<Widget> meta;
  final Widget primaryAction;
  final Widget? secondaryActions;

  const AlembicListRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.description,
    this.leading,
    required this.meta,
    required this.primaryAction,
    this.secondaryActions,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AlembicShadcnTokens.listRowMaxWidth,
        ),
        child: SizedBox(
          width: double.infinity,
          child: AlembicSurface(
            padding: EdgeInsets.zero,
            tone: AlembicSurfaceTone.panel,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                bool compact = constraints.maxWidth < 430;
                Widget copy = _AlembicListRowCopy(
                  title: title,
                  subtitle: subtitle,
                  description: description,
                  meta: meta,
                );
                Widget actions = SizedBox(
                  width: AlembicShadcnTokens.rowActionColumnWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        width: AlembicShadcnTokens.rowActionButtonWidth,
                        child: primaryAction,
                      ),
                      if (secondaryActions != null) ...<Widget>[
                        const Gap(AlembicShadcnTokens.gapSm),
                        Align(
                          alignment: Alignment.centerRight,
                          child: secondaryActions!,
                        ),
                      ],
                    ],
                  ),
                );
                if (compact) {
                  return Padding(
                    padding: AlembicShadcnTokens.rowPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _AlembicListRowContent(
                          leading: leading,
                          copy: copy,
                        ),
                        const Gap(AlembicShadcnTokens.gapMd),
                        actions,
                      ],
                    ),
                  );
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AlembicShadcnTokens.listRowHeight,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      if (leading != null) ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.only(
                            left: AlembicShadcnTokens.gapMd,
                          ),
                          child: leading!,
                        ),
                        const Gap(AlembicShadcnTokens.gapSm),
                      ],
                      Expanded(
                        child: Padding(
                          padding: AlembicShadcnTokens.rowPadding,
                          child: copy,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          right: AlembicShadcnTokens.gapMd,
                        ),
                        child: actions,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AlembicListRowContent extends StatelessWidget {
  final Widget? leading;
  final Widget copy;

  const _AlembicListRowContent({
    required this.leading,
    required this.copy,
  });

  @override
  Widget build(BuildContext context) {
    if (leading == null) {
      return copy;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        leading!,
        const Gap(AlembicShadcnTokens.gapSm),
        Expanded(child: copy),
      ],
    );
  }
}

class AlembicMetaText extends StatelessWidget {
  final String label;

  const AlembicMetaText({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: Theme.of(context).typography.xSmall.copyWith(
              color: Theme.of(context).colorScheme.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
      );
}

class _AlembicListRowCopy extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? description;
  final List<Widget> meta;

  const _AlembicListRowCopy({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.small.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Gap(2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.xSmall.copyWith(
            color: theme.colorScheme.mutedForeground,
          ),
        ),
        const Gap(AlembicShadcnTokens.gapXs),
        SizedBox(
          height: AlembicShadcnTokens.listDescriptionLineHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              description ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.xSmall.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          ),
        ),
        if (meta.isNotEmpty) ...<Widget>[
          const Gap(AlembicShadcnTokens.gapSm),
          Wrap(
            spacing: AlembicShadcnTokens.gapSm,
            runSpacing: AlembicShadcnTokens.gapXs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: meta,
          ),
        ],
      ],
    );
  }
}
