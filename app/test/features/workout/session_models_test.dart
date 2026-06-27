import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/features/plans/plan_models.dart';
import 'package:gymbuddy/features/workout/session_mapper.dart';
import 'package:gymbuddy/features/workout/session_models.dart';
import 'package:gymbuddy/sensors/sensor_source.dart';

void main() {
  group('value types', () {
    test('SessionExercise has defaults and value equality', () {
      const exercise = SessionExercise(
        exercise: TrackedExercise(name: 'Squat', formTracked: true),
      );
      expect(exercise.sets, 1);
      expect(exercise.targetReps, isNull);
      expect(exercise.restSeconds, 60);
      expect(
        exercise,
        const SessionExercise(
          exercise: TrackedExercise(name: 'Squat', formTracked: true),
        ),
      );
      expect(
        exercise,
        isNot(const SessionExercise(
          exercise: TrackedExercise(name: 'Squat', formTracked: true),
          sets: 3,
        )),
      );
    });

    test('SessionPlan and CompletedSet have value equality', () {
      const a = SessionPlan(
        name: 'Push',
        exercises: <SessionExercise>[
          SessionExercise(exercise: TrackedExercise(name: 'Bench')),
        ],
      );
      const b = SessionPlan(
        name: 'Push',
        exercises: <SessionExercise>[
          SessionExercise(exercise: TrackedExercise(name: 'Bench')),
        ],
      );
      expect(a, b);
      expect(SessionPlan.empty.exercises, isEmpty);
      expect(
        const CompletedSet(exerciseName: 'Bench', setNumber: 1, reps: 10),
        const CompletedSet(exerciseName: 'Bench', setNumber: 1, reps: 10),
      );
      expect(
        const CompletedSet(exerciseName: 'Bench', setNumber: 1, reps: 10),
        isNot(const CompletedSet(exerciseName: 'Bench', setNumber: 1, reps: 9)),
      );
      // Weight is part of identity; it defaults to null (unlogged).
      expect(
        const CompletedSet(exerciseName: 'Bench', setNumber: 1, reps: 10).weight,
        isNull,
      );
      expect(
        const CompletedSet(
            exerciseName: 'Bench', setNumber: 1, reps: 10, weight: 60),
        const CompletedSet(
            exerciseName: 'Bench', setNumber: 1, reps: 10, weight: 60),
      );
      expect(
        const CompletedSet(
            exerciseName: 'Bench', setNumber: 1, reps: 10, weight: 60),
        isNot(const CompletedSet(exerciseName: 'Bench', setNumber: 1, reps: 10)),
      );
    });
  });

  group('WorkoutSessionState', () {
    test('idle starts empty and exposes derived getters', () {
      final state = WorkoutSessionState.idle();
      expect(state.isIdle, isTrue);
      expect(state.currentExercise, isNull);
      expect(state.targetReps, isNull);
      expect(state.totalExercises, 0);
    });

    test('currentExercise/targetReps reflect the position', () {
      const plan = SessionPlan(
        name: 'Legs',
        exercises: <SessionExercise>[
          SessionExercise(
            exercise: TrackedExercise(name: 'Squat'),
            sets: 3,
            targetReps: 8,
          ),
          SessionExercise(exercise: TrackedExercise(name: 'Lunge')),
        ],
      );
      final state = WorkoutSessionState.idle().copyWith(
        status: SessionStatus.exercising,
        plan: plan,
        exerciseIndex: 0,
      );
      expect(state.currentExercise?.exercise.name, 'Squat');
      expect(state.targetReps, 8);
      expect(state.exerciseNumber, 1);
      expect(state.totalExercises, 2);
    });

    test('copyWith clearFormCue nulls the cue, otherwise it is preserved', () {
      const cue = FormCue(severity: FormSeverity.minor, message: 'Slow down');
      final withCue = WorkoutSessionState.idle().copyWith(formCue: cue);
      expect(withCue.formCue, cue);
      expect(withCue.copyWith(reps: 5).formCue, cue);
      expect(withCue.copyWith(clearFormCue: true).formCue, isNull);
    });
  });

  group('PlanWorkout.toSessionPlan (the session edge)', () {
    test('maps exercises down to TrackedExercise with prescriptions', () {
      const workout = PlanWorkout(
        name: 'Leg Day',
        exercises: <PlanExercise>[
          PlanExercise(
            name: 'Back Squat',
            formTracked: true,
            sets: 3,
            reps: 8,
            restSeconds: 90,
          ),
          PlanExercise(name: 'Plank', formTracked: false),
        ],
      );

      final session = workout.toSessionPlan();

      expect(session.name, 'Leg Day');
      expect(session.exercises, hasLength(2));
      final squat = session.exercises[0];
      expect(squat.exercise,
          const TrackedExercise(name: 'Back Squat', formTracked: true));
      expect(squat.sets, 3);
      expect(squat.targetReps, 8);
      expect(squat.restSeconds, 90);

      final plank = session.exercises[1];
      expect(plank.exercise.formTracked, isFalse);
      // Missing prescription falls back to defaults; null reps = manual set.
      expect(plank.sets, 1);
      expect(plank.targetReps, isNull);
      expect(plank.restSeconds, 60);
    });
  });
}
