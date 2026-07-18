import 'package:arcane/arcane.dart';
import 'package:alembic/main.dart';
import 'package:alembic/ui/alembic_ui.dart';

const String alembicThemeModeKey = 'theme_mode_v1';

ThemeMode loadAlembicThemeMode() {
  String raw =
      boxSettings.get(alembicThemeModeKey, defaultValue: ThemeMode.system.name);
  for (ThemeMode mode in ThemeMode.values) {
    if (mode.name == raw) {
      return mode;
    }
  }
  return ThemeMode.system;
}

Future<void> saveAlembicThemeMode(ThemeMode mode) {
  return boxSettings.put(alembicThemeModeKey, mode.name);
}

ArcaneTheme buildAlembicTheme() {
  return ArcaneTheme(
    radius: 0.32,
    surfaceEffect: const StaticSurfaceEffect(),
    backupSurfaceEffect: const StaticSurfaceEffect(),
    surfaceOpacity: 1,
    surfaceOpacityLight: 1,
    themeMode: loadAlembicThemeMode(),
    scheme: AlembicShadcnTokens.scheme,
    materialThemeBuilder: AlembicShadcnTokens.buildMaterialTheme,
  );
}
