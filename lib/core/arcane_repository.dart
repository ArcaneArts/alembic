import 'dart:io';
import 'dart:math';

import 'package:alembic/core/repository_runtime.dart';
import 'package:alembic/main.dart';
import 'package:alembic/util/clone_transport.dart';
import 'package:alembic/util/extensions.dart';
import 'package:alembic/util/git_signing.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:fast_log/fast_log.dart';
import 'package:flutter/cupertino.dart';
import 'package:github/github.dart';
import 'package:rxdart/rxdart.dart';

enum RepoState { active, archived, cloud }

class ArcaneRepository {
  final Repository repository;
  final RepositoryRuntime runtime;
  final CommandRunner commandRunner;
  final GitSigningManager signingManager;
  bool? _specific;

  ArcaneRepository({
    required this.repository,
    required this.runtime,
    CommandRunner? commandRunner,
    GitSigningManager? signingManager,
  })  : commandRunner = commandRunner ?? cmd,
        signingManager = signingManager ??
            GitSigningManager(commandRunner: commandRunner ?? cmd);

  String get repoPath => expandPath(
      "${config.workspaceDirectory}/${repository.owner?.login}/${repository.name}");

  String get imagePath => expandPath(
      "${config.archiveDirectory}/archives/${repository.owner?.login ?? 'unknown'}/${repository.name}.zip");

  String get authenticatedCloneUrl {
    final String token = box.get("1");
    return "https://$token@github.com/${repository.owner?.login}/${repository.name}.git";
  }

  String get publicCloneUrl {
    return "https://github.com/${repository.owner?.login}/${repository.name}.git";
  }

  String get sshCloneUrl {
    return "git@github.com:${repository.owner?.login}/${repository.name}.git";
  }

  bool shouldBeSpecific() {
    _specific ??= runtime.activeRepositories
            .where((Repository i) => i.name == repository.name)
            .length >
        1;
    return _specific!;
  }

  Future<bool> get isActive => Directory("$repoPath/.git").exists();

  bool get isActiveSync => Directory("$repoPath/.git").existsSync();

  Future<bool> get isArchived => File(imagePath).exists();

  bool get isArchivedSync => File(imagePath).existsSync();

  Future<RepoState> get state =>
      Future.wait(<Future<bool>>[isActive, isArchived]).then((statuses) {
        final bool isActiveStatus = statuses[0];
        final bool isArchivedStatus = statuses[1];

        if (isActiveStatus) {
          return RepoState.active;
        }
        if (isArchivedStatus) {
          return RepoState.archived;
        }
        return RepoState.cloud;
      });

  Future<bool> get isStaleActive async {
    if (!await isActive) {
      return false;
    }
    final int? lastOpen = getRepoConfig(repository).lastOpen;
    if (lastOpen == null) {
      return false;
    }
    final int? latestModification = await getLatestFileModificationTime();
    final int lastActivityTime = max(lastOpen, latestModification ?? 0);
    final int inactiveTime =
        DateTime.timestamp().millisecondsSinceEpoch - lastActivityTime;
    final int staleThreshold =
        Duration(days: config.daysToArchive).inMilliseconds;
    return inactiveTime > staleThreshold;
  }

  Future<int> get daysUntilArchival async {
    if (!await isActive) {
      return 0;
    }
    final int? lastOpen = getRepoConfig(repository).lastOpen;
    if (lastOpen == null) {
      return config.daysToArchive;
    }
    final int? latestModification = await getLatestFileModificationTime();
    final int lastActivityTime = max(lastOpen, latestModification ?? 0);
    final int daysElapsed = Duration(
      milliseconds:
          DateTime.timestamp().millisecondsSinceEpoch - lastActivityTime,
    ).inDays;
    final int daysRemaining = config.daysToArchive - daysElapsed;
    return max(0, daysRemaining);
  }

