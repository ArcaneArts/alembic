import 'dart:async';
import 'dart:io';

import 'package:alembic/core/account_registry.dart';
import 'package:alembic/core/arcane_repository.dart';
import 'package:alembic/core/repository_runtime.dart';
import 'package:alembic/main.dart';
import 'package:alembic/presentation/home_view_state.dart';
import 'package:alembic/util/archive_master.dart';
import 'package:alembic/util/environment.dart';
import 'package:alembic/util/extensions.dart';
import 'package:alembic/util/git_accounts.dart';
import 'package:alembic/util/repository_catalog.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:alembic/util/semaphore.dart';
import 'package:fast_log/fast_log.dart';
import 'package:github/github.dart';
import 'package:rxdart/rxdart.dart';

class HomeController {
  final AccountRegistry registry;
  final RepositoryRuntime runtime;
  final Map<Organization, List<Repository>> orgRepos =
      <Organization, List<Repository>>{};
  final List<Repository> personalRepos = <Repository>[];
  final Map<String, String> _accountByFullName = <String, String>{};
  final Set<String> _personalLoginsLower = <String>{};
  final BehaviorSubject<int> fetching = BehaviorSubject<int>.seeded(0);
  final BehaviorSubject<double?> progress =
      BehaviorSubject<double?>.seeded(null);
  final BehaviorSubject<String?> progressLabel =
      BehaviorSubject<String?>.seeded(null);

  Future<List<Repository>> allRepos = Future<List<Repository>>.value(
    <Repository>[],
  );

  Timer? _staleCheckTimer;
  bool _staleCheckRunning = false;
  bool _classicMigrationPromptConsumed = false;

  HomeController({
    required this.registry,
    required this.runtime,
  });

  GitHub get primaryGitHub => registry.primaryGitHub ?? GitHub();

  String? accountIdForRepository(Repository repository) {
    final String key = repository.fullName.toLowerCase();
    final String? cached = _accountByFullName[key];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final String? configId = getRepoConfig(repository).accountId;
    if (configId != null && configId.isNotEmpty) {
      _accountByFullName[key] = configId;
      return configId;
    }
    return registry.primaryAccountId;
  }

  GitAccount? accountForRepository(Repository repository) {
    final String? id = accountIdForRepository(repository);
    if (id == null) {
      return null;
    }
    return registry.accountById(id);
  }

  GitHub githubForRepository(Repository repository) {
    final String? id = accountIdForRepository(repository);
    final GitHub? specific = id == null ? null : registry.githubForAccount(id);
    return specific ?? primaryGitHub;
  }

