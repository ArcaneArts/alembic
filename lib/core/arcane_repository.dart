import 'dart:io';
import 'dart:math';

import 'package:alembic/main.dart';
import 'package:alembic/screen/home.dart';
import 'package:alembic/screen/settings.dart';
import 'package:alembic/util/extensions.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:alembic/widget/repository_tile.dart';
import 'package:arcane/arcane.dart';
import 'package:fast_log/fast_log.dart';
import 'package:github/github.dart';

enum RepoState { active, archived, cloud }
final BehaviorSubject<List<(Repository, String)>> repoWork = BehaviorSubject.seeded([]);
class ArcaneRepository {
  final Repository repository;
  bool? _specific;

  ArcaneRepository({required this.repository});
  // ======== PATH PROPERTIES ========
  /// Path to the repository on the local filesystem
  String get repoPath => expandPath(
      "${config.workspaceDirectory}/${repository.owner?.login}/${repository.name}");
  /// Path to the repository archive zip file
  String get imagePath => expandPath(
      "${config.archiveDirectory}/archives/${repository.owner?.login ?? 'unknown'}/${repository.name}.zip");
  /// GitHub clone URL with authentication token
  String get authenticatedCloneUrl {
    final String token = box.get("1");
    return "https://$token@github.com/${repository.owner?.login}/${repository.name}.git";
  }

  // ======== STATE CHECKING ========
  /// Determines if the repository name should be displayed with owner prefix
  bool shouldBeSpecific() {
    _specific ??= active.where((i) => i.name == repository.name).length > 1;
    return _specific!;
  }

  /// Checks if repository is active (exists on local filesystem)
  Future<bool> get isActive => Directory("$repoPath/.git").exists();
  /// Synchronously checks if repository is active
  bool get isActiveSync => Directory("$repoPath/.git").existsSync();
  /// Checks if repository is archived (exists as zip archive)
  Future<bool> get isArchived => File(imagePath).exists();
  /// Synchronously checks if repository is archived
  bool get isArchivedSync => File(imagePath).existsSync();
  /// Gets the current state of the repository
  Future<RepoState> get state => Future.wait([isActive, isArchived])
      .then((List<bool> statuses) {
    final bool isActiveStatus = statuses[0];
    final bool isArchivedStatus = statuses[1];

    if (isActiveStatus) return RepoState.active;
    if (isArchivedStatus) return RepoState.archived;
    return RepoState.cloud;
  });
  /// Checks if an active repository is stale (inactive for too long)
  Future<bool> get isStaleActive async {
    if (!await isActive) return false;
    final int? lastOpen = getRepoConfig(repository).lastOpen;
    if (lastOpen == null) return false;
    final int? latestModification = await getLatestFileModificationTime();
    final int lastActivityTime = max(lastOpen, latestModification ?? 0);
    final int inactiveTime = DateTime.timestamp().millisecondsSinceEpoch - lastActivityTime;
    final int staleThreshold = Duration(days: config.daysToArchive).inMilliseconds;
    return inactiveTime > staleThreshold;
  }

  /// Calculates days remaining until repository will be automatically archived
  Future<int> get daysUntilArchival async {
    if (!await isActive) return 0;
    final int? lastOpen = getRepoConfig(repository).lastOpen;
    if (lastOpen == null) return config.daysToArchive;
    final int? latestModification = await getLatestFileModificationTime();
    final int lastActivityTime = max(lastOpen, latestModification ?? 0);
    final int daysElapsed = Duration(
        milliseconds: DateTime.timestamp().millisecondsSinceEpoch - lastActivityTime
    ).inDays;
    final int daysRemaining = config.daysToArchive - daysElapsed;
    return max(0, daysRemaining);
  }

