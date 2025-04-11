import 'package:alembic/main.dart';
import 'package:alembic/util/extensions.dart';
import 'package:arcane/arcane.dart';
import 'package:file_picker/file_picker.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import 'package:alembic/util/repo_config.dart';

/// Main settings screen for the application
class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) => SliverScreen(
    header: const Bar(titleText: "Settings"),
    sliver: MultiSliver(
      children: [
        _buildApplicationSection(),
        _buildToolsSection(),
        _buildAboutSection(),
      ],
    ),
  );

  /// Builds the application settings section
  Widget _buildApplicationSection() => BarSection(
    subtitleText: "Application",
    sliver: SListView(
      children: [
        _buildAutoLaunchSetting(),
        _buildUpdateCheckSetting(),
      ],
    ),
  );

  /// Builds the tools settings section
  Widget _buildToolsSection() => BarSection(
    subtitleText: "Tools",
    sliver: SListView(
      children: [
        _buildWorkspaceDirectorySetting(),
        _buildArchiveDirectorySetting(),
        _buildEditorToolSetting(),
        _buildGitToolSetting(),
        _buildArchiveDurationSetting(),
      ],
    ),
  );

  /// Builds the about section
  Widget _buildAboutSection() => BarSection(
    subtitleText: "About",
    sliver: SListView(
      children: [
        _buildConfigPathInfo(),
        _buildViewLogsOption(),
      ],
    ),
  );

  /// Auto-launch setting checkbox
  Widget _buildAutoLaunchSetting() => CheckboxTile(
    title: const Text("Launch at Startup"),
    leading: const Icon(Icons.open_ionic),
    subtitle: const Text("Add / Remove Alembic from Login Items"),
    value: boxSettings.get("autolaunch", defaultValue: true),
    onChanged: (bool? value) {
      if (value != null) {
        boxSettings.put("autolaunch", value);

        if (value) {
          launchAtStartup.enable();
        } else {
          launchAtStartup.disable();
        }

        setState(() {});
      }
    },
  );

  /// Update check setting checkbox
  Widget _buildUpdateCheckSetting() => CheckboxTile(
    title: const Text("Check for Updates on Launch"),
    leading: const Icon(Icons.arrow_circle_up),
    subtitle: const Text("Allow Alembic to check for updates when launched"),
    value: boxSettings.get("achup", defaultValue: true),
    onChanged: (bool? value) {
      if (value != null) {
        boxSettings.put("achup", value);
        setState(() {});
      }
    },
  );

  /// Workspace directory picker
  Widget _buildWorkspaceDirectorySetting() => ListTile(
    title: const Text("Workspace Directory"),
    subtitle: Text(config.workspaceDirectory),
    leading: const Icon(Icons.folder_fill),
    onPressed: () => _selectDirectory(
      initialDirectory: expandPath(config.workspaceDirectory),
      dialogTitle: "Select Workspace Directory",
      onSelected: (String path) {
        setConfig(config..workspaceDirectory = path);
        setState(() {});
      },
    ),
  );

  /// Archive directory picker
  Widget _buildArchiveDirectorySetting() => ListTile(
    title: const Text("Archive Directory"),
    subtitle: Text(config.archiveDirectory),
    leading: const Icon(Icons.archive_fill),
    onPressed: () => _selectDirectory(
      initialDirectory: expandPath(config.archiveDirectory),
      dialogTitle: "Select Archive Directory",
      onSelected: (String path) {
        setConfig(config..archiveDirectory = path);
        setState(() {});
      },
    ),
  );

  /// Editor tool selection
  Widget _buildEditorToolSetting() => ListTile(
    leading: const Icon(Icons.app_window),
    title: const Text("Editor Tool"),
    subtitle: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(8),
        CardCarousel(
          children: [
            RadioCards<ApplicationTool>(
              items: ApplicationTool.values,
              value: config.editorTool ?? ApplicationTool.intellij,
              builder: (ApplicationTool tool) => Basic(
                title: Text(tool.displayName)
                    .withTooltip(tool.help ?? ""),
              ),
              onChanged: (ApplicationTool tool) {
                setConfig(config..editorTool = tool);
                setState(() {});
              },
            )
          ],
        ),
        const Gap(8),
        const Text("The IDE to use for opening projects")
      ],
    ),
  );

  /// Git tool selection
  Widget _buildGitToolSetting() => ListTile(
    leading: const Icon(Icons.git_branch),
    title: const Text("Git Tool"),
    subtitle: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(8),
        CardCarousel(
          children: [
            RadioCards<GitTool>(
              items: GitTool.values,
              value: config.gitTool ?? GitTool.gitkraken,
              builder: (GitTool tool) => Basic(
                title: Text(tool.displayName),
              ),
              onChanged: (GitTool tool) {
                setConfig(config..gitTool = tool);
                setState(() {});
              },
            )
          ],
        ),
        const Gap(8),
        const Text("The tool to use for opening repositories")
      ],
    ),
  );

  /// Archive duration setting
  Widget _buildArchiveDurationSetting() => ListTile(
    title: const Text("Archive Duration (Days)"),
    subtitle: TextField(
      placeholder: Text("${config.daysToArchive} days"),
      initialValue: "${config.daysToArchive}",
      keyboardType: TextInputType.number,
      minLines: 1,
      maxLines: 2,
      leading: const Icon(Icons.calendar_clear_outline_ionic),
      maxLength: 3,
      onChanged: (String value) {
        final int? days = int.tryParse(value);

        if (days != null && days > 0) {
          setConfig(config..daysToArchive = days);
        } else {
          setConfig(config..daysToArchive = 30);
        }

        setState(() {});
      },
    ),
    leading: const Icon(Icons.timer),
  );

  /// Config path info
  Widget _buildConfigPathInfo() => ListTile(
    leading: const Icon(Icons.folder_fill),
    title: const Text("Config Path"),
    subtitle: Text(configPath),
    onPressed: () => cmd("open", [configPath]),
  );

  /// View logs option
  Widget _buildViewLogsOption() => ListTile(
    leading: const Icon(Icons.list),
    title: const Text("View Logs"),
    subtitle: Text(configPath),
    onPressed: () => cmd("open", ["$configPath/alembic.log"]),
  );

  /// Helper method to handle directory selection
  Future<void> _selectDirectory({
    required String initialDirectory,
    required String dialogTitle,
    required Function(String) onSelected,
  }) async {
    try {
      final String? selectedPath = await FilePicker.platform.getDirectoryPath(
        initialDirectory: initialDirectory,
        dialogTitle: dialogTitle,
      );

      final String? compressedPath = compressPath(selectedPath);

      if (compressedPath != null) {
        onSelected(compressedPath);
      }
    } catch (e) {
      // Handle directory picker errors
      TextToast("Error selecting directory: $e").open(context);
    }
  }
}