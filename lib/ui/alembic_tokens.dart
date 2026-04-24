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

  static const double gapXs = 4;
  static const double gapSm = 8;
  static const double gapMd = 10;
  static const double gapLg = 12;
  static const double gapXl = 16;

  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    background: m.Color(0xFFF7F7F8),
    foreground: m.Color(0xFF111113),
    card: m.Color(0xFFFFFFFF),
    cardForeground: m.Color(0xFF111113),
    popover: m.Color(0xFFFFFFFF),
    popoverForeground: m.Color(0xFF111113),
    primary: m.Color(0xFF18181B),
    primaryForeground: m.Color(0xFFFAFAFA),
    secondary: m.Color(0xFFF1F1F3),
    secondaryForeground: m.Color(0xFF18181B),
    muted: m.Color(0xFFF2F2F4),
    mutedForeground: m.Color(0xFF6B7280),
    accent: m.Color(0xFFEFF6FF),
    accentForeground: m.Color(0xFF172554),
    destructive: m.Color(0xFFDC2626),
    border: m.Color(0xFFE1E1E5),
    input: m.Color(0xFFDCDCE2),
    ring: m.Color(0xFF9CA3AF),
    chart1: m.Color(0xFF2563EB),
    chart2: m.Color(0xFF059669),
    chart3: m.Color(0xFFD97706),
    chart4: m.Color(0xFF7C3AED),
    chart5: m.Color(0xFFE11D48),
    sidebar: m.Color(0xFFF2F2F4),
    sidebarForeground: m.Color(0xFF111113),
    sidebarPrimary: m.Color(0xFF18181B),
    sidebarPrimaryForeground: m.Color(0xFFFAFAFA),
    sidebarAccent: m.Color(0xFFE9E9ED),
    sidebarAccentForeground: m.Color(0xFF18181B),
    sidebarBorder: m.Color(0xFFE1E1E5),
    sidebarRing: m.Color(0xFF9CA3AF),
  );

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    background: m.Color(0xFF08080A),
    foreground: m.Color(0xFFF4F4F5),
    card: m.Color(0xFF111114),
    cardForeground: m.Color(0xFFF4F4F5),
    popover: m.Color(0xFF121216),
    popoverForeground: m.Color(0xFFF4F4F5),
    primary: m.Color(0xFFF4F4F5),
    primaryForeground: m.Color(0xFF111114),
    secondary: m.Color(0xFF1A1A20),
    secondaryForeground: m.Color(0xFFF4F4F5),
    muted: m.Color(0xFF18181D),
    mutedForeground: m.Color(0xFFA1A1AA),
    accent: m.Color(0xFF172033),
    accentForeground: m.Color(0xFFBFDBFE),
    destructive: m.Color(0xFFFB7185),
    border: m.Color(0xFF27272F),
    input: m.Color(0xFF2A2A32),
    ring: m.Color(0xFF71717A),
    chart1: m.Color(0xFF60A5FA),
    chart2: m.Color(0xFF34D399),
    chart3: m.Color(0xFFFBBF24),
    chart4: m.Color(0xFFA78BFA),
    chart5: m.Color(0xFFFB7185),
    sidebar: m.Color(0xFF0E0E12),
    sidebarForeground: m.Color(0xFFF4F4F5),
    sidebarPrimary: m.Color(0xFFF4F4F5),
    sidebarPrimaryForeground: m.Color(0xFF111114),
    sidebarAccent: m.Color(0xFF18181D),
    sidebarAccentForeground: m.Color(0xFFF4F4F5),
    sidebarBorder: m.Color(0xFF27272F),
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
