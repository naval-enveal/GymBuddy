import 'package:flutter/material.dart';

import 'package:gymbuddy/core/design/tokens/app_colors.dart';
import 'package:gymbuddy/core/design/tokens/app_spacing.dart';
import 'package:gymbuddy/core/design/tokens/app_typography.dart';

/// The focus-mode rep readout — one huge, glanceable numeral.
///
/// Shows [reps] in the display numeric style; when a [target] is given it
/// appends `/ target` in a muted tone so the lifter sees progress toward the
/// set at a glance. Purely presentational: it renders whatever count the
/// session provider feeds it and counts nothing itself (rep detection lives in
/// the sensor/session layer, M6+).
class RepCounter extends StatelessWidget {
  const RepCounter({
    required this.reps,
    this.target,
    this.label = 'REPS',
    super.key,
  });

  /// Completed reps in the current set.
  final int reps;

  /// Optional target rep count for the set.
  final int? target;

  /// Caption above the numeral.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$reps', style: AppTypography.numericDisplay),
            if (target != null)
              Text(
                ' / $target',
                style: AppTypography.numericLarge.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
