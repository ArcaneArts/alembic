import 'package:github/github.dart';
import 'package:rxdart/rxdart.dart';

enum RepositoryWorkKind {
  generic,
  clone,
}

class RepositoryWork {
  final Repository repository;
  final RepositoryWorkKind kind;
  String message;
  double? progress;

  RepositoryWork({
    required this.repository,
    required this.message,
    this.kind = RepositoryWorkKind.generic,
    this.progress,
  });
}

class RepositoryRuntime {
  final BehaviorSubject<int> changed = BehaviorSubject<int>.seeded(0);
  final BehaviorSubject<List<Repository>> syncingRepositories =
      BehaviorSubject<List<Repository>>.seeded(<Repository>[]);
  final BehaviorSubject<List<RepositoryWork>> repoWork =
      BehaviorSubject<List<RepositoryWork>>.seeded(
    <RepositoryWork>[],
  );

  List<Repository> _activeRepositories = <Repository>[];

  List<Repository> get activeRepositories =>
      List<Repository>.unmodifiable(_activeRepositories);

  void clearActiveRepositories() {
    setActiveRepositories(const <Repository>[]);
  }

  void setActiveRepositories(Iterable<Repository> repositories) {
    final Map<String, Repository> deduped = <String, Repository>{};
    for (final Repository repository in repositories) {
      deduped[repository.fullName.toLowerCase()] = repository;
    }
    _activeRepositories = deduped.values.toList()
      ..sort((Repository a, Repository b) => a.fullName.compareTo(b.fullName));
    notifyChanged();
  }

  bool isActiveRepository(Repository repository) {
    String target = repository.fullName.toLowerCase();
    return _activeRepositories.any(
      (Repository item) => item.fullName.toLowerCase() == target,
    );
  }

  void addActiveRepository(Repository repository, {bool notify = true}) {
    if (isActiveRepository(repository)) {
      return;
    }
    _activeRepositories = <Repository>[..._activeRepositories, repository];
    if (notify) {
      notifyChanged();
    }
  }

  void removeActiveRepository(Repository repository, {bool notify = true}) {
    final int before = _activeRepositories.length;
    String target = repository.fullName.toLowerCase();
    _activeRepositories = _activeRepositories
        .where((Repository item) => item.fullName.toLowerCase() != target)
        .toList();
    if (notify && before != _activeRepositories.length) {
      notifyChanged();
    }
  }

  RepositoryWork beginWork(
    Repository repository,
    String message, {
    RepositoryWorkKind kind = RepositoryWorkKind.generic,
    double? progress,
  }) {
    RepositoryWork job = RepositoryWork(
      repository: repository,
      message: message,
      kind: kind,
      progress: progress,
    );
    repoWork.add(<RepositoryWork>[...repoWork.value, job]);
    return job;
  }

  void updateWork(
    RepositoryWork job, {
    String? message,
    double? progress,
    bool clearProgress = false,
  }) {
    if (message != null) {
      job.message = message;
    }
    if (clearProgress) {
      job.progress = null;
    } else if (progress != null) {
      job.progress = _clampedProgress(progress);
    }
    repoWork.add(<RepositoryWork>[...repoWork.value]);
  }

  void endWork(RepositoryWork job) {
    repoWork.add(
      repoWork.value.where((item) => item != job).toList(),
    );
  }

  Stream<List<RepositoryWork>> streamWorkEntries(Repository repository) {
    String target = repository.fullName.toLowerCase();
    return repoWork.stream.map((List<RepositoryWork> work) {
      return work
          .where(
            (RepositoryWork item) =>
                item.repository.fullName.toLowerCase() == target,
          )
          .toList();
    });
  }

  Stream<List<String>> streamWork(Repository repository) {
    return streamWorkEntries(repository).map((List<RepositoryWork> work) {
      return work.map((RepositoryWork item) => item.message).toList();
    });
  }

  void addSyncingRepository(Repository repository) {
    syncingRepositories.add(
      <Repository>[...syncingRepositories.value, repository],
    );
  }

  void removeSyncingRepository(Repository repository) {
    String target = repository.fullName.toLowerCase();
    syncingRepositories.add(
      syncingRepositories.value
          .where((item) => item.fullName.toLowerCase() != target)
          .toList(),
    );
  }

  void notifyChanged() {
    changed.add(changed.value + 1);
  }

  Future<void> dispose() async {
    await changed.close();
    await syncingRepositories.close();
    await repoWork.close();
  }

  double _clampedProgress(double value) {
    if (value < 0) {
      return 0;
    }
    if (value > 1) {
      return 1;
    }
    return value;
  }
}
