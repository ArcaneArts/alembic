import 'package:github/github.dart';
import 'package:rxdart/rxdart.dart';

class RepositoryRuntime {
  final BehaviorSubject<int> changed = BehaviorSubject<int>.seeded(0);
  final BehaviorSubject<List<Repository>> syncingRepositories =
      BehaviorSubject<List<Repository>>.seeded(<Repository>[]);
  final BehaviorSubject<List<(Repository, String)>> repoWork =
      BehaviorSubject<List<(Repository, String)>>.seeded(
    <(Repository, String)>[],
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

  (Repository, String) beginWork(Repository repository, String message) {
    final (Repository, String) job = (repository, message);
    repoWork.add(<(Repository, String)>[...repoWork.value, job]);
    return job;
  }

  void endWork((Repository, String) job) {
    repoWork.add(
      repoWork.value.where((item) => item != job).toList(),
    );
  }

  Stream<List<String>> streamWork(Repository repository) {
    String target = repository.fullName.toLowerCase();
    return repoWork.stream.map((List<(Repository, String)> work) {
      return work
          .where((item) => item.$1.fullName.toLowerCase() == target)
          .map((item) => item.$2)
          .toList();
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
}
