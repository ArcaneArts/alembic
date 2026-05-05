import 'package:alembic/ui/alembic_tokens.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

class AlembicProgressMark extends StatelessWidget {
  final double? value;
  final double size;
  final m.Color? color;

  const AlembicProgressMark({
    super.key,
    this.value,
    this.size = 13,
    this.color,
  });

  double get _fillValue {
    double? progress = value;
    if (progress == null) {
      return 0;
    }
    if (progress < 0) {
      return 0;
    }
    if (progress > 1) {
      return 1;
    }
    return progress;
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    m.Color foreground = color ?? theme.colorScheme.foreground;
    m.Color border = foreground.withValues(alpha: 0.32);
    m.Color fill = foreground.withValues(alpha: value == null ? 0.62 : 0.9);
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary,
          borderRadius: BorderRadius.circular(AlembicShadcnTokens.badgeRadius),
          border: Border.all(color: border),
        ),
        child: value == null
            ? Center(
                child: SizedBox.square(
                  dimension: 5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _fillValue,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: fill,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class AlembicProgressBar extends StatelessWidget {
  final double? value;
  final double height;

  const AlembicProgressBar({
    super.key,
    this.value,
    this.height = 3,
  });

  double get _fillValue {
    double? progress = value;
    if (progress == null) {
      return 0.16;
    }
    if (progress < 0) {
      return 0;
    }
    if (progress > 1) {
      return 1;
    }
    return progress;
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary,
          borderRadius: BorderRadius.circular(AlembicShadcnTokens.badgeRadius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AlembicShadcnTokens.badgeRadius),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: _fillValue,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
