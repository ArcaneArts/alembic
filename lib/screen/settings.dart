import 'dart:convert';

import 'package:alembic/main.dart';
import 'package:arcane/arcane.dart';
import 'package:github/github.dart';

enum ApplicationTool { vscode, intellij, zed, xcode }

extension XApplicationTool on ApplicationTool {
  String get displayName => switch (this) {
        ApplicationTool.vscode => "VS Code",
        ApplicationTool.intellij => "IntelliJ",
        ApplicationTool.zed => "Zed",
        ApplicationTool.xcode => "Xcode",
      };

  String? get help => switch (this) {
        ApplicationTool.intellij => "Install via JetBrains Toolbox",
        ApplicationTool.vscode =>
          "To use, open Command Palette > Install 'code' command",
        ApplicationTool.zed => "To use, open Command Palette > cli:install",
        ApplicationTool.xcode => "Works out of the box",
      };

  Future<void> launch(String path) => switch (this) {
        ApplicationTool.vscode => cmd("code", [path]),
        ApplicationTool.intellij => cmd("idea", [path]),
        ApplicationTool.zed => cmd("zed", [path]),
        ApplicationTool.xcode => cmd("xed", [path]),
      };
}

enum GitTool { githubDesktop, gitkraken, tower, fork, sourcetree }

extension XGitTool on GitTool {
  String get displayName => switch (this) {
        GitTool.githubDesktop => "GH Desktop",
        GitTool.gitkraken => "GitKraken",
        GitTool.tower => "Tower",
        GitTool.fork => "Fork",
        GitTool.sourcetree => "SourceTree",
      };

  Future<void> launch(String path) => switch (this) {
        GitTool.gitkraken => cmd("gitkraken", ["-p", path]),
        _ => Future.value()
      };
}

AlembicRepoConfig getRepoConfig(Repository repo) =>
    AlembicRepoConfig.fromJson(boxSettings.get("config/${repo.fullName}",
        defaultValue: AlembicRepoConfig().json));

void setRepoConfig(Repository repo, AlembicRepoConfig c) =>
    boxSettings.put("config/${repo.fullName}", c.json);

AlembicConfig get config => AlembicConfig.fromJson(
    boxSettings.get("config", defaultValue: AlembicConfig().json));
void setConfig(AlembicConfig c) => boxSettings.put("config", c.json);

class Settings extends StatelessWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context) => SettingsScreen(
          options: OptionScreen(name: "Settings", options: [
        OptionGroup(name: "Tools", options: [
          StringOption(
            name: "Workspace Directory",
            reader: () => config.workspaceDirectory,
            writer: (v) => setConfig(config..workspaceDirectory = v ?? ""),
            icon: Icons.folder_fill,
            description: "The directory to store projects",
          ),
          StringOption(
            name: "Archive Directory",
            reader: () => config.archiveDirectory,
            writer: (v) => setConfig(config..archiveDirectory = v ?? ""),
            icon: Icons.archive_fill,
            description:
                "The directory to archive images of active projects. Used for iCloud syncing projects safely.",
          ),
          EnumOption<ApplicationTool>(
              name: "Editor Tool",
              options: ApplicationTool.values,
              reader: () => config.editorTool,
              writer: (v) =>
                  setConfig(config..editorTool = v ?? ApplicationTool.intellij),
              icon: Icons.app_window,
              description: "The IDE to use for opening projects",
              defaultValue: ApplicationTool.intellij,
              decorator: (v) => Basic(
                    title: Text(v.displayName).withTooltip(v.help ?? ""),
                  )),
          EnumOption<GitTool>(
              name: "Git Tool",
              options: GitTool.values,
              reader: () => config.gitTool,
              writer: (v) =>
                  setConfig(config..gitTool = v ?? GitTool.gitkraken),
              icon: Icons.git_branch,
              description: "The tool to use for opening repositories",
              defaultValue: GitTool.gitkraken,
              decorator: (v) => Basic(
                    title: Text(v.displayName),
                  )),
        ]),
        OptionGroup(name: "Archive", options: [
          IntOption(
            name: "Days to Archive",
            reader: () => config.daysToArchive,
            writer: (v) => setConfig(config..daysToArchive = v ?? 30),
            icon: Icons.calendar_fill,
            description:
                "The number of days to keep a project in the active list before archiving.",
          ),
        ]),
      ]));
}

class AlembicConfig {
  late ApplicationTool editorTool;
  late GitTool gitTool;
  late String workspaceDirectory;
  late String archiveDirectory;
  late int daysToArchive;

  AlembicConfig(
      {this.editorTool = ApplicationTool.intellij,
      this.gitTool = GitTool.gitkraken,
      this.workspaceDirectory = "~/development/workspace",
      this.archiveDirectory = "~/Documents/Alembic",
      this.daysToArchive = 30});

  AlembicConfig.fromJson(String json) {
    final data = jsonDecode(json);
    editorTool =
        ApplicationTool.values.select((e) => e.name == data["editorTool"]) ??
            AlembicConfig().editorTool;
    gitTool = GitTool.values.select((e) => e.name == data["gitTool"]) ??
        AlembicConfig().gitTool;
    workspaceDirectory =
        data["workspaceDirectory"] ?? AlembicConfig().workspaceDirectory;
    archiveDirectory =
        data["archiveDirectory"] ?? AlembicConfig().archiveDirectory;
    daysToArchive = data["daysToArchive"] ?? AlembicConfig().daysToArchive;
  }

  String get json => jsonEncode({
        "editorTool": editorTool.name,
        "gitTool": gitTool.name,
        "workspaceDirectory": workspaceDirectory,
        "archiveDirectory": archiveDirectory,
        "daysToArchive": daysToArchive
      });
}

class AlembicRepoConfig {
  late ApplicationTool? editorTool;
  late GitTool? gitTool;
  late String openDirectory;
  late int? lastOpen;

  AlembicRepoConfig(
      {this.editorTool, this.gitTool, this.openDirectory = "/", this.lastOpen});

  AlembicRepoConfig.fromJson(String json) {
    final data = jsonDecode(json);
    editorTool =
        ApplicationTool.values.select((e) => e.name == data["editorTool"]) ??
            config.editorTool;
    gitTool = GitTool.values.select((e) => e.name == data["gitTool"]) ??
        config.gitTool;
    openDirectory = data["openDirectory"] ?? AlembicRepoConfig().openDirectory;
    lastOpen = data["lastOpen"];
  }

  String get json => jsonEncode({
        if (editorTool != null && editorTool != config.editorTool)
          "editorTool": editorTool!.name,
        if (gitTool != null && gitTool != config.gitTool)
          "gitTool": gitTool!.name,
        "openDirectory": openDirectory,
        if (lastOpen != null) "lastOpen": lastOpen
      });
}
