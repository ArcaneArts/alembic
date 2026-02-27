import 'dart:async';
import 'dart:io';

import 'package:alembic/core/arcane_repository.dart';
import 'package:alembic/core/repository_runtime.dart';
import 'package:alembic/main.dart';
import 'package:alembic/util/repository_catalog.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:alembic/util/semaphore.dart';
import 'package:alembic/widget/glass_panel.dart';
import 'package:fast_log/fast_log.dart';
import 'package:github/github.dart';
import 'package:rxdart/rxdart.dart';

class HomeController {
  final GitHub github;
  final RepositoryRuntime runtime;
  final Map<Organization, List<Repository>> orgRepos =
      <Organization, List<Repository>>{};
  final List<Repository> personalRepos = <Repository>[];
  final BehaviorSubject<int> fetching = BehaviorSubject<int>.seeded(0);
  final BehaviorSubject<double?> progress =
      BehaviorSubject<double?>.seeded(null);

  Future<List<Repository>> allRepos = Future<List<Repository>>.value(
    <Repository>[],
  );

  Timer? _staleCheckTimer;
  bool _staleCheckRunning = false;
  bool _classicMigrationPromptConsumed = false;

  HomeController({
    required this.github,
    required this.runtime,
  });

  ArcaneRepository repositoryFor(Repository repository) {
    return ArcaneRepository(
      repository: repository,
      runtime: runtime,
    );
  }

  Future<List<Repository>> initialize({bool updateTokens = true}) {
    runtime.clearActiveRepositories();
    allRepos = _buildRepositoryFuture();
    if (updateTokens) {
      allRepos.then((List<Repository> _) => updateAllRepositoryTokens());
    }
    scheduleStaleCheck();
    return allRepos;
  }

  Future<void> dispose() async {
    _staleCheckTimer?.cancel();
    await fetching.close();
    await progress.close();
  }

  Future<void> reloadRepositories({bool updateTokens = false}) async {
    allRepos = _buildRepositoryFuture();
    if (updateTokens) {
      allRepos.then((List<Repository> _) => updateAllRepositoryTokens());
    }
    await allRepos;
  }

  Future<List<Repository>> _buildRepositoryFuture() {
    return _fetchAllRepos().catchError((Object e, StackTrace stackTrace) {
      error(e);
      error(stackTrace);
      return <Repository>[];
    }).then(_processActiveRepos);
  }

  Future<List<Repository>> _processActiveRepos(List<Repository> repos) async {
    List<Repository> activeRepositories = <Repository>[];
    List<Future<void>> work = <Future<void>>[];
    for (Repository repo in repos) {
      ArcaneRepository repository = repositoryFor(repo);
      work.add(repository.isActive.then((bool isActiveRepo) {
        if (isActiveRepo) {
          activeRepositories.add(repo);
        }
      }));
    }
    await Future.wait(work);
    runtime.setActiveRepositories(activeRepositories);
    return repos;
  }

