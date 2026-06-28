import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:gymbuddy/core/design/tokens/app_colors.dart';

/// A circular progress ring with a glanceable value at its center.
///
/// Used for vitals (readiness, sleep, steps-to-goal) and any 0–1 completion
/// metric. Renders a dim full-circle track with an accent arc sweeping
/// clockwise from 12 o'clock to represent [progress]. Purely presentational —
/// [progress] is clamped to `[0, 1]` so out-of-range inputs never overshoot the
/// circle.
class StatRing extends StatelessWidget {
  const StatRing({
    required this.progress,
    this.value,
    this.label,
    this.size = 96,
    this.strokeWidth = 8,
    this.color = AppColors.accent,
    this.semanticLabel,
    super.key,
  });

  /// Completion in `[0, 1]`; values outside the range are clamped.
  final double progress;

  /// Optional large center value (e.g. "82").
  final String? value;

  /// Optional caption under the value (e.g. "Readiness").
  final String? label;

  /// Outer diameter in logical pixels.
  final double size;

  /// Ring thickness.
  final double strokeWidth;

  /// Arc color; defaults to the accent.
  final Color color;

  /// When set, the visual subtree is hidden from screen readers and announced
  /// as this single label instead of the split value/caption (e.g.
  /// "Readiness, 82 out of 100"). When null the center value and label, if any,
  /// are read as-is; a ring with no center text is then purely decorative.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = progress.clamp(0.0, 1.0).toDouble();
    final ring = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: clamped,
          color: color,
          trackColor: AppColors.surfaceBright,
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null)
                Text(
                  value!,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              if (label != null)
                Text(
                  label!,
                  style: theme.textTheme.labelSmall,
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );

    if (semanticLabel == null) return ring;
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(child: ring),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  /// Start at 12 o'clock (canvas angles begin at 3 o'clock / 0 rad).
  static const double _startAngle = -math.pi / 2;
  static const double _fullSweep = 2 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) {
      return;
    }

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, _startAngle, _fullSweep * progress, false, arcPaint);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
