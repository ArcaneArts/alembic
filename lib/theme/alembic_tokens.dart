import 'package:flutter/cupertino.dart';

@immutable
class AlembicTokens {
  final Color backdropTop;
  final Color backdropBottom;

  final Color ambientBlue;
  final Color ambientRose;

  final Color prismCyan;
  final Color prismMagenta;
  final Color prismBlue;

  final Color hostFill;
  final Color controlFill;
  final Color inlineFill;
  final Color overlayFill;

  final Color stroke;
  final Color rim;
  final Color specular;
  final Color shadow;

  final Color frameStroke;
  final Color modalScrim;
  final Color modalChromaWash;

  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color warning;
  final Color danger;

  final double hostFillOpacity;
  final double controlFillOpacity;
  final double inlineFillOpacity;
  final double overlayFillOpacity;

  final double strokeOpacity;
  final double frameStrokeOpacity;

  final double chromaLowOpacity;
  final double chromaMediumOpacity;
  final double chromaHighOpacity;

  final double edgeWidthLow;
  final double edgeWidthMedium;
  final double edgeWidthHigh;

  final double edgeGlowHighOpacity;
  final double modalBlurSigma;

  final double singleShadowBlur;
  final double singleShadowOffsetY;

  final double radiusLarge;
  final double radiusMedium;
  final double radiusSmall;
  final double contentPadding;

  const AlembicTokens({
    required this.backdropTop,
    required this.backdropBottom,
    required this.ambientBlue,
    required this.ambientRose,
    required this.prismCyan,
    required this.prismMagenta,
    required this.prismBlue,
    required this.hostFill,
    required this.controlFill,
    required this.inlineFill,
    required this.overlayFill,
    required this.stroke,
    required this.rim,
    required this.specular,
    required this.shadow,
    required this.frameStroke,
    required this.modalScrim,
    required this.modalChromaWash,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.hostFillOpacity,
    required this.controlFillOpacity,
    required this.inlineFillOpacity,
    required this.overlayFillOpacity,
    required this.strokeOpacity,
    required this.frameStrokeOpacity,
    required this.chromaLowOpacity,
    required this.chromaMediumOpacity,
    required this.chromaHighOpacity,
    required this.edgeWidthLow,
    required this.edgeWidthMedium,
    required this.edgeWidthHigh,
    required this.edgeGlowHighOpacity,
    required this.modalBlurSigma,
    required this.singleShadowBlur,
    required this.singleShadowOffsetY,
    required this.radiusLarge,
    required this.radiusMedium,
    required this.radiusSmall,
    required this.contentPadding,
  });

  static const AlembicTokens light = AlembicTokens(
    backdropTop: Color(0xFFF7FAFF),
    backdropBottom: Color(0xFFEFF5FF),
    ambientBlue: Color(0x10FFFFFF),
    ambientRose: Color(0x0AFFFFFF),
    prismCyan: Color(0xFFBED9E7),
    prismMagenta: Color(0xFFD8C5D4),
    prismBlue: Color(0xFFC0CCE2),
    hostFill: Color(0xFFFFFFFF),
    controlFill: Color(0xFFFFFFFF),
    inlineFill: Color(0xFFFFFFFF),
    overlayFill: Color(0xFFFFFFFF),
    stroke: Color(0xFFFFFFFF),
    rim: Color(0xFFFFFFFF),
    specular: Color(0xFFFFFFFF),
    shadow: Color(0x14000000),
    frameStroke: Color(0xFFFFFFFF),
    modalScrim: Color(0x0A000000),
    modalChromaWash: Color(0x1AFFFFFF),
    textPrimary: Color(0xFF1B2533),
    textSecondary: Color(0xCC3A4A5C),
    success: Color(0xE01D2E43),
    warning: Color(0xD27A6334),
    danger: Color(0xD27E3E55),
    hostFillOpacity: 0.22,
    controlFillOpacity: 0.24,
    inlineFillOpacity: 0.20,
    overlayFillOpacity: 0.46,
    strokeOpacity: 0.48,
    frameStrokeOpacity: 0.78,
    chromaLowOpacity: 0.0040,
    chromaMediumOpacity: 0.0050,
    chromaHighOpacity: 0.0062,
    edgeWidthLow: 0.74,
    edgeWidthMedium: 0.90,
    edgeWidthHigh: 1.08,
    edgeGlowHighOpacity: 0.14,
    modalBlurSigma: 64,
    singleShadowBlur: 6,
    singleShadowOffsetY: 2,
    radiusLarge: 24,
    radiusMedium: 16,
    radiusSmall: 12,
    contentPadding: 14,
  );

