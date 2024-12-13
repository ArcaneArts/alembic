import 'dart:io';

import 'package:alembic/main.dart';
import 'package:alembic/screen/settings.dart';
import 'package:alembic/widget/repository_tile.dart';
import 'package:fast_log/fast_log.dart';
import 'package:github/github.dart';

enum RepoState { active, archived, cloud }

class ArcaneRepository {
  final Repository repository;

  ArcaneRepository({required this.repository});

  String get repoPath =>
      expandPath("${config.workspaceDirectory}/${repository.name}");

  String get imagePath => expandPath(
      "${config.archiveDirectory}/${repository.owner?.login ?? 'unknown'}/${repository.name}.sparsebundle");

  String get authenticatedCloneUrl =>
      "https://${box.get("1")}:x-oauth-basic@github.com/${repository.owner?.login}/${repository.name}.git";

  Future<bool> get isArchived => File(imagePath).exists();

  Future<RepoState> get state =>
      Future.wait([isActive, isArchived]).then((v) => v[0]
          ? RepoState.active
          : v[1]
              ? RepoState.archived
              : RepoState.cloud);

  Future<void> openInFinder() async =>
      cmd('open', [Directory(repoPath).absolute.path]);

  Future<void> open(GitHub github) async {
    await ensureRepositoryActive(github);
    ApplicationTool tool =
        getRepoConfig(repository).editorTool ?? config.editorTool;
    info("Opening ${repository.fullName} with ${tool.displayName}");
    ensureRepositoryUpdated(github);
    tool.launch("$repoPath/${getRepoConfig(repository).openDirectory}"
        .replaceAll("//", "/"));
    setRepoConfig(
        repository,
        getRepoConfig(repository)
          ..lastOpen = DateTime.timestamp().millisecondsSinceEpoch);
  }

  Future<bool> get isActive => Directory("$repoPath/.git").exists();

  Future<void> ensureRepositoryActive(GitHub github) async {
    Directory repoDir = Directory(repoPath);

    if (!await repoDir.exists()) {
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
    } else {
      info("Repository ${repository.fullName} already exists $repoPath");
    }
  }

  Future<void> ensureRepositoryUpdated(GitHub github) async {
    info("Pulling ${repository.fullName} ");
    if (await cmd('git', ['-C', repoPath, 'pull']) != 0) {
      throw Exception('Git pull failed!');
    }

    success("Pulled ${repository.fullName}");
  }
}
