import 'dart:async';
import 'dart:io';

import 'package:alembic/bloc/repository_list_store.dart';
import 'package:alembic/core/repository_runtime.dart';
import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:alembic/spike/spike_channels.dart';
import 'package:alembic/spike/spike_diagnostics.dart';
import 'package:alembic/spike/spike_repository_runtime.dart';
import 'package:alembic/util/archive_master.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:flutter/services.dart';
import 'package:github/github.dart';

class RepositoryWorkBridge {
  RepositoryWorkBridge({
    required RepositoryListStore store,
    SpikeDiagnostics? diagnostics,
  })  : _store = store,
        _diagnostics = diagnostics ?? SpikeDiagnostics.instance,
        _channel = const MethodChannel(SpikeChannels.repositoryWork);

  static const String _logTag = 'repo_work_bridge';

  final RepositoryListStore _store;
  final SpikeDiagnostics _diagnostics;
  final MethodChannel _channel;

  StreamSubscription<List<RepositoryWork>>? _workSub;
  StreamSubscription<List<Repository>>? _syncingSub;
  StreamSubscription<int>? _changedSub;

  Timer? _debounceTimer;
  Timer? _rescanTimer;
  bool _attached = false;
  bool _scanBusy = false;

  final Set<String> _activeRepositories = <String>{};
  final Set<String> _archivedRepositories = <String>{};

