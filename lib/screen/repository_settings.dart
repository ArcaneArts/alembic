import 'package:alembic/util/extensions.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:alembic/widget/glass_context_menu.dart';
import 'package:alembic/widget/glass_modal_overlay.dart';
import 'package:alembic/widget/glass_settings_sheet.dart';
import 'package:alembic/widget/glass_shell.dart';
import 'package:alembic/widget/glass_text_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:github/github.dart';

Future<void> showRepositorySettingsModal(
  BuildContext context,
  Repository repository,
) async {
  await showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x00000000),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, __) {
      return SafeArea(
        child: GlassModalOverlay(
          mode: GlassModalFocusMode.blurAndDim,
          blurSigmaMultiplier: 2.40,
          dimStrengthOverride: 0.04,
          whiteLiftStrengthOverride: 0.30,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 680,
              maxHeight: 760,
            ),
            child: RepositorySettings(
              repository: repository,
              modal: true,
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      CurvedAnimation fadeCurve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      CurvedAnimation scaleCurve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: fadeCurve,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.93, end: 1).animate(scaleCurve),
          child: child,
        ),
      );
    },
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
  late TextEditingController _pathController;
  late ApplicationTool _editorTool;
  late GitTool _gitTool;

  @override
  void initState() {
    super.initState();
    AlembicRepoConfig repoConfig = getRepoConfig(widget.repository);
    _pathController = TextEditingController(text: repoConfig.openDirectory);
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

  Future<void> _pickEditorTool() async {
    ApplicationTool? selected = await GlassContextMenu.show<ApplicationTool>(
      context,
      title: 'Editor Tool',
      actions: ApplicationTool.values.map((tool) {
        return GlassMenuAction<ApplicationTool>(
          value: tool,
          title: tool.displayName,
        );
      }).toList(),
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _editorTool = selected;
    });
    setRepoConfig(
      widget.repository,
      getRepoConfig(widget.repository)..editorTool = selected,
    );
  }

  Future<void> _pickGitTool() async {
    GitTool? selected = await GlassContextMenu.show<GitTool>(
      context,
      title: 'Git Tool',
      actions: GitTool.values.map((tool) {
        return GlassMenuAction<GitTool>(
          value: tool,
          title: tool.displayName,
        );
      }).toList(),
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _gitTool = selected;
    });
    setRepoConfig(
      widget.repository,
      getRepoConfig(widget.repository)..gitTool = selected,
    );
  }

  @override
  Widget build(BuildContext context) {
    String owner = widget.repository.owner?.login ?? 'Unknown';
    String visibility =
        widget.repository.isPrivate == true ? 'Private' : 'Public';

    Widget sheet = GlassSettingsSheetScaffold(
      title: 'Repository Settings',
      subtitle: widget.repository.fullName,
      onClosePressed: () => Navigator.of(context).pop(),
      onFooterPressed: () => Navigator.of(context).pop(),
      footerLabel: 'Done',
      showDragStrip: !widget.modal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GlassSettingsSection(
            title: 'Repository',
            children: <Widget>[
              GlassSettingsActionRow(
                label: 'Owner',
                value: owner,
                supportingText: 'GitHub organization or user.',
                onPressed: null,
              ),
              GlassSettingsActionRow(
                label: 'Visibility',
                value: visibility,
                supportingText: 'Read-only repository metadata.',
                onPressed: null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          GlassSettingsSection(
            title: 'Workspace',
            children: <Widget>[
              GlassSettingsFieldRow(
                label: 'Open Subdirectory',
                supportingText:
                    'Subdirectory Alembic opens in your selected tools.',
                child: GlassTextField(
                  controller: _pathController,
                  placeholder: '/ or package/subdir',
                  prefix: const Icon(
                    CupertinoIcons.folder,
                    size: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GlassSettingsSection(
            title: 'Tool Overrides',
            children: <Widget>[
              GlassSettingsActionRow(
                label: 'Editor Tool',
                value: _editorTool.displayName,
                supportingText: 'Override editor for this repository only.',
                onPressed: _pickEditorTool,
              ),
              GlassSettingsActionRow(
                label: 'Git Tool',
                value: _gitTool.displayName,
                supportingText: 'Override Git client for this repository only.',
                onPressed: _pickGitTool,
              ),
            ],
          ),
        ],
      ),
    );

    if (widget.modal) {
      return sheet;
    }

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.transparent,
      child: GlassShell(
        safeArea: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
          child: sheet,
        ),
      ),
    );
  }
}
