import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/pose/exercise_form_configs.dart';
import 'package:gymbuddy/core/pose/pose_detector.dart';
import 'package:gymbuddy/core/pose/pose_form_checker.dart';
import 'package:gymbuddy/sensors/sensor_source.dart';

// A torso-lean-style rule: fault when the shoulder–hip–knee angle drops below
// 45° (folded too far forward). The upper bound is wide open.
const _leanRule = FormRule(
  id: 'lean',
  pivot: KeypointId.leftHip,
  from: KeypointId.leftShoulder,
  to: KeypointId.leftKnee,
  minAngle: 45.0,
  maxAngle: 180.0,
  severity: FormSeverity.minor,
  message: 'chest up',
);

/// Builds a frame where the shoulder–hip–knee angle is [angleDeg].
/// Pivot (hip) at origin; one arm up (0,1); the other rotated by [angleDeg].
PoseFrame _leanFrame(double angleDeg, {double confidence = 0.9}) {
  final rad = angleDeg * math.pi / 180;
  return PoseFrame(
    keypoints: [
      Keypoint(
        id: KeypointId.leftShoulder,
        x: 0,
        y: 1,
        confidence: confidence,
      ),
      Keypoint(id: KeypointId.leftHip, x: 0, y: 0, confidence: confidence),
      Keypoint(
        id: KeypointId.leftKnee,
        x: math.sin(rad),
        y: math.cos(rad),
        confidence: confidence,
      ),
    ],
  );
}

void main() {
  group('FormRule', () {
    test('assert fires when minAngle > maxAngle', () {
      expect(
        () => FormRule(
          id: 'bad',
          pivot: KeypointId.leftHip,
          from: KeypointId.leftShoulder,
          to: KeypointId.leftKnee,
          minAngle: 180.0,
          maxAngle: 45.0,
          severity: FormSeverity.minor,
          message: 'x',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('minConfidence defaults to 0.3', () {
      expect(_leanRule.minConfidence, 0.3);
    });
  });

  group('PoseFormChecker', () {
    test('emits no cue for a frame inside the good band', () {
      final checker = PoseFormChecker(const [_leanRule]);
      expect(checker.processFrame(_leanFrame(90)), isEmpty);
    });

    test('fires a cue carrying the rule severity and message on a fault', () {
      final checker = PoseFormChecker(const [_leanRule]);
      final cues = checker.processFrame(_leanFrame(30)); // < 45° → fault
      expect(cues, hasLength(1));
      expect(
        cues.single,
        const FormCue(severity: FormSeverity.minor, message: 'chest up'),
      );
    });

    test('fires above the upper bound too', () {
      // A rule with a closed upper bound fires when the angle exceeds it.
      const closed = FormRule(
        id: 'closed',
        pivot: KeypointId.leftHip,
        from: KeypointId.leftShoulder,
        to: KeypointId.leftKnee,
        minAngle: 45.0,
        maxAngle: 120.0,
        severity: FormSeverity.major,
        message: 'too open',
      );
      final checker = PoseFormChecker(const [closed]);
      expect(checker.processFrame(_leanFrame(90)), isEmpty);
      expect(checker.processFrame(_leanFrame(160)), hasLength(1)); // > 120°
    });

    test('is edge-triggered: a held fault fires only once', () {
      final checker = PoseFormChecker(const [_leanRule]);
      expect(checker.processFrame(_leanFrame(30)), hasLength(1));
      expect(checker.processFrame(_leanFrame(20)), isEmpty);
      expect(checker.processFrame(_leanFrame(35)), isEmpty);
    });

    test('fires again after recovering into the good band', () {
      final checker = PoseFormChecker(const [_leanRule]);
      expect(checker.processFrame(_leanFrame(30)), hasLength(1)); // fault
      expect(checker.processFrame(_leanFrame(90)), isEmpty); // recovered
      expect(checker.processFrame(_leanFrame(30)), hasLength(1)); // fault again
    });

    test('cannot evaluate a rule on a low-confidence frame (state unchanged)',
        () {
      final checker = PoseFormChecker(const [_leanRule]);
      // A low-confidence fault frame is skipped — no cue, no state change...
      expect(
        checker.processFrame(_leanFrame(30, confidence: 0.1)),
        isEmpty,
      );
      // ...so a subsequent clear fault frame still fires.
      expect(checker.processFrame(_leanFrame(30)), hasLength(1));
    });

    test('skips a rule whose keypoints are absent from the frame', () {
      final checker = PoseFormChecker(const [_leanRule]);
      const frame = PoseFrame(
        keypoints: [
          Keypoint(id: KeypointId.leftShoulder, x: 0, y: 1, confidence: 0.9),
          // leftHip (pivot) absent
          Keypoint(id: KeypointId.leftKnee, x: 1, y: 0, confidence: 0.9),
        ],
      );
      expect(checker.processFrame(frame), isEmpty);
    });

    test('evaluates multiple rules independently', () {
      const sag = FormRule(
        id: 'sag',
        pivot: KeypointId.leftKnee,
        from: KeypointId.leftHip,
        to: KeypointId.leftAnkle,
        minAngle: 45.0,
        maxAngle: 180.0,
        severity: FormSeverity.major,
        message: 'knees',
      );
      final checker = PoseFormChecker(const [_leanRule, sag]);
      // Only the lean rule's keypoints are present and faulted.
      final cues = checker.processFrame(_leanFrame(30));
      expect(cues, hasLength(1));
      expect(cues.single.message, 'chest up');
    });

    test('reset clears state so a held fault fires anew', () {
      final checker = PoseFormChecker(const [_leanRule]);
      expect(checker.processFrame(_leanFrame(30)), hasLength(1));
      checker.reset();
      expect(checker.processFrame(_leanFrame(30)), hasLength(1));
    });
  });

  group('resolveFormRules', () {
    test('returns rules for known exercises (case-insensitive)', () {
      expect(resolveFormRules('squat'), isNotEmpty);
      expect(resolveFormRules('Squat'), isNotEmpty);
      expect(resolveFormRules('SQUAT'), isNotEmpty);
    });

    test('returns an empty list for an exercise without form rules', () {
      expect(resolveFormRules('bicep curl'), isEmpty);
      expect(resolveFormRules('handstand'), isEmpty);
    });

    test('every configured rule resolves and has a non-empty message', () {
      for (final entry in kExerciseFormConfigs.entries) {
        final rules = resolveFormRules(entry.key);
        expect(rules, isNotEmpty, reason: '"${entry.key}" should resolve');
        for (final rule in rules) {
          expect(rule.message, isNotEmpty);
          expect(rule.minAngle, lessThanOrEqualTo(rule.maxAngle));
        }
      }
    });

    test('rule ids are unique across the whole config', () {
      final ids = <String>[];
      for (final rules in kExerciseFormConfigs.values) {
        ids.addAll(rules.map((r) => r.id));
      }
      expect(ids.toSet(), hasLength(ids.length));
    });
  });
}
