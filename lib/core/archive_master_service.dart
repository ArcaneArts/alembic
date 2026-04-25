import 'dart:async';

import 'package:alembic/core/account_registry.dart';
import 'package:alembic/core/arcane_repository.dart';
import 'package:alembic/core/repository_runtime.dart';
import 'package:alembic/util/archive_master.dart';
import 'package:alembic/util/environment.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:alembic/util/semaphore.dart';
import 'package:fast_log/fast_log.dart';
import 'package:github/github.dart';
import 'package:rxdart/rxdart.dart';

ArchiveMasterService? _archiveMasterServiceInstance;

ArchiveMasterService? get archiveMasterService => _archiveMasterServiceInstance;

void setArchiveMasterService(ArchiveMasterService? service) {
  _archiveMasterServiceInstance = service;
}

class ArchiveMasterService {
  final AccountRegistry registry;
  final RepositoryRuntime runtime;

  Timer? _scheduleTimer;
  Timer? _initialDelayTimer;
  bool _running = false;
  int _lastRunMs = 0;
  bool _disposed = false;

  final BehaviorSubject<bool> isRunning = BehaviorSubject<bool>.seeded(false);
  final BehaviorSubject<int> lastRunMs = BehaviorSubject<int>.seeded(0);

  ArchiveMasterService({
    required this.registry,
    required this.runtime,
  });

  Future<void> dispose() async {
    _disposed = true;
    _scheduleTimer?.cancel();
    _scheduleTimer = null;
    _initialDelayTimer?.cancel();
    _initialDelayTimer = null;
    await isRunning.close();
    await lastRunMs.close();
  }

  void start() {
    if (_disposed) {
      return;
    }
    _scheduleTimer?.cancel();
    _initialDelayTimer?.cancel();
    if (alembicIsFlutterTestEnvironment()) {
      return;
    }
    final int intervalMinutes = config.archiveMasterIntervalMinutes;
    final Duration period = Duration(
      minutes: intervalMinutes <= 0 ? 60 : intervalMinutes,
    );
    _scheduleTimer = Timer.periodic(period, (_) {
      if (_disposed) {
        return;
      }
      unawaited(runOnce());
    });
    _initialDelayTimer = Timer(const Duration(seconds: 5), () {
      if (_disposed) {
        return;
      }
      unawaited(runOnce());
    });
  }

  void rescheduleAfterConfigChange() {
    start();
  }

  Future<void> runOnce({bool force = false}) async {
    if (_running) {
      return;
    }
    final List<ArchiveMasterTarget> targets = loadArchiveMasterTargets();
    if (targets.isEmpty) {
      return;
    }
    final int nowMs = DateTime.timestamp().millisecondsSinceEpoch;
    final int intervalMs = Duration(
      minutes: config.archiveMasterIntervalMinutes <= 0
          ? 60
          : config.archiveMasterIntervalMinutes,
    ).inMilliseconds;
    if (!force && _lastRunMs > 0 && (nowMs - _lastRunMs) < intervalMs) {
      return;
    }
    _running = true;
    isRunning.add(true);
    try {
      final List<_TargetWork> resolvedWork = await _resolveTargets(targets);
      if (resolvedWork.isEmpty) {
        return;
      }
      List<Future<void> Function()> jobs = <Future<void> Function()>[];
      for (final _TargetWork work in resolvedWork) {
        jobs.add(() => _runTargetWork(work));
      }
      await jobs.waitSemaphore<void>(3);
    } catch (e) {
      error('Archive master service run failed: $e');
    } finally {
      _running = false;
      _lastRunMs = DateTime.timestamp().millisecondsSinceEpoch;
      lastRunMs.add(_lastRunMs);
      isRunning.add(false);
    }
  }

  Future<void> _runTargetWork(_TargetWork work) async {
    try {
      final ArcaneRepository arcane = ArcaneRepository(
        repository: work.repository,
        runtime: runtime,
        accountId: work.accountId,
      );
      final GitHub github =
          registry.githubForAccount(work.accountId ?? '') ??
              registry.primaryGitHub ??
              GitHub();
      await arcane.ensureArchiveMaster(github);
    } catch (e) {
      warn('Archive master target ${work.repository.fullName} failed: $e');
    }
  }

