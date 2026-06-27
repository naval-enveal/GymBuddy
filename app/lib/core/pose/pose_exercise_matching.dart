/// Maps an arbitrary exercise name to one of a set of canonical pose keys.
///
/// Plans seed real, descriptive names — "Back Squat", "Goblet Squat",
/// "Dumbbell Romanian Deadlift" — while the pose configs are keyed by short
/// canonical movements ("squat", "romanian deadlift"). Exact lookup would miss
/// every real plan exercise, so matching is case-insensitive *substring*
/// matching: a name matches a key when the (lowercased) key appears anywhere in
/// the (lowercased) name. When several keys match, the **longest** wins so the
/// specific "romanian deadlift" is preferred over the generic "deadlift".
///
/// Returns the matched key, or null when nothing matches. This is the one
/// matching primitive every pose resolver shares ([resolveAngleConfig],
/// [resolveFormRules], and the catalog's `canonicalExerciseKey`) so rep
/// counting, form checks, and pose-trackability never disagree about whether a
/// given exercise is recognised.
String? matchCanonicalKey(String exerciseName, Iterable<String> keys) {
  final name = exerciseName.toLowerCase().trim();
  if (name.isEmpty) return null;
  String? best;
  for (final key in keys) {
    if (name.contains(key) && (best == null || key.length > best.length)) {
      best = key;
    }
  }
  return best;
}
