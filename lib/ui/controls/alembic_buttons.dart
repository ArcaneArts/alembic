import 'package:alembic/ui/alembic_tokens.dart';
import 'package:alembic/ui/controls/alembic_control_frame.dart';
import 'package:alembic/ui/controls/alembic_progress.dart';
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
  final bool busy;
  final bool smallLabel;
  final bool expand;
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
    this.busy = false,
    this.smallLabel = false,
    this.expand = false,
    this.tooltip,
  }) : assert(!iconOnly || leadingIcon != null || trailingIcon != null);

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    _AlembicButtonTone tone = _toneFor();
    Widget content = _buildContent(context);
    Widget button = _AlembicButtonSurface(
      onPressed: busy ? null : onPressed,
      height: iconOnly
          ? AlembicShadcnTokens.iconButtonSize
          : compact
              ? AlembicShadcnTokens.compactButtonHeight
              : AlembicShadcnTokens.controlHeight,
      padding: iconOnly
          ? EdgeInsets.zero
          : compact
              ? AlembicShadcnTokens.compactControlPadding
              : AlembicShadcnTokens.controlPadding,
      borderRadius: AlembicShadcnTokens.controlRadius,
      foreground: tone.foreground(theme),
      background: tone.background(theme),
      border: tone.border(theme),
      disabledForeground: theme.colorScheme.mutedForeground,
      disabledBackground: tone.disabledBackground(theme),
      expand: expand,
      child: content,
    );
    Widget sizedButton = AlembicControlFrame(
      compact: compact,
      iconOnly: iconOnly,
      child: button,
    );
    Widget framed = tooltip == null && !iconOnly
        ? sizedButton
        : m.Tooltip(
            message: tooltip ?? label,
            child: sizedButton,
          );
    if (expand) {
      return framed;
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      heightFactor: 1,
      child: framed,
    );
  }

  _AlembicButtonTone _toneFor() {
    if (prominent) {
      return _AlembicButtonTone.primary;
    }
    if (quiet) {
      return _AlembicButtonTone.ghost;
    }
    if (destructive) {
      return _AlembicButtonTone.destructive;
    }
    return _AlembicButtonTone.outline;
  }

  Widget _buildContent(BuildContext context) {
    if (busy) {
      return _AlembicButtonBusyContent(
        label: label,
        iconOnly: iconOnly,
      );
    }
    if (iconOnly) {
      return m.Icon(leadingIcon ?? trailingIcon ?? m.Icons.circle, size: 16);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (leadingIcon != null) ...<Widget>[
          m.Icon(leadingIcon, size: smallLabel ? 13 : 15),
          Gap(
            smallLabel ? AlembicShadcnTokens.gapXs : AlembicShadcnTokens.gapSm,
          ),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: smallLabel ? const TextStyle(fontSize: 11) : null,
          ),
        ),
        if (trailingIcon != null) ...<Widget>[
          Gap(
            smallLabel ? AlembicShadcnTokens.gapXs : AlembicShadcnTokens.gapSm,
          ),
          m.Icon(trailingIcon, size: smallLabel ? 13 : 15),
        ],
      ],
    );
  }
}

class AlembicSelectionToggle extends StatelessWidget {
  final bool selected;
  final ValueChanged<bool>? onChanged;
  final String label;
  final double size;

  const AlembicSelectionToggle({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.label,
    this.size = AlembicShadcnTokens.compactIconButtonSize,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    _AlembicButtonTone tone =
        selected ? _AlembicButtonTone.primary : _AlembicButtonTone.outline;
    double scale = size / AlembicShadcnTokens.compactIconButtonSize;
    return SizedBox.square(
      dimension: size,
      child: m.Tooltip(
        message: label,
        child: _AlembicButtonSurface(
          onPressed: onChanged == null ? null : () => onChanged!(!selected),
          height: size,
          padding: EdgeInsets.zero,
          borderRadius: AlembicShadcnTokens.controlRadius * scale,
          foreground: tone.foreground(theme),
          background: tone.background(theme),
          border: tone.border(theme),
          disabledForeground: theme.colorScheme.mutedForeground,
          disabledBackground: tone.disabledBackground(theme),
          child: m.Icon(
            selected ? m.Icons.check : m.Icons.check_box_outline_blank,
            size: 16 * scale,
          ),
        ),
      ),
    );
  }
}

enum _AlembicButtonTone {
  primary,
  outline,
  ghost,
  destructive;

  m.Color background(ThemeData theme) => switch (this) {
        _AlembicButtonTone.primary => theme.colorScheme.primary,
        _AlembicButtonTone.outline => theme.colorScheme.card,
        _AlembicButtonTone.ghost => m.Colors.transparent,
        _AlembicButtonTone.destructive => theme.colorScheme.card,
      };

  m.Color foreground(ThemeData theme) => switch (this) {
        _AlembicButtonTone.primary => theme.colorScheme.primaryForeground,
        _AlembicButtonTone.outline => theme.colorScheme.foreground,
        _AlembicButtonTone.ghost => theme.colorScheme.foreground,
        _AlembicButtonTone.destructive => theme.colorScheme.destructive,
      };

  m.Color border(ThemeData theme) => switch (this) {
        _AlembicButtonTone.primary => theme.colorScheme.primary,
        _AlembicButtonTone.outline => theme.colorScheme.border,
        _AlembicButtonTone.ghost => m.Colors.transparent,
        _AlembicButtonTone.destructive => theme.colorScheme.border,
      };

  m.Color disabledBackground(ThemeData theme) => switch (this) {
        _AlembicButtonTone.primary => theme.colorScheme.muted,
        _AlembicButtonTone.outline => theme.colorScheme.card,
        _AlembicButtonTone.ghost => m.Colors.transparent,
        _AlembicButtonTone.destructive => theme.colorScheme.card,
      };
}

class _AlembicButtonSurface extends StatelessWidget {
  final VoidCallback? onPressed;
  final double height;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final m.Color foreground;
  final m.Color background;
  final m.Color border;
  final m.Color disabledForeground;
  final m.Color disabledBackground;
  final bool expand;
  final Widget child;

  const _AlembicButtonSurface({
    required this.onPressed,
    required this.height,
    required this.padding,
    required this.borderRadius,
    required this.foreground,
    required this.background,
    required this.border,
    required this.disabledForeground,
    required this.disabledBackground,
    this.expand = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    bool enabled = onPressed != null;
    m.Color resolvedForeground = enabled ? foreground : disabledForeground;
    m.Color resolvedBackground = enabled ? background : disabledBackground;
    m.Color resolvedBorder = enabled ? border : border.withValues(alpha: 0.7);
    return m.Material(
      color: m.Colors.transparent,
      child: m.InkWell(
        onTap: onPressed,
        canRequestFocus: false,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: resolvedBackground,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: resolvedBorder),
          ),
          child: Center(
            widthFactor: expand ? null : 1,
            child: IconTheme.merge(
              data: m.IconThemeData(color: resolvedForeground),
              child: m.DefaultTextStyle.merge(
                style: TextStyle(
                  color: resolvedForeground,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlembicButtonBusyContent extends StatelessWidget {
  final String label;
  final bool iconOnly;

  const _AlembicButtonBusyContent({
    required this.label,
    required this.iconOnly,
  });

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color color = m.DefaultTextStyle.of(context).style.color ??
        theme.colorScheme.foreground;
    Widget mark = AlembicProgressMark(
      color: color,
    );
    if (iconOnly) {
      return mark;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        mark,
        const Gap(AlembicShadcnTokens.gapSm),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
