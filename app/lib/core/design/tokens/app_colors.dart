import 'package:flutter/widgets.dart';

/// Raw color tokens for GymBuddy.
///
/// The palette is dark-first: near-black surfaces with a single energetic
/// accent ([accent]) layered on a neutral grayscale ramp. Feature code should
/// almost always read colors from `Theme.of(context).colorScheme` rather than
/// reaching for these constants directly — they exist to *define* the theme
/// (see `app_theme.dart`) and to cover the few cases the [ColorScheme] can't
/// express (e.g. the dim track behind a [StatRing]).
abstract final class AppColors {
  /// The one energetic accent. Used sparingly for primary actions, active
  /// states, and live in-workout data. Everything else stays grayscale so this
  /// reads as "the thing that matters right now".
  static const Color accent = Color(0xFF00E5A0);

  /// A dimmed accent for pressed/hover overlays and ring tracks tinted toward
  /// the accent rather than pure gray.
  static const Color accentDim = Color(0xFF0A7A5C);

  /// Text/icon color that sits legibly *on top of* [accent]. The accent is a
  /// bright mint, so near-black gives the strongest contrast.
  static const Color onAccent = Color(0xFF04150F);

  /// App backdrop — the darkest surface, behind everything.
  static const Color background = Color(0xFF0A0B0D);

  /// Default card/sheet surface, one step lighter than [background].
  static const Color surface = Color(0xFF15171B);

  /// Raised or selected surface, and the fill behind inputs.
  static const Color surfaceBright = Color(0xFF1E2127);

  /// Hairline borders and dividers.
  static const Color outline = Color(0xFF2A2E36);

  /// Primary text and icons on dark surfaces.
  static const Color textPrimary = Color(0xFFF5F7FA);

  /// Secondary text — labels, captions, units, inactive states.
  static const Color textMuted = Color(0xFF9AA3AD);

  /// Destructive actions and error states.
  static const Color error = Color(0xFFFF5A5F);

  /// Text/icon color on top of [error].
  static const Color onError = Color(0xFF1A0405);

  /// Caution / approaching-limit states (e.g. a rest timer running low).
  static const Color warning = Color(0xFFFFB020);
}
