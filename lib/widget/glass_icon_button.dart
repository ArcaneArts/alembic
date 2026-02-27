import 'package:alembic/theme/alembic_motion.dart';
import 'package:alembic/theme/alembic_tokens.dart';
import 'package:alembic/widget/glass_panel.dart';
import 'package:flutter/cupertino.dart';

class GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final double size;
  final Color? iconColor;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
    this.size = 34,
    this.iconColor,
  });

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    AlembicTokens tokens = context.alembicTokens;
    bool enabled = widget.onPressed != null;
    double scale = _pressed ? 0.96 : (_hovered ? 1.03 : 1);
    double opacity = enabled ? 1 : 0.46;

    double fillOpacity = tokens.controlFillOpacity + (_hovered ? 0.02 : 0.0);

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
        onTap: enabled ? widget.onPressed : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          curve: _pressed ? Curves.easeInOutCubic : Curves.easeOutBack,
          child: AnimatedOpacity(
            opacity: opacity,
            duration: AlembicMotion.content,
            curve: AlembicMotion.standard,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: GlassPanel(
                role: GlassPanelRole.control,
                borderRadius: BorderRadius.circular(widget.size * 0.5),
                fillColor: tokens.controlFill.withValues(alpha: fillOpacity),
                child: Center(
                  child: Icon(
                    widget.icon,
                    size: widget.size * 0.5,
                    semanticLabel: widget.semanticLabel,
                    color: widget.iconColor ?? tokens.textSecondary,
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
