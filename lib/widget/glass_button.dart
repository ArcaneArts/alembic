import 'package:alembic/theme/alembic_motion.dart';
import 'package:alembic/theme/alembic_tokens.dart';
import 'package:alembic/widget/glass_panel.dart';
import 'package:flutter/cupertino.dart';

enum GlassButtonKind { primary, secondary, destructive }

class GlassButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final GlassButtonKind kind;
  final EdgeInsetsGeometry padding;

  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = GlassButtonKind.secondary,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    AlembicTokens tokens = context.alembicTokens;
    bool enabled = widget.onPressed != null;

    Color textColor = switch (widget.kind) {
      GlassButtonKind.primary => tokens.textPrimary,
      GlassButtonKind.secondary => tokens.textPrimary,
      GlassButtonKind.destructive => tokens.danger,
    };

    Color fillBase = switch (widget.kind) {
      GlassButtonKind.primary => tokens.controlFill,
      GlassButtonKind.secondary => tokens.inlineFill,
      GlassButtonKind.destructive => tokens.inlineFill,
    };

    double fillOpacity = switch (widget.kind) {
      GlassButtonKind.primary => tokens.controlFillOpacity + 0.03,
      GlassButtonKind.secondary => tokens.inlineFillOpacity,
      GlassButtonKind.destructive => tokens.inlineFillOpacity,
    };

    if (_hovered) {
      fillOpacity += 0.02;
    }
    if (_pressed) {
      fillOpacity += 0.04;
    }

    double scale = _pressed ? 0.98 : (_hovered ? 1.01 : 1);
    double opacity = enabled ? 1 : 0.48;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? widget.onPressed : null,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          scale: scale,
          duration: AlembicMotion.hover,
          curve: AlembicMotion.standard,
          child: AnimatedOpacity(
            opacity: opacity,
            duration: AlembicMotion.content,
            curve: AlembicMotion.standard,
            child: SizedBox(
              height: 40,
              child: GlassPanel(
                role: GlassPanelRole.control,
                borderRadius: BorderRadius.circular(13),
                fillColor: fillBase.withValues(alpha: fillOpacity),
                child: Center(
                  child: Padding(
                    padding: widget.padding,
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
