import 'dart:async';
import 'dart:ui';

import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:alembic/platform/native_menus.dart';
import 'package:alembic/platform/native_window.dart';
import 'package:fast_log/fast_log.dart';

typedef NativeMenuCallback = void Function();

class NativeBootstrap {
  static bool _attached = false;
  static StreamSubscription<NativeThemeChange>? _themeSubscription;
  static StreamSubscription<String>? _appMenuSubscription;
  static final Map<String, NativeMenuCallback> _appMenuActions =
      <String, NativeMenuCallback>{};
  static Brightness _currentBrightness = Brightness.dark;

  static Brightness get currentBrightness => _currentBrightness;

  static Future<void> install() async {
    if (_attached) {
      return;
    }
    if (!DesktopPlatformAdapter.instance.isMacOS &&
        !DesktopPlatformAdapter.instance.isWindows) {
      return;
    }
    _attached = true;
    NativeWindow.instance.attach();
    NativeMenus.instance.attach();
    NativeMaterial detected = await NativeWindow.instance.detectMaterial();
    verbose('Native material detected: ${detected.wireValue}');
    NativeMaterial target = _preferredMaterial(detected);
    if (target != detected) {
      await NativeWindow.instance.setMaterial(target);
      verbose('Native material set to: ${target.wireValue}');
    }
    await pushThemeTokens();
    _themeSubscription =
        NativeWindow.instance.themeChanges.listen(_handleThemeChange);
    _appMenuSubscription = NativeMenus.instance.applicationMenuSelections
        .listen(_handleAppMenuSelection);
  }

  static void registerApplicationMenuAction(
    String id,
    NativeMenuCallback callback,
  ) {
    _appMenuActions[id] = callback;
  }

  static void unregisterApplicationMenuAction(String id) {
    _appMenuActions.remove(id);
  }

  static void _handleAppMenuSelection(String id) {
    NativeMenuCallback? callback = _appMenuActions[id];
    if (callback != null) {
      callback();
      return;
    }
    verbose('Native app menu selection had no registered handler: $id');
  }

  static NativeMaterial _preferredMaterial(NativeMaterial detected) {
    if (DesktopPlatformAdapter.instance.isMacOS) {
      if (detected == NativeMaterial.liquidGlass) {
        return NativeMaterial.liquidGlass;
      }
      return NativeMaterial.vibrancy;
    }
    if (detected == NativeMaterial.mica) {
      return NativeMaterial.mica;
    }
    if (detected == NativeMaterial.acrylic) {
      return NativeMaterial.acrylic;
    }
    return detected;
  }

  static Future<void> pushThemeTokens() async {
    Map<String, Object?> tokens = _buildTokenMap();
    await NativeWindow.instance.pushThemeTokens(tokens);
  }

  static Map<String, Object?> _buildTokenMap() {
    return <String, Object?>{
      'surfaceRadius': 8,
      'controlRadius': 7,
      'modalMaxWidth': 560,
      'gapXs': 4,
      'gapSm': 8,
      'gapMd': 10,
      'gapLg': 12,
      'gapXl': 16,
      'light': _lightSchemeWire,
      'dark': _darkSchemeWire,
    };
  }

  static Map<String, Object?> get _lightSchemeWire => <String, Object?>{
        'background': _argb(0xFF, 0xF4, 0xF4, 0xF4),
        'foreground': _argb(0xFF, 0x09, 0x09, 0x09),
        'card': _argb(0xFF, 0xFF, 0xFF, 0xFF),
        'cardForeground': _argb(0xFF, 0x09, 0x09, 0x09),
        'popover': _argb(0xFF, 0xFF, 0xFF, 0xFF),
        'popoverForeground': _argb(0xFF, 0x09, 0x09, 0x09),
        'primary': _argb(0xFF, 0x18, 0x18, 0x18),
        'primaryForeground': _argb(0xFF, 0xFA, 0xFA, 0xFA),
        'secondary': _argb(0xFF, 0xF1, 0xF1, 0xF1),
        'secondaryForeground': _argb(0xFF, 0x18, 0x18, 0x18),
        'muted': _argb(0xFF, 0xED, 0xED, 0xED),
        'mutedForeground': _argb(0xFF, 0x70, 0x70, 0x70),
        'accent': _argb(0xFF, 0xE6, 0xE6, 0xE6),
        'accentForeground': _argb(0xFF, 0x18, 0x18, 0x18),
        'destructive': _argb(0xFF, 0x5C, 0x5C, 0x5C),
        'border': _argb(0xFF, 0xE2, 0xE2, 0xE2),
        'input': _argb(0xFF, 0xD7, 0xD7, 0xD7),
        'ring': _argb(0xFF, 0x9A, 0x9A, 0x9A),
      };

  static Map<String, Object?> get _darkSchemeWire => <String, Object?>{
        'background': _argb(0xFF, 0x0B, 0x0B, 0x0B),
        'foreground': _argb(0xFF, 0xF4, 0xF4, 0xF4),
        'card': _argb(0xFF, 0x14, 0x14, 0x14),
        'cardForeground': _argb(0xFF, 0xF4, 0xF4, 0xF4),
        'popover': _argb(0xFF, 0x17, 0x17, 0x17),
        'popoverForeground': _argb(0xFF, 0xF4, 0xF4, 0xF4),
        'primary': _argb(0xFF, 0xF4, 0xF4, 0xF4),
        'primaryForeground': _argb(0xFF, 0x18, 0x18, 0x18),
        'secondary': _argb(0xFF, 0x1D, 0x1D, 0x1D),
        'secondaryForeground': _argb(0xFF, 0xF4, 0xF4, 0xF4),
        'muted': _argb(0xFF, 0x1B, 0x1B, 0x1B),
        'mutedForeground': _argb(0xFF, 0xA1, 0xA1, 0xA1),
        'accent': _argb(0xFF, 0x27, 0x27, 0x27),
        'accentForeground': _argb(0xFF, 0xF4, 0xF4, 0xF4),
        'destructive': _argb(0xFF, 0x9A, 0x9A, 0x9A),
        'border': _argb(0xFF, 0x2A, 0x2A, 0x2A),
        'input': _argb(0xFF, 0x2E, 0x2E, 0x2E),
        'ring': _argb(0xFF, 0x71, 0x71, 0x71),
      };

  static int _argb(int a, int r, int g, int b) {
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  static void _handleThemeChange(NativeThemeChange change) {
    verbose(
      'Native theme change: ${change.brightness.name} (${change.rawSystemTheme ?? "<no raw>"})',
    );
    _currentBrightness = change.brightness;
  }

  static Future<void> dispose() async {
    await _themeSubscription?.cancel();
    _themeSubscription = null;
    await _appMenuSubscription?.cancel();
    _appMenuSubscription = null;
    _appMenuActions.clear();
    _attached = false;
  }
}
