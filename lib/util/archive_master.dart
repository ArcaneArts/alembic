import 'dart:convert';

import 'package:alembic/main.dart';

const String archiveMasterTargetsKey = 'archive_master_targets_v1';
const String archiveMasterStatesKey = 'archive_master_states_v1';

enum ArchiveMasterTargetKind {
  repository,
  organization,
}

class ArchiveMasterTarget {
  final String id;
  final ArchiveMasterTargetKind kind;
  final String owner;
  final String? repository;
  final String? accountId;
  final int createdAtMs;

  const ArchiveMasterTarget({
    required this.id,
    required this.kind,
    required this.owner,
    required this.repository,
    required this.accountId,
    required this.createdAtMs,
  });

  String get displayName {
    if (kind == ArchiveMasterTargetKind.organization) {
      return owner;
    }
    return '$owner/${repository ?? ''}';
  }

  String get matchKey {
    if (kind == ArchiveMasterTargetKind.organization) {
      return 'org:${owner.toLowerCase()}';
    }
    return 'repo:${owner.toLowerCase()}/${(repository ?? '').toLowerCase()}';
  }

  ArchiveMasterTarget copyWith({
    String? accountId,
  }) {
    return ArchiveMasterTarget(
      id: id,
      kind: kind,
      owner: owner,
      repository: repository,
      accountId: accountId ?? this.accountId,
      createdAtMs: createdAtMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind.name,
        'owner': owner,
        if (repository != null) 'repository': repository,
        if (accountId != null) 'accountId': accountId,
        'createdAtMs': createdAtMs,
      };

  static ArchiveMasterTarget? fromJson(Map<String, dynamic> data) {
    final String id = (data['id'] as String? ?? '').trim();
    final String kindRaw = (data['kind'] as String? ?? '').trim();
    final String owner = (data['owner'] as String? ?? '').trim();
    if (id.isEmpty || owner.isEmpty) {
      return null;
    }
    final ArchiveMasterTargetKind kind = ArchiveMasterTargetKind.values
        .firstWhere(
            (ArchiveMasterTargetKind value) => value.name == kindRaw,
            orElse: () => ArchiveMasterTargetKind.repository);
    final String? repository = () {
      final String raw = (data['repository'] as String? ?? '').trim();
      if (raw.isEmpty) {
        return null;
      }
      return raw;
    }();
    if (kind == ArchiveMasterTargetKind.repository &&
        (repository == null || repository.isEmpty)) {
      return null;
    }
    return ArchiveMasterTarget(
      id: id,
      kind: kind,
      owner: owner,
      repository: repository,
      accountId: () {
        final String raw = (data['accountId'] as String? ?? '').trim();
        if (raw.isEmpty) {
          return null;
        }
        return raw;
      }(),
      createdAtMs: (data['createdAtMs'] as int?) ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class ArchiveMasterRepoState {
  final String fullName;
  final int? lastCheckedMs;
  final int? lastPulledMs;
  final String? lastCommitHash;
  final String? lastErrorMessage;

  const ArchiveMasterRepoState({
    required this.fullName,
    required this.lastCheckedMs,
    required this.lastPulledMs,
    required this.lastCommitHash,
    required this.lastErrorMessage,
  });

  ArchiveMasterRepoState copyWith({
    int? lastCheckedMs,
    int? lastPulledMs,
    String? lastCommitHash,
    String? lastErrorMessage,
    bool clearError = false,
  }) {
    return ArchiveMasterRepoState(
      fullName: fullName,
      lastCheckedMs: lastCheckedMs ?? this.lastCheckedMs,
      lastPulledMs: lastPulledMs ?? this.lastPulledMs,
      lastCommitHash: lastCommitHash ?? this.lastCommitHash,
      lastErrorMessage:
          clearError ? null : (lastErrorMessage ?? this.lastErrorMessage),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'fullName': fullName,
        if (lastCheckedMs != null) 'lastCheckedMs': lastCheckedMs,
        if (lastPulledMs != null) 'lastPulledMs': lastPulledMs,
        if (lastCommitHash != null) 'lastCommitHash': lastCommitHash,
        if (lastErrorMessage != null) 'lastErrorMessage': lastErrorMessage,
      };

  static ArchiveMasterRepoState? fromJson(Map<String, dynamic> data) {
    final String fullName = (data['fullName'] as String? ?? '').trim();
    if (fullName.isEmpty) {
      return null;
    }
    return ArchiveMasterRepoState(
      fullName: fullName,
      lastCheckedMs: data['lastCheckedMs'] as int?,
      lastPulledMs: data['lastPulledMs'] as int?,
      lastCommitHash: () {
        final String raw = (data['lastCommitHash'] as String? ?? '').trim();
        if (raw.isEmpty) {
          return null;
        }
        return raw;
      }(),
      lastErrorMessage: () {
        final String raw = (data['lastErrorMessage'] as String? ?? '').trim();
        if (raw.isEmpty) {
          return null;
        }
        return raw;
      }(),
    );
  }
}

String generateArchiveMasterTargetId() {
  final int now = DateTime.now().microsecondsSinceEpoch;
  return 'amt_${now.toRadixString(36)}';
}

List<ArchiveMasterTarget> loadArchiveMasterTargets() {
  final dynamic raw = boxSettings.get(archiveMasterTargetsKey);
  if (raw is! String || raw.trim().isEmpty) {
    return <ArchiveMasterTarget>[];
  }
  try {
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return <ArchiveMasterTarget>[];
    }
    final List<ArchiveMasterTarget> targets = <ArchiveMasterTarget>[];
    for (final dynamic entry in decoded) {
      if (entry is Map) {
        final Map<String, dynamic> typed = <String, dynamic>{};
        entry.forEach((dynamic key, dynamic value) {
          typed[key.toString()] = value;
        });
        final ArchiveMasterTarget? target = ArchiveMasterTarget.fromJson(typed);
        if (target != null) {
          targets.add(target);
        }
      }
    }
    return targets;
  } catch (_) {
    return <ArchiveMasterTarget>[];
  }
}

Future<void> saveArchiveMasterTargets(
    List<ArchiveMasterTarget> targets) async {
  final List<Map<String, dynamic>> serialized = targets
      .map((ArchiveMasterTarget target) => target.toJson())
      .toList();
  await boxSettings.put(
    archiveMasterTargetsKey,
    jsonEncode(serialized),
  );
}

Future<ArchiveMasterTarget> addArchiveMasterRepository({
  required String owner,
  required String repository,
  String? accountId,
}) async {
  final List<ArchiveMasterTarget> targets = loadArchiveMasterTargets();
  final String matchKey =
      'repo:${owner.toLowerCase()}/${repository.toLowerCase()}';
  for (final ArchiveMasterTarget existing in targets) {
    if (existing.matchKey == matchKey) {
      if (existing.accountId == accountId) {
        return existing;
      }
      final ArchiveMasterTarget updated = existing.copyWith(accountId: accountId);
      final List<ArchiveMasterTarget> next = targets
          .map((ArchiveMasterTarget item) =>
              item.id == existing.id ? updated : item)
          .toList();
      await saveArchiveMasterTargets(next);
      return updated;
    }
  }
  final ArchiveMasterTarget target = ArchiveMasterTarget(
    id: generateArchiveMasterTargetId(),
    kind: ArchiveMasterTargetKind.repository,
    owner: owner,
    repository: repository,
    accountId: accountId,
    createdAtMs: DateTime.now().millisecondsSinceEpoch,
  );
  targets.add(target);
  await saveArchiveMasterTargets(targets);
  return target;
}

Future<ArchiveMasterTarget> addArchiveMasterOrganization({
  required String owner,
  String? accountId,
}) async {
  final List<ArchiveMasterTarget> targets = loadArchiveMasterTargets();
  final String matchKey = 'org:${owner.toLowerCase()}';
  for (final ArchiveMasterTarget existing in targets) {
    if (existing.matchKey == matchKey) {
      if (existing.accountId == accountId) {
        return existing;
      }
      final ArchiveMasterTarget updated = existing.copyWith(accountId: accountId);
      final List<ArchiveMasterTarget> next = targets
          .map((ArchiveMasterTarget item) =>
              item.id == existing.id ? updated : item)
          .toList();
      await saveArchiveMasterTargets(next);
      return updated;
    }
  }
  final ArchiveMasterTarget target = ArchiveMasterTarget(
    id: generateArchiveMasterTargetId(),
    kind: ArchiveMasterTargetKind.organization,
    owner: owner,
    repository: null,
    accountId: accountId,
    createdAtMs: DateTime.now().millisecondsSinceEpoch,
  );
  targets.add(target);
  await saveArchiveMasterTargets(targets);
  return target;
}

Future<void> removeArchiveMasterTarget(String id) async {
  final List<ArchiveMasterTarget> targets = loadArchiveMasterTargets();
  targets.removeWhere((ArchiveMasterTarget target) => target.id == id);
  await saveArchiveMasterTargets(targets);
}

Future<void> removeArchiveMasterRepository(String owner, String repository) async {
  final String matchKey =
      'repo:${owner.toLowerCase()}/${repository.toLowerCase()}';
  final List<ArchiveMasterTarget> targets = loadArchiveMasterTargets();
  targets.removeWhere(
      (ArchiveMasterTarget target) => target.matchKey == matchKey);
  await saveArchiveMasterTargets(targets);
}

Future<void> removeArchiveMasterOrganization(String owner) async {
  final String matchKey = 'org:${owner.toLowerCase()}';
  final List<ArchiveMasterTarget> targets = loadArchiveMasterTargets();
  targets.removeWhere(
      (ArchiveMasterTarget target) => target.matchKey == matchKey);
  await saveArchiveMasterTargets(targets);
}

bool isArchiveMasterRepository(String owner, String repository) {
  final String matchKey =
      'repo:${owner.toLowerCase()}/${repository.toLowerCase()}';
  for (final ArchiveMasterTarget target in loadArchiveMasterTargets()) {
    if (target.matchKey == matchKey) {
      return true;
    }
    if (target.kind == ArchiveMasterTargetKind.organization &&
        target.owner.toLowerCase() == owner.toLowerCase()) {
      return true;
    }
  }
  return false;
}

bool isArchiveMasterOrganization(String owner) {
  final String matchKey = 'org:${owner.toLowerCase()}';
  for (final ArchiveMasterTarget target in loadArchiveMasterTargets()) {
    if (target.matchKey == matchKey) {
      return true;
    }
  }
  return false;
}

Map<String, ArchiveMasterRepoState> loadArchiveMasterRepoStates() {
  final dynamic raw = boxSettings.get(archiveMasterStatesKey);
  if (raw is! String || raw.trim().isEmpty) {
    return <String, ArchiveMasterRepoState>{};
  }
  try {
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return <String, ArchiveMasterRepoState>{};
    }
    final Map<String, ArchiveMasterRepoState> states =
        <String, ArchiveMasterRepoState>{};
    decoded.forEach((dynamic key, dynamic value) {
      if (value is Map) {
        final Map<String, dynamic> typed = <String, dynamic>{};
        value.forEach((dynamic mk, dynamic mv) {
          typed[mk.toString()] = mv;
        });
        final ArchiveMasterRepoState? state =
            ArchiveMasterRepoState.fromJson(typed);
        if (state != null) {
          states[key.toString().toLowerCase()] = state;
        }
      }
    });
    return states;
  } catch (_) {
    return <String, ArchiveMasterRepoState>{};
  }
}

Future<void> saveArchiveMasterRepoStates(
    Map<String, ArchiveMasterRepoState> states) async {
  final Map<String, dynamic> serialized = <String, dynamic>{};
  states.forEach((String key, ArchiveMasterRepoState value) {
    serialized[key.toLowerCase()] = value.toJson();
  });
  await boxSettings.put(archiveMasterStatesKey, jsonEncode(serialized));
}

Future<void> updateArchiveMasterRepoState(
    String fullName, ArchiveMasterRepoState state) async {
  final Map<String, ArchiveMasterRepoState> states =
      loadArchiveMasterRepoStates();
  states[fullName.toLowerCase()] = state;
  await saveArchiveMasterRepoStates(states);
}

Future<void> removeArchiveMasterRepoState(String fullName) async {
  final Map<String, ArchiveMasterRepoState> states =
      loadArchiveMasterRepoStates();
  states.remove(fullName.toLowerCase());
  await saveArchiveMasterRepoStates(states);
}

ArchiveMasterRepoState? getArchiveMasterRepoState(String fullName) {
  return loadArchiveMasterRepoStates()[fullName.toLowerCase()];
}
