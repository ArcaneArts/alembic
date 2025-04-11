import 'package:alembic/screen/settings.dart';
import 'package:alembic/util/extensions.dart';
import 'package:arcane/arcane.dart';
import 'package:github/github.dart';

import '../util/repo_config.dart';

class RepositorySettings extends StatelessWidget {
  const RepositorySettings({super.key});

  @override
  Widget build(BuildContext context) {
    final Repository repository = context.repository;

    return SettingsScreen(
      options: OptionScreen(
        name: "Settings",
        description: repository.fullName,
        options: [
          OptionGroup(
            name: "Tools",
            options: _buildToolOptions(context, repository),
          ),
        ],
      ),
    );
  }

  List<Option> _buildToolOptions(BuildContext context, Repository repository) {
    return [
      _buildWorkspaceDirectoryOption(repository),
      _buildEditorToolOption(repository),
      _buildGitToolOption(repository),
    ];
  }

  StringOption _buildWorkspaceDirectoryOption(Repository repository) {
    return StringOption(
      name: "Workspace Directory",
      reader: () => getRepoConfig(repository).openDirectory,
      writer: (String? value) => setRepoConfig(
        repository,
        getRepoConfig(repository)..openDirectory = value ?? "",
      ),
      icon: Icons.folder_fill,
      description: "The subdirectory to open the project in with tools",
    );
  }

  EnumOption<ApplicationTool> _buildEditorToolOption(Repository repository) {
    return EnumOption<ApplicationTool>(
      name: "Editor Tool",
      options: ApplicationTool.values,
      reader: () => getRepoConfig(repository).editorTool,
      writer: (ApplicationTool? value) => setRepoConfig(
        repository,
        getRepoConfig(repository)..editorTool = value ?? ApplicationTool.intellij,
      ),
      icon: Icons.app_window,
      description: "Overrides the default IDE to use for opening projects",
      defaultValue: ApplicationTool.intellij,
      decorator: (ApplicationTool value) => Basic(
        title: Text(value.displayName).withTooltip(value.help ?? ""),
      ),
    );
  }

  EnumOption<GitTool> _buildGitToolOption(Repository repository) {
    return EnumOption<GitTool>(
      name: "Git Tool",
      options: GitTool.values,
      reader: () => getRepoConfig(repository).gitTool,
      writer: (GitTool? value) => setRepoConfig(
        repository,
        getRepoConfig(repository)..gitTool = value ?? GitTool.gitkraken,
      ),
      icon: Icons.git_branch,
      description: "Overrides the default tool to use for opening repositories",
      defaultValue: GitTool.gitkraken,
      decorator: (value) => Basic(
        title: Text(value.displayName),
      ),
    );
  }
}