  void scheduleStaleCheck() {
    _staleCheckTimer?.cancel();
    runStaleCheck();
    _staleCheckTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => runStaleCheck(),
    );
  }

  Future<void> runStaleCheck() async {
    if (_staleCheckRunning) {
      return;
    }
    _staleCheckRunning = true;
    try {
      List<Repository> snapshot = List<Repository>.from(
        runtime.activeRepositories,
      );
      for (Repository repo in snapshot) {
        ArcaneRepository repository = repositoryFor(repo);
        bool stale = await repository.isStaleActive;
        if (!stale) {
          continue;
        }
        warn('${repo.fullName} is stale, archiving');
        await repository.archive();
      }
    } finally {
      _staleCheckRunning = false;
    }
  }

  Future<void> refreshActiveRepositories() async {
    List<Repository> repositories = await allRepos;
    List<Repository> activeRepositories = <Repository>[];
    for (Repository repo in repositories) {
      if (repositoryFor(repo).isActiveSync) {
        activeRepositories.add(repo);
      }
    }
    runtime.setActiveRepositories(activeRepositories);
  }

  Future<int> updateAllRepositoryTokens() async {
    if (!box.containsKey('1')) {
      return 0;
    }

    String latestToken = box.get('1');
    progress.add(0.0);

    List<Repository> repositories = await allRepos;
    int total = repositories.length;
    int current = 0;
    int updated = 0;

    for (Repository repo in repositories) {
      ArcaneRepository repository = repositoryFor(repo);
      if (await repository.isActive) {
        bool wasUpdated = await repository.checkAndUpdateToken(latestToken);
        if (wasUpdated) {
          updated++;
          success('Updated token for ${repo.fullName}');
        }
      }
      current++;
      progress.add(total == 0 ? null : current / total);
    }

    progress.add(null);
    return updated;
  }

  Future<List<Repository>> _fetchAllRepos() async {
    if (alembicIsFlutterTestEnvironment()) {
      personalRepos.clear();
      orgRepos.clear();
      fetching.add(0);
      return <Repository>[];
    }

    personalRepos.clear();
    orgRepos.clear();
    fetching.add(0);

    Map<String, Repository> mergedRepositories = <String, Repository>{};
    String currentLogin = '';

    try {
      try {
        CurrentUser currentUser = await github.users.getCurrentUser();
        currentLogin = (currentUser.login ?? '').toLowerCase();
        if (currentLogin.isNotEmpty) {
          await boxSettings.put('current_user_login', currentLogin);
        }
      } catch (_) {
        currentLogin =
            (boxSettings.get('current_user_login', defaultValue: '') as String)
                .toLowerCase();
      }

      List<Repository> fetchedRepositories =
          await listRepositoriesAggressive(type: 'all').toList();
      for (Repository repository in fetchedRepositories) {
        mergedRepositories[repository.fullName.toLowerCase()] = repository;
      }

      List<RepositoryRef> manualRefs = loadManualRepoRefs();
      List<RepositoryRef> unresolvedManualRefs = <RepositoryRef>[];
      for (RepositoryRef ref in manualRefs) {
        String key = ref.fullName.toLowerCase();
        if (!mergedRepositories.containsKey(key)) {
          unresolvedManualRefs.add(ref);
        }
      }

      if (unresolvedManualRefs.isNotEmpty) {
        Map<String, Repository> manualResolved = await resolveManualRefs(
          refs: unresolvedManualRefs,
          existing: mergedRepositories,
          maxConcurrency: 4,
          resolve: resolveRepositoryRef,
          localFallback: localFallbackRepository,
        );
        mergedRepositories.addAll(manualResolved);
      }

      List<Repository> repos = mergedRepositories.values.toList()
        ..sort(
          (Repository a, Repository b) => a.fullName.compareTo(b.fullName),
        );
      Map<String, Organization> ownerOrganizations = <String, Organization>{};
      for (Repository repo in repos) {
        String ownerLogin = repo.owner?.login ?? 'unknown';
        bool isPersonal = ownerLogin.toLowerCase() == currentLogin;

        if (!isPersonal) {
          if (!ownerOrganizations.containsKey(ownerLogin)) {
            ownerOrganizations[ownerLogin] = Organization()..login = ownerLogin;
            orgRepos[ownerOrganizations[ownerLogin]!] = <Repository>[];
          }
          orgRepos[ownerOrganizations[ownerLogin]!]!.add(repo);
        } else {
          personalRepos.add(repo);
        }
        fetching.add(fetching.value + 1);
      }

      if (personalRepos.isEmpty && orgRepos.isEmpty) {
        personalRepos.addAll(repos);
      }

      return repos;
    } catch (e, stackTrace) {
      error('Error in _fetchAllRepos: $e');
      error(stackTrace.toString());
      return <Repository>[];
    }
  }

  Future<Map<String, Repository>> resolveManualRefs({
    required List<RepositoryRef> refs,
    required Map<String, Repository> existing,
    required Future<Repository?> Function(RepositoryRef ref) resolve,
    required Repository? Function(RepositoryRef ref) localFallback,
    int maxConcurrency = 4,
  }) async {
    List<Future<MapEntry<String, Repository>?> Function()> work =
        <Future<MapEntry<String, Repository>?> Function()>[];

    for (RepositoryRef ref in refs) {
      work.add(() async {
        String key = ref.fullName.toLowerCase();
        if (existing.containsKey(key)) {
          return null;
        }

        Repository? resolvedRepository = await resolve(ref);
        if (resolvedRepository != null) {
          return MapEntry<String, Repository>(key, resolvedRepository);
        }

        Repository? fallbackRepository = localFallback(ref);
        if (fallbackRepository != null) {
          return MapEntry<String, Repository>(key, fallbackRepository);
        }

        return null;
      });
    }

    List<MapEntry<String, Repository>?> resolvedEntries =
        await work.waitSemaphore<MapEntry<String, Repository>?>(maxConcurrency);
    List<MapEntry<String, Repository>> nonNullEntries =
        <MapEntry<String, Repository>>[];
    for (MapEntry<String, Repository>? entry in resolvedEntries) {
      if (entry == null) {
        continue;
      }
      nonNullEntries.add(entry);
    }

    nonNullEntries.sort(
      (MapEntry<String, Repository> a, MapEntry<String, Repository> b) =>
          a.key.compareTo(b.key),
    );

    Map<String, Repository> resolvedMap = <String, Repository>{};
    for (MapEntry<String, Repository> entry in nonNullEntries) {
      resolvedMap[entry.key] = entry.value;
    }

    return resolvedMap;
  }

  Future<Repository?> resolveRepositoryRef(RepositoryRef ref) async {
    RepositorySlug slug = RepositorySlug(ref.owner, ref.name);
    try {
      return await github.repositories.getRepository(slug);
    } catch (_) {}

    GitHub anonymousGitHub = GitHub();
    try {
      return await anonymousGitHub.repositories.getRepository(slug);
    } catch (_) {
      return null;
    } finally {
      anonymousGitHub.dispose();
    }
  }

  Repository? localFallbackRepository(RepositoryRef ref) {
    String path =
        expandPath('${config.workspaceDirectory}/${ref.owner}/${ref.name}');
    if (!Directory('$path/.git').existsSync()) {
      return null;
    }
    return Repository.fromJson(<String, dynamic>{
      'id': ref.fullName.toLowerCase().hashCode.abs(),
      'name': ref.name,
      'full_name': ref.fullName,
      'owner': <String, dynamic>{
        'login': ref.owner,
        'id': ref.owner.toLowerCase().hashCode.abs(),
        'avatar_url': 'https://github.com/${ref.owner}.png',
        'html_url': 'https://github.com/${ref.owner}',
      },
      'private': false,
    });
  }

  Stream<Repository> listRepositoriesAggressive({
    String type = 'all',
    String sort = 'full_name',
    String direction = 'asc',
  }) {
    Map<String, dynamic> params = <String, dynamic>{
      'type': type,
      'sort': sort,
      'direction': direction,
      'per_page': 100,
    };

    return PaginationHelper(github).objects<Map<String, dynamic>, Repository>(
      'GET',
      '/user/repos',
      Repository.fromJson,
      params: params,
    );
  }

  Future<void> executeBulkOperation(
    Iterable<Repository> repositories,
    Future<void> Function(ArcaneRepository repository) operation,
  ) async {
    progress.add(0);
    await repositories
        .map(
          (Repository repository) => () => operation(repositoryFor(repository)),
        )
        .waitSemaphore<void>(
          4,
          progress: (double value) => progress.add(value),
        );
    progress.add(null);
    await refreshActiveRepositories();
  }

  Future<bool> consumeClassicTokenMigrationPrompt() async {
    if (_classicMigrationPromptConsumed) {
      return false;
    }
    _classicMigrationPromptConsumed = true;

    bool isAuthenticated = box.get('authenticated', defaultValue: false);
    if (!isAuthenticated) {
      return false;
    }

    String token = box.get('1', defaultValue: '').toString().trim();
    if (token.isEmpty) {
      return false;
    }

    String tokenType =
        box.get('token_type', defaultValue: 'unknown').toString();
    if (tokenType == 'unknown') {
      tokenType = detectTokenType(token);
      await box.put('token_type', tokenType);
    }

    return tokenType == 'classic';
  }

  String detectTokenType(String token) {
    if (token.startsWith('github_pat_')) {
      return 'fine_grained';
    }
    if (token.startsWith('ghp_')) {
      return 'personal';
    }
    return 'classic';
  }
}
