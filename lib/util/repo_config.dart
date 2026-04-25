import 'dart:convert';

import 'package:alembic/main.dart';
import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:github/github.dart';

import 'extensions.dart';

/// Functions for working with repository configurations
AlembicRepoConfig getRepoConfig(Repository repo) =>
    AlembicRepoConfig.fromJson(boxSettings.get("config/${repo.fullName}",
        defaultValue: AlembicRepoConfig().json));

void setRepoConfig(Repository repo, AlembicRepoConfig config) =>
    boxSettings.put("config/${repo.fullName}", config.json);

/// Functions for working with global app configuration
AlembicConfig get config => AlembicConfig.fromJson(
    boxSettings.get("config", defaultValue: AlembicConfig().json));

void setConfig(AlembicConfig config) => boxSettings.put("config", config.json);

/// Helper function to compress macOS paths to use ~ for home directory
String? compressPath(String? path) {
  if (path == null) {
    return null;
  }
  return DesktopPlatformAdapter.instance.compressHomePath(path);
}

/// Global application configuration
class AlembicConfig {
  ApplicationTool? editorTool;
  GitTool? gitTool;
  String workspaceDirectory;
  String archiveDirectory;
  String archiveMasterDirectory;
  int daysToArchive;
  int archiveMasterIntervalMinutes;

  /// Default constructor with reasonable defaults
  AlembicConfig({
    this.editorTool = ApplicationTool.intellij,
    this.gitTool = GitTool.gitkraken,
    this.workspaceDirectory = "~/Developer/RemoteGit",
    this.archiveDirectory = "~/Developer/AlembicArchive",
    this.archiveMasterDirectory = "~/Developer/AlembicArchiveMaster",
    this.daysToArchive = 30,
    this.archiveMasterIntervalMinutes = 1440,
  });

  /// Create config from JSON string
  AlembicConfig.fromJson(String jsonString)
      : workspaceDirectory = "~/Developer/RemoteGit",
        archiveDirectory = "~/Developer/AlembicArchive",
        archiveMasterDirectory = "~/Developer/AlembicArchiveMaster",
        daysToArchive = 30,
        archiveMasterIntervalMinutes = 1440 {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);

      // Parse editor tool from JSON or use default
      final String? editorToolName = data["editorTool"] as String?;
      if (editorToolName != null) {
        editorTool = ApplicationTool.values.firstWhere(
          (tool) => tool.name == editorToolName,
          orElse: () => ApplicationTool.intellij,
        );
      } else {
        editorTool = ApplicationTool.intellij;
      }

      // Parse git tool from JSON or use default
      final String? gitToolName = data["gitTool"] as String?;
      if (gitToolName != null) {
        gitTool = GitTool.values.firstWhere(
          (tool) => tool.name == gitToolName,
          orElse: () => GitTool.gitkraken,
        );
      } else {
        gitTool = GitTool.gitkraken;
      }

      // Load other settings
      workspaceDirectory =
          data["workspaceDirectory"] as String? ?? workspaceDirectory;
      archiveDirectory =
          data["archiveDirectory"] as String? ?? archiveDirectory;
      archiveMasterDirectory =
          data["archiveMasterDirectory"] as String? ?? archiveMasterDirectory;
      daysToArchive = data["daysToArchive"] as int? ?? daysToArchive;
      archiveMasterIntervalMinutes =
          data["archiveMasterIntervalMinutes"] as int? ??
              archiveMasterIntervalMinutes;
    } catch (e) {
      // Failed to parse JSON, use defaults
      editorTool = ApplicationTool.intellij;
      gitTool = GitTool.gitkraken;
    }
  }

  /// Convert config to JSON string
  String get json => jsonEncode({
        "editorTool": editorTool?.name,
        "gitTool": gitTool?.name,
        "workspaceDirectory": workspaceDirectory,
        "archiveDirectory": archiveDirectory,
        "archiveMasterDirectory": archiveMasterDirectory,
        "daysToArchive": daysToArchive,
        "archiveMasterIntervalMinutes": archiveMasterIntervalMinutes,
      });
}

/// Repository-specific configuration
class AlembicRepoConfig {
  ApplicationTool? editorTool;
  GitTool? gitTool;
  String openDirectory;
  int? lastOpen;
  String? accountId;

  /// Default constructor with reasonable defaults
  AlembicRepoConfig({
    this.editorTool,
    this.gitTool,
    this.openDirectory = "/",
    this.lastOpen,
    this.accountId,
  });

  /// Create config from JSON string
  AlembicRepoConfig.fromJson(String jsonString) : openDirectory = "/" {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);

      // Parse editor tool from JSON
      final String? editorToolName = data["editorTool"] as String?;
      if (editorToolName != null) {
        editorTool = ApplicationTool.values.firstWhere(
          (tool) => tool.name == editorToolName,
          orElse: () => config.editorTool ?? ApplicationTool.intellij,
        );
      }

      // Parse git tool from JSON
      final String? gitToolName = data["gitTool"] as String?;
      if (gitToolName != null) {
        gitTool = GitTool.values.firstWhere(
          (tool) => tool.name == gitToolName,
          orElse: () => config.gitTool ?? GitTool.gitkraken,
        );
      }

      // Load other settings
      openDirectory = data["openDirectory"] as String? ?? "/";
      lastOpen = data["lastOpen"] as int?;
      final String? rawAccountId = data["accountId"] as String?;
      if (rawAccountId != null && rawAccountId.trim().isNotEmpty) {
        accountId = rawAccountId.trim();
      }
    } catch (e) {
      // Failed to parse JSON, use defaults
    }
  }

  /// Convert config to JSON string - only includes non-default values
  String get json => jsonEncode({
        if (editorTool != null && editorTool != config.editorTool)
          "editorTool": editorTool!.name,
        if (gitTool != null && gitTool != config.gitTool)
          "gitTool": gitTool!.name,
        "openDirectory": openDirectory,
        if (lastOpen != null) "lastOpen": lastOpen,
        if (accountId != null && accountId!.trim().isNotEmpty)
          "accountId": accountId,
      });
}
