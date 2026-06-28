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
///
/// The split numeral + caption read as disconnected fragments to a screen
/// reader, so the visual subtree is excluded from semantics and replaced with a
/// single spoken label ("8 of 12 reps" / "8 reps"). Pass [semanticLabel] to
/// override the default phrasing.
class RepCounter extends StatelessWidget {
  const RepCounter({
    required this.reps,
    this.target,
    this.label = 'REPS',
    this.semanticLabel,
    super.key,
  });

  /// Completed reps in the current set.
  final int reps;

  /// Optional target rep count for the set.
  final int? target;

  /// Caption above the numeral.
  final String label;

  /// Overrides the spoken label. Defaults to "{reps} of {target} {label}" (or
  /// "{reps} {label}" with no target), with [label] lowercased.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spokenUnit = label.toLowerCase();
    final effectiveLabel = semanticLabel ??
        (target != null
            ? '$reps of $target $spokenUnit'
            : '$reps $spokenUnit');
    return Semantics(
      label: effectiveLabel,
      child: ExcludeSemantics(
        child: Column(
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
        ),
      ),
    );
  }
}
