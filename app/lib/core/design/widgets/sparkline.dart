import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:gymbuddy/core/design/tokens/app_colors.dart';

/// A compact line chart of a short numeric series, for dashboard trends.
///
/// Purely presentational. Renders [values] (oldest→newest) as a polyline
/// normalized to its own min/max, so the *shape* of the trend reads at a glance
/// regardless of absolute scale. A higher value sits higher on screen. With a
/// constant series the line sits flat through the middle; with fewer than two
/// points there's nothing to connect, so it draws an empty box and the caller
/// shows its own empty state.
class Sparkline extends StatelessWidget {
  const Sparkline({
    required this.values,
    this.color = AppColors.accent,
    this.height = 32,
    this.strokeWidth = 2,
    super.key,
  });

  /// The series to chart, oldest→newest.
  final List<double> values;

  /// Line color; defaults to the accent.
  final Color color;

  /// Fixed height of the chart.
  final double height;

  /// Line thickness.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          color: color,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.values,
    required this.color,
    required this.strokeWidth,
  });

  final List<double> values;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    var min = values.first;
    var max = values.first;
    for (final v in values) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    final range = max - min;

    // Inset vertically by half the stroke so the line never clips at the edges.
    final top = strokeWidth / 2;
    final usableHeight = size.height - strokeWidth;
    final dx = size.width / (values.length - 1);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = dx * i;
      // Constant series → 0.5 (centered); otherwise normalize into [0, 1].
      final t = range == 0 ? 0.5 : (values[i] - min) / range;
      final y = top + (1 - t) * usableHeight;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return !listEquals(oldDelegate.values, values) ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
