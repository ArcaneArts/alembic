import 'dart:async';
import 'dart:io';

import 'package:alembic/bloc/repository_list_store.dart';
import 'package:alembic/core/repository_runtime.dart';
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
  })  : _diagnostics = diagnostics ?? SpikeDiagnostics.instance,
        _channel = const MethodChannel(SpikeChannels.repositoryWork);

  static const String _logTag = 'repo_work_bridge';

  final SpikeDiagnostics _diagnostics;
  final MethodChannel _channel;

  StreamSubscription<List<RepositoryWork>>? _workSub;
  StreamSubscription<List<Repository>>? _syncingSub;
  StreamSubscription<int>? _changedSub;

  Timer? _debounceTimer;
  bool _attached = false;

  final Set<String> _activeRepositories = <String>{};
  final Set<String> _archivedRepositories = <String>{};

  Future<void> attach() async {
    if (_attached) {
      _diagnostics.warn(_logTag, 'attach() called twice; ignoring');
      return;
    }
    _attached = true;
    _diagnostics.log(_logTag, 'attaching to channel ${SpikeChannels.repositoryWork}');
    _channel.setMethodCallHandler(_handle);

    _workSub = spikeRepositoryRuntime.repoWork.stream.listen((_) {
      _schedulePush();
    });
    _syncingSub = spikeRepositoryRuntime.syncingRepositories.stream.listen((_) {
      _schedulePush();
    });
    _changedSub = spikeRepositoryRuntime.changed.stream.listen((_) {
      _schedulePush();
    });

    await _rescanFromDisk();
    _push();
    _diagnostics.success(_logTag, 'work bridge attached');
  }

  Future<void> dispose() async {
    _attached = false;
    _debounceTimer?.cancel();
    _debounceTimer = null;
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

  Future<void> _rescanFromDisk() async {
    final String workspaceDir = _safeWorkspaceDir();
    final String archiveDir = _safeArchiveDir();
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

    _diagnostics.log(
      _logTag,
      'disk scan complete: active=${_activeRepositories.length} archived=${_archivedRepositories.length}',
    );
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

    final List<RepositoryWork> liveWork = spikeRepositoryRuntime.repoWork.value;
    final List<Repository> syncing =
        spikeRepositoryRuntime.syncingRepositories.value;
    final Map<String, ArchiveMasterRepoState> masterStates =
        loadArchiveMasterRepoStates();

    final List<Map<String, Object?>> workEntries = liveWork
        .map(_workEntryToJson)
        .toList(growable: false);

    final List<Map<String, Object?>> masterStatesJson =
        <Map<String, Object?>>[];
    masterStates.forEach((String key, ArchiveMasterRepoState state) {
      masterStatesJson.add(<String, Object?>{
        'fullName': state.fullName,
        'lastCheckedMs': state.lastCheckedMs,
        'lastPulledMs': state.lastPulledMs,
        'lastCommitHash': state.lastCommitHash,
        'lastErrorMessage': state.lastErrorMessage,
      });
    });

    return <String, Object?>{
      'activeRepositories': _activeRepositories.toList()..sort(),
      'archivedRepositories': _archivedRepositories.toList()..sort(),
      'syncingRepositories': syncing
          .map((Repository repo) => repo.fullName)
          .toList(growable: false),
      'workEntries': workEntries,
      'archiveMasterStates': masterStatesJson,
    };
  }

  void _refreshDerivedSets() {
    for (final Repository active in spikeRepositoryRuntime.activeRepositories) {
      _activeRepositories.add(active.fullName.toLowerCase());
    }
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
