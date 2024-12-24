import 'dart:convert';

import 'package:alembic/main.dart';
import 'package:arcane/arcane.dart';
import 'package:file_picker/file_picker.dart';
import 'package:github/github.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

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

String? compressPath(String? path) {
  if (path == null) return null;
  if (path.startsWith("/Volumes/Macintosh HD/Users/")) {
    List<String> p = path.substring(1).split("/");
    print(p);
    return "~/${p.sublist(4).join("/")}";
  }
  return path;
}

AlembicRepoConfig getRepoConfig(Repository repo) =>
    AlembicRepoConfig.fromJson(boxSettings.get("config/${repo.fullName}",
        defaultValue: AlembicRepoConfig().json));

void setRepoConfig(Repository repo, AlembicRepoConfig c) =>
    boxSettings.put("config/${repo.fullName}", c.json);

AlembicConfig get config => AlembicConfig.fromJson(
    boxSettings.get("config", defaultValue: AlembicConfig().json));
void setConfig(AlembicConfig c) => boxSettings.put("config", c.json);

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) => SliverScreen(
        header: Bar(
          titleText: "Settings",
        ),
        sliver: MultiSliver(
          children: [
            BarSection(
                subtitleText: "Application",
                sliver: SListView(
                  children: [
                    CheckboxTile(
                      title: Text("Launch at Startup"),
                      leading: Icon(Icons.open_ionic),
                      subtitle: Text("Add / Remove Alembic from Login Items"),
                      value: boxSettings.get("autolaunch", defaultValue: true),
                      onChanged: (b) {
                        boxSettings.put("autolaunch", b);

                        if (b == true) {
                          launchAtStartup.enable();
                        } else {
                          launchAtStartup.disable();
                        }

                        setState(() {});
                      },
                    ),
                    CheckboxTile(
                      title: Text("Check for Updates on Launch"),
                      leading: Icon(Icons.arrow_circle_up),
                      subtitle: Text(
                          "Allow Alembic to check for updates when launched"),
                      value: boxSettings.get("achup", defaultValue: true),
                      onChanged: (b) {
                        boxSettings.put("achup", b);
                        setState(() {});
                      },
                    )
                  ],
                )),
            BarSection(
                subtitleText: "Tools",
                sliver: SListView(
                  children: [
                    ListTile(
                      title: Text("Workspace Directory"),
                      subtitle: Text(config.workspaceDirectory),
                      leading: Icon(Icons.folder_fill),
                      onPressed: () => FilePicker.platform
                          .getDirectoryPath(
                            initialDirectory:
                                expandPath(config.workspaceDirectory),
                            dialogTitle: "Select Workspace Directory",
                          )
                          .then((v) => compressPath(v))
                          .then((v) {
                        if (v == null) {
                          return;
                        }

                        setConfig(config..workspaceDirectory = v);
                        setState(() {});
                      }),
                    ),
                    ListTile(
                      title: Text("Archive Directory"),
                      subtitle: Text(config.archiveDirectory),
                      leading: Icon(Icons.archive_fill),
                      onPressed: () => FilePicker.platform
                          .getDirectoryPath(
                            initialDirectory:
                                expandPath(config.archiveDirectory),
                            dialogTitle: "Select Archive Directory",
                          )
                          .then((v) => compressPath(v))
                          .then((v) {
                        if (v == null) {
                          return;
                        }

                        setConfig(config..archiveDirectory = v);
                        setState(() {});
                      }),
                    ),
                    ListTile(
                      leading: Icon(Icons.app_window),
                      title: Text("Editor Tool"),
                      subtitle: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Gap(8),
                          CardCarousel(
                            children: [
                              RadioCards<ApplicationTool>(
                                items: ApplicationTool.values,
                                value: config.editorTool ??
                                    ApplicationTool.intellij,
                                builder: (v) => Basic(
                                  title: Text(v.displayName)
                                      .withTooltip(v.help ?? ""),
                                ),
                                onChanged: (v) {
                                  setConfig(config..editorTool = v);
                                  setState(() {});
                                },
                              )
                            ],
                          ),
                          Gap(8),
                          Text("The IDE to use for opening projects")
                        ],
                      ),
                    ),
                    ListTile(
                      leading: Icon(Icons.git_branch),
                      title: Text("Git Tool"),
                      subtitle: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Gap(8),
                          CardCarousel(
                            children: [
                              RadioCards<GitTool>(
                                items: GitTool.values,
                                value: config.gitTool ?? GitTool.gitkraken,
                                builder: (v) => Basic(
                                  title: Text(v.displayName),
                                ),
                                onChanged: (v) {
                                  setConfig(config..gitTool = v);
                                  setState(() {});
                                },
                              )
                            ],
                          ),
                          Gap(8),
                          Text("he tool to use for opening repositories")
                        ],
                      ),
                    )
                  ],
                )),
            BarSection(
                subtitleText: "About",
                sliver: SListView(
                  children: [
                    ListTile(
                      leading: Icon(Icons.folder_fill),
                      title: Text("Config Path"),
                      subtitle: Text(configPath),
                      onPressed: () => cmd("open", [configPath]),
                    ),
                    ListTile(
                      leading: Icon(Icons.list),
                      title: Text("View Logs"),
                      subtitle: Text(configPath),
                      onPressed: () => cmd("open", ["$configPath/alembic.log"]),
                    )
                  ],
                ))
          ],
        ),
      );
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
