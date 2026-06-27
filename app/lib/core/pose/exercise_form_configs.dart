import 'package:gymbuddy/core/pose/pose_detector.dart';
import 'package:gymbuddy/core/pose/pose_exercise_matching.dart';
import 'package:gymbuddy/core/pose/pose_form_checker.dart';
import 'package:gymbuddy/sensors/sensor_source.dart';

/// Per-exercise joint-angle form rules for pose-based form feedback.
///
/// The companion to `kExerciseAngleConfigs` (rep counting): these read the same
/// POV/mirror-visible keypoints to flag common faults. Only exercises whose
/// faults are visible from the glasses' first-person view are listed; an
/// exercise absent here (or one tracked with `formTracked == false`) simply
/// emits no pose-derived form cues.
///
/// Two angle proxies recur:
///  * **torso lean** — the hip angle (shoulder–hip–knee); too small means the
///    chest has dropped too far forward.
///  * **spine rounding** — the ear–shoulder–hip line; neutral is near-straight
///    (~180°), so a smaller angle means the upper back has rounded.
///
/// Thresholds are approximate and will be calibrated on-device; the mechanism,
/// not the exact degrees, is what M8 task 3 establishes.
const Map<String, List<FormRule>> kExerciseFormConfigs = {
  'squat': [
    FormRule(
      id: 'squat-forward-lean',
      pivot: KeypointId.leftHip,
      from: KeypointId.leftShoulder,
      to: KeypointId.leftKnee,
      minAngle: 45.0,
      maxAngle: 180.0,
      severity: FormSeverity.minor,
      message: 'Keep your chest up; avoid leaning too far forward.',
    ),
  ],
  'deadlift': [
    FormRule(
      id: 'deadlift-back-rounding',
      pivot: KeypointId.leftShoulder,
      from: KeypointId.leftEar,
      to: KeypointId.leftHip,
      minAngle: 150.0,
      maxAngle: 180.0,
      severity: FormSeverity.major,
      message: 'Keep your back flat; avoid rounding your spine.',
    ),
  ],
  'romanian deadlift': [
    FormRule(
      id: 'rdl-back-rounding',
      pivot: KeypointId.leftShoulder,
      from: KeypointId.leftEar,
      to: KeypointId.leftHip,
      minAngle: 150.0,
      maxAngle: 180.0,
      severity: FormSeverity.major,
      message: 'Keep your back flat; avoid rounding your spine.',
    ),
  ],
  'push-up': [
    FormRule(
      id: 'pushup-hip-sag',
      pivot: KeypointId.leftHip,
      from: KeypointId.leftShoulder,
      to: KeypointId.leftKnee,
      minAngle: 155.0,
      maxAngle: 180.0,
      severity: FormSeverity.minor,
      message: 'Hold a straight line; do not let your hips sag.',
    ),
  ],
  'lunge': [
    FormRule(
      id: 'lunge-forward-lean',
      pivot: KeypointId.leftHip,
      from: KeypointId.leftShoulder,
      to: KeypointId.leftKnee,
      minAngle: 45.0,
      maxAngle: 180.0,
      severity: FormSeverity.minor,
      message: 'Stay tall; keep your torso upright.',
    ),
  ],
};

/// Returns the form rules for [exerciseName], or an empty list for exercises
/// without pose-based form feedback. Matching is case-insensitive and
/// longest-key-wins (see [matchCanonicalKey]), so descriptive plan names
/// ("Dumbbell Romanian Deadlift") resolve to the canonical movement.
List<FormRule> resolveFormRules(String exerciseName) {
  final key = matchCanonicalKey(exerciseName, kExerciseFormConfigs.keys);
  return key == null ? const <FormRule>[] : kExerciseFormConfigs[key]!;
}
