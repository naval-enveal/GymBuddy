import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/pose/pose_detector.dart';

void main() {
  group('poseDetectorProvider', () {
    test('defaults to a MockPoseDetector', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(poseDetectorProvider), isA<MockPoseDetector>());
    });
  });

  group('value types', () {
    test('Keypoint has value equality', () {
      const a = Keypoint(
        id: KeypointId.leftKnee,
        x: 0.4,
        y: 0.8,
        confidence: 0.95,
      );
      const b = Keypoint(
        id: KeypointId.leftKnee,
        x: 0.4,
        y: 0.8,
        confidence: 0.95,
      );
      const c = Keypoint(
        id: KeypointId.rightKnee,
        x: 0.4,
        y: 0.8,
        confidence: 0.95,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('PoseFrame operator[] returns the matching keypoint', () {
      const kp = Keypoint(
        id: KeypointId.leftShoulder,
        x: 0.3,
        y: 0.2,
        confidence: 0.9,
      );
      const frame = PoseFrame(keypoints: [kp]);
      expect(frame[KeypointId.leftShoulder], equals(kp));
    });

    test('PoseFrame operator[] returns null for an absent keypoint', () {
      const frame = PoseFrame(keypoints: []);
      expect(frame[KeypointId.nose], isNull);
    });
  });

  group('MockPoseDetector', () {
    late MockPoseDetector detector;

    setUp(() => detector = MockPoseDetector());
    tearDown(() => detector.dispose());

    test('isReady is false before init', () {
      expect(detector.isReady, isFalse);
    });

    test('init returns true and sets isReady', () async {
      final result = await detector.init();
      expect(result, isTrue);
      expect(detector.isReady, isTrue);
    });

    test('frames is a broadcast stream', () {
      expect(detector.frames.isBroadcast, isTrue);
    });

    test('emitFrame delivers the frame to a subscriber', () async {
      const kp = Keypoint(
        id: KeypointId.rightHip,
        x: 0.5,
        y: 0.6,
        confidence: 0.85,
      );
      const frame = PoseFrame(keypoints: [kp]);

      final received = <PoseFrame>[];
      final sub = detector.frames.listen(received.add);
      addTearDown(sub.cancel);

      detector.emitFrame(frame);
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.single[KeypointId.rightHip], equals(kp));
    });

    test('emitFrame throws after dispose', () async {
      await detector.dispose();
      expect(
        () => detector.emitFrame(const PoseFrame(keypoints: [])),
        throwsStateError,
      );
    });

    test('multiple subscribers each receive emitted frames', () async {
      final a = <PoseFrame>[];
      final b = <PoseFrame>[];
      final subA = detector.frames.listen(a.add);
      final subB = detector.frames.listen(b.add);
      addTearDown(subA.cancel);
      addTearDown(subB.cancel);

      detector.emitFrame(const PoseFrame(keypoints: []));
      await Future<void>.delayed(Duration.zero);

      expect(a, hasLength(1));
      expect(b, hasLength(1));
    });
  });
}