  // ======== FILE OPERATIONS ========
  /// Gets the latest modification time of any file in the repository
  Future<int?> getLatestFileModificationTime() async {
    if (!await isActive) return null;
    int? latestTime;
    try {
      await for (FileSystemEntity entity in Directory(repoPath).list(
        recursive: true,
        followLinks: false,
      )) {
        // Skip .git directory for performance
        if (entity.path.contains('/.git/')) continue;
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
  /// Gets repository size in kilobytes
  Future<int> get sizeKB async {
    final BehaviorSubject<String> stdout = BehaviorSubject<String>();
    int? kb;
    stdout.listen((String e) => kb ??= int.tryParse(e.split("\t").first));
    await cmd('du', ['-sk', repoPath], stdout: stdout);
    return kb ?? -1;
  }

  // ======== WORK TRACKING ========
  /// Tracks work being done on this repository
  Future<T> doWork<T>(String message, Future<T> Function() workFn) async {
    final (Repository, String) job = (repository, message);
    // Add job to global work tracking
    repoWork.add([...repoWork.value, job]);
    T result;
    try {
      result = await workFn();
    } finally {
      // Remove job from tracking regardless of success/failure
      repoWork.add([
        ...repoWork.value.where((i) => i != job),
      ]);
    }
    return result;
  }

  /// Get stream of current work happening on this repository
  Stream<List<String>> streamWork() => repoWork.stream
      .map((List<(Repository, String)> work) =>
      work.where((item) => item.$1 == repository)
          .map((item) => item.$2)
          .toList());
  // ======== REPOSITORY OPERATIONS ========
  /// Checks and updates the git remote URL with a new token if needed
  Future<bool> checkAndUpdateToken(String latestToken) async {
    if (!await isActive) return false;
    try {
      final Directory gitDir = Directory("$repoPath/.git");
      if (!await gitDir.exists()) return false;
      // Get current remote URL
      final BehaviorSubject<String> stdout = BehaviorSubject<String>();
      await cmd(
          'git',
          ['-C', repoPath, 'config', '--get', 'remote.origin.url'],
          stdout: stdout
      );
      final String? currentUrl = stdout.valueOrNull;
      if (currentUrl == null || currentUrl.isEmpty) return false;
      // Check if URL contains a token
      if (currentUrl.contains("@github.com")) {
        final RegExp tokenRegex = RegExp(r'https://([^@]+)@github\.com');
        final match = tokenRegex.firstMatch(currentUrl);
        if (match != null && match.group(1) != latestToken) {
          // Update the token in the remote URL
          info("Updating token for repository ${repository.fullName}");
          final String updatedUrl = "https://$latestToken@github.com/${repository.owner?.login}/${repository.name}.git";
          final int exitCode = await cmd(
              'git',
              ['-C', repoPath, 'remote', 'set-url', 'origin', updatedUrl]
          );
          return exitCode == 0;
        }
      }
      return false; // No update needed
    } catch (e) {
      error("Error checking token for ${repository.fullName}: $e");
      return false;
    }
  }
  /// Ensure repository is cloned and available locally
  Future<void> ensureRepositoryActive(GitHub github, {bool updateActive = true}) =>
      doWork("Activating", () async {
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
        update.add(update.value + 1);
      });
  /// Clone repository from GitHub
  Future<void> _cloneRepository(bool updateActive) => doWork("Cloning", () async {
    syncingRepositories.add([...syncingRepositories.value, repository]);
    try {
      await Directory(repoPath).create(recursive: true);
      final String cloneUrl = authenticatedCloneUrl;
      info("Cloning ${repository.fullName} from $cloneUrl");
      if (await cmd('git', ['clone', cloneUrl, repoPath]) != 0) {
        throw Exception('Git clone failed!');
      }
      success("Cloned ${repository.fullName}");
      if (updateActive) {
        active.add(repository);
      }
      setRepoConfig(
          repository,
          getRepoConfig(repository)
            ..lastOpen = DateTime.timestamp().millisecondsSinceEpoch
      );
    } catch (e) {
      error("Clone failed: $e");
      rethrow;
    } finally {
      syncingRepositories.add(
          syncingRepositories.value
              .where((i) => i.fullName != repository.fullName)
              .toList()
      );
    }
  });
  /// Pull latest changes from GitHub
  Future<void> ensureRepositoryUpdated(GitHub github) =>
      doWork("Pulling", () async {
        info("Pulling ${repository.fullName}");
        if (await cmd('git', ['-C', repoPath, 'pull']) != 0) {
          throw Exception('Git pull failed!');
        }
        success("Pulled ${repository.fullName}");
        update.add(update.value + 1);
      });
  /// Open repository in IDE and Git client
  Future<void> open(GitHub github, BuildContext context) =>
      doWork("Opening", () async {
        await ensureRepositoryActive(github);
        // Open in IDE
        final ApplicationTool tool = getRepoConfig(repository).editorTool ??
            config.editorTool ??
            ApplicationTool.intellij;        info("Opening ${repository.fullName} with IDE ${tool.displayName}");
        tool.launch("$repoPath/${getRepoConfig(repository).openDirectory}".replaceAll("//", "/"));
        // Open in Git client
        final GitTool gitTool = getRepoConfig(repository).gitTool ??
            config.gitTool ??
            GitTool.gitkraken;
        info("Opening ${repository.fullName} with Git Client ${gitTool.displayName}");
        gitTool.launch(repoPath);
        // Run Flutter pub get in all dart packages
        ensureRepositoryUpdated(github);
        runAutoMacros();
        // Update last open timestamp
        setRepoConfig(
            repository,
            getRepoConfig(repository)
              ..lastOpen = DateTime.timestamp().millisecondsSinceEpoch
        );
      });
  /// Open repository folder in Finder
  Future<void> openInFinder() => cmd('open', [Directory(repoPath).absolute.path]);
  // ======== ARCHIVE OPERATIONS ========
  /// Create zip archive of repository
  Future<void> archive() => doWork("Archiving", () async {
    if (await isArchived) return;
    if (!await isActive) return;
    // Create parent directory if it doesn't exist
    File(imagePath).absolute.parent.createSync(recursive: true);
    // Create zip archive
    final int exitCode = await cmd(
        'zip',
        ['-r', imagePath, '.'],
        workingDirectory: repoPath
    );
    if (exitCode != 0) {
      throw Exception('Failed to create zip archive at $imagePath');
    }
    success("Archived repository at $repoPath to $imagePath");
    // Clean up after archiving
    await deleteRepository();
    active.remove(repository);
    update.add(update.value + 1);
  });
  /// Extract repository from archive
  Future<void> unarchive(
      GitHub github,
      {bool waitForPull = false, bool notifyActive = true}
      ) => doWork("Extracting", () async {
    if (!await isArchived) return;
    if (await isActive) return;
    await Directory(repoPath).create(recursive: true);
    final int exitCode = await cmd('unzip', [imagePath, '-d', repoPath]);
    if (exitCode != 0) {
      throw Exception('Failed to unzip archive at $imagePath');
    }
    await File(imagePath).delete();
    success("Unarchived repository to $repoPath from $imagePath");
    if (notifyActive) {
      active.add(repository);
      update.add(update.value + 1);
    }
    setRepoConfig(
        repository,
        getRepoConfig(repository)
          ..lastOpen = DateTime.timestamp().millisecondsSinceEpoch
    );
    final Future<void> pull = ensureRepositoryUpdated(github);
    if (waitForPull) {
      await pull;
    }
  });
  /// Archive repository from cloud without activating it first
  Future<void> archiveFromCloud(GitHub github) => doWork("Archiving", () async {
    if (await isArchived) return;
    if (await isActive) return;

    await ensureRepositoryActive(github, updateActive: false);
    await archive();
  });
  /// Update an archived repository by activating it, pulling, and re-archiving
  Future<void> updateArchive(GitHub github) => doWork("Updating", () async {
    if (!await isArchived) return;

    await unarchive(github, waitForPull: true, notifyActive: false);
    await archive();
  });
  /// Delete repository from local filesystem
  Future<void> deleteRepository() => doWork("Deleting", () async {
    final int exitCode = await cmd('rm', ['-rf', repoPath]);
    if (exitCode != 0) {
      throw Exception('Failed to delete repository at $repoPath');
    }
    info("Deleted repository at $repoPath");
    active.remove(repository);
    update.add(update.value + 1);
  });
  /// Delete repository archive
  Future<void> deleteArchive() => doWork("Deleting Archive", () async {
    if (!await isArchived) return;
    await File(imagePath).delete();
    info("Deleted archive at $imagePath");
  });
  // ======== DEPENDENCY MANAGEMENT ========
  /// Find all Dart packages in the repository
  Stream<String> findDartPackages(String path) async* {
    if (await File("$path/pubspec.yaml").exists()) {
      yield path;
    }
    for (FileSystemEntity entity in Directory(path).listSync(followLinks: false)) {
      if (entity is Directory) {
        if (entity.path.endsWith(".plugin_symlinks")) continue;
        yield* findDartPackages(entity.path);
      }
    }
  }
  /// Run Flutter pub get in all Dart packages
  Future<void> runAutoMacros() async {
    final List<String> packagePaths = [
      ...await findDartPackages(
          "$repoPath/${getRepoConfig(repository).openDirectory}".replaceAll("//", "/")
      ).toList(),
      ...await findDartPackages(repoPath).toList()
    ];
    for (String path in packagePaths) {
      warn("Running pub get in $path");
      await cmd("flutter", ["pub", "get"], workingDirectory: path);
    }
  }
}