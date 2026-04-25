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
  static const double tabWidth = 104;
  static const double tabIconWidth = 34;
  static const double dropdownMenuMaxHeight = 320;

  static const double gapXs = 4;
  static const double gapSm = 8;
  static const double gapMd = 10;
  static const double gapLg = 12;
  static const double gapXl = 16;

  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    background: m.Color(0xFFF4F4F5),
    foreground: m.Color(0xFF09090B),
    card: m.Color(0xFFFFFFFF),
    cardForeground: m.Color(0xFF09090B),
    popover: m.Color(0xFFFFFFFF),
    popoverForeground: m.Color(0xFF09090B),
    primary: m.Color(0xFF18181B),
    primaryForeground: m.Color(0xFFFAFAFA),
    secondary: m.Color(0xFFF1F1F3),
    secondaryForeground: m.Color(0xFF18181B),
    muted: m.Color(0xFFEDEDEF),
    mutedForeground: m.Color(0xFF70707A),
    accent: m.Color(0xFFE6E6E9),
    accentForeground: m.Color(0xFF18181B),
    destructive: m.Color(0xFFB91C1C),
    border: m.Color(0xFFE2E2E5),
    input: m.Color(0xFFD7D7DB),
    ring: m.Color(0xFF9A9AA4),
    chart1: m.Color(0xFF18181B),
    chart2: m.Color(0xFF3F3F46),
    chart3: m.Color(0xFF70707A),
    chart4: m.Color(0xFFA1A1AA),
    chart5: m.Color(0xFFD4D4D8),
    sidebar: m.Color(0xFFECECEF),
    sidebarForeground: m.Color(0xFF09090B),
    sidebarPrimary: m.Color(0xFF18181B),
    sidebarPrimaryForeground: m.Color(0xFFFAFAFA),
    sidebarAccent: m.Color(0xFFE6E6E9),
    sidebarAccentForeground: m.Color(0xFF18181B),
    sidebarBorder: m.Color(0xFFE2E2E5),
    sidebarRing: m.Color(0xFF9A9AA4),
  );

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    background: m.Color(0xFF0B0B0E),
    foreground: m.Color(0xFFF4F4F5),
    card: m.Color(0xFF141418),
    cardForeground: m.Color(0xFFF4F4F5),
    popover: m.Color(0xFF17171B),
    popoverForeground: m.Color(0xFFF4F4F5),
    primary: m.Color(0xFFF4F4F5),
    primaryForeground: m.Color(0xFF18181B),
    secondary: m.Color(0xFF1D1D22),
    secondaryForeground: m.Color(0xFFF4F4F5),
    muted: m.Color(0xFF1B1B1F),
    mutedForeground: m.Color(0xFFA1A1AA),
    accent: m.Color(0xFF27272B),
    accentForeground: m.Color(0xFFF4F4F5),
    destructive: m.Color(0xFFF17171),
    border: m.Color(0xFF2A2A2F),
    input: m.Color(0xFF2E2E34),
    ring: m.Color(0xFF71717A),
    chart1: m.Color(0xFFF4F4F5),
    chart2: m.Color(0xFFD4D4D8),
    chart3: m.Color(0xFFA1A1AA),
    chart4: m.Color(0xFF71717A),
    chart5: m.Color(0xFF52525B),
    sidebar: m.Color(0xFF101014),
    sidebarForeground: m.Color(0xFFF4F4F5),
    sidebarPrimary: m.Color(0xFFF4F4F5),
    sidebarPrimaryForeground: m.Color(0xFF18181B),
    sidebarAccent: m.Color(0xFF1D1D22),
    sidebarAccentForeground: m.Color(0xFFF4F4F5),
    sidebarBorder: m.Color(0xFF2A2A2F),
    sidebarRing: m.Color(0xFF71717A),
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
