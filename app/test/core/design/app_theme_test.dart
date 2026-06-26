// Pins the load-bearing choices in the app theme so a future tweak can't
// silently drop the dark/accent identity the whole design system assumes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gymbuddy/core/design/design.dart';

void main() {
  group('AppTheme.dark', () {
    final theme = AppTheme.dark;

    test('is a dark, Material 3 theme', () {
      expect(theme.brightness, Brightness.dark);
      expect(theme.useMaterial3, isTrue);
    });

    test('uses the energetic accent as the primary color', () {
      expect(theme.colorScheme.primary, AppColors.accent);
      expect(theme.colorScheme.onPrimary, AppColors.onAccent);
    });

    test('paints scaffolds on the near-black background', () {
      expect(theme.scaffoldBackgroundColor, AppColors.background);
    });

    test('primary buttons meet the 48dp minimum touch target', () {
      final style = theme.filledButtonTheme.style;
      final size = style?.minimumSize?.resolve(<WidgetState>{});
      expect(size?.height, AppSpacing.minTouchTarget);
    });

    test('cards are flat (un-elevated) per the stripped-down look', () {
      expect(theme.cardTheme.elevation, 0);
      expect(theme.cardTheme.color, AppColors.surface);
    });
  });
}
