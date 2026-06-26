/// Spacing and sizing tokens on an 8pt grid.
///
/// Every margin, padding, and gap in the app should be one of these values so
/// layouts stay rhythmically consistent. [xxs] (4) is the only half-step — used
/// for tight inline gaps (e.g. a value and its unit) — everything else is a
/// multiple of 8.
abstract final class AppSpacing {
  /// 4 — half-step for tight inline gaps only.
  static const double xxs = 4;

  /// 8 — base unit.
  static const double xs = 8;

  /// 12 — between [xs] and [md] for snug-but-not-tight padding.
  static const double sm = 12;

  /// 16 — default padding inside cards and screen edges.
  static const double md = 16;

  /// 24 — section spacing.
  static const double lg = 24;

  /// 32 — large gaps between major blocks.
  static const double xl = 32;

  /// 48 — hero spacing and the minimum interactive target size.
  static const double xxl = 48;

  /// Minimum tap target edge (dp) for ≥48dp "sweaty hands" touch targets.
  static const double minTouchTarget = 48;
}
