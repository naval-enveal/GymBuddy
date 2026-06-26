import 'package:flutter/material.dart';

import 'package:gymbuddy/core/design/tokens/app_colors.dart';
import 'package:gymbuddy/core/design/tokens/app_radii.dart';
import 'package:gymbuddy/core/design/tokens/app_spacing.dart';
import 'package:gymbuddy/core/design/tokens/app_typography.dart';

/// The GymBuddy application theme.
///
/// Dark-first by design — there is intentionally only [dark] for now; a light
/// theme isn't a product goal. Material 3 is the substrate but its defaults are
/// overridden heavily so the app reads as GymBuddy, not stock Material:
/// near-black surfaces, the single [AppColors.accent], flat (un-elevated)
/// cards, and pill-shaped primary actions.
abstract final class AppTheme {
  /// The dark theme. Wire this into `MaterialApp.theme`.
  static ThemeData get dark {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.accent,
      onSecondary: AppColors.onAccent,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceBright,
      onSurfaceVariant: AppColors.textMuted,
      outline: AppColors.outline,
      error: AppColors.error,
      onError: AppColors.onError,
    );

    final textTheme = AppTypography.textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      textTheme: textTheme,
      dividerTheme: const DividerThemeData(
        color: AppColors.outline,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      ),
      // The PrimaryButton widget is the canonical CTA, but theme the underlying
      // FilledButton too so any direct use stays on-brand.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          disabledBackgroundColor: AppColors.surfaceBright,
          disabledForegroundColor: AppColors.textMuted,
          minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget),
          textStyle: textTheme.labelLarge,
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size(
            AppSpacing.minTouchTarget,
            AppSpacing.minTouchTarget,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceBright,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accentDim,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.all(textTheme.labelSmall),
      ),
    );
  }
}
