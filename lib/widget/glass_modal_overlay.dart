import 'dart:ui';

import 'package:alembic/theme/alembic_tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

enum GlassModalFocusMode {
  nativeDimFocus,
  blurAndDim,
  dimOnly,
}

class GlassModalOverlay extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Alignment alignment;
  final bool includeChromaWash;
  final Duration duration;
  final GlassModalFocusMode? mode;
  final double blurSigmaMultiplier;
  final double? dimStrengthOverride;
  final double? whiteLiftStrengthOverride;

  const GlassModalOverlay({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.alignment = Alignment.center,
    this.includeChromaWash = false,
    this.duration = const Duration(milliseconds: 180),
    this.mode,
    this.blurSigmaMultiplier = 1.0,
    this.dimStrengthOverride,
    this.whiteLiftStrengthOverride,
  });

  @override
  Widget build(BuildContext context) {
    AlembicTokens tokens = context.alembicTokens;
    Animation<double>? routeAnimation = ModalRoute.of(context)?.animation;
    if (routeAnimation != null) {
      return AnimatedBuilder(
        animation: routeAnimation,
        builder: (context, _) {
          double value =
              Curves.easeOutCubic.transform(routeAnimation.value.clamp(0, 1));
          return _buildOverlay(tokens, value);
        },
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => _buildOverlay(tokens, value),
    );
  }

  Widget _buildOverlay(AlembicTokens tokens, double value) {
    GlassModalFocusMode resolvedMode = _resolveMode();
    double baseScrimAlpha = tokens.modalScrim.a;
    double dimStrength = dimStrengthOverride ??
        switch (resolvedMode) {
          GlassModalFocusMode.nativeDimFocus => 0.22,
          GlassModalFocusMode.blurAndDim => 0.10,
          GlassModalFocusMode.dimOnly => 0.32,
        };
    double resolvedScrimAlpha =
        (baseScrimAlpha * value * dimStrength).clamp(0.0, 1.0);
    double resolvedBlurSigma =
        (tokens.modalBlurSigma * blurSigmaMultiplier * value)
            .clamp(0.0, 256.0)
            .toDouble();
    double secondPassBlurSigma =
        (resolvedBlurSigma * 0.65).clamp(0.0, 256.0).toDouble();
    double whiteLiftStrength = whiteLiftStrengthOverride ??
        switch (resolvedMode) {
          GlassModalFocusMode.blurAndDim => 0.16,
          _ => 0,
        };

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (resolvedMode == GlassModalFocusMode.blurAndDim)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: resolvedBlurSigma,
                    sigmaY: resolvedBlurSigma,
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: secondPassBlurSigma,
                      sigmaY: secondPassBlurSigma,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.modalScrim.withValues(alpha: resolvedScrimAlpha),
              ),
            ),
          ),
        ),
        if (resolvedMode == GlassModalFocusMode.blurAndDim)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: CupertinoColors.white.withValues(
                    alpha: (whiteLiftStrength * value).clamp(0.0, 1.0),
                  ),
                ),
              ),
            ),
          ),
        if (includeChromaWash)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.2, -0.1),
                    radius: 1.1,
                    colors: <Color>[
                      tokens.modalChromaWash.withValues(alpha: value),
                      tokens.modalChromaWash.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Align(
          alignment: alignment,
          child: Padding(
            padding: padding,
            child: Opacity(
              opacity: (0.78 + (0.22 * value)).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: (0.985 + (0.015 * value)).clamp(0.0, 1.0),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }

  GlassModalFocusMode _resolveMode() {
    if (mode != null) {
      return mode!;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      return GlassModalFocusMode.nativeDimFocus;
    }
    return GlassModalFocusMode.blurAndDim;
  }
}
