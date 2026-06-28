import 'package:gymbuddy/core/pose/pose_detector.dart';
import 'package:gymbuddy/sensors/sensor_source.dart';

/// Which angle to track for rep counting and the thresholds that define
/// the bottom and top of the movement.
class RepAngleConfig {
  const RepAngleConfig({
    required this.pivot,
    required this.from,
    required this.to,
    required this.lowThreshold,
    required this.highThreshold,
    this.minConfidence = 0.3,
  }) : assert(
          lowThreshold < highThreshold,
          'lowThreshold must be less than highThreshold',
        );

  /// The joint whose angle is measured (e.g. left knee for a squat).
  final KeypointId pivot;

  /// One arm of the angle.
  final KeypointId from;

  /// The other arm of the angle.
  final KeypointId to;

  /// Below this angle (degrees) the joint is at the bottom of the movement.
  final double lowThreshold;

  /// Above this angle (degrees) the joint is back at the top of the movement.
  final double highThreshold;

  /// Minimum keypoint confidence required to use a measurement.
  final double minConfidence;
}

/// Counts repetitions from [PoseFrame]s by tracking a joint angle.
///
/// Algorithm: the rep counter starts in the [_RepPhase.top] phase. Once the
/// tracked angle dips below [RepAngleConfig.lowThreshold] the phase switches to
/// [_RepPhase.bottom]. When it rises back above [RepAngleConfig.highThreshold]
/// a rep is recorded and the phase returns to [_RepPhase.top].
///
/// Pure-Dart and synchronous — feed it frames directly in tests without needing
/// the tflite model or any hardware.
class PoseRepCounter {
  PoseRepCounter(this.config);

  final RepAngleConfig config;

  int _count = 0;
  _RepPhase _phase = _RepPhase.top;

  int get repCount => _count;

  /// Processes one [frame] and returns a [RepEvent] if a rep just completed,
  /// or null otherwise.
  RepEvent? processFrame(PoseFrame frame, DateTime timestamp) {
    final angle = _measureAngle(frame);
    if (angle == null) return null;

    switch (_phase) {
      case _RepPhase.top:
        if (angle < config.lowThreshold) {
          _phase = _RepPhase.bottom;
        }
      case _RepPhase.bottom:
        if (angle > config.highThreshold) {
          _phase = _RepPhase.top;
          _count++;
          return RepEvent(index: _count, timestamp: timestamp);
        }
    }
    return null;
  }

  /// Resets the rep count and phase. Call this on [WorkoutSensorSource.stopTracking].
  void reset() {
    _count = 0;
    _phase = _RepPhase.top;
  }

  double? _measureAngle(PoseFrame frame) => frame.angleDegrees(
        config.from,
        config.pivot,
        config.to,
        minConfidence: config.minConfidence,
      );
}

enum _RepPhase { top, bottom }
