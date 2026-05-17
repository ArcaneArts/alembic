import 'dart:async';

import 'package:fast_log/fast_log.dart';
import 'package:flutter/services.dart';

enum NativeModalStyle {
  sheet,
  alert,
  popover,
  fullScreen,
}

extension NativeModalStyleWire on NativeModalStyle {
  String get wireValue => switch (this) {
        NativeModalStyle.sheet => 'sheet',
        NativeModalStyle.alert => 'alert',
        NativeModalStyle.popover => 'popover',
        NativeModalStyle.fullScreen => 'full_screen',
      };
}

enum NativeButtonRole {
  normal,
  primary,
  destructive,
  cancel,
}

extension NativeButtonRoleWire on NativeButtonRole {
  String get wireValue => switch (this) {
        NativeButtonRole.normal => 'normal',
        NativeButtonRole.primary => 'primary',
        NativeButtonRole.destructive => 'destructive',
        NativeButtonRole.cancel => 'cancel',
      };
}

class NativeDialogButton {
  final String id;
  final String label;
  final NativeButtonRole role;
  final bool isDefault;

  const NativeDialogButton({
    required this.id,
    required this.label,
    this.role = NativeButtonRole.normal,
    this.isDefault = false,
  });

  Map<String, Object?> toWire() => <String, Object?>{
        'id': id,
        'label': label,
        'role': role.wireValue,
        'isDefault': isDefault,
      };
}

class NativeInputField {
  final String id;
  final String? placeholder;
  final String? initialValue;
  final bool secure;
  final bool multiline;

  const NativeInputField({
    required this.id,
    this.placeholder,
    this.initialValue,
    this.secure = false,
    this.multiline = false,
  });

  Map<String, Object?> toWire() => <String, Object?>{
        'id': id,
        'placeholder': placeholder,
        'initialValue': initialValue,
        'secure': secure,
        'multiline': multiline,
      };
}

class NativeDialogResult {
  final String? buttonId;
  final bool cancelled;
  final Map<String, String> values;

  const NativeDialogResult({
    this.buttonId,
    this.cancelled = false,
    this.values = const <String, String>{},
  });

  String? valueFor(String id) => values[id];

  static NativeDialogResult fromWire(Map<dynamic, dynamic>? raw) {
    if (raw == null) {
      return const NativeDialogResult(cancelled: true);
    }
    String? buttonId = raw['buttonId'] is String ? raw['buttonId'] as String : null;
    bool cancelled = raw['cancelled'] == true;
    Map<String, String> values = <String, String>{};
    Object? rawValues = raw['values'];
    if (rawValues is Map) {
      rawValues.forEach((Object? k, Object? v) {
        if (k is String && v is String) {
          values[k] = v;
        }
      });
    }
    return NativeDialogResult(
      buttonId: buttonId,
      cancelled: cancelled,
      values: values,
    );
  }
}

class NativeModals {
  static final NativeModals instance = NativeModals._();

  static const MethodChannel _channel = MethodChannel('alembic_modals');

  NativeModals._();

  Future<void> showInfo({
    required String title,
    required String message,
    String closeLabel = 'Close',
    NativeModalStyle style = NativeModalStyle.sheet,
  }) async {
    await _invoke<void>('showInfo', <String, Object?>{
      'title': title,
      'message': message,
      'closeLabel': closeLabel,
      'style': style.wireValue,
    });
  }

  Future<bool> showConfirm({
    required String title,
    required String description,
    String confirmLabel = 'Continue',
    String cancelLabel = 'Cancel',
    bool destructive = false,
    NativeModalStyle style = NativeModalStyle.sheet,
  }) async {
    bool? raw = await _invoke<bool>('showConfirm', <String, Object?>{
      'title': title,
      'description': description,
      'confirmLabel': confirmLabel,
      'cancelLabel': cancelLabel,
      'destructive': destructive,
      'style': style.wireValue,
    });
    return raw == true;
  }

  Future<String?> showInput({
    required String title,
    required String description,
    required String placeholder,
    String confirmLabel = 'Save',
    String cancelLabel = 'Cancel',
    String? initialValue,
    bool secure = false,
    bool multiline = false,
    NativeModalStyle style = NativeModalStyle.sheet,
  }) async {
    String? raw = await _invoke<String>('showInput', <String, Object?>{
      'title': title,
      'description': description,
      'placeholder': placeholder,
      'confirmLabel': confirmLabel,
      'cancelLabel': cancelLabel,
      'initialValue': initialValue,
      'secure': secure,
      'multiline': multiline,
      'style': style.wireValue,
    });
    return raw;
  }

  Future<NativeDialogResult> showCustom({
    required String title,
    String? description,
    List<NativeInputField> fields = const <NativeInputField>[],
    List<NativeDialogButton> buttons = const <NativeDialogButton>[],
    NativeModalStyle style = NativeModalStyle.sheet,
  }) async {
    Map<dynamic, dynamic>? raw =
        await _invokeMap<dynamic, dynamic>('showCustom', <String, Object?>{
      'title': title,
      'description': description,
      'fields': fields.map((NativeInputField f) => f.toWire()).toList(),
      'buttons': buttons.map((NativeDialogButton b) => b.toWire()).toList(),
      'style': style.wireValue,
    });
    return NativeDialogResult.fromWire(raw);
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException catch (e) {
      warn('NativeModals.$method missing plugin: $e');
      return null;
    } on PlatformException catch (e) {
      warn('NativeModals.$method platform exception: ${e.message ?? e.code}');
      return null;
    }
  }

  Future<Map<K, V>?> _invokeMap<K, V>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMapMethod<K, V>(method, arguments);
    } on MissingPluginException catch (e) {
      warn('NativeModals.$method missing plugin: $e');
      return null;
    } on PlatformException catch (e) {
      warn('NativeModals.$method platform exception: ${e.message ?? e.code}');
      return null;
    }
  }
}
