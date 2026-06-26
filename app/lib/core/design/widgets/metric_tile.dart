import 'package:flutter/material.dart';

import 'package:gymbuddy/core/design/tokens/app_colors.dart';
import 'package:gymbuddy/core/design/tokens/app_radii.dart';
import 'package:gymbuddy/core/design/tokens/app_spacing.dart';
import 'package:gymbuddy/core/design/tokens/app_typography.dart';

/// A compact surface that presents a single labelled metric.
///
/// The building block for dashboard grids — a [label] caption above a glanceable
/// [value], with an optional [unit] trailing the value and an optional leading
/// [icon]. Purely presentational; callers pass already-formatted strings.
class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    super.key,
  });

  /// Caption describing the metric (e.g. "Resting HR").
  final String label;

  /// The formatted value (e.g. "58").
  final String value;

  /// Optional unit shown after the value (e.g. "bpm").
  final String? unit;

  /// Optional leading icon, tinted with the accent.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.accent),
                const SizedBox(width: AppSpacing.xxs),
              ],
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppTypography.numericMedium),
              if (unit != null) ...[
                const SizedBox(width: AppSpacing.xxs),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(unit!, style: theme.textTheme.bodyMedium),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
