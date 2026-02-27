import 'package:alembic/main.dart';
import 'package:github/github.dart';

extension XSearchFilterRepo on List<Repository> {
  List<Repository> filterBy(String? query) {
    String normalizedQuery = (query ?? '').trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return this;
    }

    return where((Repository repository) {
      String name = repository.name.toLowerCase();
      String fullName = repository.fullName.toLowerCase();
      String owner = (repository.owner?.login ?? '').toLowerCase();
      return name.contains(normalizedQuery) ||
          fullName.contains(normalizedQuery) ||
          owner.contains(normalizedQuery);
    }).toList();
  }
}

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
          "Open Command Palette and install the `code` CLI command",
        ApplicationTool.zed =>
          "In Zed, run `CLI: Install zed CLI command` from Command Palette",
        ApplicationTool.xcode => "Works out of the box",
      };

  Future<void> launch(String path) => switch (this) {
        ApplicationTool.vscode => cmd("code", <String>[path]),
        ApplicationTool.intellij => cmd("idea", <String>[path]),
        ApplicationTool.zed => cmd("zed", <String>[path]),
        ApplicationTool.xcode => cmd("xed", <String>[path]),
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
        GitTool.gitkraken => cmd("gitkraken", <String>["-p", path]),
        _ => Future<void>.value(),
      };
}
