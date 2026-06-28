import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gymbuddy/core/pose/pose_detector.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Bundled MoveNet SinglePose Lightning model. Absent from the repo (only a
/// `.gitkeep` lives in `assets/models/`); download the quantised TFLite file
/// from https://tfhub.dev/google/lite-model/movenet/singlepose/lightning/3 and
/// drop it here before building for a device. Until then [TflitePoseDetector]
/// stays "not ready" and the app falls back to the native/mock rep path.
const String kPoseModelAsset = 'assets/models/movenet_lightning.tflite';

/// MoveNet Lightning takes a square `kMoveNetInputSize` RGB image.
const int kMoveNetInputSize = 192;

/// Loads a tflite [Interpreter] for the given asset. Injected so tests exercise
/// the graceful-degradation path without touching the native FFI runtime (which
/// isn't available under `flutter test`).
typedef InterpreterLoader = Future<Interpreter> Function(String asset);

/// The real, on-device [PoseDetector]: MoveNet SinglePose Lightning via
/// tflite_flutter, fed by the glasses' POV camera frames.
///
/// Construction is cheap and touches no native code — the model loads lazily in
/// [init]. When the `.tflite` asset isn't bundled (every build until it's
/// dropped into `assets/models/`) or the native runtime is unavailable, [init]
/// catches the failure, returns `false`, and the detector stays
/// [isReady]` == false` with a silent [frames] stream, so rep counting falls
/// back gracefully — the same mock-first posture as the sensor layer.
///
/// Once ready it subscribes to [frameSource] — the raw camera frames the
/// glasses source decodes off its native camera channel — runs each through the
/// model, and emits the decoded [PoseFrame] on [frames].
class TflitePoseDetector implements PoseDetector {
  TflitePoseDetector({
    this.frameSource,
    this.modelAsset = kPoseModelAsset,
    InterpreterLoader? loadInterpreter,
  }) : _loadInterpreter = loadInterpreter ?? Interpreter.fromAsset;

  final Stream<PoseInput>? frameSource;
  final String modelAsset;
  final InterpreterLoader _loadInterpreter;

  final _controller = StreamController<PoseFrame>.broadcast();
  Interpreter? _interpreter;
  StreamSubscription<PoseInput>? _frameSub;
  bool _disposed = false;

  @override
  bool get isReady => _interpreter != null && !_disposed;

  @override
  Stream<PoseFrame> get frames => _controller.stream;

  @override
  Future<bool> init() async {
    if (_disposed) throw StateError('TflitePoseDetector used after dispose()');
    if (_interpreter != null) return true;
    try {
      _interpreter = await _loadInterpreter(modelAsset);
    } on Object {
      // Model not bundled / native runtime unavailable. Degrade gracefully:
      // [frames] stays silent and rep counting falls back to another path.
      _interpreter = null;
      return false;
    }
    // Only start consuming camera frames once the model is actually loaded.
    final source = frameSource;
    if (source != null) {
      _frameSub = source.listen(_onFrame);
    }
    return true;
  }

  void _onFrame(PoseInput input) {
    final frame = _estimate(input);
    if (frame != null && !_controller.isClosed) {
      _controller.add(frame);
    }
  }

  /// Runs one frame through the model. Returns null when not ready or if
  /// inference throws (a single bad frame must not tear down the stream).
  PoseFrame? _estimate(PoseInput input) {
    final interpreter = _interpreter;
    if (interpreter == null) return null;
    try {
      final inputTensor = buildInputTensor(input);
      // MoveNet SinglePose output: [1, 1, 17, 3] of (y, x, score) in 0..1.
      final output = [
        [List.generate(17, (_) => List<double>.filled(3, 0.0))],
      ];
      interpreter.run(inputTensor, output);
      return decodeOutput(output, timestamp: input.timestamp);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _frameSub?.cancel();
    _interpreter?.close();
    _interpreter = null;
    await _controller.close();
  }

  /// Resizes [input] to the model's square input via nearest-neighbour
  /// sampling and packs it as a `[1, size, size, 3]` uint8 tensor.
  ///
  /// Visible for testing: pure and native-free, so preprocessing is verified
  /// headless without a loaded interpreter.
  @visibleForTesting
  static List<List<List<List<int>>>> buildInputTensor(
    PoseInput input, {
    int size = kMoveNetInputSize,
  }) {
    final rgb = input.rgb;
    final srcW = input.width;
    final srcH = input.height;
    return List<List<List<List<int>>>>.generate(1, (_) {
      return List<List<List<int>>>.generate(size, (dy) {
        final sy = (dy * srcH ~/ size).clamp(0, srcH - 1);
        return List<List<int>>.generate(size, (dx) {
          final sx = (dx * srcW ~/ size).clamp(0, srcW - 1);
          final base = (sy * srcW + sx) * 3;
          return <int>[rgb[base], rgb[base + 1], rgb[base + 2]];
        });
      });
    });
  }

  /// Decodes a MoveNet SinglePose output tensor (`[1, 1, 17, 3]`, each triple
  /// `(y, x, score)` normalised to 0..1) into a [PoseFrame].
  ///
  /// Visible for testing: pure, so the keypoint mapping is verified headless.
  @visibleForTesting
  static PoseFrame decodeOutput(Object output, {DateTime? timestamp}) {
    final batch = output as List;
    final person = batch[0] as List;
    final rawKeypoints = person[0] as List;
    final keypoints = <Keypoint>[];
    final count = KeypointId.values.length < rawKeypoints.length
        ? KeypointId.values.length
        : rawKeypoints.length;
    for (var i = 0; i < count; i++) {
      final triple = rawKeypoints[i] as List;
      keypoints.add(
        Keypoint(
          id: KeypointId.values[i],
          // MoveNet emits (y, x, score); our Keypoint is (x, y, confidence).
          y: (triple[0] as num).toDouble(),
          x: (triple[1] as num).toDouble(),
          confidence: (triple[2] as num).toDouble(),
        ),
      );
    }
    return PoseFrame(keypoints: keypoints, timestamp: timestamp);
  }
}
