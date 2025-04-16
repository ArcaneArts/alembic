import 'package:alembic/core/arcane_repository.dart';
import 'package:alembic/main.dart';
import 'package:arcane/arcane.dart';
import 'package:github/github.dart';


extension XBuildContextRepo on BuildContext {
  BehaviorSubject<String?> get search => pylon<BehaviorSubject<String?>>();

  GitHub get github => pylon<GitHub>();

  Repository get repository => pylon<Repository>();

  ArcaneRepository get arepository => pylon<ArcaneRepository>();

  Organization get organization => pylon<Organization>();

  List<Repository> get repositories => pylon<List<Repository>>();

  Map<Organization, List<Repository>> get organizations =>
      pylon<Map<Organization, List<Repository>>>();
}

extension XSearchFilterRepo on List<Repository> {
  List<Repository> filterBy(String? query) => query == null || query.isEmpty
      ? this
      : where((i) => i.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
}

/// Supported IDE/Code Editor tools
enum ApplicationTool {
  vscode,
  intellij,
  zed,
  xcode
}

/// Extension methods for working with ApplicationTool enum
extension XApplicationTool on ApplicationTool {
  /// User-friendly display name for the tool
  String get displayName => switch (this) {
    ApplicationTool.vscode => "VS Code",
    ApplicationTool.intellij => "IntelliJ",
    ApplicationTool.zed => "Zed",
    ApplicationTool.xcode => "Xcode",
  };

  /// Help text with setup instructions
  String? get help => switch (this) {
    ApplicationTool.intellij => "Install via JetBrains Toolbox",
    ApplicationTool.vscode =>
    "To use, open Command Palette > Install 'code' command",
    ApplicationTool.zed =>
    "To use Zed, open the app, press Cmd+Shift+P, search for 'CLI: Install zed CLI command', and select it",
    ApplicationTool.xcode => "Works out of the box",
  };

  /// Launch the tool with the specified path
  Future<void> launch(String path) => switch (this) {
    ApplicationTool.vscode => cmd("code", [path]),
    ApplicationTool.intellij => cmd("idea", [path]),
    ApplicationTool.zed => cmd("zed", [path]),
    ApplicationTool.xcode => cmd("xed", [path]),
  };
}

/// Supported Git client tools
enum GitTool {
  githubDesktop,
  gitkraken,
  tower,
  fork,
  sourcetree
}

/// Extension methods for working with GitTool enum
extension XGitTool on GitTool {
  /// User-friendly display name for the tool
  String get displayName => switch (this) {
    GitTool.githubDesktop => "GH Desktop",
    GitTool.gitkraken => "GitKraken",
    GitTool.tower => "Tower",
    GitTool.fork => "Fork",
    GitTool.sourcetree => "SourceTree",
  };

  /// Launch the git tool with the specified repository path
  Future<void> launch(String path) => switch (this) {
    GitTool.gitkraken => cmd("gitkraken", ["-p", path]),
  // Currently only GitKraken is fully implemented
    _ => Future.value(),
  };
}