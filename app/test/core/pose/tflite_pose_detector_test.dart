import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/pose/pose_detector.dart';
import 'package:gymbuddy/core/pose/tflite_pose_detector.dart';

void main() {
  // A loader that always fails — the headless reality (the .tflite asset isn't
  // bundled and the native runtime is absent under `flutter test`). Lets us
  // drive the graceful-degradation path without touching tflite_flutter FFI.
  Future<Never> failingLoader(String _) async =>
      throw Exception('model not bundled');

  group('graceful degradation when the model is absent', () {
    test('init returns false and the detector stays not ready', () async {
      final detector = TflitePoseDetector(loadInterpreter: failingLoader);
      addTearDown(detector.dispose);

      expect(await detector.init(), isFalse);
      expect(detector.isReady, isFalse);
    });

    test('does not consume camera frames when the model failed to load',
        () async {
      final frames = StreamController<PoseInput>.broadcast();
      addTearDown(frames.close);
      final detector = TflitePoseDetector(
        frameSource: frames.stream,
        loadInterpreter: failingLoader,
      );

      expect(await detector.init(), isFalse);
      // A failed model must not subscribe to the camera stream, so no frame is
      // ever run through (a missing inference path, not a crashing one).
      expect(frames.hasListener, isFalse);
    });

    test('init after dispose throws', () async {
      final detector = TflitePoseDetector(loadInterpreter: failingLoader);
      await detector.dispose();
      await expectLater(detector.init(), throwsStateError);
    });

    test('dispose is idempotent', () async {
      final detector = TflitePoseDetector(loadInterpreter: failingLoader);
      await detector.dispose();
      await expectLater(detector.dispose(), completes);
    });
  });

  group('buildInputTensor', () {
    test('packs a [1, size, size, 3] tensor at the model resolution', () {
      final input = PoseInput(
        rgb: Uint8List(4 * 4 * 3),
        width: 4,
        height: 4,
      );
      final tensor = TflitePoseDetector.buildInputTensor(input, size: 8);

      expect(tensor, hasLength(1));
      expect(tensor[0], hasLength(8));
      expect(tensor[0][0], hasLength(8));
      expect(tensor[0][0][0], hasLength(3));
    });

    test('nearest-neighbour samples the source pixels', () {
      // A 2x2 image with a distinct colour per pixel.
      final rgb = Uint8List.fromList(<int>[
        10, 11, 12, // (0,0)
        20, 21, 22, // (1,0)
        30, 31, 32, // (0,1)
        40, 41, 42, // (1,1)
      ]);
      final input = PoseInput(rgb: rgb, width: 2, height: 2);

      // size == source size => an exact 1:1 mapping.
      final tensor = TflitePoseDetector.buildInputTensor(input, size: 2);

      expect(tensor[0][0][0], <int>[10, 11, 12]);
      expect(tensor[0][0][1], <int>[20, 21, 22]);
      expect(tensor[0][1][0], <int>[30, 31, 32]);
      expect(tensor[0][1][1], <int>[40, 41, 42]);
    });
  });

  group('decodeOutput', () {
    test('maps MoveNet (y, x, score) triples onto Keypoints', () {
      // 17 keypoints; give each a recognisable triple.
      final raw = List<List<double>>.generate(
        17,
        (i) => <double>[i * 0.01, i * 0.02, i * 0.05],
      );
      final output = <Object>[
        <Object>[raw],
      ];

      final ts = DateTime.fromMillisecondsSinceEpoch(1234);
      final frame = TflitePoseDetector.decodeOutput(output, timestamp: ts);

      expect(frame.keypoints, hasLength(17));
      expect(frame.timestamp, ts);

      final nose = frame[KeypointId.nose]!;
      expect(nose.y, 0.0);
      expect(nose.x, 0.0);
      expect(nose.confidence, 0.0);

      final leftKnee = frame[KeypointId.leftKnee]!; // index 13
      expect(leftKnee.y, closeTo(13 * 0.01, 1e-9));
      expect(leftKnee.x, closeTo(13 * 0.02, 1e-9));
      expect(leftKnee.confidence, closeTo(13 * 0.05, 1e-9));
    });
  });
}
