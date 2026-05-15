import 'package:alembic/ui/alembic_ui.dart';
import 'package:alembic/util/clone_transport.dart';
import 'package:alembic/util/extensions.dart';
import 'package:alembic/util/git_signing.dart';
import 'package:alembic/util/repo_config.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

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
        const _SshSigningExample(),
      ],
    );
  }
}

class _SshSigningExample extends StatelessWidget {
  static const String _commands = '''
ssh-keygen -t ed25519 -C "you@example.com"
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
pbcopy < ~/.ssh/id_ed25519.pub
ssh -T git@github.com''';

  const _SshSigningExample();

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'SSH signing setup',
          style: theme.typography.small.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Gap(AlembicShadcnTokens.gapXs),
        Text(
          'Generate an Ed25519 key, point Git signing at the public key, then add that public key to GitHub as a Signing key.',
          style: theme.typography.xSmall.copyWith(
            color: theme.colorScheme.mutedForeground,
          ),
        ),
        const Gap(AlembicShadcnTokens.gapSm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AlembicShadcnTokens.gapMd),
          decoration: BoxDecoration(
            color: m.Color.alphaBlend(
              theme.colorScheme.muted.withValues(alpha: 0.28),
              theme.colorScheme.card,
            ),
            borderRadius: BorderRadius.circular(
              AlembicShadcnTokens.controlRadius,
            ),
            border: Border.all(color: theme.colorScheme.border),
          ),
          child: m.SelectableText(
            _commands,
            style: theme.typography.xSmall.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.foreground,
              height: 1.45,
            ),
          ),
        ),
        const Gap(AlembicShadcnTokens.gapSm),
        Text(
          'GitHub path: Settings > SSH and GPG keys > New SSH key > Key type: Signing Key.',
          style: theme.typography.xSmall.copyWith(
            color: theme.colorScheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}
