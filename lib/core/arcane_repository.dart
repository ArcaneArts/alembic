import 'dart:io';
import 'dart:math';

import 'package:alembic/main.dart';
import 'package:alembic/screen/home.dart';
import 'package:alembic/screen/settings.dart';
import 'package:alembic/widget/repository_tile.dart';
import 'package:arcane/arcane.dart';
import 'package:fast_log/fast_log.dart';
import 'package:github/github.dart';

enum RepoState { active, archived, cloud }

BehaviorSubject<List<(Repository, String)>> repoWork =
    BehaviorSubject.seeded([]);

class ArcaneRepository {
  final Repository repository;
  bool? _specific;

  ArcaneRepository({required this.repository});

  bool shouldBeSpecific() {
    _specific ??= active.where((i) => i.name == repository.name).length > 1;
    return _specific!;
  }

  Future<T> doWork<T>(String msg, Future<T> Function() work) async {
    (Repository, String) job = (repository, msg);
    repoWork.add([...repoWork.value, job]);
    T t = await work();
    repoWork.add([
      ...repoWork.value.where((i) => i != job),
    ]);

    return t;
  }

  Stream<List<String>> streamWork() => repoWork.stream
      .map((i) => i.where((i) => i.$1 == repository).map((i) => i.$2).toList());

  String get repoPath => expandPath(
      "${config.workspaceDirectory}/${repository.owner?.login}/${repository.name}");

  String get imagePath => expandPath(
      "${config.archiveDirectory}/archives/${repository.owner?.login ?? 'unknown'}/${repository.name}.zip");

  String get authenticatedCloneUrl {
    final token = box.get("1");
    return "https://$token@github.com/${repository.owner?.login}/${repository.name}.git";
  }

  Future<bool> get isStaleActive async {
    if (!await isActive) return false;

    // Get the last time the repo was opened through the app
    int? lastOpen = getRepoConfig(repository).lastOpen;
    if (lastOpen == null) return false;

    // Get the latest file modification time in the repo
    int? latestModification = await getLatestFileModificationTime();

    // Use the most recent activity time (either open or file modification)
    int lastActivityTime = max(lastOpen, latestModification ?? 0);

    // Check if the repo is stale based on the last activity time
    if (DateTime.timestamp().millisecondsSinceEpoch - lastActivityTime >
        Duration(days: config.daysToArchive).inMilliseconds) {
      return true;
    }

    return false;
  }

  Future<bool> checkAndUpdateToken(String latestToken) async {
    if (!await isActive) return false;

    try {
      // Read the git config to check current token
      final Directory gitDir = Directory("$repoPath/.git");
      if (!await gitDir.exists()) return false;

      // Get the remote URL
      BehaviorSubject<String> stdout = BehaviorSubject();
      await cmd('git', ['-C', repoPath, 'config', '--get', 'remote.origin.url'],
          stdout: stdout);

      String? currentUrl = stdout.valueOrNull;
      if (currentUrl == null || currentUrl.isEmpty) return false;

      // Check if URL contains a token (https://TOKEN@github.com)
      if (currentUrl.contains("@github.com") && !currentUrl.contains(latestToken)) {
        // We need to update the token
        info("Updating token for repository ${repository.fullName}");

        // Create updated URL with new token
        String updatedUrl = "https://$latestToken@github.com/${repository.owner?.login}/${repository.name}.git";

        // Set the new URL
        int exitCode = await cmd('git', ['-C', repoPath, 'remote', 'set-url', 'origin', updatedUrl]);

        return exitCode == 0;
      }

      return false; // No update needed
    } catch (e) {
      error("Error checking token for ${repository.fullName}: $e");
      return false;
    }
  }