  static const AlembicTokens dark = AlembicTokens(
    backdropTop: Color(0xFFF7FAFF),
    backdropBottom: Color(0xFFEFF5FF),
    ambientBlue: Color(0x10FFFFFF),
    ambientRose: Color(0x0AFFFFFF),
    prismCyan: Color(0xFFBED9E7),
    prismMagenta: Color(0xFFD8C5D4),
    prismBlue: Color(0xFFC0CCE2),
    hostFill: Color(0xFFFFFFFF),
    controlFill: Color(0xFFFFFFFF),
    inlineFill: Color(0xFFFFFFFF),
    overlayFill: Color(0xFFFFFFFF),
    stroke: Color(0xFFFFFFFF),
    rim: Color(0xFFFFFFFF),
    specular: Color(0xFFFFFFFF),
    shadow: Color(0x14000000),
    frameStroke: Color(0xFFFFFFFF),
    modalScrim: Color(0x0A000000),
    modalChromaWash: Color(0x1AFFFFFF),
    textPrimary: Color(0xFF1B2533),
    textSecondary: Color(0xCC3A4A5C),
    success: Color(0xE01D2E43),
    warning: Color(0xD27A6334),
    danger: Color(0xD27E3E55),
    hostFillOpacity: 0.22,
    controlFillOpacity: 0.24,
    inlineFillOpacity: 0.20,
    overlayFillOpacity: 0.46,
    strokeOpacity: 0.48,
    frameStrokeOpacity: 0.78,
    chromaLowOpacity: 0.0040,
    chromaMediumOpacity: 0.0050,
    chromaHighOpacity: 0.0062,
    edgeWidthLow: 0.74,
    edgeWidthMedium: 0.90,
    edgeWidthHigh: 1.08,
    edgeGlowHighOpacity: 0.14,
    modalBlurSigma: 64,
    singleShadowBlur: 6,
    singleShadowOffsetY: 2,
    radiusLarge: 24,
    radiusMedium: 16,
    radiusSmall: 12,
    contentPadding: 14,
  );

  static AlembicTokens resolve(Brightness brightness) {
    return light;
  }

  @Deprecated('Use controlFillOpacity')
  double get surfaceFillOpacity => controlFillOpacity;

  @Deprecated('Use strokeOpacity')
  double get surfaceStrokeOpacity => strokeOpacity;

  @Deprecated('Use stroke')
  Color get surfaceStroke => stroke;

  @Deprecated('Use controlFill')
  Color get surfaceFill => controlFill;

  @Deprecated('Use shadow')
  Color get surfaceShadow => shadow;

  @Deprecated('Use controlFill')
  Color get panelBase => controlFill;

  @Deprecated('Use inlineFill')
  Color get panelBaseSoft => inlineFill;

  @Deprecated('Use hostFill')
  Color get lensTint => hostFill;

  @Deprecated('Use specular')
  Color get lensHighlight => specular;

  @Deprecated('Use shadow')
  Color get overlayScrim => shadow;

  @Deprecated('Use stroke')
  Color get panelBorder => stroke;

  @Deprecated('Use shadow')
  Color get panelShadow => shadow;

  @Deprecated('Use inlineFill')
  Color get chipBase => inlineFill;

  @Deprecated('Use controlFill')
  Color get chipActive => controlFill;

  @Deprecated('Use inlineFill')
  Color get inputFill => inlineFill;

  @Deprecated('Use chromaLowOpacity')
  double get edgePrismLowOpacity => chromaLowOpacity;

  @Deprecated('Use chromaMediumOpacity')
  double get edgePrismMediumOpacity => chromaMediumOpacity;

  @Deprecated('Use chromaHighOpacity')
  double get edgePrismHighOpacity => chromaHighOpacity;
}

extension XAlembicTokens on BuildContext {
  AlembicTokens get alembicTokens {
    Brightness brightness = CupertinoTheme.of(this).brightness ??
        MediaQuery.platformBrightnessOf(this);
    return AlembicTokens.resolve(brightness);
  }
}
