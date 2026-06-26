/// GymBuddy design system — single import surface.
///
/// Feature code should import this barrel rather than reaching into individual
/// token/widget files:
///
/// ```dart
/// import 'package:gymbuddy/core/design/design.dart';
/// ```
///
/// Exposes the theme ([AppTheme]), the raw tokens (colors, spacing, radii,
/// typography, durations), and the reusable widgets (PrimaryButton, MetricTile,
/// StatRing, RepCounter, RestTimer). Build feature UI from these — don't
/// hardcode colors, sizes, or one-off buttons.
library;

export 'app_theme.dart';
export 'tokens/app_colors.dart';
export 'tokens/app_durations.dart';
export 'tokens/app_radii.dart';
export 'tokens/app_spacing.dart';
export 'tokens/app_typography.dart';
export 'widgets/metric_tile.dart';
export 'widgets/primary_button.dart';
export 'widgets/rep_counter.dart';
export 'widgets/rest_timer.dart';
export 'widgets/stat_ring.dart';
