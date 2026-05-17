import 'dart:async';
import 'dart:io';

import 'package:alembic/spike/spike_channels.dart';
import 'package:flutter/services.dart';

class SpikeLogEntry {
  SpikeLogEntry({
    required this.timestampMillis,
    required this.level,
    required this.tag,
    required this.message,
  });

  final int timestampMillis;
  final String level;
  final String tag;
  final String message;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'timestampMillis': timestampMillis,
      'level': level,
      'tag': tag,
      'message': message,
    };
  }
}

class SpikeDiagnostics {
  SpikeDiagnostics._() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static final SpikeDiagnostics instance = SpikeDiagnostics._();

  static const int _bufferLimit = 500;
  static const MethodChannel _channel =
      MethodChannel(SpikeChannels.diagnostics);
  static final bool _traceEnabled =
      Platform.environment['ALEMBIC_DIAGNOSTICS_TRACE'] == '1' ||
          Platform.environment['ALEMBIC_DIAGNOSTICS_STDOUT'] == '1';
  static final bool _consoleVerbose =
      Platform.environment['ALEMBIC_DIAGNOSTICS_STDOUT'] == '1';

  final List<SpikeLogEntry> _buffer = <SpikeLogEntry>[];
  int _seq = 0;

  void trace(String tag, String message) {
    if (_traceEnabled) {
      _emit(SpikeDiagnosticsLevel.trace, tag, message);
    }
  }

  void log(String tag, String message) =>
      _emit(SpikeDiagnosticsLevel.info, tag, message);

  void warn(String tag, String message) =>
      _emit(SpikeDiagnosticsLevel.warn, tag, message);

  void error(String tag, String message) =>
      _emit(SpikeDiagnosticsLevel.error, tag, message);

  void success(String tag, String message) =>
      _emit(SpikeDiagnosticsLevel.success, tag, message);

  List<SpikeLogEntry> snapshot() {
    return List<SpikeLogEntry>.unmodifiable(_buffer);
  }

  void _emit(String level, String tag, String message) {
    _seq += 1;
    final SpikeLogEntry entry = SpikeLogEntry(
      timestampMillis: DateTime.now().millisecondsSinceEpoch,
      level: level,
      tag: tag,
      message: message,
    );
    _buffer.add(entry);
    if (_buffer.length > _bufferLimit) {
      _buffer.removeRange(0, _buffer.length - _bufferLimit);
    }
    _writeStdout(level, tag, message);
    _pushToNative(entry);
  }

  void _writeStdout(String level, String tag, String message) {
    if (!_shouldWriteStdout(level)) {
      return;
    }
    final String stamp = DateTime.now().toIso8601String();
    final String composed = '[$stamp] [$level] [$tag] $message';
    stderr.writeln('alembic.spike $composed');
  }

  bool _shouldWriteStdout(String level) =>
      _consoleVerbose ||
      level == SpikeDiagnosticsLevel.warn ||
      level == SpikeDiagnosticsLevel.error;

  Future<void> _pushToNative(SpikeLogEntry entry) async {
    try {
      await _channel.invokeMethod<void>(
        SpikeDiagnosticsChannelMethods.log,
        entry.toJson(),
      );
    } on MissingPluginException {
      // Native diagnostics handler not yet attached; entry still buffered.
    } on PlatformException {
      // Channel failure during shutdown; entry still buffered.
    }
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == SpikeDiagnosticsChannelMethods.requestSnapshot) {
      return <String, Object?>{
        'entries': _buffer
            .map((SpikeLogEntry entry) => entry.toJson())
            .toList(growable: false),
        'seq': _seq,
      };
    }
    return null;
  }
}
