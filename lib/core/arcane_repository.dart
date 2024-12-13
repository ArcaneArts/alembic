import 'dart:io';

import 'package:alembic/main.dart';
import 'package:alembic/screen/settings.dart';
import 'package:fast_log/fast_log.dart';
import 'package:github/github.dart';

class ArcaneRepository {
  final Repository repository;

  ArcaneRepository({required this.repository});

  String get repoPath =>
      expandPath("${config.workspaceDirectory}/${repository.name}");

  String get imagePath => expandPath(
      "${config.archiveDirectory}/${repository.owner?.login ?? 'unknown'}/${repository.name}.sparsebundle");

  String get authenticatedCloneUrl =>
      "https://${box.get("1")}:x-oauth-basic@github.com/${repository.owner?.login}/${repository.name}.git";

  Future<void> open(GitHub github) async {
    await ensureRepositoryActive(github);
    ApplicationTool tool =
        getRepoConfig(repository).editorTool ?? config.editorTool;
    info("Opening ${repository.fullName} with ${tool.displayName}");
    ensureRepositoryUpdated(github);
    tool.launch("$repoPath/${getRepoConfig(repository).openDirectory}"
        .replaceAll("//", "/"));
  }

  Future<bool> get isActive => Directory("$repoPath/.git").exists();

  Future<void> ensureRepositoryActive(GitHub github) async {
    Directory repoDir = Directory(repoPath);

    if (!await repoDir.exists()) {
      await repoDir.create(recursive: true);
      String cloneUrl = authenticatedCloneUrl;
      info("Cloning ${repository.fullName} from $cloneUrl");
      if (await cmd('git', ['clone', cloneUrl, repoPath]) != 0) {
        throw Exception('Git clone failed!');
      }
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
