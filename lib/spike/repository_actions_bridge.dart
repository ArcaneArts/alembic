import 'dart:async';

import 'package:alembic/bloc/repository_list_store.dart';
import 'package:alembic/core/arcane_repository.dart';
import 'package:alembic/spike/spike_channels.dart';
import 'package:alembic/spike/spike_diagnostics.dart';
import 'package:alembic/spike/spike_repository_runtime.dart';
import 'package:alembic/util/archive_master.dart';
import 'package:alembic/util/git_accounts.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:flutter/services.dart';
import 'package:github/github.dart';

class RepositoryActionsBridge {
  RepositoryActionsBridge({
    required RepositoryListStore store,
    SpikeDiagnostics? diagnostics,
  })  : _store = store,
        _diagnostics = diagnostics ?? SpikeDiagnostics.instance,
        _channel = const MethodChannel(SpikeChannels.repositoryActions);

  static const String _logTag = 'repo_actions_bridge';

  final RepositoryListStore _store;
  final SpikeDiagnostics _diagnostics;
  final MethodChannel _channel;
  bool _attached = false;

  Future<void> attach() async {
    if (_attached) {
      _diagnostics.warn(_logTag, 'attach called twice; ignoring');
      return;
    }
    _attached = true;
    _diagnostics.log(
        _logTag, 'attaching to channel ${SpikeChannels.repositoryActions}');
    _channel.setMethodCallHandler(_handle);
    _diagnostics.success(_logTag, 'actions bridge attached');
  }

