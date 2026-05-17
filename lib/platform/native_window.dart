import 'dart:async';

import 'package:fast_log/fast_log.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';

enum NativeMaterial {
  liquidGlass,
  vibrancy,
  mica,
  micaAlt,
  acrylic,
  acrylicLegacy,
  solid,
  unknown,
}

extension NativeMaterialName on NativeMaterial {
  String get wireValue => switch (this) {
        NativeMaterial.liquidGlass => 'liquid_glass',
        NativeMaterial.vibrancy => 'vibrancy',
        NativeMaterial.mica => 'mica',
        NativeMaterial.micaAlt => 'mica_alt',
        NativeMaterial.acrylic => 'acrylic',
        NativeMaterial.acrylicLegacy => 'acrylic_legacy',
        NativeMaterial.solid => 'solid',
        NativeMaterial.unknown => 'unknown',
      };

  static NativeMaterial fromWire(String? value) {
    return switch (value) {
      'liquid_glass' => NativeMaterial.liquidGlass,
      'vibrancy' => NativeMaterial.vibrancy,
      'mica' => NativeMaterial.mica,
      'mica_alt' => NativeMaterial.micaAlt,
      'acrylic' => NativeMaterial.acrylic,
      'acrylic_legacy' => NativeMaterial.acrylicLegacy,
      'solid' => NativeMaterial.solid,
      _ => NativeMaterial.unknown,
    };
  }
}

class NativeThemeChange {
  final Brightness brightness;
  final String? rawSystemTheme;

  const NativeThemeChange({
    required this.brightness,
    this.rawSystemTheme,
  });
}

class NativeWindow {
  static final NativeWindow instance = NativeWindow._();

  static const MethodChannel _channel = MethodChannel('alembic_window');

  bool _attached = false;
  final BehaviorSubject<NativeThemeChange> _themeChanges =
      BehaviorSubject<NativeThemeChange>();

  NativeWindow._();

  Stream<NativeThemeChange> get themeChanges => _themeChanges.stream;

  Future<NativeMaterial> detectMaterial() async {
    String? raw = await _invoke<String>('detectMaterial');
    return NativeMaterialName.fromWire(raw);
  }

  Future<void> setMaterial(NativeMaterial material) async {
    await _invoke<void>('setMaterial', <String, Object?>{
      'material': material.wireValue,
    });
  }

  Future<void> pushThemeTokens(Map<String, Object?> tokens) async {
    await _invoke<void>('pushThemeTokens', <String, Object?>{
      'tokens': tokens,
    });
  }

  Future<void> suspendHideOnBlur() async {
    await _invoke<void>('suspendHideOnBlur');
  }

  Future<void> resumeHideOnBlur({bool ensureVisible = false}) async {
    await _invoke<void>('resumeHideOnBlur', <String, Object?>{
      'ensureVisible': ensureVisible,
    });
  }

  Future<Map<String, Object?>> dumpDiagnostics() async {
    Map<dynamic, dynamic>? raw =
        await _invokeMap<dynamic, dynamic>('dumpDiagnostics');
    return _normalizeMap(raw);
  }

  Future<void> showAboutPanel({
    String? appName,
    String? version,
    String? build,
    String? copyright,
    String? creditsHtml,
  }) async {
    Map<String, Object?> payload = <String, Object?>{};
    if (appName != null && appName.isNotEmpty) {
      payload['appName'] = appName;
    }
    if (version != null && version.isNotEmpty) {
      payload['version'] = version;
    }
    if (build != null && build.isNotEmpty) {
      payload['build'] = build;
    }
    if (copyright != null && copyright.isNotEmpty) {
      payload['copyright'] = copyright;
    }
    if (creditsHtml != null && creditsHtml.isNotEmpty) {
      payload['creditsHtml'] = creditsHtml;
    }
    await _invoke<void>('showAboutPanel', payload);
  }

  void attach() {
    if (_attached) {
      return;
    }
    _attached = true;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onThemeChanged':
        Map<dynamic, dynamic>? args =
            call.arguments is Map ? call.arguments as Map : null;
        String? raw = args?['theme'] is String ? args!['theme'] as String : null;
        Brightness brightness = raw == 'dark' ? Brightness.dark : Brightness.light;
        _themeChanges.add(NativeThemeChange(
          brightness: brightness,
          rawSystemTheme: raw,
        ));
        return null;
      default:
        return null;
    }
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException catch (e) {
      warn('NativeWindow.$method missing plugin: $e');
      return null;
    } on PlatformException catch (e) {
      warn('NativeWindow.$method platform exception: ${e.message ?? e.code}');
      return null;
    }
  }

  Future<Map<K, V>?> _invokeMap<K, V>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMapMethod<K, V>(method, arguments);
    } on MissingPluginException catch (e) {
      warn('NativeWindow.$method missing plugin: $e');
      return null;
    } on PlatformException catch (e) {
      warn('NativeWindow.$method platform exception: ${e.message ?? e.code}');
      return null;
    }
  }

  static Map<String, Object?> _normalizeMap(Map<dynamic, dynamic>? raw) {
    Map<String, Object?> result = <String, Object?>{};
    if (raw == null) {
      return result;
    }
    raw.forEach((Object? k, Object? v) {
      if (k is String) {
        result[k] = v;
      }
    });
    return result;
  }
}
