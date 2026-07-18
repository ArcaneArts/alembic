import 'package:alembic/core/update_status.dart';
import 'package:alembic/main.dart';
import 'package:alembic/screen/settings/accounts_pane.dart';
import 'package:alembic/screen/settings/advanced_pane.dart';
import 'package:alembic/screen/settings/archive_master_pane.dart';
import 'package:alembic/screen/settings/diagnostics_pane.dart';
import 'package:alembic/screen/settings/general_pane.dart';
import 'package:alembic/screen/settings/settings_types.dart';
import 'package:alembic/screen/settings/tools_pane.dart';
import 'package:alembic/screen/settings/updates_pane.dart';
import 'package:alembic/screen/settings/workspace_pane.dart';
import 'package:alembic/ui/alembic_ui.dart';
import 'package:alembic/util/clone_transport.dart';
import 'package:alembic/util/git_signing.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

class SettingsSidebar extends StatelessWidget {
  final SettingsPane pane;
  final ValueChanged<SettingsPane> onSelected;

  const SettingsSidebar({
    super.key,
    required this.pane,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<UpdateSnapshot>(
        stream: updateController.stream,
        initialData: updateController.value,
        builder: (context, snapshot) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (SettingsPane item in SettingsPane.values) ...<Widget>[
              if (item != SettingsPane.values.first) const Gap(2),
              _SettingsSidebarItem(
                item: item,
                selected: item == pane,
                showUpdateDot: item == SettingsPane.updates &&
                    (snapshot.data?.updateAvailable ?? false),
                onPressed: () => onSelected(item),
              ),
            ],
          ],
        ),
      );
}

class _SettingsSidebarItem extends StatefulWidget {
  final SettingsPane item;
  final bool selected;
  final bool showUpdateDot;
  final VoidCallback onPressed;

  const _SettingsSidebarItem({
    required this.item,
    required this.selected,
    required this.showUpdateDot,
    required this.onPressed,
  });

  @override
  State<_SettingsSidebarItem> createState() => _SettingsSidebarItemState();
}

class _SettingsSidebarItemState extends State<_SettingsSidebarItem> {
  static const double _height = 34;
  static const double _dotSize = 7;
  static const m.Color _dotColor = m.Color(0xFFF0A32E);

  bool _hovered = false;

  BoxDecoration _decorationFor(ThemeData theme) {
    bool isDark = theme.colorScheme.brightness == Brightness.dark;
    Color selectedShadow = isDark
        ? m.Colors.black.withValues(alpha: 0.30)
        : m.Colors.black.withValues(alpha: 0.08);
    Color fill = widget.selected
        ? theme.colorScheme.card
        : _hovered
            ? theme.colorScheme.secondary
            : m.Colors.transparent;
    return BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(AlembicShadcnTokens.controlRadius),
      border: Border.all(
        color:
            widget.selected ? theme.colorScheme.border : m.Colors.transparent,
      ),
      boxShadow: widget.selected
          ? <BoxShadow>[
              BoxShadow(
                color: selectedShadow,
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ]
          : const <BoxShadow>[],
    );
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color foreground = widget.selected
        ? theme.colorScheme.foreground
        : theme.colorScheme.mutedForeground;
    return m.Material(
      color: m.Colors.transparent,
      child: m.InkWell(
        onTap: widget.onPressed,
        onHover: (value) => setState(() => _hovered = value),
        canRequestFocus: false,
        hoverColor: m.Colors.transparent,
        borderRadius: BorderRadius.circular(AlembicShadcnTokens.controlRadius),
        child: Container(
          height: _height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: _decorationFor(theme),
          child: Row(
            children: <Widget>[
              m.Icon(widget.item.iconData, size: 16, color: foreground),
              const Gap(AlembicShadcnTokens.gapSm),
              Expanded(
                child: Text(
                  widget.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.small.copyWith(
                    color: foreground,
                    fontWeight:
                        widget.selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              if (widget.showUpdateDot) ...<Widget>[
                const Gap(AlembicShadcnTokens.gapSm),
                const SizedBox.square(
                  dimension: _dotSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsContent extends StatelessWidget {
  final SettingsPane pane;
  final m.TextEditingController archiveDaysController;
  final CloneTransportMode cloneTransportMode;
  final bool signingBusy;
  final GitSigningStatus? signingStatus;
  final SelectDirectoryCallback onSelectDirectory;
  final ValueChanged<CloneTransportMode> onCloneTransportChanged;
  final Future<void> Function() onConfigureCommitSigning;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback? onLogout;

  const SettingsContent({
    super.key,
    required this.pane,
    required this.archiveDaysController,
    required this.cloneTransportMode,
    required this.signingBusy,
    required this.signingStatus,
    required this.onSelectDirectory,
    required this.onCloneTransportChanged,
    required this.onConfigureCommitSigning,
    required this.onThemeModeChanged,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return switch (pane) {
      SettingsPane.general => GeneralSettingsPane(
          onThemeModeChanged: onThemeModeChanged,
        ),
      SettingsPane.updates => const UpdatesSettingsPane(),
      SettingsPane.workspace => WorkspaceSettingsPane(
          archiveDaysController: archiveDaysController,
          onSelectDirectory: onSelectDirectory,
        ),
      SettingsPane.tools => ToolsSettingsPane(
          cloneTransportMode: cloneTransportMode,
          signingBusy: signingBusy,
          signingStatus: signingStatus,
          onCloneTransportChanged: onCloneTransportChanged,
          onConfigureCommitSigning: onConfigureCommitSigning,
        ),
      SettingsPane.archiveMaster => const ArchiveMasterSettingsPane(),
      SettingsPane.accounts => AccountsSettingsPane(
          onLogout: onLogout,
        ),
      SettingsPane.advanced => const AdvancedSettingsPane(),
      SettingsPane.diagnostics => const DiagnosticsSettingsPane(),
    };
  }
}
