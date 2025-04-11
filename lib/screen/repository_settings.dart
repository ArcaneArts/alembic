import 'package:alembic/screen/settings.dart';
import 'package:alembic/util/extensions.dart';
import 'package:arcane/arcane.dart';

class RepositorySettings extends StatelessWidget {
  const RepositorySettings({super.key});

  @override
  Widget build(BuildContext context) => SettingsScreen(
          options: OptionScreen(
              name: "Settings",
              description: context.repository.fullName,
              options: [
            OptionGroup(name: "Tools", options: [
              StringOption(
                name: "Workspace Directory",
                reader: () => getRepoConfig(context.repository).openDirectory,
                writer: (String? v) => setRepoConfig(context.repository,
                    getRepoConfig(context.repository)..openDirectory = v ?? ""),
                icon: Icons.folder_fill,
                description:
                    "The subdirectory to open the project in with tools",
              ),
              EnumOption<ApplicationTool>(
                  name: "Editor Tool",
                  options: ApplicationTool.values,
                  reader: () => getRepoConfig(context.repository).editorTool,
                  writer: (ApplicationTool? v) => setRepoConfig(
                      context.repository,
                      getRepoConfig(context.repository)
                        ..editorTool = v ?? ApplicationTool.intellij),
                  icon: Icons.app_window,
                  description:
                      "Overrides The default IDE to use for opening projects",
                  defaultValue: ApplicationTool.intellij,
                  decorator: (ApplicationTool v) => Basic(
                        title: Text(v.displayName).withTooltip(v.help ?? ""),
                      )),
              EnumOption<GitTool>(
                  name: "Git Tool",
                  options: GitTool.values,
                  reader: () => getRepoConfig(context.repository).gitTool,
                  writer: (GitTool? v) => setRepoConfig(
                      context.repository,
                      getRepoConfig(context.repository)
                        ..gitTool = v ?? GitTool.gitkraken),
                  icon: Icons.git_branch,
                  description:
                      "Overrides The default tool to use for opening repositories",
                  defaultValue: GitTool.gitkraken,
                  decorator: (v) => Basic(
                        title: Text(v.displayName),
                      )),
            ])
          ]));
}
