import 'dart:math' as math;
import 'dart:ui';

import 'package:alembic/theme/alembic_tokens.dart';
import 'package:alembic/widget/refracting_edge.dart' show GlassEdgeIntensity;
import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

bool alembicIsFlutterTestEnvironment() {
  if (const bool.fromEnvironment('FLUTTER_TEST')) {
    return true;
  }

  String bindingName = WidgetsBinding.instance.runtimeType.toString();
  return bindingName.contains('TestWidgetsFlutterBinding') ||
      bindingName.contains('AutomatedTestWidgetsFlutterBinding') ||
      bindingName.contains('LiveTestWidgetsFlutterBinding');
}

enum GlassPanelRole {
  host,
  control,
  inline,
  overlay,
}

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? fillColor;
  final GlassPanelRole role;
  final GlassEdgeIntensity? edgeIntensity;
  final bool animateEdge;
  final bool liveLens;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.fillColor,
    this.role = GlassPanelRole.control,
    this.edgeIntensity,
    this.animateEdge = true,
    this.liveLens = false,
  });

  @override
  Widget build(BuildContext context) {
    if (role == GlassPanelRole.host) {
      return Padding(
        padding: padding,
        child: child,
      );
    }

    AlembicTokens tokens = context.alembicTokens;
    _PanelRecipe recipe = _PanelRecipe.fromRole(
      role: role,
      tokens: tokens,
      edgeIntensity: edgeIntensity,
    );

    Color panelColor = fillColor ?? recipe.baseColor;
    double panelOpacity =
        (fillColor?.a ?? recipe.fillOpacity).clamp(0.0, 1.0).toDouble();

    bool useLiveLens = recipe.useLiveLens && liveLens;
    if (useLiveLens && !alembicIsFlutterTestEnvironment()) {
      return _buildOverlayLens(
        tokens: tokens,
        recipe: recipe,
        panelColor: panelColor,
        panelOpacity: panelOpacity,
      );
    }

    return _buildStaticPanel(
      tokens: tokens,
      recipe: recipe,
      panelColor: panelColor,
      panelOpacity: panelOpacity,
    );
  }

  Widget _buildOverlayLens({
    required AlembicTokens tokens,
    required _PanelRecipe recipe,
    required Color panelColor,
    required double panelOpacity,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: recipe.shadowOpacity <= 0
            ? const <BoxShadow>[]
            : <BoxShadow>[
                BoxShadow(
                  color: tokens.shadow.withValues(alpha: recipe.shadowOpacity),
                  blurRadius: tokens.singleShadowBlur,
                  offset: Offset(0, tokens.singleShadowOffsetY),
                ),
              ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedWidth ||
              !constraints.hasBoundedHeight ||
              constraints.maxWidth <= 0 ||
              constraints.maxHeight <= 0) {
            return _buildStaticPanel(
              tokens: tokens,
              recipe: recipe.copyWith(useLiveLens: false),
              panelColor: panelColor,
              panelOpacity: panelOpacity,
            );
          }

          Size panelSize = Size(constraints.maxWidth, constraints.maxHeight);
          double shortestEdge = math.min(panelSize.width, panelSize.height);
          double maxCornerRadius = math.max((shortestEdge * 0.5) - 1, 0);
          double cornerRadius =
              _resolveCornerRadius().clamp(0, maxCornerRadius);

          return ClipRRect(
            borderRadius: borderRadius,
            child: LiquidGlassView(
              pixelRatio: 1,
              useSync: true,
              realTimeCapture: true,
              refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
              // Never black: this fallback scene is refracted when route capture
              // data is sparse or unavailable.
              backgroundWidget: _LensFallbackBackground(
                topTint: panelColor.withValues(
                  alpha: (panelOpacity * 0.22).clamp(0.0, 1.0),
                ),
                bottomTint: panelColor.withValues(
                  alpha: (panelOpacity * 0.12).clamp(0.0, 1.0),
                ),
              ),
              children: <LiquidGlass>[
                LiquidGlass(
                  width: panelSize.width,
                  height: panelSize.height,
                  position: const LiquidGlassOffsetPosition(left: 0, top: 0),
                  magnification: 1,
                  distortion: recipe.distortion,
                  distortionWidth: recipe.distortionWidth,
                  chromaticAberration: recipe.chromaticAberration,
                  blur: const LiquidGlassBlur(sigmaX: 1.1, sigmaY: 1.1),
                  color: panelColor.withValues(
                    alpha: (panelOpacity * 0.24).clamp(0.0, 1.0),
                  ),
                  saturation: 1.10,
                  draggable: false,
                  outOfBoundaries: false,
                  enableInnerRadiusTransparent: false,
                  shape: RoundedRectangleShape(
                    cornerRadius: cornerRadius,
                    borderWidth: 1,
                    borderSoftness: 2.4,
                    lightIntensity: 1.26,
                    oneSideLightIntensity: 0.34,
                    borderColor:
                        tokens.rim.withValues(alpha: recipe.rimOpacity),
                    lightDirection: 39,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          panelColor.withValues(
                            alpha: (panelOpacity * 0.22).clamp(0.0, 1.0),
                          ),
                          panelColor.withValues(
                            alpha: (panelOpacity * 0.1).clamp(0.0, 1.0),
                          ),
                        ],
                      ),
                      borderRadius: borderRadius,
                    ),
                    child: Padding(
                      padding: padding,
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStaticPanel({
    required AlembicTokens tokens,
    required _PanelRecipe recipe,
    required Color panelColor,
    required double panelOpacity,
  }) {
    double highAlpha = (panelOpacity * 1.08).clamp(0.0, 1.0);
    double lowAlpha = (panelOpacity * 0.76).clamp(0.0, 1.0);
    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            panelColor.withValues(alpha: highAlpha),
            panelColor.withValues(alpha: lowAlpha),
          ],
        ),
        border: Border.all(
          color: tokens.stroke.withValues(alpha: recipe.strokeOpacity),
          width: 1,
        ),
        boxShadow: recipe.shadowOpacity <= 0
            ? const <BoxShadow>[]
            : <BoxShadow>[
                BoxShadow(
                  color: tokens.shadow.withValues(alpha: recipe.shadowOpacity),
                  blurRadius: tokens.singleShadowBlur,
                  offset: Offset(0, tokens.singleShadowOffsetY),
                ),
              ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (recipe.blurSigma <= 0) {
      return ClipRRect(borderRadius: borderRadius, child: body);
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: recipe.blurSigma,
          sigmaY: recipe.blurSigma,
        ),
        child: body,
      ),
    );
  }

  double _resolveCornerRadius() {
    return math.max(
      math.max(borderRadius.topLeft.x, borderRadius.topRight.x),
      math.max(borderRadius.bottomLeft.x, borderRadius.bottomRight.x),
    );
  }
}

class _LensFallbackBackground extends StatelessWidget {
  final Color topTint;
  final Color bottomTint;

  const _LensFallbackBackground({
    required this.topTint,
    required this.bottomTint,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[topTint, bottomTint],
        ),
      ),
    );
  }
}

