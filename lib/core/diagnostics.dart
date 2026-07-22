import 'dart:async';
import 'dart:io';

class AlembicDiagnosticsLevel {
  static const String trace = 'trace';
  static const String info = 'info';
  static const String warn = 'warn';
  static const String error = 'error';
  static const String success = 'success';

  const AlembicDiagnosticsLevel._();
}

class AlembicLogEntry {
  final int timestampMillis;
  final String level;
  final String tag;
  final String message;

  AlembicLogEntry({
    required this.timestampMillis,
    required this.level,
    required this.tag,
    required this.message,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'timestampMillis': timestampMillis,
        'level': level,
        'tag': tag,
        'message': message,
      };
}

class AlembicDiagnostics {
  static final AlembicDiagnostics instance = AlembicDiagnostics._();

  static const int _bufferLimit = 500;
  static final bool _traceEnabled =
      Platform.environment['ALEMBIC_DIAGNOSTICS_TRACE'] == '1' ||
          Platform.environment['ALEMBIC_DIAGNOSTICS_STDOUT'] == '1';
  static final bool _consoleVerbose =
      Platform.environment['ALEMBIC_DIAGNOSTICS_STDOUT'] == '1';

  final List<AlembicLogEntry> _buffer = <AlembicLogEntry>[];
  final StreamController<AlembicLogEntry> _entries =
      StreamController<AlembicLogEntry>.broadcast();

  AlembicDiagnostics._();

  Stream<AlembicLogEntry> get entries => _entries.stream;

  void trace(String tag, String message) {
    if (_traceEnabled) {
      _emit(AlembicDiagnosticsLevel.trace, tag, message);
    }
  }

  void log(String tag, String message) =>
      _emit(AlembicDiagnosticsLevel.info, tag, message);

  void warn(String tag, String message) =>
      _emit(AlembicDiagnosticsLevel.warn, tag, message);

  void error(String tag, String message) =>
      _emit(AlembicDiagnosticsLevel.error, tag, message);

  void success(String tag, String message) =>
      _emit(AlembicDiagnosticsLevel.success, tag, message);

  List<AlembicLogEntry> snapshot() =>
      List<AlembicLogEntry>.unmodifiable(_buffer);

  void _emit(String level, String tag, String message) {
    AlembicLogEntry entry = AlembicLogEntry(
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
    _entries.add(entry);
  }

  void _writeStdout(String level, String tag, String message) {
    if (!_shouldWriteStdout(level)) {
      return;
    }
    String stamp = DateTime.now().toIso8601String();
    stderr.writeln('alembic [$stamp] [$level] [$tag] $message');
  }

  bool _shouldWriteStdout(String level) =>
      _consoleVerbose ||
      level == AlembicDiagnosticsLevel.warn ||
      level == AlembicDiagnosticsLevel.error;
}
