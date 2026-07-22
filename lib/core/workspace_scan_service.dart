import 'dart:async';
import 'dart:io';

import 'package:alembic/bloc/repository_list_store.dart';
import 'package:alembic/core/diagnostics.dart';
import 'package:alembic/core/repository_runtime.dart';
import 'package:alembic/domain/repository_list_status.dart';
import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:alembic/util/archive_master.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:github/github.dart';
import 'package:rxdart/rxdart.dart';

class RepositoryLocalState {
  final String fullName;
  final String state;
  final int daysUntilArchive;
  final int? lastOpenMs;

  const RepositoryLocalState({
    required this.fullName,
    required this.state,
    required this.daysUntilArchive,
    required this.lastOpenMs,
  });
}

class WorkspaceScanSnapshot {
  final List<String> activeRepositories;
  final List<String> archivedRepositories;
  final List<String> syncingRepositories;
  final List<RepositoryWork> workEntries;
  final Map<String, ArchiveMasterRepoState> archiveMasterStates;
  final Map<String, RepositoryLocalState> localStates;

  const WorkspaceScanSnapshot({
    required this.activeRepositories,
    required this.archivedRepositories,
    required this.syncingRepositories,
    required this.workEntries,
    required this.archiveMasterStates,
    required this.localStates,
  });

  factory WorkspaceScanSnapshot.empty() => const WorkspaceScanSnapshot(
        activeRepositories: <String>[],
        archivedRepositories: <String>[],
        syncingRepositories: <String>[],
        workEntries: <RepositoryWork>[],
        archiveMasterStates: <String, ArchiveMasterRepoState>{},
        localStates: <String, RepositoryLocalState>{},
      );

  RepositoryLocalState? localStateFor(String fullName) =>
      localStates[fullName.toLowerCase()];

  bool isActive(String fullName) =>
      activeRepositories.contains(fullName.toLowerCase());

  bool isArchived(String fullName) =>
      archivedRepositories.contains(fullName.toLowerCase());
}

class WorkspaceScanService {
  static const String _logTag = 'workspace_scan';
  static const Duration _rescanInterval = Duration(seconds: 5);
  static const Duration _debounceDelay = Duration(milliseconds: 80);

  final RepositoryListStore _store;
  final RepositoryRuntime _runtime;
  final AlembicDiagnostics _diagnostics;
  final BehaviorSubject<WorkspaceScanSnapshot> _subject;
  final Set<String> _activeRepositories = <String>{};
  final Set<String> _archivedRepositories = <String>{};

  StreamSubscription<List<RepositoryWork>>? _workSub;
  StreamSubscription<List<Repository>>? _syncingSub;
  StreamSubscription<int>? _changedSub;
  Timer? _debounceTimer;
  Timer? _rescanTimer;
  bool _started = false;
  bool _scanBusy = false;

  WorkspaceScanService({
    required RepositoryListStore store,
    required RepositoryRuntime runtime,
    AlembicDiagnostics? diagnostics,
  })  : _store = store,
        _runtime = runtime,
        _diagnostics = diagnostics ?? AlembicDiagnostics.instance,
        _subject = BehaviorSubject<WorkspaceScanSnapshot>.seeded(
          WorkspaceScanSnapshot.empty(),
        );

  Stream<WorkspaceScanSnapshot> get stream => _subject.stream;

  WorkspaceScanSnapshot get value => _subject.value;

  Future<void> start() async {
    if (_started) {
      _diagnostics.warn(_logTag, 'start() called twice; ignoring');
      return;
    }
    _started = true;
    _workSub = _runtime.repoWork.stream.listen((_) {
      _scheduleEmit();
    });
    _syncingSub = _runtime.syncingRepositories.stream.listen((_) {
      _scheduleEmit();
    });
    _changedSub = _runtime.changed.stream.listen((_) {
      unawaited(_rescanAndEmitIfChanged(forceEmit: true));
    });
    await _rescanFromDisk();
    _emitSnapshot();
    _rescanTimer = Timer.periodic(_rescanInterval, (_) {
      unawaited(_rescanAndEmitIfChanged());
    });
    _diagnostics.success(_logTag, 'workspace scan service started');
  }

  Future<void> rescan() async {
    await _rescanFromDisk();
    _emitSnapshot();
  }

  Future<void> dispose() async {
    _started = false;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _rescanTimer?.cancel();
    _rescanTimer = null;
    await _workSub?.cancel();
    await _syncingSub?.cancel();
    await _changedSub?.cancel();
    await _subject.close();
  }

