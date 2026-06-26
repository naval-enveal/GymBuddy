/// Motion duration tokens.
///
/// Motion is subtle and purposeful — fast enough to feel responsive, never
/// decorative. Use [fast] for taps/state flips, [medium] for transitions, and
/// [slow] sparingly for emphasis.
abstract final class AppDurations {
  /// 120ms — immediate feedback (button press, toggle).
  static const Duration fast = Duration(milliseconds: 120);

  /// 240ms — standard transitions and reveals.
  static const Duration medium = Duration(milliseconds: 240);

  /// 400ms — deliberate emphasis only.
  static const Duration slow = Duration(milliseconds: 400);
}