class _PanelRecipe {
  final Color baseColor;
  final double fillOpacity;
  final double strokeOpacity;
  final double rimOpacity;
  final double shadowOpacity;
  final double blurSigma;
  final bool useLiveLens;
  final double distortion;
  final double distortionWidth;
  final double chromaticAberration;

  const _PanelRecipe({
    required this.baseColor,
    required this.fillOpacity,
    required this.strokeOpacity,
    required this.rimOpacity,
    required this.shadowOpacity,
    required this.blurSigma,
    required this.useLiveLens,
    required this.distortion,
    required this.distortionWidth,
    required this.chromaticAberration,
  });

  factory _PanelRecipe.fromRole({
    required GlassPanelRole role,
    required AlembicTokens tokens,
    required GlassEdgeIntensity? edgeIntensity,
  }) {
    double chroma = switch (edgeIntensity ?? GlassEdgeIntensity.medium) {
      GlassEdgeIntensity.low => tokens.chromaLowOpacity,
      GlassEdgeIntensity.medium => tokens.chromaMediumOpacity,
      GlassEdgeIntensity.high => tokens.chromaHighOpacity,
    };
    double lensChroma = chroma < 0.0018 ? 0.0018 : chroma;
    double overlayChroma = chroma < 0.0024 ? 0.0024 : chroma;

    double rim = switch (edgeIntensity ?? GlassEdgeIntensity.medium) {
      GlassEdgeIntensity.low => tokens.frameStrokeOpacity * 0.82,
      GlassEdgeIntensity.medium => tokens.frameStrokeOpacity,
      GlassEdgeIntensity.high => tokens.frameStrokeOpacity * 1.15,
    };

    return switch (role) {
      GlassPanelRole.host => _PanelRecipe(
          baseColor: tokens.hostFill,
          fillOpacity: 0,
          strokeOpacity: 0,
          rimOpacity: 0,
          shadowOpacity: 0,
          blurSigma: 0,
          useLiveLens: false,
          distortion: 0.75,
          distortionWidth: 75,
          chromaticAberration: lensChroma,
        ),
      GlassPanelRole.control => _PanelRecipe(
          baseColor: tokens.controlFill,
          fillOpacity: tokens.controlFillOpacity,
          strokeOpacity: tokens.strokeOpacity * 0.9,
          rimOpacity: 0,
          shadowOpacity: 0.018,
          blurSigma: 14,
          useLiveLens: false,
          distortion: 0.78,
          distortionWidth: 78,
          chromaticAberration: lensChroma,
        ),
      GlassPanelRole.inline => _PanelRecipe(
          baseColor: tokens.inlineFill,
          fillOpacity: tokens.inlineFillOpacity,
          strokeOpacity: tokens.strokeOpacity * 0.82,
          rimOpacity: 0,
          shadowOpacity: 0.014,
          blurSigma: 12,
          useLiveLens: false,
          distortion: 0.78,
          distortionWidth: 78,
          chromaticAberration: lensChroma,
        ),
      GlassPanelRole.overlay => _PanelRecipe(
          baseColor: tokens.overlayFill,
          fillOpacity: tokens.overlayFillOpacity,
          strokeOpacity: tokens.strokeOpacity,
          rimOpacity: rim,
          shadowOpacity: 0.05,
          blurSigma: 28,
          useLiveLens: true,
          distortion: 0.86,
          distortionWidth: 92,
          chromaticAberration: overlayChroma,
        ),
    };
  }

  _PanelRecipe copyWith({
    bool? useLiveLens,
  }) {
    return _PanelRecipe(
      baseColor: baseColor,
      fillOpacity: fillOpacity,
      strokeOpacity: strokeOpacity,
      rimOpacity: rimOpacity,
      shadowOpacity: shadowOpacity,
      blurSigma: blurSigma,
      useLiveLens: useLiveLens ?? this.useLiveLens,
      distortion: distortion,
      distortionWidth: distortionWidth,
      chromaticAberration: chromaticAberration,
    );
  }
}
