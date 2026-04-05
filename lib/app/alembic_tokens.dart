import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

class AlembicShadcnTokens {
  static const EdgeInsets shellPadding = EdgeInsets.all(12);
  static const EdgeInsets surfacePadding = EdgeInsets.all(14);
  static const EdgeInsets compactSurfacePadding = EdgeInsets.all(10);
  static const EdgeInsets controlPadding =
      EdgeInsets.symmetric(horizontal: 9, vertical: 7);
  static const EdgeInsets compactControlPadding =
      EdgeInsets.symmetric(horizontal: 7, vertical: 5);

  static const double surfaceRadius = 12;
  static const double controlRadius = 12;
  static const double badgeRadius = 8;
  static const double sidebarWidth = 300;
  static const double asideWidth = 280;

  static const double gapSm = 8;
  static const double gapMd = 10;
  static const double gapLg = 12;
  static const double gapXl = 16;

  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    background: m.Color(0xFFF5F5F5),
    foreground: m.Color(0xFF0A0A0A),
    card: m.Color(0xFFFFFFFF),
    cardForeground: m.Color(0xFF0A0A0A),
    popover: m.Color(0xFFFFFFFF),
    popoverForeground: m.Color(0xFF0A0A0A),
    primary: m.Color(0xFF111111),
    primaryForeground: m.Color(0xFFFAFAFA),
    secondary: m.Color(0xFFF0F0F0),
    secondaryForeground: m.Color(0xFF111111),
    muted: m.Color(0xFFF0F0F0),
    mutedForeground: m.Color(0xFF6B7280),
    accent: m.Color(0xFFF0F0F0),
    accentForeground: m.Color(0xFF111111),
    destructive: m.Color(0xFFDC2626),
    border: m.Color(0xFFE4E4E7),
    input: m.Color(0xFFE4E4E7),
    ring: m.Color(0xFFA3A3A3),
    chart1: m.Color(0xFF2563EB),
    chart2: m.Color(0xFF059669),
    chart3: m.Color(0xFFF59E0B),
    chart4: m.Color(0xFF9333EA),
    chart5: m.Color(0xFFE11D48),
    sidebar: m.Color(0xFFF8F8F8),
    sidebarForeground: m.Color(0xFF0A0A0A),
    sidebarPrimary: m.Color(0xFF111111),
    sidebarPrimaryForeground: m.Color(0xFFFAFAFA),
    sidebarAccent: m.Color(0xFFF0F0F0),
    sidebarAccentForeground: m.Color(0xFF111111),
    sidebarBorder: m.Color(0xFFE4E4E7),
    sidebarRing: m.Color(0xFFA3A3A3),
  );

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    background: m.Color(0xFF050505),
    foreground: m.Color(0xFFFAFAFA),
    card: m.Color(0xFF111111),
    cardForeground: m.Color(0xFFFAFAFA),
    popover: m.Color(0xFF101010),
    popoverForeground: m.Color(0xFFFAFAFA),
    primary: m.Color(0xFFFAFAFA),
    primaryForeground: m.Color(0xFF111111),
    secondary: m.Color(0xFF181818),
    secondaryForeground: m.Color(0xFFFAFAFA),
    muted: m.Color(0xFF161616),
    mutedForeground: m.Color(0xFFA3A3A3),
    accent: m.Color(0xFF1B1B1B),
    accentForeground: m.Color(0xFFFAFAFA),
    destructive: m.Color(0xFFFB7185),
    border: m.Color(0xFF262626),
    input: m.Color(0xFF222222),
    ring: m.Color(0xFF737373),
    chart1: m.Color(0xFF3B82F6),
    chart2: m.Color(0xFF10B981),
    chart3: m.Color(0xFFF59E0B),
    chart4: m.Color(0xFFA855F7),
    chart5: m.Color(0xFFF43F5E),
    sidebar: m.Color(0xFF0F0F0F),
    sidebarForeground: m.Color(0xFFFAFAFA),
    sidebarPrimary: m.Color(0xFFFAFAFA),
    sidebarPrimaryForeground: m.Color(0xFF111111),
    sidebarAccent: m.Color(0xFF191919),
    sidebarAccentForeground: m.Color(0xFFFAFAFA),
    sidebarBorder: m.Color(0xFF262626),
    sidebarRing: m.Color(0xFF737373),
  );

  static const ContrastedColorScheme scheme = ContrastedColorScheme(
    light: lightScheme,
    dark: darkScheme,
  );

  static m.ThemeData buildMaterialTheme(
    ArcaneTheme theme,
    Brightness brightness,
  ) {
    m.ThemeData base = brightness == Brightness.dark
        ? m.ThemeData.dark()
        : m.ThemeData.light();
    ThemeData shadTheme = theme.shadThemeBuilder(theme, brightness);
    ColorScheme shadColors = shadTheme.colorScheme;
    m.ColorScheme materialColors = base.colorScheme.copyWith(
      brightness: brightness,
      primary: shadColors.primary,
      onPrimary: shadColors.primaryForeground,
      secondary: shadColors.secondary,
      onSecondary: shadColors.secondaryForeground,
      error: shadColors.destructive,
      onError: shadColors.foreground,
      surface: shadColors.card,
      onSurface: shadColors.cardForeground,
    );

    return base.copyWith(
      colorScheme: materialColors,
      scaffoldBackgroundColor: shadColors.background,
      cardColor: shadColors.card,
      dividerColor: shadColors.border,
      splashFactory: m.NoSplash.splashFactory,
      highlightColor: m.Colors.transparent,
      hoverColor: shadColors.secondary.withValues(alpha: 0.65),
      dialogTheme: m.DialogThemeData(
        backgroundColor: shadColors.card,
        surfaceTintColor: m.Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(surfaceRadius),
          side: BorderSide(color: shadColors.border),
        ),
      ),
      popupMenuTheme: m.PopupMenuThemeData(
        color: shadColors.popover,
        surfaceTintColor: m.Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          side: BorderSide(color: shadColors.border),
        ),
        textStyle: m.TextStyle(
          color: shadColors.popoverForeground,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: m.CardThemeData(
        color: shadColors.card,
        surfaceTintColor: m.Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(surfaceRadius),
          side: BorderSide(color: shadColors.border),
        ),
      ),
      pageTransitionsTheme: m.PageTransitionsTheme(
        builders: <m.TargetPlatform, m.PageTransitionsBuilder>{
          for (m.TargetPlatform platform in m.TargetPlatform.values)
            platform: const m.FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
