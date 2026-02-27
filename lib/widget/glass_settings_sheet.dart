import 'package:alembic/theme/alembic_tokens.dart';
import 'package:alembic/widget/glass_button.dart';
import 'package:alembic/widget/glass_drag_strip.dart';
import 'package:alembic/widget/glass_icon_button.dart';
import 'package:alembic/widget/glass_panel.dart';
import 'package:alembic/widget/glass_switch.dart';
import 'package:flutter/cupertino.dart';

class GlassSettingsSheetScaffold extends StatelessWidget {
  static const double outerRadius = 28;
  static const double sheetPadding = 16;

  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback onClosePressed;
  final VoidCallback onFooterPressed;
  final String footerLabel;
  final bool showDragStrip;

  const GlassSettingsSheetScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onClosePressed,
    required this.onFooterPressed,
    this.footerLabel = 'Done',
    this.showDragStrip = false,
  });

  @override
  Widget build(BuildContext context) {
    AlembicTokens tokens = context.alembicTokens;
    double fillAlpha =
        (tokens.overlayFillOpacity + 0.08).clamp(0.0, 1.0).toDouble();

    Widget sheet = GlassPanel(
      role: GlassPanelRole.overlay,
      borderRadius: BorderRadius.circular(outerRadius),
      fillColor: tokens.overlayFill.withValues(alpha: fillAlpha),
      padding: const EdgeInsets.all(sheetPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null) const SizedBox(height: 4),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: tokens.textSecondary.withValues(alpha: 0.92),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GlassIconButton(
                icon: CupertinoIcons.xmark,
                onPressed: onClosePressed,
                semanticLabel: 'Close',
                size: 34,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 6),
              child: child,
            ),
          ),
          const SizedBox(height: 10),
          GlassButton(
            label: footerLabel,
            onPressed: onFooterPressed,
            kind: GlassButtonKind.primary,
          ),
        ],
      ),
    );

    if (!showDragStrip) {
      return sheet;
    }

    return Column(
      children: <Widget>[
        const GlassDragStrip(height: 15),
        const SizedBox(height: 4),
        Expanded(child: sheet),
      ],
    );
  }
}

class GlassSettingsSection extends StatelessWidget {
  static const double sectionRadius = 16;

  final String title;
  final List<Widget> children;

  const GlassSettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    AlembicTokens tokens = context.alembicTokens;
    List<Widget> content = <Widget>[];

    for (int index = 0; index < children.length; index++) {
      content.add(children[index]);
      if (index < children.length - 1) {
        content.add(
          Container(
            height: 1,
            color: tokens.stroke.withValues(alpha: 0.24),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        GlassPanel(
          role: GlassPanelRole.inline,
          borderRadius: BorderRadius.circular(sectionRadius),
          fillColor: tokens.overlayFill.withValues(alpha: 0.34),
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: content,
          ),
        ),
      ],
    );
  }
}

class GlassSettingsActionRow extends StatefulWidget {
  final String label;
  final String? value;
  final String? supportingText;
  final VoidCallback? onPressed;
  final IconData trailingIcon;

  const GlassSettingsActionRow({
    super.key,
    required this.label,
    required this.value,
    this.supportingText,
    this.onPressed,
    this.trailingIcon = CupertinoIcons.chevron_forward,
  });

  @override
  State<GlassSettingsActionRow> createState() => _GlassSettingsActionRowState();
}

class _GlassSettingsActionRowState extends State<GlassSettingsActionRow> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    AlembicTokens tokens = context.alembicTokens;
    bool enabled = widget.onPressed != null;
    double rowAlpha = _pressed ? 0.46 : (_hovered ? 0.40 : 0.28);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: tokens.inlineFill.withValues(alpha: rowAlpha),
            border: Border.all(
              color: tokens.stroke.withValues(alpha: 0.24),
              width: 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (widget.supportingText != null)
                      const SizedBox(height: 2),
                    if (widget.supportingText != null)
                      Text(
                        widget.supportingText!,
                        style: TextStyle(
                          color: tokens.textSecondary.withValues(alpha: 0.86),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.value != null) const SizedBox(width: 10),
              if (widget.value != null)
                Flexible(
                  child: Text(
                    widget.value!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: tokens.textSecondary.withValues(alpha: 0.90),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (enabled) const SizedBox(width: 8),
              if (enabled)
                Icon(
                  widget.trailingIcon,
                  size: 14,
                  color: tokens.textSecondary.withValues(alpha: 0.84),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class GlassSettingsToggleRow extends StatefulWidget {
  final String label;
  final String? supportingText;
  final bool value;
  final ValueChanged<bool> onChanged;

  const GlassSettingsToggleRow({
    super.key,
    required this.label,
    this.supportingText,
    required this.value,
    required this.onChanged,
  });

  @override
  State<GlassSettingsToggleRow> createState() => _GlassSettingsToggleRowState();
}

class _GlassSettingsToggleRowState extends State<GlassSettingsToggleRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    AlembicTokens tokens = context.alembicTokens;
    double rowAlpha = _hovered ? 0.40 : 0.28;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onChanged(!widget.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: tokens.inlineFill.withValues(alpha: rowAlpha),
            border: Border.all(
              color: tokens.stroke.withValues(alpha: 0.24),
              width: 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (widget.supportingText != null)
                      const SizedBox(height: 2),
                    if (widget.supportingText != null)
                      Text(
                        widget.supportingText!,
                        style: TextStyle(
                          color: tokens.textSecondary.withValues(alpha: 0.86),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              GlassSwitch(
                value: widget.value,
                onChanged: widget.onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GlassSettingsFieldRow extends StatefulWidget {
  final String label;
  final String? supportingText;
  final Widget child;

  const GlassSettingsFieldRow({
    super.key,
    required this.label,
    this.supportingText,
    required this.child,
  });

  @override
  State<GlassSettingsFieldRow> createState() => _GlassSettingsFieldRowState();
}

class _GlassSettingsFieldRowState extends State<GlassSettingsFieldRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    AlembicTokens tokens = context.alembicTokens;
    double rowAlpha = _hovered ? 0.40 : 0.28;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: tokens.inlineFill.withValues(alpha: rowAlpha),
          border: Border.all(
            color: tokens.stroke.withValues(alpha: 0.24),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.label,
              style: TextStyle(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            if (widget.supportingText != null) const SizedBox(height: 2),
            if (widget.supportingText != null)
              Text(
                widget.supportingText!,
                style: TextStyle(
                  color: tokens.textSecondary.withValues(alpha: 0.86),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 8),
            widget.child,
          ],
        ),
      ),
    );
  }
}
