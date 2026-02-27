import 'dart:math' as math;
import 'dart:ui';

import 'package:alembic/theme/alembic_tokens.dart';
import 'package:flutter/cupertino.dart';

enum GlassEdgeIntensity {
  low,
  medium,
  high,
}

class RefractingEdge extends StatefulWidget {
  final BorderRadius borderRadius;
  final bool circular;
  final GlassEdgeIntensity intensity;
  final bool animate;
  final Duration duration;
  final double strokeWidth;
  final Color prismCyan;
  final Color prismMagenta;
  final Color prismBlue;
  final Color frameStroke;

  const RefractingEdge({
    super.key,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.circular = false,
    this.intensity = GlassEdgeIntensity.medium,
    this.animate = true,
    this.duration = const Duration(milliseconds: 9000),
    this.strokeWidth = 1.0,
    required this.prismCyan,
    required this.prismMagenta,
    required this.prismBlue,
    required this.frameStroke,
  });

  @override
  State<RefractingEdge> createState() => _RefractingEdgeState();
}

class _RefractingEdgeState extends State<RefractingEdge>
    with SingleTickerProviderStateMixin {
  static const double _staticPhase = 0.173;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.animate) {
      _controller.repeat();
    } else {
      _controller.value = _staticPhase;
    }
  }

  @override
  void didUpdateWidget(covariant RefractingEdge oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }

    if (oldWidget.animate != widget.animate) {
      if (widget.animate) {
        _controller.repeat();
      } else {
        _controller
          ..stop()
          ..value = _staticPhase;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AlembicTokens tokens = context.alembicTokens;

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedWidth ||
              !constraints.hasBoundedHeight ||
              constraints.maxWidth <= 0 ||
              constraints.maxHeight <= 0) {
            return const SizedBox.shrink();
          }

          Size paintSize = Size(constraints.maxWidth, constraints.maxHeight);
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                size: paintSize,
                painter: _RefractingEdgePainter(
                  borderRadius: widget.borderRadius,
                  circular: widget.circular,
                  intensity: widget.intensity,
                  phase: _controller.value,
                  strokeWidth: widget.strokeWidth,
                  prismCyan: widget.prismCyan,
                  prismMagenta: widget.prismMagenta,
                  prismBlue: widget.prismBlue,
                  frameStroke: widget.frameStroke,
                  tokens: tokens,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RefractingEdgePainter extends CustomPainter {
  final BorderRadius borderRadius;
  final bool circular;
  final GlassEdgeIntensity intensity;
  final double phase;
  final double strokeWidth;
  final Color prismCyan;
  final Color prismMagenta;
  final Color prismBlue;
  final Color frameStroke;
  final AlembicTokens tokens;

  const _RefractingEdgePainter({
    required this.borderRadius,
    required this.circular,
    required this.intensity,
    required this.phase,
    required this.strokeWidth,
    required this.prismCyan,
    required this.prismMagenta,
    required this.prismBlue,
    required this.frameStroke,
    required this.tokens,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    double widthMultiplier;
    double prismOpacity;
    double glowOpacity;
    double rimBoost;

    switch (intensity) {
      case GlassEdgeIntensity.low:
        widthMultiplier = tokens.edgeWidthLow;
        prismOpacity = tokens.chromaLowOpacity;
        glowOpacity = 0;
        rimBoost = 0.9;
      case GlassEdgeIntensity.medium:
        widthMultiplier = tokens.edgeWidthMedium;
        prismOpacity = tokens.chromaMediumOpacity;
        glowOpacity = 0;
        rimBoost = 1;
      case GlassEdgeIntensity.high:
        widthMultiplier = tokens.edgeWidthHigh;
        prismOpacity = tokens.chromaHighOpacity;
        glowOpacity = tokens.edgeGlowHighOpacity * 0.6;
        rimBoost = 1.04;
    }

    double width = strokeWidth * widthMultiplier;
    Rect edgeRect = (Offset.zero & size).deflate(width * 0.5);
    Path edgePath = _edgePath(edgeRect);

    Paint rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = frameStroke.withValues(
        alpha: (tokens.frameStrokeOpacity * rimBoost).clamp(0, 1),
      );
    canvas.drawPath(edgePath, rimPaint);

    _paintSpecularHighlights(canvas, edgePath, width);

    SweepGradient chromaGradient = SweepGradient(
      colors: <Color>[
        prismCyan.withValues(alpha: prismOpacity),
        prismBlue.withValues(alpha: prismOpacity * 0.95),
        prismMagenta.withValues(alpha: prismOpacity),
        prismBlue.withValues(alpha: prismOpacity * 0.9),
        prismCyan.withValues(alpha: prismOpacity),
      ],
      stops: const <double>[0.0, 0.24, 0.48, 0.75, 1.0],
      transform: GradientRotation(phase * math.pi * 2),
    );

    Paint chromaPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.94
      ..shader = chromaGradient.createShader(edgeRect.inflate(width * 0.8));
    canvas.drawPath(edgePath, chromaPaint);

    if (glowOpacity > 0) {
      Paint glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 1.4
        ..color = tokens.specular.withValues(alpha: glowOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4);
      canvas.drawPath(edgePath, glowPaint);
    }
  }

  void _paintSpecularHighlights(Canvas canvas, Path edgePath, double width) {
    List<PathMetric> metrics = edgePath.computeMetrics().toList();
    if (metrics.isEmpty) {
      return;
    }

    PathMetric metric = metrics.first;
    double length = metric.length;
    double phaseShiftA = (phase * 0.08 + 0.04) % 1.0;
    double phaseShiftB = (phase * 0.06 + 0.56) % 1.0;

    Path highlightA = _extract(metric, length, phaseShiftA, 0.14);
    Path highlightB = _extract(metric, length, phaseShiftB, 0.09);

    Paint highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width * 1.18
      ..color = tokens.specular.withValues(alpha: 0.56)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);

    canvas.drawPath(highlightA, highlightPaint);
    canvas.drawPath(
      highlightB,
      highlightPaint
        ..strokeWidth = width * 1.08
        ..color = tokens.specular.withValues(alpha: 0.4),
    );
  }

  Path _extract(PathMetric metric, double length, double startT, double spanT) {
    double start = (startT % 1.0) * length;
    double end = start + (spanT * length);

    if (end <= length) {
      return metric.extractPath(start, end);
    }

    Path split = Path();
    split.addPath(metric.extractPath(start, length), Offset.zero);
    split.addPath(metric.extractPath(0, end - length), Offset.zero);
    return split;
  }

  Path _edgePath(Rect rect) {
    if (circular) {
      return Path()..addOval(rect);
    }
    return Path()..addRRect(borderRadius.toRRect(rect));
  }

  @override
  bool shouldRepaint(covariant _RefractingEdgePainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.circular != circular ||
        oldDelegate.intensity != intensity ||
        oldDelegate.phase != phase ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.prismCyan != prismCyan ||
        oldDelegate.prismMagenta != prismMagenta ||
        oldDelegate.prismBlue != prismBlue ||
        oldDelegate.frameStroke != frameStroke ||
        oldDelegate.tokens != tokens;
  }
}
