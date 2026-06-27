import 'package:gymbuddy/core/pose/pose_exercise_catalog.dart';
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
  ///
  /// Whether an exercise is form-tracked is decided by the pose catalog
  /// ([poseTrackingFor]) — the single source of truth for what the on-device
  /// pipeline can actually attempt — not by the server-supplied flag. This
  /// keeps the session engine from promising form feedback the pose layer has
  /// no rules for (and vice versa).
  SessionPlan toSessionPlan() {
    return SessionPlan(
      name: name,
      exercises: <SessionExercise>[
        for (final e in exercises)
          SessionExercise(
            exercise: TrackedExercise(
              name: e.name,
              formTracked: poseTrackingFor(e.name).isFormTracked,
            ),
            sets: (e.sets != null && e.sets! > 0) ? e.sets! : 1,
            targetReps: e.reps,
            restSeconds: e.restSeconds ?? 60,
          ),
      ],
    );
  }
}
