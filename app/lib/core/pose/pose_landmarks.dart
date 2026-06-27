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
}