  Future<dynamic> _handle(MethodCall call) async {
    _diagnostics.trace(_logTag, 'native -> ${call.method}');
    try {
      switch (call.method) {
        case SpikeRepositoryActionMethods.clone:
          return await _runAction(call.arguments, _clone);
        case SpikeRepositoryActionMethods.pull:
          return await _runAction(call.arguments, _pull);
        case SpikeRepositoryActionMethods.open:
          return await _runAction(call.arguments, _open);
        case SpikeRepositoryActionMethods.openInFinder:
          return await _runAction(call.arguments, _openInFinder);
        case SpikeRepositoryActionMethods.archive:
          return await _runAction(call.arguments, _archive);
        case SpikeRepositoryActionMethods.unarchive:
          return await _runAction(call.arguments, _unarchive);
        case SpikeRepositoryActionMethods.updateArchive:
          return await _runAction(call.arguments, _updateArchive);
        case SpikeRepositoryActionMethods.archiveFromCloud:
          return await _runAction(call.arguments, _archiveFromCloud);
        case SpikeRepositoryActionMethods.delete:
          return await _runAction(call.arguments, _delete);
        case SpikeRepositoryActionMethods.deleteArchive:
          return await _runAction(call.arguments, _deleteArchive);
        case SpikeRepositoryActionMethods.fork:
          return await _runAction(call.arguments, _fork);
        case SpikeRepositoryActionMethods.enrollArchiveMaster:
          return await _runAction(call.arguments, _enrollArchiveMaster);
        case SpikeRepositoryActionMethods.unenrollArchiveMaster:
          return await _runAction(call.arguments, _unenrollArchiveMaster);
        case SpikeRepositoryActionMethods.refreshArchiveMaster:
          return await _runAction(call.arguments, _refreshArchiveMaster);
        case SpikeRepositoryActionMethods.promoteArchiveMaster:
          return await _runAction(call.arguments, _promoteArchiveMaster);
        case SpikeRepositoryActionMethods.getDetail:
          return await _getDetail(call.arguments);
        default:
          _diagnostics.warn(_logTag, 'unhandled action ${call.method}');
          return <String, Object?>{
            'ok': false,
            'error': 'Unknown action: ${call.method}',
          };
      }
    } catch (e, stack) {
      _diagnostics.error(_logTag, '${call.method} threw: $e');
      _diagnostics.trace(_logTag, 'stack: $stack');
      return <String, Object?>{
        'ok': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, Object?>> _runAction(
    Object? rawArgs,
    Future<Map<String, Object?>> Function(_ActionContext ctx) handler,
  ) async {
    final _ActionContext? ctx = _resolveContext(rawArgs);
    if (ctx == null) {
      return <String, Object?>{
        'ok': false,
        'error': 'Repository not found or no account available.',
      };
    }
    return await handler(ctx);
  }

  _ActionContext? _resolveContext(Object? rawArgs) {
    final Map<dynamic, dynamic>? args = rawArgs is Map ? rawArgs : null;
    final String fullName = (args?['fullName'] as String? ?? '').trim();
    if (fullName.isEmpty) {
      _diagnostics.warn(_logTag, 'missing fullName argument');
      return null;
    }
    final Repository? repository = _store.findRepository(fullName);
    if (repository == null) {
      _diagnostics.warn(_logTag, 'repository not in cache: $fullName');
      return null;
    }

    _store.registry.refreshFromStorage();
    final String? requestedAccountId =
        (args?['accountId'] as String? ?? '').trim().isEmpty
            ? null
            : (args!['accountId'] as String).trim();
    final String? perRepoAccountId = getRepoConfig(repository).accountId;

    String? resolvedAccountId = requestedAccountId ?? perRepoAccountId;
    GitHub? github;
    if (resolvedAccountId != null) {
      github = _store.registry.githubForAccount(resolvedAccountId);
    }
    if (github == null) {
      github = _store.registry.primaryGitHub;
      resolvedAccountId = _store.registry.primaryAccountId;
    }
    if (github == null) {
      _diagnostics.warn(_logTag, 'no github client available for $fullName');
      return null;
    }

    final ArcaneRepository arcane = ArcaneRepository(
      repository: repository,
      runtime: spikeRepositoryRuntime,
      accountId: resolvedAccountId,
    );
    return _ActionContext(
      repository: repository,
      github: github,
      arcane: arcane,
      accountId: resolvedAccountId,
    );
  }

  Future<Map<String, Object?>> _clone(_ActionContext ctx) async {
    await ctx.arcane.ensureRepositoryActive(ctx.github);
    return await _stateResult(ctx);
  }

  Future<Map<String, Object?>> _pull(_ActionContext ctx) async {
    await ctx.arcane.ensureRepositoryUpdated(ctx.github);
    return await _stateResult(ctx);
  }

  Future<Map<String, Object?>> _open(_ActionContext ctx) async {
    await ctx.arcane.open(ctx.github);
    return await _stateResult(ctx);
  }

  Future<Map<String, Object?>> _openInFinder(_ActionContext ctx) async {
    await ctx.arcane.openInFinder();
    return await _stateResult(ctx);
  }

  Future<Map<String, Object?>> _archive(_ActionContext ctx) async {
    await ctx.arcane.archive();
    return await _stateResult(ctx);
  }

  Future<Map<String, Object?>> _unarchive(_ActionContext ctx) async {
    await ctx.arcane.unarchive(ctx.github);
    return await _stateResult(ctx);
  }

  Future<Map<String, Object?>> _updateArchive(_ActionContext ctx) async {
    await ctx.arcane.updateArchive(ctx.github);
    return await _stateResult(ctx);
  }

  Future<Map<String, Object?>> _archiveFromCloud(_ActionContext ctx) async {
    await ctx.arcane.archiveFromCloud(ctx.github);
    return await _stateResult(ctx);
  }

  Future<Map<String, Object?>> _delete(_ActionContext ctx) async {
    await ctx.arcane.deleteRepository();
    return await _stateResult(ctx);
  }

  Future<Map<String, Object?>> _deleteArchive(_ActionContext ctx) async {
    await ctx.arcane.deleteArchive();
    return await _stateResult(ctx);
  }

  Future<Map<String, Object?>> _fork(_ActionContext ctx) async {
    await ctx.arcane.forkAndClone(ctx.github);
    return await _stateResult(ctx);
  }

  Future<Map<String, Object?>> _enrollArchiveMaster(_ActionContext ctx) async {
    final String owner = ctx.repository.owner?.login ?? '';
    if (owner.isEmpty) {
      return <String, Object?>{
        'ok': false,
        'error': 'Repository owner is unknown',
      };
    }
    await addArchiveMasterRepository(
      owner: owner,
      repository: ctx.repository.name,
      accountId: ctx.accountId,
    );
    unawaited(ctx.arcane.ensureArchiveMaster(ctx.github));
    return await _stateResult(ctx);
  }

  Future<Map<String, Object?>> _unenrollArchiveMaster(
      _ActionContext ctx) async {
    final String owner = ctx.repository.owner?.login ?? '';
    if (owner.isEmpty) {
      return <String, Object?>{
        'ok': false,
        'error': 'Repository owner is unknown',
      };
    }
    await removeArchiveMasterRepository(owner, ctx.repository.name);
    await ctx.arcane.removeArchiveMaster();
    return await _stateResult(ctx);
  }

  Future<Map<String, Object?>> _refreshArchiveMaster(_ActionContext ctx) async {
    await ctx.arcane.ensureArchiveMaster(ctx.github);
    return await _stateResult(ctx);
  }

  Future<Map<String, Object?>> _promoteArchiveMaster(_ActionContext ctx) async {
    await ctx.arcane.promoteArchiveMaster(ctx.github);
    return await _stateResult(ctx);
  }

  Future<Map<String, Object?>> _getDetail(Object? rawArgs) async {
    final _ActionContext? ctx = _resolveContext(rawArgs);
    if (ctx == null) {
      return <String, Object?>{
        'ok': false,
        'error': 'Repository not found',
      };
    }
    final RepoState state = await ctx.arcane.state;
    final int daysUntilArchival = await ctx.arcane.daysUntilArchival;
    final int? latestModification =
        await ctx.arcane.getLatestFileModificationTime();
    final ArchiveMasterRepoState? masterState =
        getArchiveMasterRepoState(ctx.repository.fullName);
    final int? lastOpen = getRepoConfig(ctx.repository).lastOpen;
    final GitAccount? account =
        ctx.accountId == null ? null : findGitAccountById(ctx.accountId);
    return <String, Object?>{
      'ok': true,
      'fullName': ctx.repository.fullName,
      'repoPath': ctx.arcane.repoPath,
      'archivePath': ctx.arcane.imagePath,
      'archiveMasterPath': ctx.arcane.archiveMasterPath,
      'state': _stateName(state),
      'daysUntilArchival': daysUntilArchival,
      'lastOpenMs': lastOpen,
      'latestFileModificationMs': latestModification,
      'accountId': ctx.accountId,
      'accountLogin': account?.login,
      'archiveMaster': masterState == null
          ? null
          : <String, Object?>{
              'fullName': masterState.fullName,
              'lastCheckedMs': masterState.lastCheckedMs,
              'lastPulledMs': masterState.lastPulledMs,
              'lastCommitHash': masterState.lastCommitHash,
              'lastErrorMessage': masterState.lastErrorMessage,
            },
    };
  }

  Future<Map<String, Object?>> _stateResult(_ActionContext ctx) async {
    final RepoState state = await ctx.arcane.state;
    return <String, Object?>{
      'ok': true,
      'fullName': ctx.repository.fullName,
      'state': _stateName(state),
    };
  }

  String _stateName(RepoState state) {
    switch (state) {
      case RepoState.active:
        return SpikeRepoStateValue.active;
      case RepoState.archived:
        return SpikeRepoStateValue.archived;
      case RepoState.cloud:
        return SpikeRepoStateValue.cloud;
    }
  }
}

class _ActionContext {
  _ActionContext({
    required this.repository,
    required this.github,
    required this.arcane,
    required this.accountId,
  });

  final Repository repository;
  final GitHub github;
  final ArcaneRepository arcane;
  final String? accountId;
}
