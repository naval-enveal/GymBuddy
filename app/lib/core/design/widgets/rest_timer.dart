import 'package:flutter/material.dart';

import 'package:gymbuddy/core/design/tokens/app_colors.dart';
import 'package:gymbuddy/core/design/tokens/app_typography.dart';
import 'package:gymbuddy/core/design/widgets/stat_ring.dart';

/// A between-sets rest countdown, drawn as a depleting ring around a mm:ss
/// readout.
///
/// Driven entirely by props — [remaining] and [total] — so the ticking lives in
/// a provider (M6), not here. The ring shows the fraction of rest *left* (full
/// at the start, empty at zero); both the ring and the numerals turn
/// [AppColors.warning] once the remaining time drops to [warningThreshold] so a
/// lifter glancing over knows the set is about to start.
class RestTimer extends StatelessWidget {
  const RestTimer({
    required this.remaining,
    required this.total,
    this.size = 200,
    this.warningThreshold = const Duration(seconds: 10),
    super.key,
  });

  /// Time left in the rest period.
  final Duration remaining;

  /// The full rest period, used to compute the ring fraction.
  final Duration total;

  /// Outer diameter of the ring.
  final double size;

  /// At or below this remaining time, the timer switches to the warning color.
  final Duration warningThreshold;

  @override
  Widget build(BuildContext context) {
    // Guard against a zero/negative total so the fraction stays well-defined.
    final fraction = total.inMilliseconds <= 0
        ? 0.0
        : remaining.inMilliseconds / total.inMilliseconds;
    final isWarning = remaining <= warningThreshold;
    final color = isWarning ? AppColors.warning : AppColors.accent;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          StatRing(
            progress: fraction,
            size: size,
            strokeWidth: 12,
            color: color,
          ),
          Text(
            _format(remaining),
            style: AppTypography.numericLarge.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  /// Formats a non-negative duration as `m:ss` (clamps negatives to zero).
  static String _format(Duration d) {
    final totalSeconds = d.inSeconds < 0 ? 0 : d.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
