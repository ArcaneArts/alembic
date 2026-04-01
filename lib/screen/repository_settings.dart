import 'package:alembic/app/alembic_scaffold.dart';
import 'package:alembic/app/alembic_tokens.dart';
import 'package:alembic/app/alembic_widgets.dart';
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: AlembicPanel(
              child: m.ListView(
                shrinkWrap: true,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: AlembicSectionHeader(
                          title: 'Repository Settings',
                          subtitle: widget.repository.fullName,
                        ),
                      ),
                      AlembicToolbarButton(
                        onPressed: () => Navigator.of(context).pop(),
                        label: 'Done',
                      ),
                    ],
                  ),
                  const Gap(AlembicShadcnTokens.gapLg),
                  _RepositoryInfoRow(
                    title: 'Owner',
                    value: owner,
                    description: 'GitHub organization or user.',
                  ),
                  const Divider(),
                  _RepositoryInfoRow(
                    title: 'Visibility',
                    value: visibility,
                    description: 'Read-only repository metadata.',
                  ),
                  const Divider(),
                  AlembicLabeledField(
                    label: 'Open subdirectory',
                    supportingText:
                        'Alembic opens this relative path in your configured tools.',
                    child: AlembicTextInput(
                      controller: _pathController,
                      placeholder: '/ or package/subdir',
                    ),
                  ),
                  const Gap(AlembicShadcnTokens.gapLg),
                  _RepositoryMenuRow<ApplicationTool>(
                    title: 'Editor tool override',
                    description:
                        'Use a different editor for this repository only.',
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
                  const Divider(),
                  _RepositoryMenuRow<GitTool>(
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
          ),
        ),
      ),
    );
  }
}

class _RepositoryInfoRow extends StatelessWidget {
  final String title;
  final String description;
  final String value;

  const _RepositoryInfoRow({
    required this.title,
    required this.description,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).typography.small.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Gap(4),
              Text(
                description,
                style: Theme.of(context).typography.xSmall.copyWith(
                      color: Theme.of(context).colorScheme.mutedForeground,
                    ),
              ),
            ],
          ),
        ),
        const Gap(12),
        Text(value, style: Theme.of(context).typography.small),
      ],
    );
  }
}

class _RepositoryMenuRow<T> extends StatelessWidget {
  final String title;
  final String description;
  final String valueLabel;
  final List<T> items;
  final String Function(T item) itemLabel;
  final ValueChanged<T> onSelected;

  const _RepositoryMenuRow({
    required this.title,
    required this.description,
    required this.valueLabel,
    required this.items,
    required this.itemLabel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    List<AlembicDropdownOption<T>> options = <AlembicDropdownOption<T>>[
      for (T item in items)
        AlembicDropdownOption<T>(
          value: item,
          label: itemLabel(item),
        ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).typography.small.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Gap(4),
              Text(
                description,
                style: Theme.of(context).typography.xSmall.copyWith(
                      color: Theme.of(context).colorScheme.mutedForeground,
                    ),
              ),
            ],
          ),
        ),
        const Gap(12),
        AlembicSelect<T>(
          value: items.firstWhere((T item) => itemLabel(item) == valueLabel),
          options: options,
          onChanged: onSelected,
        ),
      ],
    );
  }
}
