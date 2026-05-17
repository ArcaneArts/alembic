import 'dart:async';

import 'package:fast_log/fast_log.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';

enum NativeMenuItemKind {
  command,
  toggle,
  separator,
  submenu,
}

extension NativeMenuItemKindWire on NativeMenuItemKind {
  String get wireValue => switch (this) {
        NativeMenuItemKind.command => 'command',
        NativeMenuItemKind.toggle => 'toggle',
        NativeMenuItemKind.separator => 'separator',
        NativeMenuItemKind.submenu => 'submenu',
      };
}

class NativeMenuItem {
  final String id;
  final String? label;
  final NativeMenuItemKind kind;
  final bool enabled;
  final bool checked;
  final bool destructive;
  final String? sfSymbol;
  final String? keyEquivalent;
  final List<String> modifiers;
  final List<NativeMenuItem> children;

  const NativeMenuItem({
    required this.id,
    this.label,
    this.kind = NativeMenuItemKind.command,
    this.enabled = true,
    this.checked = false,
    this.destructive = false,
    this.sfSymbol,
    this.keyEquivalent,
    this.modifiers = const <String>[],
    this.children = const <NativeMenuItem>[],
  });

  const NativeMenuItem.separator()
      : id = '__separator__',
        label = null,
        kind = NativeMenuItemKind.separator,
        enabled = true,
        checked = false,
        destructive = false,
        sfSymbol = null,
        keyEquivalent = null,
        modifiers = const <String>[],
        children = const <NativeMenuItem>[];

  factory NativeMenuItem.submenu({
    required String id,
    required String label,
    required List<NativeMenuItem> children,
    bool enabled = true,
    String? sfSymbol,
  }) {
    return NativeMenuItem(
      id: id,
      label: label,
      kind: NativeMenuItemKind.submenu,
      enabled: enabled,
      sfSymbol: sfSymbol,
      children: children,
    );
  }

  Map<String, Object?> toWire() => <String, Object?>{
        'id': id,
        'label': label,
        'kind': kind.wireValue,
        'enabled': enabled,
        'checked': checked,
        'destructive': destructive,
        'sfSymbol': sfSymbol,
        'keyEquivalent': keyEquivalent,
        'modifiers': modifiers,
        'children':
            children.map((NativeMenuItem c) => c.toWire()).toList(),
      };
}

class NativeMenuOrigin {
  final double x;
  final double y;

  const NativeMenuOrigin(this.x, this.y);

  Map<String, Object?> toWire() => <String, Object?>{
        'x': x,
        'y': y,
      };
}

class NativeMenus {
  static final NativeMenus instance = NativeMenus._();

  static const MethodChannel _channel = MethodChannel('alembic_menus');

  final PublishSubject<String> _appMenuSelections = PublishSubject<String>();
  bool _attached = false;

  NativeMenus._();

  Stream<String> get applicationMenuSelections => _appMenuSelections.stream;

  void attach() {
    if (_attached) {
      return;
    }
    _attached = true;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onApplicationMenuItemSelected':
        Map<dynamic, dynamic>? args =
            call.arguments is Map ? call.arguments as Map : null;
        Object? rawId = args?['id'];
        if (rawId is String && rawId.isNotEmpty) {
          _appMenuSelections.add(rawId);
        }
        return null;
      default:
        return null;
    }
  }

  Future<String?> showContextMenu({
    required List<NativeMenuItem> items,
    NativeMenuOrigin? origin,
  }) async {
    String? raw = await _invoke<String>('showContextMenu', <String, Object?>{
      'items': items.map((NativeMenuItem i) => i.toWire()).toList(),
      'origin': origin?.toWire(),
    });
    return raw;
  }

  Future<void> setApplicationMenu(List<NativeMenuItem> items) async {
    await _invoke<void>('setApplicationMenu', <String, Object?>{
      'items': items.map((NativeMenuItem i) => i.toWire()).toList(),
    });
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException catch (e) {
      warn('NativeMenus.$method missing plugin: $e');
      return null;
    } on PlatformException catch (e) {
      warn('NativeMenus.$method platform exception: ${e.message ?? e.code}');
      return null;
    }
  }
}
