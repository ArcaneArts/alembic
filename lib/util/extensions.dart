import 'package:alembic/main.dart';
import 'package:alembic/platform/desktop_platform_adapter.dart';
import 'package:fast_log/fast_log.dart';
import 'package:github/github.dart';

extension XSearchFilterRepo on List<Repository> {
  List<Repository> filterBy(String? query) {
    final String normalizedQuery = (query ?? '').trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return this;
    }

    return where((Repository repository) {
      final String name = repository.name.toLowerCase();
      final String fullName = repository.fullName.toLowerCase();
      final String owner = (repository.owner?.login ?? '').toLowerCase();
      return name.contains(normalizedQuery) ||
          fullName.contains(normalizedQuery) ||
          owner.contains(normalizedQuery);
    }).toList();
  }
}

enum ApplicationTool {
  vscode,
  intellij,
  zed,
  xcode,
}

extension XApplicationTool on ApplicationTool {
  String get displayName => switch (this) {
        ApplicationTool.vscode => 'VS Code',
        ApplicationTool.intellij => 'IntelliJ',
        ApplicationTool.zed => 'Zed',
        ApplicationTool.xcode => 'Xcode',
      };

  String? get help => switch (this) {
        ApplicationTool.intellij => 'Install via JetBrains Toolbox',
        ApplicationTool.vscode =>
          'Open Command Palette and install the `code` CLI command',
        ApplicationTool.zed =>
          'In Zed, run `CLI: Install zed CLI command` from Command Palette',
        ApplicationTool.xcode => 'Works out of the box on macOS',
      };

  bool get supportedOnCurrentPlatform {
    if (this == ApplicationTool.xcode) {
      return DesktopPlatformAdapter.instance.isMacOS;
    }
    return true;
  }

  static List<ApplicationTool> get supportedTools {
    return ApplicationTool.values.where((ApplicationTool tool) {
      return tool.supportedOnCurrentPlatform;
    }).toList();
  }

  Future<void> launch(String path) async {
    await _launchCandidates(
      commands: switch (this) {
        ApplicationTool.vscode => <String>['code', 'code.cmd'],
        ApplicationTool.intellij => <String>['idea', 'idea64.exe'],
        ApplicationTool.zed => <String>['zed', 'zed.exe'],
        ApplicationTool.xcode => <String>['xed'],
      },
      args: <String>[path],
    );
  }
}

enum GitTool {
  githubDesktop,
  gitkraken,
  tower,
  fork,
  sourcetree,
}

extension XGitTool on GitTool {
  String get displayName => switch (this) {
        GitTool.githubDesktop => 'GitHub Desktop',
        GitTool.gitkraken => 'GitKraken',
        GitTool.tower => 'Tower',
        GitTool.fork => 'Fork',
        GitTool.sourcetree => 'SourceTree',
      };

  bool get supportedOnCurrentPlatform {
    if (this == GitTool.tower) {
      return DesktopPlatformAdapter.instance.isMacOS;
    }
    return true;
  }

  static List<GitTool> get supportedTools {
    return GitTool.values.where((GitTool tool) {
      return tool.supportedOnCurrentPlatform;
    }).toList();
  }

  Future<void> launch(String path) async {
    await _launchCandidates(
      commands: switch (this) {
        GitTool.githubDesktop => <String>[
            'github',
            'github-desktop',
            'GitHubDesktop.exe',
          ],
        GitTool.gitkraken => <String>['gitkraken', 'gitkraken.exe'],
        GitTool.tower => <String>['gittower', 'tower'],
        GitTool.fork => <String>['fork', 'Fork.exe'],
        GitTool.sourcetree => <String>['sourcetree', 'SourceTree.exe'],
      },
      args: switch (this) {
        GitTool.gitkraken => <String>['-p', path],
        _ => <String>[path],
      },
    );
  }
}

Future<void> _launchCandidates({
  required List<String> commands,
  required List<String> args,
}) async {
  int lastExitCode = -1;
  for (final String command in commands) {
    final int exitCode = await cmd(command, args);
    lastExitCode = exitCode;
    if (exitCode == 0) {
      return;
    }
  }

  if (lastExitCode != 0) {
    error(
      'Unable to launch external tool with candidates: ${commands.join(", ")}',
    );
  }
}