  ArcaneRepository repositoryFor(Repository repository) {
    return ArcaneRepository(
      repository: repository,
      runtime: runtime,
      accountId: accountIdForRepository(repository),
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
    await progressLabel.close();
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
    final List<GitAccount> accounts = registry.accounts;
    if (accounts.isEmpty) {
      return 0;
    }

    progressLabel.add('Checking repository tokens');
    progress.add(0.0);

    List<Repository> repositories = await allRepos;
    int total = repositories.length;
    int current = 0;
    int updated = 0;

    for (Repository repo in repositories) {
      ArcaneRepository repository = repositoryFor(repo);
      if (await repository.isActive) {
        final String latestToken = repository.resolvedToken;
        if (latestToken.isNotEmpty) {
          bool wasUpdated = await repository.checkAndUpdateToken(latestToken);
          if (wasUpdated) {
            updated++;
            success('Updated token for ${repo.fullName}');
          }
        }
      }
      current++;
      progress.add(total == 0 ? null : current / total);
    }

    progress.add(null);
    progressLabel.add(null);
    return updated;
  }

  Future<List<Repository>> _fetchAllRepos() async {
    if (alembicIsFlutterTestEnvironment()) {
      personalRepos.clear();
      orgRepos.clear();
      _accountByFullName.clear();
      _personalLoginsLower.clear();
      fetching.add(0);
      return <Repository>[];
    }

    personalRepos.clear();
    orgRepos.clear();
    _accountByFullName.clear();
    _personalLoginsLower.clear();
    fetching.add(0);

    Map<String, Repository> mergedRepositories = <String, Repository>{};

    try {
      final List<AccountClient> clients = registry.clients;
      if (clients.isEmpty) {
        return <Repository>[];
      }

      for (AccountClient client in clients) {
        try {
          final CurrentUser currentUser =
              await client.github.users.getCurrentUser();
          final String login = (currentUser.login ?? '').toLowerCase();
          if (login.isNotEmpty) {
            _personalLoginsLower.add(login);
          }
          if (client.account.id == registry.primaryAccountId &&
              login.isNotEmpty) {
            await boxSettings.put('current_user_login', login);
          }
        } catch (_) {
          if (client.account.login != null &&
              client.account.login!.trim().isNotEmpty) {
            _personalLoginsLower.add(client.account.login!.toLowerCase());
          }
        }
      }
      if (_personalLoginsLower.isEmpty) {
        final String stored =
            (boxSettings.get('current_user_login', defaultValue: '') as String)
                .trim()
                .toLowerCase();
        if (stored.isNotEmpty) {
          _personalLoginsLower.add(stored);
        }
      }

      for (AccountClient client in clients) {
        try {
          List<Repository> fetchedRepositories =
              await listRepositoriesAggressive(
            client.github,
            type: 'all',
          ).toList();
          for (Repository repository in fetchedRepositories) {
            String key = repository.fullName.toLowerCase();
            if (mergedRepositories.containsKey(key)) {
              continue;
            }
            mergedRepositories[key] = repository;
            _accountByFullName[key] = client.account.id;
            try {
              final AlembicRepoConfig repoConfig = getRepoConfig(repository);
              if (repoConfig.accountId != client.account.id) {
                repoConfig.accountId = client.account.id;
                setRepoConfig(repository, repoConfig);
              }
            } catch (_) {}
          }
        } catch (e) {
          error(
            'Failed fetching repos for account ${client.account.name}: $e',
          );
        }
      }

      List<RepositoryRef> workspaceRefs = scanWorkspaceRepositoryRefs();
      List<RepositoryRef> unresolvedWorkspaceRefs = <RepositoryRef>[];
      for (RepositoryRef ref in workspaceRefs) {
        String key = ref.fullName.toLowerCase();
        if (!mergedRepositories.containsKey(key)) {
          unresolvedWorkspaceRefs.add(ref);
        }
      }

      if (unresolvedWorkspaceRefs.isNotEmpty) {
        Map<String, Repository> workspaceResolved = await resolveManualRefs(
          refs: unresolvedWorkspaceRefs,
          existing: mergedRepositories,
          maxConcurrency: 4,
          resolve: resolveRepositoryRef,
          localFallback: localFallbackRepository,
        );
        mergedRepositories.addAll(workspaceResolved);
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
        bool isPersonal =
            _personalLoginsLower.contains(ownerLogin.toLowerCase());

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

  List<RepositoryRef> scanWorkspaceRepositoryRefs() {
    String workspacePath = expandPath(config.workspaceDirectory);
    Directory workspaceDirectory = Directory(workspacePath);
    if (!workspaceDirectory.existsSync()) {
      return <RepositoryRef>[];
    }

    Map<String, RepositoryRef> refsByName = <String, RepositoryRef>{};
    List<FileSystemEntity> ownerDirectories;
    try {
      ownerDirectories = workspaceDirectory.listSync(followLinks: false);
    } catch (_) {
      return <RepositoryRef>[];
    }

    for (FileSystemEntity ownerEntity in ownerDirectories) {
      if (ownerEntity is! Directory) {
        continue;
      }

      String ownerFolderName = _lastPathSegment(ownerEntity.path);
      if (ownerFolderName.startsWith('.')) {
        continue;
      }

      List<FileSystemEntity> repositoryDirectories;
      try {
        repositoryDirectories = ownerEntity.listSync(followLinks: false);
      } catch (_) {
        continue;
      }

      for (FileSystemEntity repositoryEntity in repositoryDirectories) {
        if (repositoryEntity is! Directory) {
          continue;
        }

        Directory gitDirectory = Directory('${repositoryEntity.path}/.git');
        if (!gitDirectory.existsSync()) {
          continue;
        }

        String repositoryFolderName = _lastPathSegment(repositoryEntity.path);
        RepositoryRef? ref = _repositoryRefFromLocalDirectory(
          repositoryEntity,
          fallbackOwner: ownerFolderName,
          fallbackName: repositoryFolderName,
        );
        if (ref == null) {
          continue;
        }

        refsByName[ref.fullName.toLowerCase()] = ref;
      }
    }

    List<RepositoryRef> refs = refsByName.values.toList();
    refs.sort(
      (RepositoryRef a, RepositoryRef b) =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
    return refs;
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
    for (AccountClient client in registry.clients) {
      try {
        return await client.github.repositories.getRepository(slug);
      } catch (_) {}
    }

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

  RepositoryRef? _repositoryRefFromLocalDirectory(
    Directory directory, {
    required String fallbackOwner,
    required String fallbackName,
  }) {
    File gitConfig = File('${directory.path}/.git/config');
    if (gitConfig.existsSync()) {
      try {
        String contents = gitConfig.readAsStringSync();
        RegExp urlPattern = RegExp(r'^\s*url\s*=\s*(.+)\s*$', multiLine: true);
        for (RegExpMatch match in urlPattern.allMatches(contents)) {
          String? rawUrl = match.group(1);
          if (rawUrl == null) {
            continue;
          }
          RepositoryRef? ref = parseRepositoryRef(rawUrl);
          if (ref != null) {
            return ref;
          }
        }
      } catch (_) {}
    }

    return RepositoryRef(owner: fallbackOwner, name: fallbackName);
  }

  String _lastPathSegment(String path) {
    Uri uri = Uri.file(path);
    List<String> segments =
        uri.pathSegments.where((String segment) => segment.isNotEmpty).toList();
    if (segments.isEmpty) {
      return path;
    }
    return segments.last;
  }

  Stream<Repository> listRepositoriesAggressive(
    GitHub github, {
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
    Future<void> Function(ArcaneRepository repository) operation, {
    String label = 'Working repositories',
  }) async {
    progressLabel.add(label);
    progress.add(0);
    try {
      await repositories
          .map(
            (Repository repository) =>
                () => operation(repositoryFor(repository)),
          )
          .waitSemaphore<void>(
            4,
            progress: (double value) => progress.add(value),
          );
      await refreshActiveRepositories();
    } finally {
      progress.add(null);
      progressLabel.add(null);
    }
  }

  Future<bool> consumeClassicTokenMigrationPrompt() async {
    if (_classicMigrationPromptConsumed) {
      return false;
    }
    _classicMigrationPromptConsumed = true;

    bool isAuthenticated =
        box.get(gitAccountsLegacyAuthFlag, defaultValue: false);
    if (!isAuthenticated) {
      return false;
    }

    String token =
        box.get(gitAccountsLegacyTokenKey, defaultValue: '').toString().trim();
    if (token.isEmpty) {
      return false;
    }

    String tokenType =
        box.get(gitAccountsLegacyTypeKey, defaultValue: 'unknown').toString();
    if (tokenType == 'unknown') {
      tokenType = detectTokenType(token);
      await box.put(gitAccountsLegacyTypeKey, tokenType);
    }

    return tokenType == 'classic';
  }

  List<Repository> repositoriesForSelection({
    required HomeSelectionState selection,
    required String? query,
    required List<Repository> all,
  }) =>
      switch (selection.tab) {
        HomeTab.active => sortedProjects(all, query),
        HomeTab.personal => sortedPersonal(query),
        HomeTab.organizations =>
          organizationRepositoriesFor(selection.organizationFilter, query),
        HomeTab.archiveMaster => archiveMasterRepositories(all, query),
      };

  List<Repository> sortedProjects(
    List<Repository> allRepositories,
    String? query,
  ) {
    List<Repository> repositories = allRepositories
        .where(
          (Repository repo) => repositoryFor(repo).isActiveSync,
        )
        .toList()
        .filterBy(query);
    repositories.sort((Repository a, Repository b) {
      int lastOpenComparison = (getRepoConfig(b).lastOpen ?? 0)
          .compareTo(getRepoConfig(a).lastOpen ?? 0);
      if (lastOpenComparison != 0) {
        return lastOpenComparison;
      }
      return a.fullName.compareTo(b.fullName);
    });
    return repositories;
  }

  List<Repository> sortedPersonal(String? query) {
    List<Repository> repositories = <Repository>[
      ...personalRepos.filterBy(query),
    ];
    repositories.sort(
      (Repository a, Repository b) => a.fullName.compareTo(b.fullName),
    );
    return repositories;
  }

  List<Repository> organizationRepositoriesFor(
    OrganizationFilter filter,
    String? query,
  ) {
    if (filter.isAll) {
      List<Organization> organizations = orgRepos.keys.toList()
        ..sort((Organization a, Organization b) {
          return (a.login ?? '').compareTo(b.login ?? '');
        });
      List<Repository> repositories = <Repository>[];
      for (Organization organization in organizations) {
        repositories.addAll(orgRepos[organization]!.filterBy(query));
      }
      return repositories;
    }

    String? selectedLogin = filter.organizationLogin;
    if (selectedLogin == null) {
      return <Repository>[];
    }

    for (Organization organization in orgRepos.keys) {
      String login = organization.login ?? '';
      if (login == selectedLogin) {
        return orgRepos[organization]!.filterBy(query);
      }
    }

    return <Repository>[];
  }

  List<Repository> archiveMasterRepositories(
    List<Repository> allRepositories,
    String? query,
  ) {
    List<ArchiveMasterTarget> targets = loadArchiveMasterTargets();
    Set<String> directRepoKeys = <String>{};
    Set<String> orgOwners = <String>{};
    for (ArchiveMasterTarget target in targets) {
      if (target.kind == ArchiveMasterTargetKind.organization) {
        orgOwners.add(target.owner.toLowerCase());
        continue;
      }
      directRepoKeys.add(
        '${target.owner.toLowerCase()}/${(target.repository ?? '').toLowerCase()}',
      );
    }
    List<Repository> repositories = <Repository>[];
    for (Repository repo in allRepositories) {
      String key = repo.fullName.toLowerCase();
      String owner = (repo.owner?.login ?? '').toLowerCase();
      if (directRepoKeys.contains(key) || orgOwners.contains(owner)) {
        repositories.add(repo);
      }
    }
    List<Repository> filtered = repositories.filterBy(query);
    filtered.sort(
      (Repository a, Repository b) => a.fullName.compareTo(b.fullName),
    );
    return filtered;
  }

  List<String> organizationLogins() {
    List<String> logins = <String>[];
    for (Organization organization in orgRepos.keys) {
      String login = organization.login ?? 'unknown';
      logins.add(login);
    }
    logins.sort();
    return logins;
  }

  bool canForkRepository(Repository repository) {
    GitAccount? account = accountForRepository(repository);
    String accountLogin = (account?.login ?? '').trim().toLowerCase();
    String fallbackLogin =
        (boxSettings.get('current_user_login', defaultValue: '') as String)
            .trim()
            .toLowerCase();
    String currentLogin =
        accountLogin.isNotEmpty ? accountLogin : fallbackLogin;
    String ownerLogin = (repository.owner?.login ?? '').trim().toLowerCase();
    return ownerLogin.isNotEmpty &&
        currentLogin.isNotEmpty &&
        ownerLogin != currentLogin;
  }
}
