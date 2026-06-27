import 'package:gymbuddy/features/plans/plan_models.dart';
import 'package:gymbuddy/features/workout/session_models.dart';
import 'package:gymbuddy/sensors/sensor_source.dart';

/// The session edge: maps a plan-feature [PlanWorkout] down to the
/// feature-agnostic [SessionPlan] the engine runs.
///
/// This is the *single* seam where the workout engine touches the plans models.
/// The session controller and its state types never import the plans feature —
/// a plan exercise is reduced to a [TrackedExercise] here so the engine stays
/// decoupled from how plans are shaped (the same rule the `sensors/` layer
/// follows).
extension PlanWorkoutSession on PlanWorkout {
  /// One [SessionExercise] per plan exercise. Missing prescription fields fall
  /// back to sensible defaults (1 set, 60s rest, null target = manual set).
  SessionPlan toSessionPlan() {
    return SessionPlan(
      name: name,
      exercises: <SessionExercise>[
        for (final e in exercises)
          SessionExercise(
            exercise: TrackedExercise(name: e.name, formTracked: e.formTracked),
            sets: (e.sets != null && e.sets! > 0) ? e.sets! : 1,
            targetReps: e.reps,
            restSeconds: e.restSeconds ?? 60,
          ),
      ],
    );
  }
}
