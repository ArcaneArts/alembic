import 'dart:convert';

class SpikeAppState {
  const SpikeAppState({
    required this.tick,
    required this.status,
    required this.epochMillis,
    required this.dartVersion,
    required this.pid,
    this.configPath = '',
    this.migrationAttempted = false,
    this.migrationSourcePath,
    this.migrationCopiedFiles = const <String>[],
    this.migrationSkippedFiles = const <String>[],
    this.migrationSearchedPaths = const <String>[],
    this.hiveEntries = 0,
    this.accountCount = 0,
    this.primaryAccountLogin,
  });

  factory SpikeAppState.initial() {
    return SpikeAppState(
      tick: 0,
      status: 'initializing',
      epochMillis: 0,
      dartVersion: const String.fromEnvironment(
        'dart.version',
        defaultValue: 'unknown',
      ),
      pid: '${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  final int tick;
  final String status;
  final int epochMillis;
  final String dartVersion;
  final String pid;
  final String configPath;
  final bool migrationAttempted;
  final String? migrationSourcePath;
  final List<String> migrationCopiedFiles;
  final List<String> migrationSkippedFiles;
  final List<String> migrationSearchedPaths;
  final int hiveEntries;
  final int accountCount;
  final String? primaryAccountLogin;

  SpikeAppState copyWith({
    int? tick,
    String? status,
    int? epochMillis,
    String? dartVersion,
    String? pid,
    String? configPath,
    bool? migrationAttempted,
    String? migrationSourcePath,
    List<String>? migrationCopiedFiles,
    List<String>? migrationSkippedFiles,
    List<String>? migrationSearchedPaths,
    int? hiveEntries,
    int? accountCount,
    String? primaryAccountLogin,
  }) {
    return SpikeAppState(
      tick: tick ?? this.tick,
      status: status ?? this.status,
      epochMillis: epochMillis ?? this.epochMillis,
      dartVersion: dartVersion ?? this.dartVersion,
      pid: pid ?? this.pid,
      configPath: configPath ?? this.configPath,
      migrationAttempted: migrationAttempted ?? this.migrationAttempted,
      migrationSourcePath: migrationSourcePath ?? this.migrationSourcePath,
      migrationCopiedFiles: migrationCopiedFiles ?? this.migrationCopiedFiles,
      migrationSkippedFiles:
          migrationSkippedFiles ?? this.migrationSkippedFiles,
      migrationSearchedPaths:
          migrationSearchedPaths ?? this.migrationSearchedPaths,
      hiveEntries: hiveEntries ?? this.hiveEntries,
      accountCount: accountCount ?? this.accountCount,
      primaryAccountLogin: primaryAccountLogin ?? this.primaryAccountLogin,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'tick': tick,
      'status': status,
      'epochMillis': epochMillis,
      'dartVersion': dartVersion,
      'pid': pid,
      'configPath': configPath,
      'migrationAttempted': migrationAttempted,
      'migrationSourcePath': migrationSourcePath,
      'migrationCopiedFiles': migrationCopiedFiles,
      'migrationSkippedFiles': migrationSkippedFiles,
      'migrationSearchedPaths': migrationSearchedPaths,
      'hiveEntries': hiveEntries,
      'accountCount': accountCount,
      'primaryAccountLogin': primaryAccountLogin,
    };
  }

  String toEncoded() {
    return jsonEncode(toJson());
  }
}
