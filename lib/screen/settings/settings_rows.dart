import 'package:alembic/ui/alembic_ui.dart';
import 'package:arcane/arcane.dart';

class SettingsPathRow extends StatelessWidget {
  final String title;
  final String description;
  final String path;
  final String actionLabel;
  final VoidCallback? onPressed;

  const SettingsPathRow({
    super.key,
    required this.title,
    required this.description,
    required this.path,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.typography.small.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Gap(AlembicShadcnTokens.gapXs),
              Text(
                description,
                style: theme.typography.xSmall.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
              const Gap(AlembicShadcnTokens.gapSm),
              Text(
                path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.xSmall.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.foreground,
                ),
              ),
            ],
          ),
        ),
        const Gap(AlembicShadcnTokens.gapLg),
        AlembicToolbarButton(
          label: actionLabel,
          onPressed: onPressed,
          compact: true,
        ),
      ],
    );
  }
}
