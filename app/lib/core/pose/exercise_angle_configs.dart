import 'package:gymbuddy/core/pose/pose_detector.dart';
import 'package:gymbuddy/core/pose/pose_rep_counter.dart';

/// Per-exercise joint-angle configurations for pose-based rep counting.
///
/// The glasses are first-person POV, so only mirror-facing and POV-visible
/// exercises are listed. Exercises not in this map fall back to the native
/// DAT-SDK rep channel (or to the mock, depending on the resolved sensor source).
///
/// Thresholds are approximate; M8 task 3 will calibrate them per-exercise.
const Map<String, RepAngleConfig> kExerciseAngleConfigs = {
  'squat': RepAngleConfig(
    pivot: KeypointId.leftKnee,
    from: KeypointId.leftHip,
    to: KeypointId.leftAnkle,
    lowThreshold: 90.0,
    highThreshold: 150.0,
  ),
  'deadlift': RepAngleConfig(
    pivot: KeypointId.leftHip,
    from: KeypointId.leftShoulder,
    to: KeypointId.leftKnee,
    lowThreshold: 80.0,
    highThreshold: 150.0,
  ),
  'bicep curl': RepAngleConfig(
    pivot: KeypointId.leftElbow,
    from: KeypointId.leftShoulder,
    to: KeypointId.leftWrist,
    lowThreshold: 60.0,
    highThreshold: 150.0,
  ),
  'push-up': RepAngleConfig(
    pivot: KeypointId.leftElbow,
    from: KeypointId.leftShoulder,
    to: KeypointId.leftWrist,
    lowThreshold: 90.0,
    highThreshold: 150.0,
  ),
  'lunge': RepAngleConfig(
    pivot: KeypointId.leftKnee,
    from: KeypointId.leftHip,
    to: KeypointId.leftAnkle,
    lowThreshold: 90.0,
    highThreshold: 150.0,
  ),
  'shoulder press': RepAngleConfig(
    pivot: KeypointId.leftElbow,
    from: KeypointId.leftShoulder,
    to: KeypointId.leftWrist,
    lowThreshold: 90.0,
    highThreshold: 160.0,
  ),
  'romanian deadlift': RepAngleConfig(
    pivot: KeypointId.leftHip,
    from: KeypointId.leftShoulder,
    to: KeypointId.leftKnee,
    lowThreshold: 80.0,
    highThreshold: 150.0,
  ),
  'overhead press': RepAngleConfig(
    pivot: KeypointId.leftElbow,
    from: KeypointId.leftShoulder,
    to: KeypointId.leftWrist,
    lowThreshold: 90.0,
    highThreshold: 160.0,
  ),
};

/// Returns the [RepAngleConfig] for [exerciseName] (case-insensitive), or
/// null for exercises without a pose-based rep counting configuration.
RepAngleConfig? resolveAngleConfig(String exerciseName) =>
    kExerciseAngleConfigs[exerciseName.toLowerCase()];
