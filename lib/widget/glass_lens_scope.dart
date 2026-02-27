import 'package:alembic/widget/glass_panel.dart';
import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

typedef GlassLensBuilder = List<LiquidGlass> Function(
  BuildContext context,
  Size size,
);

class GlassLensScope extends StatelessWidget {
  final BorderRadius borderRadius;
  final Widget backgroundWidget;
  final Widget child;
  final GlassLensBuilder lensBuilder;
  final bool ignorePointer;
  final Widget? fallback;

  const GlassLensScope({
    super.key,
    required this.borderRadius,
    required this.backgroundWidget,
    required this.child,
    required this.lensBuilder,
    this.ignorePointer = true,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (alembicIsFlutterTestEnvironment() ||
            !constraints.hasBoundedWidth ||
            !constraints.hasBoundedHeight ||
            constraints.maxWidth <= 0 ||
            constraints.maxHeight <= 0) {
          return fallback ?? child;
        }

        Widget lensLayer = ClipRRect(
          borderRadius: borderRadius,
          child: LiquidGlassView(
            pixelRatio: 1,
            useSync: true,
            realTimeCapture: true,
            refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
            backgroundWidget: backgroundWidget,
            children: lensBuilder(
              context,
              Size(constraints.maxWidth, constraints.maxHeight),
            ),
          ),
        );

        if (ignorePointer) {
          lensLayer = IgnorePointer(child: lensLayer);
        }

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            lensLayer,
            child,
          ],
        );
      },
    );
  }
}
