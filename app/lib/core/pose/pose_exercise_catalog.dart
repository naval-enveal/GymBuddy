import 'package:gymbuddy/core/pose/exercise_angle_configs.dart';
import 'package:gymbuddy/core/pose/exercise_form_configs.dart';
import 'package:gymbuddy/core/pose/pose_exercise_matching.dart';

/// What the on-device pose pipeline can do for an exercise, given the glasses'
/// first-person POV. Ordered least → most capable.
enum PoseTracking {
  /// Pose adds nothing. Reps fall back to the native DAT-SDK channel (or the
  /// mock / manual logging) and form is not assessed.
  none,

  /// Reps are counted from joint angles, but no form-fault feedback is given —
  /// the movement isn't one whose faults are reliably visible from POV.
  repsOnly,

  /// Reps are counted *and* form faults are flagged.
  formTracked,
}

extension PoseTrackingX on PoseTracking {
  /// The pose pipeline tracks this exercise in some way (reps and/or form).
  bool get isPoseTrackable => this != PoseTracking.none;

  /// Reps are counted on-device (true for both [repsOnly] and [formTracked]).
  bool get isRepTracked => this != PoseTracking.none;

  /// Form faults are flagged on-device.
  bool get isFormTracked => this == PoseTracking.formTracked;
}

/// The curated set of canonical movements the pose pipeline can track from the
/// glasses' first-person POV — the union of the rep ([kExerciseAngleConfigs])
/// and form ([kExerciseFormConfigs]) seed maps' keys.
///
/// This is the **single source of truth** for pose-trackability. The plans and
/// session layers classify an exercise through [poseTrackingFor] rather than
/// trusting a server-supplied flag, so what the UI promises and what the
/// on-device pipeline actually attempts can never drift apart. (Every
/// form-tracked movement also has a rep config — see the catalog test — so
/// form tracking always implies rep counting.)
final Set<String> kPoseTrackableExercises = <String>{
  ...kExerciseAngleConfigs.keys,
  ...kExerciseFormConfigs.keys,
};

/// Resolves [exerciseName] to its canonical pose key, or null when the pose
/// pipeline doesn't recognise it. Case-insensitive, longest-match-wins (see
/// [matchCanonicalKey]) so descriptive plan names ("Back Squat", "Dumbbell
/// Romanian Deadlift") map onto the short canonical movements.
String? canonicalExerciseKey(String exerciseName) =>
    matchCanonicalKey(exerciseName, kPoseTrackableExercises);

/// Classifies [exerciseName] by what the pose pipeline can track for it.
///
/// A form config promotes the exercise to [PoseTracking.formTracked]; an angle
/// config alone is [PoseTracking.repsOnly]; anything the catalog doesn't
/// recognise is [PoseTracking.none].
PoseTracking poseTrackingFor(String exerciseName) {
  final key = canonicalExerciseKey(exerciseName);
  if (key == null) return PoseTracking.none;
  if (kExerciseFormConfigs.containsKey(key)) return PoseTracking.formTracked;
  if (kExerciseAngleConfigs.containsKey(key)) return PoseTracking.repsOnly;
  return PoseTracking.none;
}

/// Whether the pose pipeline can track [exerciseName] at all (reps or form).
bool isPoseTrackable(String exerciseName) =>
    poseTrackingFor(exerciseName).isPoseTrackable;
