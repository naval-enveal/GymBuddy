import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gymbuddy/core/pose/pose_landmarks.dart';

export 'pose_landmarks.dart';

/// A single camera frame handed to a [PoseDetector] for estimation.
///
/// Feature-agnostic and decoupled from any camera plugin: it carries the raw
/// RGB pixels (3 bytes per pixel — red, green, blue — row-major, top-left
/// origin, no alpha or row padding) plus the source dimensions. The detector
/// resizes to whatever its model expects, so callers hand frames over at their
/// native resolution. The glasses-backed sensor source converts the DAT SDK's
/// POV camera frames into this shape; the detector owns no camera concerns.
class PoseInput {
  PoseInput({
    required this.rgb,
    required this.width,
    required this.height,
    this.timestamp,
  }) : assert(
          rgb.length == width * height * 3,
          'rgb must hold width*height*3 bytes '
          '(got ${rgb.length} for ${width}x$height)',
        );

  /// Packed 8-bit RGB pixels, length `width * height * 3`.
  final Uint8List rgb;

  /// Frame width in pixels.
  final int width;

  /// Frame height in pixels.
  final int height;

  /// When the frame was captured, if known — carried onto the resulting
  /// [PoseFrame] so downstream rep timing (M8 task 2) can use it.
  final DateTime? timestamp;
}

/// The pose-estimation seam every rep/form feature depends on.
///
/// Feature code never calls tflite_flutter directly — it goes through this
/// interface, so the session engine and form checks run unchanged against the
/// [MockPoseDetector] (tests, no hardware) or [TflitePoseDetector] (real
/// device). Mirrors the [WorkoutSensorSource] mock-first pattern.
///
/// Implementations degrade gracefully: if the model can't load (the `.tflite`
/// asset isn't bundled yet, or the platform has no delegate), [init] returns
/// `false`, [isReady] stays `false`, and [frames] simply never emits — rep
/// counting falls back to the native or mock path rather than crashing.
abstract interface class PoseDetector {
  /// Whether the model is loaded and [frames] can produce poses.
  bool get isReady;

  /// Initialises the detector (loads the model). Returns whether it is now
  /// ready; safe to call more than once. Never throws on a load failure — it
  /// returns `false`.
  Future<bool> init();

  /// Estimated pose frames emitted in real time. Broadcast stream.
  Stream<PoseFrame> get frames;

  /// Releases model resources. The detector must not be used afterwards.
  Future<void> dispose();
}

/// The active pose detector.
///
/// Defaults to [MockPoseDetector] so every rep/form feature builds and runs
/// with no model bundled. The real device path is owned by
/// `MetaGlassesSensorSource`, which wires a `TflitePoseDetector` to the
/// glasses' POV camera stream; this provider is the app-level seam the coach
/// layer (M9) reads, overridden at the composition root once pose is live.
final poseDetectorProvider = Provider<PoseDetector>((ref) {
  final detector = MockPoseDetector();
  ref.onDispose(detector.dispose);
  return detector;
});

/// A controllable pose detector for tests and hardware-free dev.
///
/// Frames are pushed manually via [emitFrame] — never auto-simulated, so tests
/// stay fully deterministic. Independent of the workout session lifecycle: any
/// subscriber can call [emitFrame] at any time, just as [MockSensorSource]
/// exposes [emitRep] independently of `startTracking`.
class MockPoseDetector implements PoseDetector {
  final _controller = StreamController<PoseFrame>.broadcast();
  bool _ready = false;
  bool _disposed = false;

  @override
  bool get isReady => _ready;

  @override
  Future<bool> init() async {
    if (_disposed) throw StateError('MockPoseDetector used after dispose()');
    _ready = true;
    return true;
  }

  @override
  Stream<PoseFrame> get frames => _controller.stream;

  /// Pushes [frame] onto [frames]. Throws after [dispose].
  void emitFrame(PoseFrame frame) {
    if (_disposed) throw StateError('MockPoseDetector used after dispose()');
    _controller.add(frame);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _ready = false;
    await _controller.close();
  }
}
