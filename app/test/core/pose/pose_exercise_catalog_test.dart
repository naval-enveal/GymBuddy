import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/pose/exercise_angle_configs.dart';
import 'package:gymbuddy/core/pose/exercise_form_configs.dart';
import 'package:gymbuddy/core/pose/pose_exercise_catalog.dart';
import 'package:gymbuddy/core/pose/pose_exercise_matching.dart';

void main() {
  group('matchCanonicalKey', () {
    const keys = ['squat', 'deadlift', 'romanian deadlift', 'bicep curl'];

    test('matches a key as a case-insensitive substring of the name', () {
      expect(matchCanonicalKey('Back Squat', keys), 'squat');
      expect(matchCanonicalKey('GOBLET SQUAT', keys), 'squat');
      expect(matchCanonicalKey('Dumbbell Bicep Curl', keys), 'bicep curl');
    });

    test('prefers the longest matching key', () {
      // "Romanian Deadlift" contains both "deadlift" and "romanian deadlift";
      // the more specific movement must win.
      expect(matchCanonicalKey('Dumbbell Romanian Deadlift', keys),
          'romanian deadlift');
      expect(matchCanonicalKey('Deadlift', keys), 'deadlift');
    });

    test('returns null when nothing matches or the name is blank', () {
      expect(matchCanonicalKey('Front Plank', keys), isNull);
      expect(matchCanonicalKey('', keys), isNull);
      expect(matchCanonicalKey('   ', keys), isNull);
    });
  });

  group('canonicalExerciseKey', () {
    test('resolves real descriptive plan names to canonical movements', () {
      expect(canonicalExerciseKey('Back Squat'), 'squat');
      expect(canonicalExerciseKey('Goblet Squat'), 'squat');
      expect(canonicalExerciseKey('Bulgarian Split Squat'), 'squat');
      expect(canonicalExerciseKey('Dumbbell Bicep Curl'), 'bicep curl');
      expect(canonicalExerciseKey('Reverse Lunge'), 'lunge');
      expect(canonicalExerciseKey('Incline Push-up'), 'push-up');
      expect(canonicalExerciseKey('Dumbbell Overhead Press'), 'overhead press');
      expect(
          canonicalExerciseKey('Dumbbell Romanian Deadlift'), 'romanian deadlift');
      expect(canonicalExerciseKey('Deadlift'), 'deadlift');
    });

    test('returns null for movements the pose pipeline does not track', () {
      expect(canonicalExerciseKey('Front Plank'), isNull);
      expect(canonicalExerciseKey('Standing Calf Raise'), isNull);
      expect(canonicalExerciseKey('Pull-up'), isNull);
    });
  });

  group('poseTrackingFor', () {
    test('classifies form-tracked movements', () {
      for (final name in [
        'Back Squat',
        'Goblet Squat',
        'Deadlift',
        'Dumbbell Romanian Deadlift',
        'Incline Push-up',
        'Walking Lunge',
      ]) {
        expect(poseTrackingFor(name), PoseTracking.formTracked, reason: name);
      }
    });

    test('classifies rep-only movements (angle config, no form rules)', () {
      for (final name in [
        'Dumbbell Bicep Curl',
        'Dumbbell Overhead Press',
        'Overhead Press',
      ]) {
        expect(poseTrackingFor(name), PoseTracking.repsOnly, reason: name);
      }
    });

    test('classifies untracked movements as none', () {
      expect(poseTrackingFor('Front Plank'), PoseTracking.none);
      expect(poseTrackingFor('Pull-up'), PoseTracking.none);
      expect(poseTrackingFor(''), PoseTracking.none);
    });
  });

  group('PoseTracking capabilities', () {
    test('expose the right rep/form/trackable flags', () {
      expect(PoseTracking.none.isPoseTrackable, isFalse);
      expect(PoseTracking.none.isRepTracked, isFalse);
      expect(PoseTracking.none.isFormTracked, isFalse);

      expect(PoseTracking.repsOnly.isPoseTrackable, isTrue);
      expect(PoseTracking.repsOnly.isRepTracked, isTrue);
      expect(PoseTracking.repsOnly.isFormTracked, isFalse);

      expect(PoseTracking.formTracked.isPoseTrackable, isTrue);
      expect(PoseTracking.formTracked.isRepTracked, isTrue);
      expect(PoseTracking.formTracked.isFormTracked, isTrue);
    });

    test('isPoseTrackable mirrors poseTrackingFor', () {
      expect(isPoseTrackable('Back Squat'), isTrue);
      expect(isPoseTrackable('Dumbbell Bicep Curl'), isTrue);
      expect(isPoseTrackable('Front Plank'), isFalse);
    });
  });

  group('kPoseTrackableExercises (the curated set)', () {
    test('is the union of the rep and form config keys', () {
      expect(
        kPoseTrackableExercises,
        {...kExerciseAngleConfigs.keys, ...kExerciseFormConfigs.keys},
      );
      expect(kPoseTrackableExercises, isNotEmpty);
    });

    test('every form-tracked movement also has a rep config '
        '(form tracking implies rep counting)', () {
      for (final key in kExerciseFormConfigs.keys) {
        expect(
          kExerciseAngleConfigs.containsKey(key),
          isTrue,
          reason: '"$key" has form rules but no rep angle config',
        );
      }
    });
  });
}