  Future<int?> getLatestFileModificationTime() async {
    if (!await isActive) return null;

    int? latestTime;
    try {
      await for (FileSystemEntity entity in Directory(repoPath).list(
        recursive: true,
        followLinks: false,
      )) {
        // Skip .git directory to improve performance
        if (entity.path.contains('/.git/')) continue;

        if (entity is File) {
          DateTime modTime = await entity.lastModified();
          int modTimeMs = modTime.millisecondsSinceEpoch;

          if (latestTime == null || modTimeMs > latestTime) {
            latestTime = modTimeMs;
          }
        }
      }
    } catch (e) {
      // Handle potential errors during directory traversal
      error("Error scanning repository files: $e");
    }

    return latestTime;
  }

  Future<void> archiveFromCloud(GitHub github) => doWork("Archiving", () async {
        if (await isArchived) return;
        if (await isActive) return;
        await ensureRepositoryActive(github, updateActive: false);
        await archive();
      });

  Future<void> archive() => doWork("Archiving", () async {
        if (await isArchived) return;
        if (!await isActive) return;
        File(imagePath).absolute.parent.createSync(recursive: true);
        int exitCode = await cmd('zip', ['-r', imagePath, '.'],
            workingDirectory: repoPath);
        // We run zip with workingDirectory = repoPath so that it zips the current directory ('.')

        if (exitCode != 0) {
          throw Exception('Failed to create zip archive at $imagePath');
        }

        success("Archived repository at $repoPath to $imagePath");
        await deleteRepository();
        active.remove(repository);
        update.add(update.value + 1);
      });

