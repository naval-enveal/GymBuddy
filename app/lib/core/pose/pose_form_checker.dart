import 'package:gymbuddy/core/pose/pose_detector.dart';
import 'package:gymbuddy/sensors/sensor_source.dart';

/// A single joint-angle form rule: the angle at [pivot] (formed by [from] and
/// [to]) must stay within `[minAngle, maxAngle]`. When a frame's measured angle
/// falls outside that band the rule fires a [FormCue] of [severity] carrying
/// [message] — e.g. a torso angle dropping too far forward on a squat, or an
/// ear–shoulder–hip line bending out of neutral on a deadlift (back rounding).
///
/// One side of the band is usually left wide open (0 or 180) so the rule reads
/// as a single threshold; both bounds matter only when a joint has a safe window
/// in the middle.
class FormRule {
  const FormRule({
    required this.id,
    required this.pivot,
    required this.from,
    required this.to,
    required this.minAngle,
    required this.maxAngle,
    required this.severity,
    required this.message,
    this.minConfidence = 0.3,
  }) : assert(minAngle <= maxAngle, 'minAngle must be <= maxAngle');

  /// Stable identifier used to debounce a held fault (see [PoseFormChecker]).
  final String id;

  /// The joint whose angle is measured (e.g. left hip for torso lean).
  final KeypointId pivot;

  /// One arm of the angle.
  final KeypointId from;

  /// The other arm of the angle.
  final KeypointId to;

  /// Inclusive lower bound (degrees) of good form. Below it the rule fires.
  final double minAngle;

  /// Inclusive upper bound (degrees) of good form. Above it the rule fires.
  final double maxAngle;

  /// How urgent the cue is when the rule fires.
  final FormSeverity severity;

  /// The coaching line surfaced when the rule fires.
  final String message;

  /// Minimum keypoint confidence required to evaluate the rule.
  final double minConfidence;
}

/// Detects common form faults from [PoseFrame]s by checking joint angles
/// against a set of [FormRule]s — the form-feedback counterpart to
/// [PoseRepCounter], reading the *same* keypoint angles.
///
/// Edge-triggered: a rule emits a [FormCue] only on the frame where the fault
/// first appears, not once per frame while it is held, so a lifter holding a
/// rounded back gets one cue rather than a stream of them. The cue can fire
/// again once the rule recovers into the good band and is then violated anew.
/// Frames where a rule's keypoints are missing or low-confidence simply can't
/// evaluate that rule — its state is left unchanged.
///
/// Pure-Dart and synchronous — feed it frames directly in tests without the
/// tflite model or any hardware.
class PoseFormChecker {
  PoseFormChecker(this.rules);

  final List<FormRule> rules;

  /// Ids of the rules currently in a violated state (for edge triggering).
  final Set<String> _active = <String>{};

  /// Evaluates [frame] against every rule and returns the cues that *newly*
  /// fired this frame (an empty list when nothing changed).
  List<FormCue> processFrame(PoseFrame frame) {
    final cues = <FormCue>[];
    for (final rule in rules) {
      final angle = frame.angleDegrees(
        rule.from,
        rule.pivot,
        rule.to,
        minConfidence: rule.minConfidence,
      );
      if (angle == null) continue;
      final violated = angle < rule.minAngle || angle > rule.maxAngle;
      if (violated) {
        if (_active.add(rule.id)) {
          cues.add(FormCue(severity: rule.severity, message: rule.message));
        }
      } else {
        _active.remove(rule.id);
      }
    }
    return cues;
  }

  /// Clears all fault state. Call this on
  /// [WorkoutSensorSource.stopTracking] so the next set starts fresh.
  void reset() => _active.clear();
}
