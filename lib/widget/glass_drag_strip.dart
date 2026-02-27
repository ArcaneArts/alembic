import 'package:alembic/widget/glass_panel.dart';
import 'package:flutter/cupertino.dart';
import 'package:window_manager/window_manager.dart';

class GlassDragStrip extends StatelessWidget {
  final double height;

  const GlassDragStrip({
    super.key,
    this.height = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (alembicIsFlutterTestEnvironment()) {
      return SizedBox(height: height);
    }

    return SizedBox(
      height: height,
      child: const DragToMoveArea(
        child: SizedBox.expand(),
      ),
    );
  }
}