  Future<int?> getLatestFileModificationTime() async {
    if (!await isActive) {
      return null;
    }

    int? latestTime;
    try {
      await for (FileSystemEntity entity in Directory(repoPath).list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity.path.contains('/.git/')) {
          continue;
        }
        if (entity is File) {
          final DateTime modTime = await entity.lastModified();
          final int modTimeMs = modTime.millisecondsSinceEpoch;
          if (latestTime == null || modTimeMs > latestTime) {
            latestTime = modTimeMs;
          }
        }
      }
    } catch (e) {
      error("Error scanning repository files: $e");
    }
    return latestTime;
  }

  Future<T> doWork<T>(String message, Future<T> Function() workFn) async {
    (Repository, String) job = runtime.beginWork(repository, message);
    try {
      return await workFn();
    } finally {
      runtime.endWork(job);
    }
  }

  Stream<List<String>> streamWork() {
    return runtime.streamWork(repository);
  }

  Future<bool> checkAndUpdateToken(String latestToken) async {
    if (!await isActive) {
      return false;
    }

    try {
      final Directory gitDir = Directory("$repoPath/.git");
      if (!await gitDir.exists()) {
        return false;
      }

      final BehaviorSubject<String> stdout = BehaviorSubject<String>();
      final BehaviorSubject<String> stderr = BehaviorSubject<String>();
      await commandRunner(
        'git',
        <String>['-C', repoPath, 'config', '--get', 'remote.origin.url'],
        stdout: stdout,
        stderr: stderr,
        redactOutput: false,
      );
      final String? currentUrl = stdout.valueOrNull;
      await stdout.close();
      await stderr.close();
      if (currentUrl == null || currentUrl.isEmpty) {
        return false;
      }

      if (currentUrl.contains("@github.com")) {
        final RegExp tokenRegex = RegExp(r'https://([^@]+)@github\.com');
        final RegExpMatch? match = tokenRegex.firstMatch(currentUrl);
        if (match != null && match.group(1) != latestToken) {
          info("Updating token for repository ${repository.fullName}");
          final String updatedUrl =
              "https://$latestToken@github.com/${repository.owner?.login}/${repository.name}.git";
          final int exitCode = await commandRunner(
            'git',
            <String>['-C', repoPath, 'remote', 'set-url', 'origin', updatedUrl],
          );
          return exitCode == 0;
        }
      }

      return false;
    } catch (e) {
      error("Error checking token for ${repository.fullName}: $e");
      return false;
    }
  }

  Future<void> ensureRepositoryActive(
    GitHub github, {
    bool updateActive = true,
  }) {
    return doWork<void>("Activating", () async {
      final Directory repoDir = Directory(repoPath);
      if (!await repoDir.exists()) {
        if (await isArchived) {
          await unarchive(github, waitForPull: false, notifyActive: true);
        } else {
          await _cloneRepository(updateActive);
        }
      } else {
        info("Repository ${repository.fullName} already exists at $repoPath");
      }
      await _ensureSigningGuard();
      runtime.notifyChanged();
    });
  }

  Future<void> _cloneRepository(bool updateActive) {
    return doWork<void>("Cloning", () async {
      runtime.addSyncingRepository(repository);
      try {
        await Directory(repoPath).parent.create(recursive: true);
        final List<String> cloneCandidates = buildCloneCandidates();
        final List<String> failures = <String>[];
        bool cloned = false;
        for (final String cloneUrl in cloneCandidates) {
          final String candidateLabel = cloneUrl == publicCloneUrl
              ? 'public'
              : (cloneUrl == sshCloneUrl ? 'ssh' : 'authenticated');
          final Directory target = Directory(repoPath);
          if (await target.exists()) {
            await target.delete(recursive: true);
          }
          final BehaviorSubject<String> stdout = BehaviorSubject<String>();
          final BehaviorSubject<String> stderr = BehaviorSubject<String>();
          final int exitCode = await commandRunner(
            'git',
            <String>['clone', cloneUrl, repoPath],
            stdout: stdout,
            stderr: stderr,
          );
          final String failureContext = sanitizeSecrets(
            stderr.valueOrNull ?? stdout.valueOrNull ?? 'exit code $exitCode',
          );
          await stdout.close();
          await stderr.close();
          if (exitCode == 0) {
            cloned = true;
            break;
          }
          failures.add('$candidateLabel -> $failureContext');
        }
        if (!cloned) {
          throw Exception(
            'Git clone failed for ${repository.fullName}: ${failures.join(" | ")}',
          );
        }
        success("Cloned ${repository.fullName}");
        if (updateActive) {
          runtime.addActiveRepository(repository);
        }
        setRepoConfig(
          repository,
          getRepoConfig(repository)
            ..lastOpen = DateTime.timestamp().millisecondsSinceEpoch,
        );
      } catch (e) {
        error("Clone failed: $e");
        rethrow;
      } finally {
        runtime.removeSyncingRepository(repository);
      }
    });
  }

  List<String> buildCloneCandidates() {
    final List<String> candidates = <String>[];
    final CloneTransportMode cloneMode = loadCloneTransportMode();
    if (cloneMode == CloneTransportMode.sshPreferred) {
      candidates.add(sshCloneUrl);
    }
    final String token = box.get("1", defaultValue: "").toString().trim();
    if (token.isNotEmpty) {
      candidates.add(authenticatedCloneUrl);
    }
    candidates.add(publicCloneUrl);
    final Map<String, String> deduped = <String, String>{};
    for (final String candidate in candidates) {
      deduped[candidate] = candidate;
    }
    return deduped.values.toList();
  }

  Future<void> ensureRepositoryUpdated(GitHub github) {
    return doWork<void>("Pulling", () async {
      info("Pulling ${repository.fullName}");
      if (await commandRunner('git', <String>['-C', repoPath, 'pull']) != 0) {
        throw Exception('Git pull failed!');
      }
      success("Pulled ${repository.fullName}");
      runtime.notifyChanged();
    });
  }

  Future<void> open(GitHub github, BuildContext context) {
    return doWork<void>("Opening", () async {
      await ensureRepositoryActive(github);

      final ApplicationTool tool = getRepoConfig(repository).editorTool ??
          config.editorTool ??
          ApplicationTool.intellij;
      info("Opening ${repository.fullName} with IDE ${tool.displayName}");
      tool.launch(
        "$repoPath/${getRepoConfig(repository).openDirectory}"
            .replaceAll("//", "/"),
      );

      final GitTool gitTool = getRepoConfig(repository).gitTool ??
          config.gitTool ??
          GitTool.gitkraken;
      info(
          "Opening ${repository.fullName} with Git Client ${gitTool.displayName}");
      gitTool.launch(repoPath);

      await Future.wait<void>(<Future<void>>[
        ensureRepositoryUpdated(github),
        runAutoMacros(),
      ]);

      setRepoConfig(
        repository,
        getRepoConfig(repository)
          ..lastOpen = DateTime.timestamp().millisecondsSinceEpoch,
      );
    });
  }

  Future<void> openInFinder() => commandRunner(
        'open',
        <String>[Directory(repoPath).absolute.path],
      );

  Future<void> archive() {
    return doWork<void>("Archiving", () async {
      if (await isArchived || !await isActive) {
        return;
      }

      File(imagePath).absolute.parent.createSync(recursive: true);
      final int exitCode = await commandRunner(
        'zip',
        <String>['-r', imagePath, '.'],
        workingDirectory: repoPath,
      );
      if (exitCode != 0) {
        throw Exception('Failed to create zip archive at $imagePath');
      }

      success("Archived repository at $repoPath to $imagePath");
      await deleteRepository();
    });
  }

  Future<void> unarchive(
    GitHub github, {
    bool waitForPull = false,
    bool notifyActive = true,
  }) {
    return doWork<void>("Extracting", () async {
      if (!await isArchived || await isActive) {
        return;
      }

      await Directory(repoPath).create(recursive: true);
      final int exitCode =
          await commandRunner('unzip', <String>[imagePath, '-d', repoPath]);
      if (exitCode != 0) {
        throw Exception('Failed to unzip archive at $imagePath');
      }

      await File(imagePath).delete();
      success("Unarchived repository to $repoPath from $imagePath");
      if (notifyActive) {
        runtime.addActiveRepository(repository);
      }
      setRepoConfig(
        repository,
        getRepoConfig(repository)
          ..lastOpen = DateTime.timestamp().millisecondsSinceEpoch,
      );
      await _ensureSigningGuard();

      final Future<void> pull = ensureRepositoryUpdated(github);
      if (waitForPull) {
        await pull;
      }
    });
  }

  Future<void> archiveFromCloud(GitHub github) {
    return doWork<void>("Archiving", () async {
      if (await isArchived || await isActive) {
        return;
      }
      await ensureRepositoryActive(github, updateActive: false);
      await archive();
    });
  }

  Future<void> updateArchive(GitHub github) {
    return doWork<void>("Updating", () async {
      if (!await isArchived) {
        return;
      }
      await unarchive(github, waitForPull: true, notifyActive: false);
      await archive();
    });
  }

  Future<void> deleteRepository() {
    return doWork<void>("Deleting", () async {
      final int exitCode = await commandRunner('rm', <String>['-rf', repoPath]);
      if (exitCode != 0) {
        throw Exception('Failed to delete repository at $repoPath');
      }
      info("Deleted repository at $repoPath");
      runtime.removeActiveRepository(repository);
    });
  }

  Future<void> deleteArchive() {
    return doWork<void>("Deleting Archive", () async {
      if (!await isArchived) {
        return;
      }
      await File(imagePath).delete();
      info("Deleted archive at $imagePath");
      runtime.notifyChanged();
    });
  }

  Future<void> forkAndClone(GitHub github) {
    return doWork<void>("Forking", () async {
      final CurrentUser currentUser = await github.users.getCurrentUser();
      final String currentLogin = (currentUser.login ?? '').trim();
      if (currentLogin.isEmpty) {
        throw Exception('Unable to determine current user login');
      }

      final String sourceOwner = (repository.owner?.login ?? '').trim();
      if (sourceOwner.isEmpty) {
        throw Exception('Repository owner is unknown');
      }

      if (sourceOwner.toLowerCase() == currentLogin.toLowerCase()) {
        await ensureRepositoryActive(github);
        return;
      }

      final RepositorySlug sourceSlug =
          RepositorySlug(sourceOwner, repository.name);
      final RepositorySlug forkSlug =
          RepositorySlug(currentLogin, repository.name);

      Repository forkRepository;
      try {
        forkRepository = await github.repositories.getRepository(forkSlug);
      } catch (_) {
        await github.repositories.createFork(sourceSlug);
        forkRepository = await _waitForFork(github, forkSlug);
      }

      final ArcaneRepository forkArcane = ArcaneRepository(
        repository: forkRepository,
        runtime: runtime,
        commandRunner: commandRunner,
        signingManager: signingManager,
      );
      await forkArcane.ensureRepositoryActive(github);

      final int removeExitCode = await commandRunner(
        'git',
        <String>['-C', forkArcane.repoPath, 'remote', 'remove', 'upstream'],
      );
      if (removeExitCode != 0) {
        final int setExitCode = await commandRunner(
          'git',
          <String>[
            '-C',
            forkArcane.repoPath,
            'remote',
            'set-url',
            'upstream',
            publicCloneUrl,
          ],
        );
        if (setExitCode != 0) {
          final int addExitCode = await commandRunner(
            'git',
            <String>[
              '-C',
              forkArcane.repoPath,
              'remote',
              'add',
              'upstream',
              publicCloneUrl,
            ],
          );
          if (addExitCode != 0) {
            throw Exception('Unable to configure upstream remote');
          }
        }
      } else {
        final int addExitCode = await commandRunner(
          'git',
          <String>[
            '-C',
            forkArcane.repoPath,
            'remote',
            'add',
            'upstream',
            publicCloneUrl,
          ],
        );
        if (addExitCode != 0) {
          final int setExitCode = await commandRunner(
            'git',
            <String>[
              '-C',
              forkArcane.repoPath,
              'remote',
              'set-url',
              'upstream',
              publicCloneUrl,
            ],
          );
          if (setExitCode != 0) {
            throw Exception('Unable to configure upstream remote');
          }
        }
      }

      runtime.notifyChanged();
    });
  }

  Future<Repository> _waitForFork(GitHub github, RepositorySlug slug) async {
    const int maxAttempts = 15;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await github.repositories.getRepository(slug);
      } catch (_) {}
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    throw Exception('Timed out waiting for fork ${slug.fullName}');
  }

  Future<void> _ensureSigningGuard() async {
    try {
      await signingManager.ensureRepoSigningGuard(repoPath);
    } catch (e) {
      warn("Signing guard failed for ${repository.fullName}: $e");
    }
  }

  Stream<String> findDartPackages(String path) async* {
    if (await File("$path/pubspec.yaml").exists()) {
      yield path;
    }
    for (FileSystemEntity entity
        in Directory(path).listSync(followLinks: false)) {
      if (entity is Directory) {
        if (entity.path.endsWith(".plugin_symlinks")) {
          continue;
        }
        yield* findDartPackages(entity.path);
      }
    }
  }

  Future<void> runAutoMacros() async {
    final List<String> packagePaths = <String>[
      ...await findDartPackages(
        "$repoPath/${getRepoConfig(repository).openDirectory}"
            .replaceAll("//", "/"),
      ).toList(),
      ...await findDartPackages(repoPath).toList(),
    ];
    for (String path in packagePaths) {
      warn("Running pub get in $path");
      await commandRunner(
        "flutter",
        <String>["pub", "get"],
        workingDirectory: path,
      );
    }
  }
}
