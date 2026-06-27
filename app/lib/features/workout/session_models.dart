/// Immutable value types for the workout session engine (M6).
///
/// These are deliberately feature-agnostic: the engine runs against
/// [TrackedExercise] from the `sensors/` layer and never imports the plans
/// feature's models. A plan workout is mapped down to a [SessionPlan] at the
/// session edge (see `session_mapper.dart`).
library;

import 'package:flutter/foundation.dart';

import 'package:gymbuddy/sensors/sensor_source.dart';

/// One exercise to perform in a session: a [TrackedExercise] the sensor source
/// watches, plus the prescription that drives the state machine.
class SessionExercise {
  const SessionExercise({
    required this.exercise,
    this.sets = 1,
    this.targetReps,
    this.restSeconds = 60,
  });

  /// What the active [WorkoutSensorSource] tracks for this exercise.
  final TrackedExercise exercise;

  /// How many sets to perform (>= 1).
  final int sets;

  /// Target reps per set. Null means time-based or "to failure": the engine
  /// won't auto-advance on rep count, so the set is ended manually (the
  /// manual-logging fallback, a later task).
  final int? targetReps;

  /// Rest countdown between sets, in seconds.
  final int restSeconds;

  @override
  bool operator ==(Object other) =>
      other is SessionExercise &&
      other.exercise == exercise &&
      other.sets == sets &&
      other.targetReps == targetReps &&
      other.restSeconds == restSeconds;

  @override
  int get hashCode => Object.hash(exercise, sets, targetReps, restSeconds);
}

/// A full workout to run through: an ordered list of [exercises].
class SessionPlan {
  const SessionPlan({required this.name, required this.exercises});

  /// The idle placeholder before a workout is started.
  static const SessionPlan empty =
      SessionPlan(name: '', exercises: <SessionExercise>[]);

  final String name;
  final List<SessionExercise> exercises;

  @override
  bool operator ==(Object other) =>
      other is SessionPlan &&
      other.name == name &&
      listEquals(other.exercises, exercises);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(exercises));
}

/// A finished set, recorded as the session advances. Feeds the post-workout
/// summary synced to WorkoutLog (a later M6 task).
class CompletedSet {
  const CompletedSet({
    required this.exerciseName,
    required this.setNumber,
    required this.reps,
  });

  final String exerciseName;

  /// 1-based set position within its exercise.
  final int setNumber;

  /// Reps actually counted for the set.
  final int reps;

  @override
  bool operator ==(Object other) =>
      other is CompletedSet &&
      other.exerciseName == exerciseName &&
      other.setNumber == setNumber &&
      other.reps == reps;

  @override
  int get hashCode => Object.hash(exerciseName, setNumber, reps);
}

/// Where the session currently is in the exercise → set → rest → next cycle.
enum SessionStatus {
  /// No workout started yet.
  idle,

  /// Performing a set — reps are being counted.
  exercising,

  /// Resting between sets, with [WorkoutSessionState.restRemaining] counting
  /// down to the next set.
  resting,

  /// All sets of all exercises are done.
  completed,
}

/// The full, immutable snapshot the focus-mode UI renders.
@immutable
class WorkoutSessionState {
  const WorkoutSessionState({
    required this.status,
    required this.plan,
    required this.exerciseIndex,
    required this.setNumber,
    required this.reps,
    required this.restRemaining,
    required this.completedSets,
    this.formCue,
  });

  /// The pre-start state.
  factory WorkoutSessionState.idle() => const WorkoutSessionState(
        status: SessionStatus.idle,
        plan: SessionPlan.empty,
        exerciseIndex: 0,
        setNumber: 1,
        reps: 0,
        restRemaining: 0,
        completedSets: <CompletedSet>[],
      );

  final SessionStatus status;
  final SessionPlan plan;

  /// 0-based index of the current exercise within [plan].
  final int exerciseIndex;

  /// 1-based set number within the current exercise.
  final int setNumber;

  /// Reps counted so far in the current set.
  final int reps;

  /// Seconds left in the current rest countdown (0 unless [status] is
  /// [SessionStatus.resting]).
  final int restRemaining;

  /// Every set finished so far, oldest first.
  final List<CompletedSet> completedSets;

  /// The most recent form cue for the current exercise, or null. Cleared when
  /// the exercise/set changes.
  final FormCue? formCue;

  bool get isIdle => status == SessionStatus.idle;
  bool get isExercising => status == SessionStatus.exercising;
  bool get isResting => status == SessionStatus.resting;
  bool get isComplete => status == SessionStatus.completed;

  int get totalExercises => plan.exercises.length;

  /// 1-based position of the current exercise, for display.
  int get exerciseNumber => exerciseIndex + 1;

  /// The exercise being performed, or null when idle/complete or out of range.
  SessionExercise? get currentExercise =>
      exerciseIndex >= 0 && exerciseIndex < plan.exercises.length
          ? plan.exercises[exerciseIndex]
          : null;

  /// Target reps for the current set, or null for a manual ("to failure") set.
  int? get targetReps => currentExercise?.targetReps;

  WorkoutSessionState copyWith({
    SessionStatus? status,
    SessionPlan? plan,
    int? exerciseIndex,
    int? setNumber,
    int? reps,
    int? restRemaining,
    List<CompletedSet>? completedSets,
    FormCue? formCue,
    bool clearFormCue = false,
  }) {
    return WorkoutSessionState(
      status: status ?? this.status,
      plan: plan ?? this.plan,
      exerciseIndex: exerciseIndex ?? this.exerciseIndex,
      setNumber: setNumber ?? this.setNumber,
      reps: reps ?? this.reps,
      restRemaining: restRemaining ?? this.restRemaining,
      completedSets: completedSets ?? this.completedSets,
      formCue: clearFormCue ? null : (formCue ?? this.formCue),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WorkoutSessionState &&
      other.status == status &&
      other.plan == plan &&
      other.exerciseIndex == exerciseIndex &&
      other.setNumber == setNumber &&
      other.reps == reps &&
      other.restRemaining == restRemaining &&
      listEquals(other.completedSets, completedSets) &&
      other.formCue == formCue;

  @override
  int get hashCode => Object.hash(
        status,
        plan,
        exerciseIndex,
        setNumber,
        reps,
        restRemaining,
        Object.hashAll(completedSets),
        formCue,
      );
}
