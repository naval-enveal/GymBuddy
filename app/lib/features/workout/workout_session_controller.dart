import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/features/workout/session_models.dart';
import 'package:gymbuddy/sensors/sensor_source.dart';

/// Drives a workout through the exercise → set → rest → next cycle (M6).
///
/// The engine listens to [workoutSensorSourceProvider]'s `reps` stream to
/// auto-advance a set once it hits its rep target, runs a rest countdown between
/// sets, then moves on to the next set or exercise — all the way to completion.
/// It runs end to end against [MockSensorSource] with no glasses attached.
///
/// All session logic lives here, never in widgets (the focus-mode UI, a later
/// task, only reads [WorkoutSessionState] and forwards the manual actions). A
/// set with a null rep target is never auto-advanced — it's ended via
/// [completeSet], the seam the manual-logging fallback (a later task) builds on.
class WorkoutSessionController extends Notifier<WorkoutSessionState> {
  StreamSubscription<RepEvent>? _repSub;
  StreamSubscription<FormCue>? _cueSub;
  Timer? _restTimer;

  @override
  WorkoutSessionState build() {
    ref.onDispose(_teardown);
    return WorkoutSessionState.idle();
  }

  WorkoutSensorSource get _source => ref.read(workoutSensorSourceProvider);

  /// Begins [plan] from its first exercise/set. No-op for an empty plan or
  /// while a session is already active (resume that one instead); a finished or
  /// idle session can be (re)started.
  Future<void> start(SessionPlan plan) async {
    if (state.isExercising || state.isResting) return;
    if (plan.exercises.isEmpty) return;
    _teardown();

    await _source.connect();
    _repSub = _source.reps.listen(_onRep);
    _cueSub = _source.formCues.listen(_onCue);

    state = WorkoutSessionState(
      status: SessionStatus.exercising,
      plan: plan,
      exerciseIndex: 0,
      setNumber: 1,
      reps: 0,
      restRemaining: 0,
      completedSets: const <CompletedSet>[],
    );
    await _source.startTracking(plan.exercises.first.exercise);
  }

  /// Ends the current set: records it, then either rests before the next set or
  /// completes the workout if this was the last set. Manual entry point for
  /// "to failure"/time-based sets and the manual-logging fallback. No-op unless
  /// a set is in progress.
  Future<void> completeSet() async {
    if (!state.isExercising) return;
    final exercise = state.currentExercise;
    if (exercise == null) return;

    final completed = <CompletedSet>[
      ...state.completedSets,
      CompletedSet(
        exerciseName: exercise.exercise.name,
        setNumber: state.setNumber,
        reps: state.reps,
      ),
    ];

    if (_hasNextSet) {
      // Set status synchronously before the async stopTracking so a rep that
      // lands during the gap can't re-trigger completion.
      final rest = exercise.restSeconds;
      state = state.copyWith(
        status: SessionStatus.resting,
        completedSets: completed,
        restRemaining: rest < 0 ? 0 : rest,
        clearFormCue: true,
      );
      await _source.stopTracking();
      _startRestTimer();
    } else {
      state = state.copyWith(
        status: SessionStatus.completed,
        completedSets: completed,
        restRemaining: 0,
        clearFormCue: true,
      );
      await _source.stopTracking();
    }
  }

  /// Skips the remaining rest and moves straight to the next set/exercise.
  /// No-op unless currently resting.
  Future<void> skipRest() async {
    if (!state.isResting) return;
    _restTimer?.cancel();
    _restTimer = null;
    await _advance();
  }

  /// Abandons the session and returns to idle, releasing sensor listeners.
  Future<void> stop() async {
    _teardown();
    await _source.stopTracking();
    state = WorkoutSessionState.idle();
  }

  /// True when there's another set to perform after the current one — either a
  /// remaining set of this exercise or a later exercise.
  bool get _hasNextSet {
    final exercise = state.currentExercise;
    if (exercise == null) return false;
    if (state.setNumber < exercise.sets) return true;
    return state.exerciseIndex < state.plan.exercises.length - 1;
  }

  void _onRep(RepEvent event) {
    if (!state.isExercising) return;
    state = state.copyWith(reps: event.index);
    final target = state.targetReps;
    if (target != null && event.index >= target) {
      unawaited(completeSet());
    }
  }

  void _onCue(FormCue cue) {
    if (!state.isExercising) return;
    state = state.copyWith(formCue: cue);
  }

  void _startRestTimer() {
    _restTimer?.cancel();
    if (state.restRemaining <= 0) {
      unawaited(_advance());
      return;
    }
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = state.restRemaining - 1;
      if (remaining <= 0) {
        _restTimer?.cancel();
        _restTimer = null;
        state = state.copyWith(restRemaining: 0);
        unawaited(_advance());
      } else {
        state = state.copyWith(restRemaining: remaining);
      }
    });
  }

  /// Moves to the next set (same exercise) or the next exercise's first set,
  /// resuming tracking; completes the workout when nothing remains.
  Future<void> _advance() async {
    final exercise = state.currentExercise;
    if (exercise == null) return;

    int nextExercise = state.exerciseIndex;
    int nextSet;
    if (state.setNumber < exercise.sets) {
      nextSet = state.setNumber + 1;
    } else {
      nextExercise = state.exerciseIndex + 1;
      nextSet = 1;
    }

    if (nextExercise >= state.plan.exercises.length) {
      state = state.copyWith(status: SessionStatus.completed, restRemaining: 0);
      return;
    }

    state = state.copyWith(
      status: SessionStatus.exercising,
      exerciseIndex: nextExercise,
      setNumber: nextSet,
      reps: 0,
      restRemaining: 0,
      clearFormCue: true,
    );
    await _source.startTracking(state.plan.exercises[nextExercise].exercise);
  }

  void _teardown() {
    _restTimer?.cancel();
    _restTimer = null;
    unawaited(_repSub?.cancel());
    _repSub = null;
    unawaited(_cueSub?.cancel());
    _cueSub = null;
  }
}

/// The active workout session. See [WorkoutSessionController].
final workoutSessionControllerProvider =
    NotifierProvider<WorkoutSessionController, WorkoutSessionState>(
  WorkoutSessionController.new,
);
