import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

class AlembicShadcnTokens {
  static const EdgeInsets shellPadding = EdgeInsets.all(10);
  static const EdgeInsets surfacePadding = EdgeInsets.all(12);
  static const EdgeInsets compactSurfacePadding = EdgeInsets.all(8);
  static const EdgeInsets controlPadding =
      EdgeInsets.symmetric(horizontal: 10, vertical: 7);
  static const EdgeInsets compactControlPadding =
      EdgeInsets.symmetric(horizontal: 8, vertical: 5);
  static const EdgeInsets rowPadding =
      EdgeInsets.symmetric(horizontal: 10, vertical: 8);

  static const double surfaceRadius = 8;
  static const double controlRadius = 7;
  static const double badgeRadius = 6;
  static const double shellMaxWidth = double.infinity;
  static const double modalMaxWidth = 560;
  static const double listRowMaxWidth = double.infinity;
  static const double listRowHeight = 102;
  static const double listDescriptionLineHeight = 16;
  static const double sidebarWidth = 292;
  static const double asideWidth = 280;
  static const double buttonHeight = 34;
  static const double compactButtonHeight = 30;
  static const double iconButtonSize = 34;
  static const double compactIconButtonSize = 34;
  static const double buttonMinWidth = 104;
  static const double compactButtonMinWidth = 104;
  static const double commandButtonWidth = 104;
  static const double commandIconWidth = 34;
  static const double rowActionButtonWidth = 104;
  static const double rowActionColumnWidth = 104;
  static const double tabWidth = 96;
  static const double tabIconWidth = 34;
  static const double dropdownMenuMaxHeight = 320;

  static const double gapXs = 4;
  static const double gapSm = 8;
  static const double gapMd = 10;
  static const double gapLg = 12;
  static const double gapXl = 16;

  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    background: m.Color(0xFFF7F7F7),
    foreground: m.Color(0xFF111111),
    card: m.Color(0xFFFFFFFF),
    cardForeground: m.Color(0xFF111111),
    popover: m.Color(0xFFFFFFFF),
    popoverForeground: m.Color(0xFF111111),
    primary: m.Color(0xFF181818),
    primaryForeground: m.Color(0xFFFAFAFA),
    secondary: m.Color(0xFFF1F1F1),
    secondaryForeground: m.Color(0xFF181818),
    muted: m.Color(0xFFF2F2F2),
    mutedForeground: m.Color(0xFF6B6B6B),
    accent: m.Color(0xFFE9E9E9),
    accentForeground: m.Color(0xFF181818),
    destructive: m.Color(0xFF3F3F3F),
    border: m.Color(0xFFE1E1E1),
    input: m.Color(0xFFDCDCDC),
    ring: m.Color(0xFF9C9C9C),
    chart1: m.Color(0xFF181818),
    chart2: m.Color(0xFF3F3F3F),
    chart3: m.Color(0xFF717171),
    chart4: m.Color(0xFFA1A1A1),
    chart5: m.Color(0xFFD4D4D4),
    sidebar: m.Color(0xFFF2F2F2),
    sidebarForeground: m.Color(0xFF111111),
    sidebarPrimary: m.Color(0xFF181818),
    sidebarPrimaryForeground: m.Color(0xFFFAFAFA),
    sidebarAccent: m.Color(0xFFE9E9E9),
    sidebarAccentForeground: m.Color(0xFF181818),
    sidebarBorder: m.Color(0xFFE1E1E1),
    sidebarRing: m.Color(0xFF9C9C9C),
  );

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    background: m.Color(0xFF080808),
    foreground: m.Color(0xFFF4F4F4),
    card: m.Color(0xFF111111),
    cardForeground: m.Color(0xFFF4F4F4),
    popover: m.Color(0xFF121212),
    popoverForeground: m.Color(0xFFF4F4F4),
    primary: m.Color(0xFFF4F4F4),
    primaryForeground: m.Color(0xFF111111),
    secondary: m.Color(0xFF1A1A1A),
    secondaryForeground: m.Color(0xFFF4F4F4),
    muted: m.Color(0xFF181818),
    mutedForeground: m.Color(0xFFA1A1A1),
    accent: m.Color(0xFF242424),
    accentForeground: m.Color(0xFFF4F4F4),
    destructive: m.Color(0xFFD4D4D4),
    border: m.Color(0xFF272727),
    input: m.Color(0xFF2A2A2A),
    ring: m.Color(0xFF717171),
    chart1: m.Color(0xFFF4F4F4),
    chart2: m.Color(0xFFD4D4D4),
    chart3: m.Color(0xFFA1A1A1),
    chart4: m.Color(0xFF717171),
    chart5: m.Color(0xFF525252),
    sidebar: m.Color(0xFF0E0E0E),
    sidebarForeground: m.Color(0xFFF4F4F4),
    sidebarPrimary: m.Color(0xFFF4F4F4),
    sidebarPrimaryForeground: m.Color(0xFF111111),
    sidebarAccent: m.Color(0xFF181818),
    sidebarAccentForeground: m.Color(0xFFF4F4F4),
    sidebarBorder: m.Color(0xFF272727),
    sidebarRing: m.Color(0xFF717171),
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
