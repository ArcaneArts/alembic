import 'package:alembic/theme/alembic_motion.dart';
import 'package:alembic/theme/alembic_tokens.dart';
import 'package:alembic/widget/glass_panel.dart';
import 'package:flutter/cupertino.dart';

class GlassSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const GlassSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    AlembicTokens tokens = context.alembicTokens;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: SizedBox(
        width: 52,
        height: 30,
        child: GlassPanel(
          role: GlassPanelRole.inline,
          borderRadius: BorderRadius.circular(18),
          fillColor: tokens.inlineFill.withValues(
            alpha: value
                ? tokens.inlineFillOpacity + 0.03
                : tokens.inlineFillOpacity,
          ),
          padding: const EdgeInsets.all(3),
          child: AnimatedAlign(
            duration: AlembicMotion.chip,
            curve: AlembicMotion.standard,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: SizedBox(
              width: 24,
              height: 24,
              child: GlassPanel(
                role: GlassPanelRole.control,
                borderRadius: BorderRadius.circular(12),
                fillColor: tokens.controlFill
                    .withValues(alpha: tokens.controlFillOpacity + 0.03),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
