import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/pose/exercise_angle_configs.dart';
import 'package:gymbuddy/core/pose/pose_detector.dart';
import 'package:gymbuddy/core/pose/pose_rep_counter.dart';

// A squat-like config: pivot = leftKnee, low = 90°, high = 150°.
const _config = RepAngleConfig(
  pivot: KeypointId.leftKnee,
  from: KeypointId.leftHip,
  to: KeypointId.leftAnkle,
  lowThreshold: 90.0,
  highThreshold: 150.0,
);

/// Builds a frame where the leftHip–leftKnee–leftAnkle angle is [angleDeg].
/// Pivot at origin; one arm points up (0,1); the other is rotated by [angleDeg].
PoseFrame _frameAt(double angleDeg) {
  final rad = angleDeg * math.pi / 180;
  return PoseFrame(
    keypoints: [
      const Keypoint(id: KeypointId.leftHip, x: 0, y: 1, confidence: 0.9),
      const Keypoint(id: KeypointId.leftKnee, x: 0, y: 0, confidence: 0.9),
      Keypoint(
        id: KeypointId.leftAnkle,
        x: math.sin(rad),
        y: math.cos(rad),
        confidence: 0.9,
      ),
    ],
  );
}

final _ts = DateTime(2024);

void main() {
  group('RepAngleConfig', () {
    test('assert fires when lowThreshold >= highThreshold', () {
      expect(
        () => RepAngleConfig(
          pivot: KeypointId.leftKnee,
          from: KeypointId.leftHip,
          to: KeypointId.leftAnkle,
          lowThreshold: 150.0,
          highThreshold: 90.0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('minConfidence defaults to 0.3', () {
      expect(_config.minConfidence, 0.3);
    });
  });

  group('PoseRepCounter', () {
    test('starts at zero', () {
      expect(PoseRepCounter(_config).repCount, 0);
    });

    test('returns null while angle stays above lowThreshold', () {
      final counter = PoseRepCounter(_config);
      expect(counter.processFrame(_frameAt(170), _ts), isNull);
      expect(counter.repCount, 0);
    });

    test('records one rep for a full top→bottom→top cycle', () {
      final counter = PoseRepCounter(_config);
      counter.processFrame(_frameAt(80), _ts); // below lowThreshold
      final event = counter.processFrame(_frameAt(160), _ts); // above highThreshold
      expect(event, isNotNull);
      expect(event!.index, 1);
      expect(counter.repCount, 1);
    });

    test('does not count a rep if the angle never dips below lowThreshold', () {
      final counter = PoseRepCounter(_config);
      counter.processFrame(_frameAt(120), _ts);
      expect(counter.processFrame(_frameAt(160), _ts), isNull);
      expect(counter.repCount, 0);
    });

    test('counts two consecutive reps correctly', () {
      final counter = PoseRepCounter(_config);
      counter.processFrame(_frameAt(80), _ts);
      counter.processFrame(_frameAt(160), _ts); // rep 1
      counter.processFrame(_frameAt(80), _ts);
      final event = counter.processFrame(_frameAt(160), _ts); // rep 2
      expect(event?.index, 2);
      expect(counter.repCount, 2);
    });

    test('reset clears count and phase so the next cycle counts from 1', () {
      final counter = PoseRepCounter(_config);
      counter.processFrame(_frameAt(80), _ts);
      counter.processFrame(_frameAt(160), _ts); // rep 1
      counter.reset();
      expect(counter.repCount, 0);
      counter.processFrame(_frameAt(80), _ts);
      final event = counter.processFrame(_frameAt(160), _ts);
      expect(event?.index, 1);
    });

    test('returns null when a keypoint is below minConfidence', () {
      final counter = PoseRepCounter(_config);
      const frame = PoseFrame(
        keypoints: [
          Keypoint(id: KeypointId.leftHip, x: 0, y: 1, confidence: 0.1),
          Keypoint(id: KeypointId.leftKnee, x: 0, y: 0, confidence: 0.9),
          Keypoint(id: KeypointId.leftAnkle, x: 0, y: -1, confidence: 0.9),
        ],
      );
      expect(counter.processFrame(frame, _ts), isNull);
    });

    test('returns null when a required keypoint is absent from the frame', () {
      final counter = PoseRepCounter(_config);
      const frame = PoseFrame(
        keypoints: [
          Keypoint(id: KeypointId.leftHip, x: 0, y: 1, confidence: 0.9),
          // leftKnee absent
          Keypoint(id: KeypointId.leftAnkle, x: 0, y: -1, confidence: 0.9),
        ],
      );
      expect(counter.processFrame(frame, _ts), isNull);
    });
  });

  group('resolveAngleConfig', () {
    test('returns a config for known exercises (case-insensitive)', () {
      expect(resolveAngleConfig('squat'), isNotNull);
      expect(resolveAngleConfig('Squat'), isNotNull);
      expect(resolveAngleConfig('SQUAT'), isNotNull);
    });

    test('returns null for an unknown exercise', () {
      expect(resolveAngleConfig('handstand'), isNull);
    });

    test('covers every entry in kExerciseAngleConfigs', () {
      for (final name in kExerciseAngleConfigs.keys) {
        expect(
          resolveAngleConfig(name),
          isNotNull,
          reason: '"$name" should resolve',
        );
      }
    });

    test('resolves all expected exercise names', () {
      const expected = [
        'squat',
        'deadlift',
        'bicep curl',
        'push-up',
        'lunge',
        'shoulder press',
        'romanian deadlift',
        'overhead press',
      ];
      for (final name in expected) {
        expect(
          resolveAngleConfig(name),
          isNotNull,
          reason: '"$name" missing from kExerciseAngleConfigs',
        );
      }
    });
  });
}