  Future<void> unarchive(GitHub github,
          {bool waitForPull = false, bool notifyActive = true}) =>
      doWork("Extracting", () async {
        if (!await isArchived) return;
        if (await isActive) return;
        await Directory(repoPath).create(recursive: true);
        int exitCode = await cmd('unzip', [imagePath, '-d', repoPath]);

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
              ..lastOpen = DateTime.timestamp().millisecondsSinceEpoch);
        Future<void> pull = ensureRepositoryUpdated(github);

        if (waitForPull) {
          await pull;
        }
      });

  Future<void> deleteRepository() => doWork("Deleting", () async {
        int exitCode = await cmd('rm', ['-rf', repoPath]);

        if (exitCode != 0) {
          throw Exception('Failed to delete repository at $repoPath');
        }

        info("Deleted repository at $repoPath");
        active.remove(repository);
        update.add(update.value + 1);
      });

  Future<void> deleteArchive() => doWork("Deleting Archive", () async {
        if (!await isArchived) return;
        await File(imagePath).delete();
        info("Deleted archive at $repoPath");
      });

  Future<void> updateArchive(GitHub github) => doWork("Updating", () async {
        if (!await isArchived) return;
        await unarchive(github, waitForPull: true, notifyActive: false);
        await archive();
      });

  Future<int> get sizeKB async {
    BehaviorSubject<String> stdout = BehaviorSubject();
    int? kb;
    stdout.listen((e) => kb ??= int.tryParse(e.split("\t").first));
    await cmd('du', ['-sk', repoPath], stdout: stdout);
    return kb ?? -1;
  }

  Future<bool> get isArchived => File(imagePath).exists();

  bool get isArchivedSync => File(imagePath).existsSync();

  Future<RepoState> get state =>
      Future.wait([isActive, isArchived]).then((v) => v[0]
          ? RepoState.active
          : v[1]
              ? RepoState.archived
              : RepoState.cloud);

  Future<void> runAutoMacros() async {
    for (String path in [
      ...await findDartPackages(
              "$repoPath/${getRepoConfig(repository).openDirectory}"
                  .replaceAll("//", "/"))
          .toList(),
      ...await findDartPackages(repoPath).toList()
    ]) {
      warn("IN $path");
      cmd("flutter", ["pub", "get"], workingDirectory: path);
    }
  }

  Stream<String> findDartPackages(String path) async* {
    if (await File("$path/pubspec.yaml").exists()) {
      yield path;
    }

    for (FileSystemEntity entity
        in Directory(path).listSync(followLinks: false)) {
      if (entity is Directory) {
        if (entity.path.endsWith(".plugin_symlinks")) continue;

        yield* findDartPackages(entity.path);
      }
    }
  }

  Future<void> openInFinder() async =>
      cmd('open', [Directory(repoPath).absolute.path]);

  Future<void> open(GitHub github, BuildContext context) =>
      doWork("Opening", () async {
        await ensureRepositoryActive(github);
        ApplicationTool tool =
            getRepoConfig(repository).editorTool ?? config.editorTool;
        info("Opening ${repository.fullName} with IDE ${tool.displayName}");
        ensureRepositoryUpdated(github);
        tool.launch("$repoPath/${getRepoConfig(repository).openDirectory}"
            .replaceAll("//", "/"));
        GitTool gitTool = getRepoConfig(repository).gitTool ?? config.gitTool;
        info(
            "Opening ${repository.fullName} with Git Client ${gitTool.displayName}");
        gitTool.launch(repoPath);
        runAutoMacros();
        setRepoConfig(
            repository,
            getRepoConfig(repository)
              ..lastOpen = DateTime.timestamp().millisecondsSinceEpoch);
      });

  Future<bool> get isActive => Directory("$repoPath/.git").exists();

  bool get isActiveSync => Directory("$repoPath/.git").existsSync();

  Future<void> ensureRepositoryActive(GitHub github,
          {bool updateActive = true}) =>
      doWork("Activating", () async {
        Directory repoDir = Directory(repoPath);

        if (!await repoDir.exists()) {
          if (await isArchived) {
            await unarchive(github, waitForPull: false, notifyActive: true);
          } else {
            await doWork("Cloning", () async {
              syncingRepositories.add({
                ...syncingRepositories.value,
                repository,
              }.toList());
              await repoDir.create(recursive: true);
              String cloneUrl = authenticatedCloneUrl;
              info("Cloning ${repository.fullName} from $cloneUrl");
              if (await cmd('git', ['clone', cloneUrl, repoPath]) != 0) {
                syncingRepositories.add(syncingRepositories.value
                    .where((i) => i.fullName != repository.fullName)
                    .toList());
                throw Exception('Git clone failed!');
              }
              syncingRepositories.add(syncingRepositories.value
                  .where((i) => i.fullName != repository.fullName)
                  .toList());
              success("Cloned ${repository.fullName}");
              if (updateActive) {
                active.add(repository);
              }
              setRepoConfig(
                  repository,
                  getRepoConfig(repository)
                    ..lastOpen = DateTime.timestamp().millisecondsSinceEpoch);
            });
          }
        } else {
          info("Repository ${repository.fullName} already exists $repoPath");
        }
        update.add(update.value + 1);
      });

  Future<void> ensureRepositoryUpdated(GitHub github) =>
      doWork("Pulling", () async {
        info("Pulling ${repository.fullName} ");
        if (await cmd('git', ['-C', repoPath, 'pull']) != 0) {
          throw Exception('Git pull failed!');
        }

        success("Pulled ${repository.fullName}");
        update.add(update.value + 1);
      });

  Future<int> get daysUntilArchival async {
    if (!await isActive) return 0;

    // Get the last time the repo was opened through the app
    int? lastOpen = getRepoConfig(repository).lastOpen;
    if (lastOpen == null)
      return config.daysToArchive; // Default to config value if never opened

    // Get the latest file modification time
    int? latestModification = await getLatestFileModificationTime();

    // Use the most recent activity time (either open or file modification)
    int lastActivityTime = max(lastOpen, latestModification ?? 0);

    // Calculate days elapsed since last activity
    int daysElapsed = Duration(
            milliseconds:
                DateTime.timestamp().millisecondsSinceEpoch - lastActivityTime)
        .inDays;

    // Calculate days remaining until archival
    int daysRemaining = config.daysToArchive - daysElapsed;

    // Ensure we don't return negative days
    return max(0, daysRemaining);
  }
}
