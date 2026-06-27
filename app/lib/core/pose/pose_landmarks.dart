import 'dart:math' as math;

/// MoveNet's 17 COCO body keypoints, in model-output order (index 0–16).
enum KeypointId {
  nose, // 0
  leftEye, // 1
  rightEye, // 2
  leftEar, // 3
  rightEar, // 4
  leftShoulder, // 5
  rightShoulder, // 6
  leftElbow, // 7
  rightElbow, // 8
  leftWrist, // 9
  rightWrist, // 10
  leftHip, // 11
  rightHip, // 12
  leftKnee, // 13
  rightKnee, // 14
  leftAnkle, // 15
  rightAnkle, // 16
}

/// A single detected body keypoint in normalised image coordinates.
class Keypoint {
  const Keypoint({
    required this.id,
    required this.x,
    required this.y,
    required this.confidence,
  });

  final KeypointId id;

  /// Horizontal position, 0 (left) → 1 (right).
  final double x;

  /// Vertical position, 0 (top) → 1 (bottom).
  final double y;

  /// Detection confidence, 0 → 1.
  final double confidence;

  @override
  bool operator ==(Object other) =>
      other is Keypoint &&
      other.id == id &&
      other.x == x &&
      other.y == y &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(id, x, y, confidence);
}

/// One pose estimation result — the body keypoints detected from a single
/// camera frame.
class PoseFrame {
  const PoseFrame({required this.keypoints, this.timestamp});

  final List<Keypoint> keypoints;

  /// When this frame was captured, if known.
  final DateTime? timestamp;

  /// Returns the keypoint for [id], or null if it is not in [keypoints].
  Keypoint? operator [](KeypointId id) {
    for (final kp in keypoints) {
      if (kp.id == id) return kp;
    }
    return null;
  }

  /// The angle in degrees at [pivot] formed by the rays pivot→[from] and
  /// pivot→[to] (range 0–180).
  ///
  /// Returns null if any of the three keypoints is absent from this frame or
  /// below [minConfidence] — the shared measurement both the [PoseRepCounter]
  /// (rep counting) and the form checks (joint-angle faults) read, so they
  /// gate on confidence identically.
  double? angleDegrees(
    KeypointId from,
    KeypointId pivot,
    KeypointId to, {
    double minConfidence = 0.0,
  }) {
    final a = this[from];
    final p = this[pivot];
    final b = this[to];
    if (a == null || p == null || b == null) return null;
    if (a.confidence < minConfidence ||
        p.confidence < minConfidence ||
        b.confidence < minConfidence) {
      return null;
    }
    final dx1 = a.x - p.x;
    final dy1 = a.y - p.y;
    final dx2 = b.x - p.x;
    final dy2 = b.y - p.y;
    final mag1 = math.sqrt(dx1 * dx1 + dy1 * dy1);
    final mag2 = math.sqrt(dx2 * dx2 + dy2 * dy2);
    if (mag1 == 0 || mag2 == 0) return 0;
    final cos = ((dx1 * dx2 + dy1 * dy2) / (mag1 * mag2)).clamp(-1.0, 1.0);
    return math.acos(cos) * 180 / math.pi;
  }
}
