import 'package:flutter/material.dart';

import 'package:gymbuddy/core/design/tokens/app_colors.dart';

/// Typography tokens.
///
/// Two jobs: a readable UI [textTheme] for everything chrome-like, and a family
/// of large, glanceable *numeric* styles ([numericDisplay], [numericLarge],
/// [numericMedium]) for in-workout data — rep counts, timers, weights — that a
/// lifter has to read mid-set from a couple of meters away.
///
/// The numeric styles use [FontFeature.tabularFigures] so digits occupy equal
/// width; a counter ticking 9 → 10 or a timer ticking down won't jitter
/// sideways as glyph widths change.
abstract final class AppTypography {
  /// Monospaced-digit feature shared by all numeric styles.
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// The biggest numeral — a focus-mode rep count or the headline timer.
  static const TextStyle numericDisplay = TextStyle(
    fontSize: 96,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: -2,
    fontFeatures: _tabular,
    color: AppColors.textPrimary,
  );

  /// A prominent metric — set weight, a [StatRing] center value.
  static const TextStyle numericLarge = TextStyle(
    fontSize: 48,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    fontFeatures: _tabular,
    color: AppColors.textPrimary,
  );

  /// A supporting metric — a [MetricTile] value.
  static const TextStyle numericMedium = TextStyle(
    fontSize: 28,
    height: 1.1,
    fontWeight: FontWeight.w600,
    fontFeatures: _tabular,
    color: AppColors.textPrimary,
  );

  /// Builds the UI text theme for chrome (titles, body, labels).
  ///
  /// Colors default to [AppColors.textPrimary]; muted variants are applied at
  /// the call site via `copyWith` so the ramp stays explicit.
  static TextTheme get textTheme => const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: AppColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.4,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.4,
          color: AppColors.textMuted,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: AppColors.textPrimary,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: AppColors.textMuted,
        ),
      );
}
