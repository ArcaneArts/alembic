import 'package:alembic/theme/alembic_tokens.dart';
import 'package:alembic/widget/glass_panel.dart';
import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart' as lgr;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

class GlassSegment<T> {
  final T value;
  final String label;

  const GlassSegment({
    required this.value,
    required this.label,
  });
}

class GlassSegmentedControl<T> extends StatelessWidget {
  final T value;
  final List<GlassSegment<T>> segments;
  final ValueChanged<T> onChanged;

  const GlassSegmentedControl({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  int _selectedIndex() {
    int index = segments.indexWhere((segment) => segment.value == value);
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    AlembicTokens tokens = context.alembicTokens;
    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }

    int selectedIndex = _selectedIndex();
    if (alembicIsFlutterTestEnvironment()) {
      return _FallbackSegmentedControl<T>(
        value: value,
        segments: segments,
        onChanged: onChanged,
      );
    }

    List<String> labels = segments.map((segment) => segment.label).toList();
    lgr.LiquidGlassSettings indicatorSettings = lgr.LiquidGlassSettings(
      glassColor: tokens.controlFill.withValues(alpha: 0.14),
      thickness: 22,
      blur: 0,
      chromaticAberration: 0.5,
      lightIntensity: 2.2,
      ambientStrength: 0.22,
      refractiveIndex: 1.18,
      saturation: 1.12,
    );

    return SizedBox(
      height: 40,
      child: lgw.GlassSegmentedControl(
        segments: labels,
        selectedIndex: selectedIndex,
        onSegmentSelected: (index) {
          if (index < 0 || index >= segments.length) {
            return;
          }
          T nextValue = segments[index].value;
          if (nextValue != value) {
            onChanged(nextValue);
          }
        },
        quality: lgw.GlassQuality.premium,
        height: 40,
        borderRadius: tokens.radiusLarge,
        padding: const EdgeInsets.all(2),
        backgroundColor: tokens.inlineFill.withValues(
          alpha: (tokens.inlineFillOpacity + 0.08).clamp(0.0, 1.0),
        ),
        indicatorColor: tokens.controlFill.withValues(alpha: 0.26),
        selectedTextStyle: TextStyle(
          color: tokens.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedTextStyle: TextStyle(
          color: tokens.textSecondary.withValues(alpha: 0.9),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        indicatorSettings: indicatorSettings,
        backgroundKey: lgw.LiquidGlassScope.of(context),
      ),
    );
  }
}

class _FallbackSegmentedControl<T> extends StatefulWidget {
  final T value;
  final List<GlassSegment<T>> segments;
  final ValueChanged<T> onChanged;

  const _FallbackSegmentedControl({
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  @override
  State<_FallbackSegmentedControl<T>> createState() =>
      _FallbackSegmentedControlState<T>();
}

class _FallbackSegmentedControlState<T>
    extends State<_FallbackSegmentedControl<T>> {
  bool _pressed = false;
  bool _dragging = false;
  int? _dragIndex;

  int _selectedIndex() {
    int selectedIndex =
        widget.segments.indexWhere((segment) => segment.value == widget.value);
    return selectedIndex < 0 ? 0 : selectedIndex;
  }

  int _indexForDx(double dx, double width) {
    if (widget.segments.isEmpty || width <= 0) {
      return 0;
    }
    double clampedDx = dx.clamp(0.0, width - 0.0001);
    int index = (clampedDx / (width / widget.segments.length)).floor();
    return index.clamp(0, widget.segments.length - 1);
  }

  void _applySelection(int index) {
    if (index < 0 || index >= widget.segments.length) {
      return;
    }
    T nextValue = widget.segments[index].value;
    if (nextValue != widget.value) {
      widget.onChanged(nextValue);
    }
  }

  void _startDrag(Offset globalPosition, double width) {
    RenderBox box = context.findRenderObject()! as RenderBox;
    Offset localPosition = box.globalToLocal(globalPosition);
    int nextIndex = _indexForDx(localPosition.dx, width);
    setState(() {
      _pressed = true;
      _dragging = true;
      _dragIndex = nextIndex;
    });
    _applySelection(nextIndex);
  }

  void _updateDrag(Offset globalPosition, double width) {
    if (!_dragging) {
      return;
    }
    RenderBox box = context.findRenderObject()! as RenderBox;
    Offset localPosition = box.globalToLocal(globalPosition);
    int nextIndex = _indexForDx(localPosition.dx, width);
    if (nextIndex != _dragIndex) {
      setState(() {
        _dragIndex = nextIndex;
      });
      _applySelection(nextIndex);
    }
  }

  void _endInteraction() {
    if (!_pressed && !_dragging && _dragIndex == null) {
      return;
    }
    setState(() {
      _pressed = false;
      _dragging = false;
      _dragIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    AlembicTokens tokens = context.alembicTokens;
    int selectedIndex = _selectedIndex();
    int visualIndex = _dragging ? (_dragIndex ?? selectedIndex) : selectedIndex;

    return SizedBox(
      height: 40,
      child: LayoutBuilder(
        builder: (context, constraints) {
          double width = constraints.maxWidth;
          double sectionWidth = width / widget.segments.length;
          double bubbleLeft = (sectionWidth * visualIndex) + 2;
          Duration motionDuration = _dragging
              ? const Duration(milliseconds: 40)
              : const Duration(milliseconds: 210);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) {
              setState(() {
                _pressed = true;
              });
            },
            onTapCancel: _endInteraction,
            onTapUp: (details) {
              RenderBox box = context.findRenderObject()! as RenderBox;
              Offset local = box.globalToLocal(details.globalPosition);
              _applySelection(_indexForDx(local.dx, width));
              _endInteraction();
            },
            onPanStart: (details) => _startDrag(details.globalPosition, width),
            onPanUpdate: (details) =>
                _updateDrag(details.globalPosition, width),
            onPanEnd: (_) => _endInteraction(),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(tokens.radiusLarge),
                    color: tokens.inlineFill.withValues(
                      alpha: (tokens.inlineFillOpacity * 1.8).clamp(0.0, 1.0),
                    ),
                    border: Border.all(
                      color: tokens.stroke.withValues(
                        alpha: (tokens.strokeOpacity * 0.72).clamp(0.0, 1.0),
                      ),
                      width: 1,
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: motionDuration,
                  curve: Curves.easeOutCubic,
                  left: bubbleLeft,
                  top: 2,
                  width: sectionWidth - 4,
                  height: 36,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(tokens.radiusMedium),
                      color: tokens.controlFill.withValues(alpha: 0.2),
                      border: Border.all(
                        color: tokens.rim.withValues(alpha: 0.36),
                        width: 1,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: tokens.shadow.withValues(alpha: 0.16),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: widget.segments.map((segment) {
                    bool selected = segment.value == widget.value;
                    return Expanded(
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 130),
                          curve: Curves.easeOutCubic,
                          style: TextStyle(
                            color: selected
                                ? tokens.textPrimary
                                : tokens.textSecondary.withValues(alpha: 0.9),
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 12,
                          ),
                          child: Text(
                            segment.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
