import 'dart:io';

import 'package:alembic/app/alembic_theme.dart';
import 'package:alembic/main.dart';
import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:arcane/arcane.dart';

class LegacyPrefsMigration {
  static const String sentinelKey = 'legacy_theme_migration_v1';
  static const String _bundleId = 'art.arcane.alembic';
  static const String _themePreferenceKey = 'alembic.theme.preference';

  const LegacyPrefsMigration._();

  static Future<void> run() async {
    if (!DesktopPlatformAdapter.instance.isMacOS) {
      return;
    }
    if (boxSettings.get(sentinelKey) == true) {
      return;
    }
    try {
      if (!boxSettings.containsKey(alembicThemeModeKey)) {
        String? preference = await _readLegacyThemePreference();
        ThemeMode? mode = switch (preference) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          'system' => ThemeMode.system,
          _ => null,
        };
        if (mode != null) {
          await saveAlembicThemeMode(mode);
        }
      }
      await boxSettings.put(sentinelKey, true);
    } catch (_) {}
  }

  static Future<String?> _readLegacyThemePreference() async {
    try {
      ProcessResult result = await Process.run(
        'defaults',
        <String>['read', _bundleId, _themePreferenceKey],
      );
      if (result.exitCode != 0) {
        return null;
      }
      return result.stdout.toString().trim().toLowerCase();
    } catch (_) {
      return null;
    }
  }
}
