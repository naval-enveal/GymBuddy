import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/network/api_client.dart';
import 'package:gymbuddy/features/workout/session_models.dart';
import 'package:gymbuddy/features/workout/workout_log_api.dart';
import 'package:gymbuddy/features/workout/workout_session_controller.dart';
import 'package:gymbuddy/sensors/mock_sensor_source.dart';
import 'package:gymbuddy/sensors/sensor_source.dart';

/// Records the workouts synced to the backend, optionally failing the save to
/// exercise the graceful-degradation path.
class _RecordingLogApi implements WorkoutLogApi {
  _RecordingLogApi({this.throws = false});

  final bool throws;
  final List<List<CompletedSet>> saved = <List<CompletedSet>>[];
  DateTime? lastStartedAt;
  DateTime? lastCompletedAt;

  @override
  Future<void> saveLog({
    required DateTime startedAt,
    required DateTime completedAt,
    required List<CompletedSet> sets,
  }) async {
    lastStartedAt = startedAt;
    lastCompletedAt = completedAt;
    saved.add(List<CompletedSet>.of(sets));
    if (throws) throw const ApiException(500, 'boom');
  }
}

void main() {
  final fixedNow = DateTime.utc(2026, 6, 27, 9);

  /// A container whose sensor source is a deterministic, manually-driven mock.
  /// The WorkoutLog sync is stubbed so no real network call fires on completion;
  /// pass a [_RecordingLogApi] to assert what gets synced.
  (ProviderContainer, MockSensorSource) makeSession({WorkoutLogApi? logApi}) {
    final mock = MockSensorSource(autoSimulate: false, clock: () => fixedNow);
    final container = ProviderContainer(
      overrides: [
        workoutSensorSourceProvider.overrideWithValue(mock),
        workoutLogApiProvider.overrideWithValue(logApi ?? _RecordingLogApi()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(mock.dispose);
    return (container, mock);
  }

  WorkoutSessionController controllerOf(ProviderContainer c) =>
      c.read(workoutSessionControllerProvider.notifier);
  WorkoutSessionState stateOf(ProviderContainer c) =>
      c.read(workoutSessionControllerProvider);

  SessionPlan planOf({
    required List<SessionExercise> exercises,
    String name = 'Workout',
  }) =>
      SessionPlan(name: name, exercises: exercises);

  group('start', () {
    test('begins at the first exercise and set, exercising', () async {
      final (container, _) = makeSession();
      final plan = planOf(exercises: const [
        SessionExercise(
          exercise: TrackedExercise(name: 'Squat'),
          sets: 3,
          targetReps: 8,
        ),
      ]);

      await controllerOf(container).start(plan);

      final state = stateOf(container);
      expect(state.isExercising, isTrue);
      expect(state.exerciseIndex, 0);
      expect(state.setNumber, 1);
      expect(state.reps, 0);
      expect(state.currentExercise?.exercise.name, 'Squat');
    });

    test('is a no-op for an empty plan', () async {
      final (container, _) = makeSession();
      await controllerOf(container).start(SessionPlan.empty);
      expect(stateOf(container).isIdle, isTrue);
    });

    test('does not restart an already-active session', () async {
      final (container, _) = makeSession();
      final first = planOf(name: 'First', exercises: const [
        SessionExercise(exercise: TrackedExercise(name: 'Squat'), targetReps: 5),
      ]);
      final second = planOf(name: 'Second', exercises: const [
        SessionExercise(exercise: TrackedExercise(name: 'Bench'), targetReps: 5),
      ]);

      await controllerOf(container).start(first);
      await controllerOf(container).start(second);

      expect(stateOf(container).plan.name, 'First');
    });
  });

  group('rep counting + auto-advance', () {
    test('counts reps from the sensor stream into state', () async {
      final (container, mock) = makeSession();
      await controllerOf(container).start(planOf(exercises: const [
        SessionExercise(
          exercise: TrackedExercise(name: 'Squat'),
          sets: 2,
          targetReps: 10,
        ),
      ]));

      mock.emitRep();
      mock.emitRep();
      await pumpEventQueue();

      expect(stateOf(container).reps, 2);
      expect(stateOf(container).isExercising, isTrue);
    });

    test('auto-advances to rest when the rep target is hit', () async {
      final (container, mock) = makeSession();
      await controllerOf(container).start(planOf(exercises: const [
        SessionExercise(
          exercise: TrackedExercise(name: 'Squat'),
          sets: 2,
          targetReps: 3,
          restSeconds: 30,
        ),
      ]));

      mock.emitRep();
      mock.emitRep();
      mock.emitRep();
      await pumpEventQueue();

      final state = stateOf(container);
      expect(state.isResting, isTrue);
      expect(state.restRemaining, 30);
      expect(state.completedSets, hasLength(1));
      expect(
        state.completedSets.single,
        const CompletedSet(exerciseName: 'Squat', setNumber: 1, reps: 3),
      );
    });

    test('a null rep target never auto-advances; completeSet ends it manually',
        () async {
      final (container, mock) = makeSession();
      await controllerOf(container).start(planOf(exercises: const [
        SessionExercise(
          exercise: TrackedExercise(name: 'Plank'),
          sets: 2,
          restSeconds: 20,
        ),
      ]));

      mock.emitRep();
      mock.emitRep();
      mock.emitRep();
      await pumpEventQueue();
      // Still exercising — reps counted but no target to trip on.
      expect(stateOf(container).isExercising, isTrue);
      expect(stateOf(container).reps, 3);

      await controllerOf(container).completeSet();
      expect(stateOf(container).isResting, isTrue);
      expect(
        stateOf(container).completedSets.single,
        const CompletedSet(exerciseName: 'Plank', setNumber: 1, reps: 3),
      );
    });

    test('reps arriving during rest are ignored', () async {
      final (container, mock) = makeSession();
      await controllerOf(container).start(planOf(exercises: const [
        SessionExercise(
          exercise: TrackedExercise(name: 'Squat'),
          sets: 2,
          targetReps: 1,
          restSeconds: 30,
        ),
      ]));

      mock.emitRep();
      await pumpEventQueue();
      expect(stateOf(container).isResting, isTrue);

      mock.emitRep();
      await pumpEventQueue();
      expect(stateOf(container).isResting, isTrue);
      expect(stateOf(container).reps, 1,
          reason: 'a rest-phase rep is ignored, not counted');
    });
  });

  group('advancing through the workout', () {
    test('skipRest moves to the next set and resets reps', () async {
      final (container, mock) = makeSession();
      await controllerOf(container).start(planOf(exercises: const [
        SessionExercise(
          exercise: TrackedExercise(name: 'Squat'),
          sets: 2,
          targetReps: 2,
          restSeconds: 30,
        ),
      ]));

      mock.emitRep();
      mock.emitRep();
      await pumpEventQueue();
      expect(stateOf(container).isResting, isTrue);

      await controllerOf(container).skipRest();
      final state = stateOf(container);
      expect(state.isExercising, isTrue);
      expect(state.setNumber, 2);
      expect(state.reps, 0);

      // Tracking resumed: new reps count again.
      mock.emitRep();
      await pumpEventQueue();
      expect(stateOf(container).reps, 1);
    });

    test('advances to the next exercise after the last set', () async {
      final (container, mock) = makeSession();
      await controllerOf(container).start(planOf(exercises: const [
        SessionExercise(
          exercise: TrackedExercise(name: 'Squat'),
          targetReps: 1,
          restSeconds: 15,
        ),
        SessionExercise(
          exercise: TrackedExercise(name: 'Lunge'),
          targetReps: 1,
          restSeconds: 15,
        ),
      ]));

      mock.emitRep();
      await pumpEventQueue();
      await controllerOf(container).skipRest();

      final state = stateOf(container);
      expect(state.isExercising, isTrue);
      expect(state.exerciseIndex, 1);
      expect(state.setNumber, 1);
      expect(state.currentExercise?.exercise.name, 'Lunge');
    });

    test('completes the workout after the final set, with no rest', () async {
      final (container, mock) = makeSession();
      await controllerOf(container).start(planOf(exercises: const [
        SessionExercise(
          exercise: TrackedExercise(name: 'Squat'),
          targetReps: 2,
        ),
      ]));

      mock.emitRep();
      mock.emitRep();
      await pumpEventQueue();

      final state = stateOf(container);
      expect(state.isComplete, isTrue);
      expect(state.completedSets, hasLength(1));
    });

    test('rest of zero seconds advances immediately', () async {
      final (container, mock) = makeSession();
      await controllerOf(container).start(planOf(exercises: const [
        SessionExercise(
          exercise: TrackedExercise(name: 'Squat'),
          sets: 2,
          targetReps: 1,
          restSeconds: 0,
        ),
      ]));

      mock.emitRep();
      await pumpEventQueue();

      final state = stateOf(container);
      expect(state.isExercising, isTrue);
      expect(state.setNumber, 2);
    });
  });

  group('form cues', () {
    test('surfaces the latest cue while exercising and clears it on advance',
        () async {
      final (container, mock) = makeSession();
      await controllerOf(container).start(planOf(exercises: const [
        SessionExercise(
          exercise: TrackedExercise(name: 'Squat', formTracked: true),
          sets: 2,
          targetReps: 1,
          restSeconds: 5,
        ),
      ]));

      const cue = FormCue(severity: FormSeverity.major, message: 'Back flat');
      mock.emitFormCue(cue);
      await pumpEventQueue();
      expect(stateOf(container).formCue, cue);

      mock.emitRep();
      await pumpEventQueue();
      await controllerOf(container).skipRest();
      expect(stateOf(container).formCue, isNull,
          reason: 'a new set starts without a stale cue');
    });
  });

  group('manual rep/weight logging', () {
    SessionPlan twoSetPlan() => planOf(exercises: const [
          SessionExercise(
            exercise: TrackedExercise(name: 'Deadlift'),
            sets: 2,
            restSeconds: 30,
          ),
        ]);

    test('setReps overrides the counted reps without auto-advancing', () async {
      final (container, mock) = makeSession();
      await controllerOf(container).start(twoSetPlan());

      mock.emitRep();
      mock.emitRep();
      await pumpEventQueue();
      expect(stateOf(container).reps, 2);

      // The lifter corrects the miscount up to 8.
      controllerOf(container).setReps(8);
      expect(stateOf(container).reps, 8);
      // Manual entry never trips auto-advance, even past a (here-absent) target.
      expect(stateOf(container).isExercising, isTrue);
    });

    test('setReps clamps to zero and is a no-op when not exercising', () async {
      final (container, _) = makeSession();
      // Not started yet → idle → no-op.
      controllerOf(container).setReps(5);
      expect(stateOf(container).reps, 0);

      await controllerOf(container).start(twoSetPlan());
      controllerOf(container).setReps(-3);
      expect(stateOf(container).reps, 0);
    });

    test('setWeight records and clears the current set weight', () async {
      final (container, _) = makeSession();
      await controllerOf(container).start(twoSetPlan());

      controllerOf(container).setWeight(60.5);
      expect(stateOf(container).weight, 60.5);

      // Null (or a negative) clears it back to unlogged.
      controllerOf(container).setWeight(null);
      expect(stateOf(container).weight, isNull);
      controllerOf(container).setWeight(-10);
      expect(stateOf(container).weight, isNull);
    });

    test('setWeight is a no-op when not exercising', () async {
      final (container, _) = makeSession();
      controllerOf(container).setWeight(40);
      expect(stateOf(container).weight, isNull);
    });

    test('completeSet snapshots the manual reps and weight into the set',
        () async {
      final (container, _) = makeSession();
      await controllerOf(container).start(twoSetPlan());

      controllerOf(container).setReps(10);
      controllerOf(container).setWeight(80);
      await controllerOf(container).completeSet();

      expect(
        stateOf(container).completedSets.single,
        const CompletedSet(
          exerciseName: 'Deadlift',
          setNumber: 1,
          reps: 10,
          weight: 80,
        ),
      );
    });

    test('weight resets to null for the next set', () async {
      final (container, _) = makeSession();
      await controllerOf(container).start(twoSetPlan());

      controllerOf(container).setWeight(80);
      await controllerOf(container).completeSet();
      expect(stateOf(container).isResting, isTrue);
      // The recorded set keeps its weight…
      expect(stateOf(container).completedSets.single.weight, 80);

      await controllerOf(container).skipRest();
      // …but the new set starts unlogged.
      expect(stateOf(container).setNumber, 2);
      expect(stateOf(container).weight, isNull);
    });
  });

  group('stop', () {
    test('returns the session to idle', () async {
      final (container, mock) = makeSession();
      await controllerOf(container).start(planOf(exercises: const [
        SessionExercise(exercise: TrackedExercise(name: 'Squat'), targetReps: 5),
      ]));
      mock.emitRep();
      await pumpEventQueue();

      await controllerOf(container).stop();
      expect(stateOf(container).isIdle, isTrue);
    });
  });

  // The rest countdown is timer-driven, so it runs under `fakeAsync` for
  // deterministic control (mirroring the mock sensor's auto-simulation tests).
  group('rest countdown', () {
    test('ticks down each second and auto-advances at zero', () {
      fakeAsync((async) {
        final mock = MockSensorSource(autoSimulate: false, clock: () => fixedNow);
        final container = ProviderContainer(
          overrides: [workoutSensorSourceProvider.overrideWithValue(mock)],
        );

        final controller =
            container.read(workoutSessionControllerProvider.notifier);
        WorkoutSessionState read() =>
            container.read(workoutSessionControllerProvider);

        unawaited(controller.start(planOf(exercises: const [
          SessionExercise(
            exercise: TrackedExercise(name: 'Squat'),
            sets: 2,
            targetReps: 1,
            restSeconds: 3,
          ),
        ])));
        async.flushMicrotasks();

        mock.emitRep();
        async.flushMicrotasks();
        expect(read().isResting, isTrue);
        expect(read().restRemaining, 3);

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(read().restRemaining, 2);

        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        // Countdown hit zero → advanced to the next set.
        expect(read().isExercising, isTrue);
        expect(read().setNumber, 2);

        container.dispose();
        unawaited(mock.dispose());
        async.flushMicrotasks();
      });
    });
  });

  group('WorkoutLog sync on completion', () {
    test('syncs the completed sets, in order, when the workout finishes',
        () async {
      final log = _RecordingLogApi();
      final (container, mock) = makeSession(logApi: log);
      await controllerOf(container).start(planOf(exercises: const [
        SessionExercise(
          exercise: TrackedExercise(name: 'Squat'),
          targetReps: 1,
          restSeconds: 0,
        ),
        SessionExercise(
          exercise: TrackedExercise(name: 'Bench'),
          targetReps: 1,
          restSeconds: 0,
        ),
      ]));

      mock.emitRep(); // completes Squat, advances to Bench (zero rest)
      await pumpEventQueue();
      mock.emitRep(); // completes Bench → workout complete
      await pumpEventQueue();

      expect(stateOf(container).isComplete, isTrue);
      expect(log.saved, hasLength(1));
      expect(
        log.saved.single.map((s) => s.exerciseName).toList(),
        ['Squat', 'Bench'],
      );
      // Stamped with the session's window: completion at/after start.
      expect(log.lastStartedAt, isNotNull);
      expect(
        log.lastCompletedAt!.isBefore(log.lastStartedAt!),
        isFalse,
      );
    });

    test('carries the manually logged weight into the synced summary',
        () async {
      final log = _RecordingLogApi();
      final (container, _) = makeSession(logApi: log);
      await controllerOf(container).start(planOf(exercises: const [
        SessionExercise(exercise: TrackedExercise(name: 'Deadlift')),
      ]));

      controllerOf(container)
        ..setReps(5)
        ..setWeight(100);
      await controllerOf(container).completeSet();
      await pumpEventQueue();

      expect(log.saved, hasLength(1));
      final set = log.saved.single.single;
      expect(set.reps, 5);
      expect(set.weight, 100);
    });

    test('does not sync a workout that was stopped before completing',
        () async {
      final log = _RecordingLogApi();
      final (container, mock) = makeSession(logApi: log);
      await controllerOf(container).start(planOf(exercises: const [
        SessionExercise(
          exercise: TrackedExercise(name: 'Squat'),
          sets: 3,
          targetReps: 5,
        ),
      ]));
      mock.emitRep();
      await pumpEventQueue();

      await controllerOf(container).stop();
      await pumpEventQueue();

      expect(stateOf(container).isIdle, isTrue);
      expect(log.saved, isEmpty);
    });

    test('a failed sync does not block completion', () async {
      final log = _RecordingLogApi(throws: true);
      final (container, mock) = makeSession(logApi: log);
      await controllerOf(container).start(planOf(exercises: const [
        SessionExercise(
          exercise: TrackedExercise(name: 'Squat'),
          targetReps: 1,
        ),
      ]));

      mock.emitRep();
      await pumpEventQueue();

      // The sync was attempted but threw; the session still reads complete and
      // can return to idle without error.
      expect(log.saved, hasLength(1));
      expect(stateOf(container).isComplete, isTrue);
      await controllerOf(container).stop();
      expect(stateOf(container).isIdle, isTrue);
    });
  });
}
