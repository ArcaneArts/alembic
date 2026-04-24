import 'package:alembic/ui/alembic_ui.dart';
import 'package:alembic/util/extensions.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;
import 'package:github/github.dart';

Future<void> showRepositorySettingsModal(
  BuildContext context,
  Repository repository,
) {
  return Navigator.of(context, rootNavigator: true).push(
    m.MaterialPageRoute<void>(
      builder: (_) => RepositorySettings(repository: repository),
    ),
  );
}

class RepositorySettings extends StatefulWidget {
  final Repository repository;
  final bool modal;

  const RepositorySettings({
    super.key,
    required this.repository,
    this.modal = false,
  });

  @override
  State<RepositorySettings> createState() => _RepositorySettingsState();
}

class _RepositorySettingsState extends State<RepositorySettings> {
  late final m.TextEditingController _pathController;
  late ApplicationTool _editorTool;
  late GitTool _gitTool;

  @override
  void initState() {
    super.initState();
    AlembicRepoConfig repoConfig = getRepoConfig(widget.repository);
    _pathController = m.TextEditingController(text: repoConfig.openDirectory);
    _pathController.addListener(_savePath);
    _editorTool = repoConfig.editorTool ?? ApplicationTool.intellij;
    _gitTool = repoConfig.gitTool ?? GitTool.gitkraken;
  }

  @override
  void dispose() {
    _pathController.removeListener(_savePath);
    _pathController.dispose();
    super.dispose();
  }

  void _savePath() {
    setRepoConfig(
      widget.repository,
      getRepoConfig(widget.repository)..openDirectory = _pathController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    String owner = widget.repository.owner?.login ?? 'Unknown';
    String visibility =
        widget.repository.isPrivate == true ? 'Private' : 'Public';

    return m.Scaffold(
      backgroundColor: m.Colors.transparent,
      body: AlembicScaffold(
        profile: AlembicShellProfile.modal,
        child: AlembicSettingsPane(
          title: 'Repository Settings',
          subtitle: widget.repository.fullName,
          shrinkWrap: true,
          trailing: AlembicToolbarButton(
            onPressed: () => Navigator.of(context).pop(),
            label: 'Done',
          ),
          children: <Widget>[
            AlembicSettingsInfoRow(
              title: 'Owner',
              value: owner,
              description: 'GitHub organization or user.',
            ),
            AlembicSettingsInfoRow(
              title: 'Visibility',
              value: visibility,
              description: 'Read-only repository metadata.',
            ),
            AlembicSettingsTextFieldRow(
              title: 'Open subdirectory',
              description:
                  'Alembic opens this relative path in your configured tools.',
              child: AlembicTextInput(
                controller: _pathController,
                placeholder: '/ or package/subdir',
              ),
            ),
            AlembicSettingsMenuRow<ApplicationTool>(
              title: 'Editor tool override',
              description: 'Use a different editor for this repository only.',
              valueLabel: _editorTool.displayName,
              items: XApplicationTool.supportedTools,
              itemLabel: (ApplicationTool tool) => tool.displayName,
              onSelected: (ApplicationTool tool) {
                setState(() {
                  _editorTool = tool;
                });
                setRepoConfig(
                  widget.repository,
                  getRepoConfig(widget.repository)..editorTool = tool,
                );
              },
            ),
            AlembicSettingsMenuRow<GitTool>(
              title: 'Git tool override',
              description:
                  'Use a different Git client for this repository only.',
              valueLabel: _gitTool.displayName,
              items: XGitTool.supportedTools,
              itemLabel: (GitTool tool) => tool.displayName,
              onSelected: (GitTool tool) {
                setState(() {
                  _gitTool = tool;
                });
                setRepoConfig(
                  widget.repository,
                  getRepoConfig(widget.repository)..gitTool = tool,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