  Future<bool> _rescanAndEmitIfChanged({bool forceEmit = false}) async {
    if (_scanBusy) {
      if (forceEmit) {
        _scheduleEmit();
      }
      return false;
    }
    _scanBusy = true;
    try {
      bool changed = await _rescanFromDisk();
      if (changed || forceEmit) {
        _emitSnapshot();
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
      return DesktopPlatformAdapter.instance
          .expandHomePath(config.workspaceDirectory);
    } catch (_) {
      return '';
    }
  }

  String _safeArchiveDir() {
    try {
      return DesktopPlatformAdapter.instance
          .expandHomePath(config.archiveDirectory);
    } catch (_) {
      return '';
    }
  }

  Future<void> _scanWorkspace(String workspaceDir) async {
    Directory root = Directory(workspaceDir);
    if (!await root.exists()) {
      return;
    }
    await for (FileSystemEntity ownerEntity in root.list(followLinks: false)) {
      if (ownerEntity is! Directory) {
        continue;
      }
      String owner = ownerEntity.uri.pathSegments
          .where((String segment) => segment.isNotEmpty)
          .last;
      try {
        await for (FileSystemEntity repoEntity
            in ownerEntity.list(followLinks: false)) {
          if (repoEntity is! Directory) {
            continue;
          }
          String name = repoEntity.uri.pathSegments
              .where((String segment) => segment.isNotEmpty)
              .last;
          Directory gitDir = Directory('${repoEntity.path}/.git');
          if (await gitDir.exists()) {
            _activeRepositories.add('$owner/$name'.toLowerCase());
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _scanArchives(String archiveDir) async {
    Directory archivesDir = Directory('$archiveDir/archives');
    if (!await archivesDir.exists()) {
      return;
    }
    await for (FileSystemEntity ownerEntity
        in archivesDir.list(followLinks: false)) {
      if (ownerEntity is! Directory) {
        continue;
      }
      String owner = ownerEntity.uri.pathSegments
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
          String fileName = zipEntity.uri.pathSegments
              .where((String segment) => segment.isNotEmpty)
              .last;
          if (!fileName.toLowerCase().endsWith('.zip')) {
            continue;
          }
          String name = fileName.substring(0, fileName.length - 4);
          _archivedRepositories.add('$owner/$name'.toLowerCase());
        }
      } catch (_) {}
    }
  }

  void _scheduleEmit() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, _emitSnapshot);
  }

  void _emitSnapshot() {
    if (!_started || _subject.isClosed) {
      return;
    }
    _subject.add(_buildSnapshot());
  }

  WorkspaceScanSnapshot _buildSnapshot() {
    _refreshDerivedSets();

    Map<String, ArchiveMasterRepoState> masterStates =
        loadArchiveMasterRepoStates();
    Map<String, RepositoryLocalState> localStates =
        <String, RepositoryLocalState>{};
    for (Repository repository in _store.cachedRepositories) {
      localStates[repository.fullName.toLowerCase()] = _localState(repository);
    }

    return WorkspaceScanSnapshot(
      activeRepositories:
          List<String>.unmodifiable(_activeRepositories.toList()..sort()),
      archivedRepositories:
          List<String>.unmodifiable(_archivedRepositories.toList()..sort()),
      syncingRepositories: List<String>.unmodifiable(
        _runtime.syncingRepositories.value
            .map((Repository repo) => repo.fullName),
      ),
      workEntries: List<RepositoryWork>.unmodifiable(_runtime.repoWork.value),
      archiveMasterStates:
          Map<String, ArchiveMasterRepoState>.unmodifiable(masterStates),
      localStates: Map<String, RepositoryLocalState>.unmodifiable(localStates),
    );
  }

  void _refreshDerivedSets() {
    List<Repository> verifiedActive = <Repository>[];
    for (Repository active in _runtime.activeRepositories) {
      if (_repositoryIsActiveSync(active)) {
        _activeRepositories.add(_repositoryKey(active));
        verifiedActive.add(active);
      }
    }
    if (verifiedActive.length != _runtime.activeRepositories.length) {
      _runtime.setActiveRepositories(verifiedActive);
    }
  }

  RepositoryLocalState _localState(Repository repository) {
    String key = _repositoryKey(repository);
    String state = RepoStateValue.cloud;
    if (_activeRepositories.contains(key)) {
      state = RepoStateValue.active;
    } else if (_archivedRepositories.contains(key)) {
      state = RepoStateValue.archived;
    }
    AlembicRepoConfig repoConfig = getRepoConfig(repository);
    int daysUntilArchive = state == RepoStateValue.active
        ? _daysUntilArchive(repository, repoConfig.lastOpen)
        : 0;
    return RepositoryLocalState(
      fullName: repository.fullName,
      state: state,
      daysUntilArchive: daysUntilArchive,
      lastOpenMs: repoConfig.lastOpen,
    );
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

  bool _repositoryIsActiveSync(Repository repository) => Directory(
        DesktopPlatformAdapter.instance.joinPath(
          _repositoryPath(repository),
          '.git',
        ),
      ).existsSync();

  String _repositoryPath(Repository repository) {
    String owner = repository.owner?.login ?? 'unknown';
    String ownerPath = DesktopPlatformAdapter.instance.joinPath(
      _safeWorkspaceDir(),
      owner,
    );
    return DesktopPlatformAdapter.instance.joinPath(ownerPath, repository.name);
  }

  String _repositoryKey(Repository repository) =>
      repository.fullName.toLowerCase();

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
}
