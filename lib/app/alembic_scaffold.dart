import 'package:arcane/arcane.dart';
import 'package:alembic/app/alembic_tokens.dart';

class AlembicScaffold extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AlembicScaffold({
    super.key,
    required this.child,
    this.padding = AlembicShadcnTokens.shellPadding,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    ColorScheme scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.background,
      ),
      child: SafeArea(
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
