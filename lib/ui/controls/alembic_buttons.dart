import 'package:alembic/ui/alembic_tokens.dart';
import 'package:alembic/ui/controls/alembic_control_frame.dart';
import 'package:arcane/arcane.dart';
import 'package:flutter/material.dart' as m;

class AlembicToolbarButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool prominent;
  final bool destructive;
  final bool quiet;
  final bool compact;
  final bool iconOnly;
  final String? tooltip;

  const AlembicToolbarButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.prominent = false,
    this.destructive = false,
    this.quiet = false,
    this.compact = false,
    this.iconOnly = false,
    this.tooltip,
  }) : assert(!iconOnly || leadingIcon != null || trailingIcon != null);

  @override
  Widget build(BuildContext context) {
    Widget content = _buildContent();
    ButtonDensity density =
        compact ? ButtonDensity.compact : ButtonDensity.normal;
    Widget button = _buttonFor(
      context: context,
      content: content,
      density: density,
    );
    Widget sizedButton = AlembicControlFrame(
      compact: compact,
      iconOnly: iconOnly,
      child: button,
    );
    if (tooltip == null && !iconOnly) {
      return sizedButton;
    }
    return m.Tooltip(
      message: tooltip ?? label,
      child: sizedButton,
    );
  }

  Widget _buildContent() {
    if (iconOnly) {
      return m.Icon(leadingIcon ?? trailingIcon ?? m.Icons.circle, size: 16);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (leadingIcon != null) ...<Widget>[
          m.Icon(leadingIcon, size: 15),
          const Gap(AlembicShadcnTokens.gapSm),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailingIcon != null) ...<Widget>[
          const Gap(AlembicShadcnTokens.gapSm),
          m.Icon(trailingIcon, size: 15),
        ],
      ],
    );
  }

  Widget _buttonFor({
    required BuildContext context,
    required Widget content,
    required ButtonDensity density,
  }) {
    ButtonDensity resolvedDensity = iconOnly ? ButtonDensity.icon : density;
    Widget centered = iconOnly ? Center(child: content) : content;
    if (prominent) {
      return PrimaryButton(
        onPressed: onPressed,
        size: ButtonSize.small,
        density: resolvedDensity,
        child: centered,
      );
    }
    if (quiet) {
      return GhostButton(
        onPressed: onPressed,
        size: ButtonSize.small,
        density: resolvedDensity,
        child: centered,
      );
    }
    if (!destructive) {
      return OutlineButton(
        onPressed: onPressed,
        size: ButtonSize.small,
        density: resolvedDensity,
        child: centered,
      );
    }

    ThemeData theme = Theme.of(context);
    return m.DefaultTextStyle.merge(
      style: m.TextStyle(color: theme.colorScheme.destructive),
      child: IconTheme.merge(
        data: m.IconThemeData(color: theme.colorScheme.destructive),
        child: OutlineButton(
          onPressed: onPressed,
          size: ButtonSize.small,
          density: resolvedDensity,
          child: centered,
        ),
      ),
    );
  }
}
