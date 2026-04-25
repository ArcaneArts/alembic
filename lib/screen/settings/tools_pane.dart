import 'package:alembic/ui/alembic_ui.dart';
import 'package:alembic/util/clone_transport.dart';
import 'package:alembic/util/extensions.dart';
import 'package:alembic/util/git_signing.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:arcane/arcane.dart';

class ToolsSettingsPane extends StatelessWidget {
  final CloneTransportMode cloneTransportMode;
  final bool signingBusy;
  final GitSigningStatus? signingStatus;
  final ValueChanged<CloneTransportMode> onCloneTransportChanged;
  final Future<void> Function() onConfigureCommitSigning;

  const ToolsSettingsPane({
    super.key,
    required this.cloneTransportMode,
    required this.signingBusy,
    required this.signingStatus,
    required this.onCloneTransportChanged,
    required this.onConfigureCommitSigning,
  });

  String _commitSigningLabel() {
    if (signingBusy) {
      return 'Configuring...';
    }
    return signingStatus?.label ?? 'Checking...';
  }

  @override
  Widget build(BuildContext context) {
    return AlembicSettingsPane(
      title: 'Tools',
      subtitle: 'Editor launchers, Git clients, and signing defaults.',
      children: <Widget>[
        AlembicSettingsMenuRow<ApplicationTool>(
          title: 'Editor tool',
          description: 'Default editor for opening repositories.',
          valueLabel:
              (config.editorTool ?? ApplicationTool.intellij).displayName,
          items: XApplicationTool.supportedTools,
          itemLabel: (ApplicationTool tool) => tool.displayName,
          onSelected: (ApplicationTool tool) {
            setConfig(config..editorTool = tool);
            (context as Element).markNeedsBuild();
          },
        ),
        AlembicSettingsMenuRow<GitTool>(
          title: 'Git tool',
          description: 'Default Git client for repository launch actions.',
          valueLabel: (config.gitTool ?? GitTool.gitkraken).displayName,
          items: XGitTool.supportedTools,
          itemLabel: (GitTool tool) => tool.displayName,
          onSelected: (GitTool tool) {
            setConfig(config..gitTool = tool);
            (context as Element).markNeedsBuild();
          },
        ),
        AlembicSettingsMenuRow<CloneTransportMode>(
          title: 'Clone transport',
          description: 'Preferred transport when Alembic clones repositories.',
          valueLabel: cloneTransportMode.label,
          items: CloneTransportMode.values,
          itemLabel: (CloneTransportMode mode) => mode.label,
          onSelected: onCloneTransportChanged,
        ),
        AlembicSettingsActionRow(
          title: 'Commit signing',
          description: 'Configure global intrinsic SSH commit signing.',
          value: _commitSigningLabel(),
          actionLabel: signingBusy ? 'Working...' : 'Configure',
          onPressed: signingBusy ? null : onConfigureCommitSigning,
        ),
      ],
    );
  }
}