  Future<List<_TargetWork>> _resolveTargets(
      List<ArchiveMasterTarget> targets) async {
    final Map<String, _TargetWork> dedup = <String, _TargetWork>{};
    for (final ArchiveMasterTarget target in targets) {
      try {
        if (target.kind == ArchiveMasterTargetKind.repository) {
          final Repository? repository = await _fetchRepository(
            owner: target.owner,
            name: target.repository ?? '',
            preferredAccountId: target.accountId,
          );
          if (repository == null) {
            warn(
              'Archive master target ${target.displayName} could not be resolved',
            );
            continue;
          }
          dedup[repository.fullName.toLowerCase()] = _TargetWork(
            repository: repository,
            accountId: target.accountId ?? registry.primaryAccountId,
          );
        } else {
          final List<Repository> orgRepos = await _fetchOrganizationRepositories(
            owner: target.owner,
            preferredAccountId: target.accountId,
          );
          for (final Repository repository in orgRepos) {
            dedup[repository.fullName.toLowerCase()] = _TargetWork(
              repository: repository,
              accountId: target.accountId ?? registry.primaryAccountId,
            );
          }
        }
      } catch (e) {
        warn('Archive master target ${target.displayName} resolution failed: $e');
      }
    }
    return dedup.values.toList();
  }

  Future<Repository?> _fetchRepository({
    required String owner,
    required String name,
    String? preferredAccountId,
  }) async {
    if (owner.isEmpty || name.isEmpty) {
      return null;
    }
    final RepositorySlug slug = RepositorySlug(owner, name);
    final List<GitHub> ordered = _orderedGitHubs(preferredAccountId);
    for (final GitHub github in ordered) {
      try {
        return await github.repositories.getRepository(slug);
      } catch (_) {}
    }
    final GitHub anonymous = GitHub();
    try {
      return await anonymous.repositories.getRepository(slug);
    } catch (_) {
      return null;
    } finally {
      anonymous.dispose();
    }
  }

  Future<List<Repository>> _fetchOrganizationRepositories({
    required String owner,
    String? preferredAccountId,
  }) async {
    if (owner.isEmpty) {
      return <Repository>[];
    }
    final List<GitHub> ordered = _orderedGitHubs(preferredAccountId);
    for (final GitHub github in ordered) {
      try {
        final List<Repository> repos = await github.repositories
            .listOrganizationRepositories(owner)
            .toList();
        if (repos.isNotEmpty) {
          return repos;
        }
        final List<Repository> userRepos = await github.repositories
            .listUserRepositories(owner)
            .toList();
        if (userRepos.isNotEmpty) {
          return userRepos;
        }
      } catch (_) {}
    }
    final GitHub anonymous = GitHub();
    try {
      final List<Repository> orgRepos = await anonymous.repositories
          .listOrganizationRepositories(owner)
          .toList();
      if (orgRepos.isNotEmpty) {
        return orgRepos;
      }
      return await anonymous.repositories.listUserRepositories(owner).toList();
    } catch (_) {
      return <Repository>[];
    } finally {
      anonymous.dispose();
    }
  }

  List<GitHub> _orderedGitHubs(String? preferredAccountId) {
    final List<GitHub> ordered = <GitHub>[];
    final Set<String> seen = <String>{};
    if (preferredAccountId != null) {
      final GitHub? specific = registry.githubForAccount(preferredAccountId);
      if (specific != null) {
        ordered.add(specific);
        seen.add(preferredAccountId);
      }
    }
    if (registry.primaryAccountId != null &&
        !seen.contains(registry.primaryAccountId) &&
        registry.primaryGitHub != null) {
      ordered.add(registry.primaryGitHub!);
      seen.add(registry.primaryAccountId!);
    }
    for (final AccountClient client in registry.clients) {
      if (seen.contains(client.account.id)) {
        continue;
      }
      ordered.add(client.github);
      seen.add(client.account.id);
    }
    return ordered;
  }
}

class _TargetWork {
  final Repository repository;
  final String? accountId;

  const _TargetWork({
    required this.repository,
    required this.accountId,
  });
}
