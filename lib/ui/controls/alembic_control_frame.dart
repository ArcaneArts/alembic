import 'package:alembic/ui/alembic_tokens.dart';
import 'package:arcane/arcane.dart';

class AlembicControlFrame extends StatelessWidget {
  final bool compact;
  final bool iconOnly;
  final Widget child;

  const AlembicControlFrame({
    super.key,
    required this.compact,
    required this.iconOnly,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      double size = compact
          ? AlembicShadcnTokens.compactIconButtonSize
          : AlembicShadcnTokens.iconButtonSize;
      return SizedBox.square(
        dimension: size,
        child: child,
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: compact
            ? AlembicShadcnTokens.compactButtonMinWidth
            : AlembicShadcnTokens.buttonMinWidth,
        minHeight: compact
            ? AlembicShadcnTokens.compactButtonHeight
            : AlembicShadcnTokens.buttonHeight,
      ),
      child: child,
    );
  }
}
