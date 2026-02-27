import 'dart:math' as math;

import 'package:alembic/theme/alembic_tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

@immutable
class LiquidLensBubbleRecipe {
  final double distortion;
  final double distortionWidth;
  final double blurSigma;
  final double tintOpacity;
  final double borderOpacity;
  final double chromaticAberration;
  final double saturation;
  final double lightIntensity;
  final double oneSideLightIntensity;
  final double borderSoftness;

  const LiquidLensBubbleRecipe({
    this.distortion = 0.75,
    this.distortionWidth = 70,
    this.blurSigma = 0.75,
    this.tintOpacity = 0.015,
    this.borderOpacity = 0.3,
    this.chromaticAberration = 0.0042,
    this.saturation = 1.08,
    this.lightIntensity = 1.34,
    this.oneSideLightIntensity = 0.34,
    this.borderSoftness = 2.8,
  });
}

class LiquidLensBubble {
  static const LiquidLensBubbleRecipe standard = LiquidLensBubbleRecipe();

  static LiquidGlass build({
    required AlembicTokens tokens,
    required BorderRadius borderRadius,
    required Size size,
    required Offset offset,
    double scale = 1,
    bool showPrism = true,
    LiquidLensBubbleRecipe recipe = standard,
    Widget? child,
  }) {
    double width = size.width * scale;
    double height = size.height * scale;
    double left = offset.dx - ((width - size.width) * 0.5);
    double top = offset.dy - ((height - size.height) * 0.5);
    double cornerRadius = _cornerRadius(borderRadius, width, height);

    return LiquidGlass(
      width: width,
      height: height,
      position: LiquidGlassOffsetPosition(left: left, top: top),
      magnification: 1,
      distortion: recipe.distortion,
      distortionWidth: recipe.distortionWidth,
      chromaticAberration: showPrism ? recipe.chromaticAberration : 0,
      blur: LiquidGlassBlur(sigmaX: recipe.blurSigma, sigmaY: recipe.blurSigma),
      color: tokens.controlFill.withValues(alpha: recipe.tintOpacity),
      saturation: recipe.saturation,
      draggable: false,
      outOfBoundaries: false,
      enableInnerRadiusTransparent: false,
      shape: RoundedRectangleShape(
        cornerRadius: cornerRadius,
        borderWidth: 0.8,
        borderSoftness: recipe.borderSoftness,
        lightIntensity: recipe.lightIntensity,
        oneSideLightIntensity: recipe.oneSideLightIntensity,
        borderColor: tokens.rim.withValues(
            alpha: tokens.frameStrokeOpacity * recipe.borderOpacity),
        lightDirection: 39,
      ),
      child: child ?? const SizedBox.expand(),
    );
  }

  static Widget fallbackSurface({
    required AlembicTokens tokens,
    required BorderRadius borderRadius,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: tokens.controlFill.withValues(
          alpha: (tokens.controlFillOpacity * 0.5).clamp(0.0, 1.0),
        ),
        border: Border.all(
          color: tokens.rim.withValues(alpha: tokens.frameStrokeOpacity * 0.45),
          width: 1,
        ),
      ),
      child: const SizedBox.expand(),
    );
  }

  static double _cornerRadius(
      BorderRadius borderRadius, double width, double height) {
    double shortestEdge = math.min(width, height);
    double maxCornerRadius = math.max((shortestEdge * 0.5) - 1, 0);
    double radius = math.max(
      math.max(borderRadius.topLeft.x, borderRadius.topRight.x),
      math.max(borderRadius.bottomLeft.x, borderRadius.bottomRight.x),
    );
    return radius.clamp(0, maxCornerRadius);
  }
}