  Future<void> attach() async {
    if (_attached) {
      _diagnostics.warn(_logTag, 'attach() called twice; ignoring');
      return;
    }
    _attached = true;
    _diagnostics.log(
        _logTag, 'attaching to channel ${SpikeChannels.repositoryWork}');
    _channel.setMethodCallHandler(_handle);

    _workSub = spikeRepositoryRuntime.repoWork.stream.listen((_) {
      _schedulePush();
    });
    _syncingSub = spikeRepositoryRuntime.syncingRepositories.stream.listen((_) {
      _schedulePush();
    });
    _changedSub = spikeRepositoryRuntime.changed.stream.listen((_) {
      unawaited(_rescanAndPushIfChanged(forcePush: true));
    });

    await _rescanFromDisk();
    _push();
    _rescanTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_rescanAndPushIfChanged());
    });
    _diagnostics.success(_logTag, 'work bridge attached');
  }

  Future<void> dispose() async {
    _attached = false;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _rescanTimer?.cancel();
    _rescanTimer = null;
    await _workSub?.cancel();
    await _syncingSub?.cancel();
    await _changedSub?.cancel();
  }

  Future<dynamic> _handle(MethodCall call) async {
    _diagnostics.trace(_logTag, 'native -> ${call.method}');
    switch (call.method) {
      case SpikeRepositoryWorkMethods.getSnapshot:
        return _buildSnapshot();
      case SpikeRepositoryWorkMethods.rescan:
        await _rescanFromDisk();
        _push();
        return _buildSnapshot();
      default:
        _diagnostics.warn(_logTag, 'unhandled method ${call.method}');
        return null;
    }
  }

  Future<bool> _rescanAndPushIfChanged({bool forcePush = false}) async {
    if (_scanBusy) {
      if (forcePush) {
        _schedulePush();
      }
      return false;
    }
    _scanBusy = true;
    try {
      bool changed = await _rescanFromDisk();
      if (changed || forcePush) {
        _push();
      }
      return changed;
    } finally {
      _scanBusy = false;
    }
  }

  Future<bool> _rescanFromDisk() async {
    Set<String> previousActive = Set<String>.from(_activeRepositories);
    Set<String> previousArchived = Set<String>.from(_archivedRepositories);
    String workspaceDir = _safeWorkspaceDir();
    String archiveDir = _safeArchiveDir();
    _activeRepositories.clear();
    _archivedRepositories.clear();

    if (workspaceDir.isNotEmpty) {
      try {
        await _scanWorkspace(workspaceDir);
      } catch (e) {
        _diagnostics.warn(_logTag, 'workspace scan failed: $e');
      }
    }
    if (archiveDir.isNotEmpty) {
      try {
        await _scanArchives(archiveDir);
      } catch (e) {
        _diagnostics.warn(_logTag, 'archive scan failed: $e');
      }
    }
    _refreshDerivedSets();

    bool changed = !_sameStringSet(previousActive, _activeRepositories) ||
        !_sameStringSet(previousArchived, _archivedRepositories);
    if (changed) {
      _diagnostics.trace(
        _logTag,
        'disk scan changed: active=${_activeRepositories.length} archived=${_archivedRepositories.length}',
      );
    }
    return changed;
  }

  String _safeWorkspaceDir() {
    try {
      return _expandIfNeeded(config.workspaceDirectory);
    } catch (_) {
      return '';
    }
  }

  String _safeArchiveDir() {
    try {
      return _expandIfNeeded(config.archiveDirectory);
    } catch (_) {
      return '';
    }
  }

  String _expandIfNeeded(String input) {
    if (input.startsWith('~')) {
      final String home = Platform.environment['HOME'] ?? '';
      if (home.isNotEmpty) {
        return input.replaceFirst('~', home);
      }
    }
    return input;
  }

  Future<void> _scanWorkspace(String workspaceDir) async {
    final Directory root = Directory(workspaceDir);
    if (!await root.exists()) {
      return;
    }
    await for (FileSystemEntity ownerEntity in root.list(followLinks: false)) {
      if (ownerEntity is! Directory) {
        continue;
      }
      final String owner = ownerEntity.uri.pathSegments
          .where((String segment) => segment.isNotEmpty)
          .last;
      try {
        await for (FileSystemEntity repoEntity
            in ownerEntity.list(followLinks: false)) {
          if (repoEntity is! Directory) {
            continue;
          }
          final String name = repoEntity.uri.pathSegments
              .where((String segment) => segment.isNotEmpty)
              .last;
          final Directory gitDir = Directory('${repoEntity.path}/.git');
          if (await gitDir.exists()) {
            _activeRepositories.add('$owner/$name'.toLowerCase());
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _scanArchives(String archiveDir) async {
    final Directory archivesDir = Directory('$archiveDir/archives');
    if (!await archivesDir.exists()) {
      return;
    }
    await for (FileSystemEntity ownerEntity
        in archivesDir.list(followLinks: false)) {
      if (ownerEntity is! Directory) {
        continue;
      }
      final String owner = ownerEntity.uri.pathSegments
          .where((String segment) => segment.isNotEmpty)
          .last;
      try {
        await for (FileSystemEntity zipEntity
            in ownerEntity.list(followLinks: false)) {
          if (zipEntity is! File) {
            continue;
          }
          if (!zipEntity.path.toLowerCase().endsWith('.zip')) {
            continue;
          }
          final String fileName = zipEntity.uri.pathSegments
              .where((String segment) => segment.isNotEmpty)
              .last;
          if (!fileName.toLowerCase().endsWith('.zip')) {
            continue;
          }
          final String name = fileName.substring(0, fileName.length - 4);
          _archivedRepositories.add('$owner/$name'.toLowerCase());
        }
      } catch (_) {}
    }
  }

  void _schedulePush() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 80), _push);
  }

  void _push() {
    if (!_attached) {
      return;
    }
    final Map<String, Object?> snapshot = _buildSnapshot();
    try {
      _channel.invokeMethod<void>(
        SpikeRepositoryWorkMethods.state,
        snapshot,
      );
    } on MissingPluginException {
      _diagnostics.trace(_logTag, 'native handler not attached for state push');
    } on PlatformException catch (e) {
      _diagnostics.error(_logTag, 'state push failed: $e');
    }
  }

  Map<String, Object?> _buildSnapshot() {
    _refreshDerivedSets();

    List<RepositoryWork> liveWork = spikeRepositoryRuntime.repoWork.value;
    List<Repository> syncing = spikeRepositoryRuntime.syncingRepositories.value;
    Map<String, ArchiveMasterRepoState> masterStates =
        loadArchiveMasterRepoStates();

    List<Map<String, Object?>> workEntries =
        liveWork.map(_workEntryToJson).toList(growable: false);

    List<Map<String, Object?>> masterStatesJson = <Map<String, Object?>>[];
    masterStates.forEach((String key, ArchiveMasterRepoState state) {
      masterStatesJson.add(<String, Object?>{
        'fullName': state.fullName,
        'lastCheckedMs': state.lastCheckedMs,
        'lastPulledMs': state.lastPulledMs,
        'lastCommitHash': state.lastCommitHash,
        'lastErrorMessage': state.lastErrorMessage,
      });
    });

    List<Map<String, Object?>> localStates = _store.cachedRepositories
        .map(_localStateToJson)
        .toList(growable: false);

    return <String, Object?>{
      'activeRepositories': _activeRepositories.toList()..sort(),
      'archivedRepositories': _archivedRepositories.toList()..sort(),
      'syncingRepositories': syncing
          .map((Repository repo) => repo.fullName)
          .toList(growable: false),
      'workEntries': workEntries,
      'archiveMasterStates': masterStatesJson,
      'localStates': localStates,
    };
  }

  void _refreshDerivedSets() {
    List<Repository> verifiedActive = <Repository>[];
    for (Repository active in spikeRepositoryRuntime.activeRepositories) {
      if (_repositoryIsActiveSync(active)) {
        _activeRepositories.add(_repositoryKey(active));
        verifiedActive.add(active);
      }
    }
    if (verifiedActive.length !=
        spikeRepositoryRuntime.activeRepositories.length) {
      spikeRepositoryRuntime.setActiveRepositories(verifiedActive);
    }
  }

  Map<String, Object?> _localStateToJson(Repository repository) {
    String key = _repositoryKey(repository);
    String state = SpikeRepoStateValue.cloud;
    if (_activeRepositories.contains(key)) {
      state = SpikeRepoStateValue.active;
    } else if (_archivedRepositories.contains(key)) {
      state = SpikeRepoStateValue.archived;
    }
    AlembicRepoConfig repoConfig = getRepoConfig(repository);
    int daysUntilArchive = state == SpikeRepoStateValue.active
        ? _daysUntilArchive(repository, repoConfig.lastOpen)
        : 0;
    return <String, Object?>{
      'fullName': repository.fullName,
      'state': state,
      'daysUntilArchive': daysUntilArchive,
      'lastOpenMs': repoConfig.lastOpen,
    };
  }

  int _daysUntilArchive(Repository repository, int? lastOpenMs) {
    if (!config.archiveEnabled) {
      return 0;
    }
    int thresholdDays = config.daysToArchive;
    if (thresholdDays <= 0) {
      return 0;
    }
    int latestActivity = lastOpenMs ?? 0;
    try {
      FileStat repoStat = Directory(_repositoryPath(repository)).statSync();
      int modifiedMs = repoStat.modified.millisecondsSinceEpoch;
      if (modifiedMs > latestActivity) {
        latestActivity = modifiedMs;
      }
    } catch (_) {}
    if (latestActivity == 0) {
      return thresholdDays;
    }
    int elapsedDays = Duration(
      milliseconds:
          DateTime.timestamp().millisecondsSinceEpoch - latestActivity,
    ).inDays;
    int remainingDays = thresholdDays - elapsedDays;
    return remainingDays < 0 ? 0 : remainingDays;
  }

  bool _repositoryIsActiveSync(Repository repository) {
    return Directory(
      DesktopPlatformAdapter.instance.joinPath(
        _repositoryPath(repository),
        '.git',
      ),
    ).existsSync();
  }

  String _repositoryPath(Repository repository) {
    String owner = repository.owner?.login ?? 'unknown';
    String ownerPath = DesktopPlatformAdapter.instance.joinPath(
      _safeWorkspaceDir(),
      owner,
    );
    return DesktopPlatformAdapter.instance.joinPath(ownerPath, repository.name);
  }

  String _repositoryKey(Repository repository) {
    return repository.fullName.toLowerCase();
  }

  bool _sameStringSet(Set<String> a, Set<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (String item in a) {
      if (!b.contains(item)) {
        return false;
      }
    }
    return true;
  }

  Map<String, Object?> _workEntryToJson(RepositoryWork work) {
    return <String, Object?>{
      'fullName': work.repository.fullName,
      'kind': work.kind.name,
      'message': work.message,
      'progress': work.progress,
    };
  }
}
