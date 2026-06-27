import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gymbuddy/sensors/mock_sensor_source.dart';

/// Whether a [WorkoutSensorSource] can be used right now. M7 uses this for
/// capability detection — if the real glasses source reports
/// [SensorAvailability.unavailable], the app falls back to [MockSensorSource]
/// so the workout still runs.
enum SensorAvailability {
  /// The source is connected and ready to track.
  available,

  /// No usable sensor (e.g. glasses absent or unsupported). Feature code falls
  /// back to the mock rather than blocking the workout.
  unavailable,
}

/// What a given [WorkoutSensorSource] can do.
///
/// The session engine reads this to decide which in-workout features to surface
/// — e.g. it only shows live form cues for an exercise when the active source
/// can actually see form. The glasses are first-person POV, so form tracking is
/// a graded capability, not a given.
class SensorCapabilities {
  const SensorCapabilities({
    required this.repCounting,
    required this.formTracking,
  });

  /// The source can detect and count repetitions.
  final bool repCounting;

  /// The source can observe and comment on exercise form.
  final bool formTracking;

  @override
  bool operator ==(Object other) =>
      other is SensorCapabilities &&
      other.repCounting == repCounting &&
      other.formTracking == formTracking;

  @override
  int get hashCode => Object.hash(repCounting, formTracking);
}

/// The exercise the source is currently watching.
///
/// A minimal, feature-agnostic descriptor: the `sensors/` layer never depends
/// on the plans feature's models, so the session engine maps a plan exercise
/// down to this before handing it to the source.
class TrackedExercise {
  const TrackedExercise({required this.name, this.formTracked = false});

  /// Human-readable exercise name (for cues and logging).
  final String name;

  /// Mirrors the plan's per-exercise flag. The glasses are first-person POV, so
  /// form correction is only attempted for mirror/POV-visible movements; the
  /// source emits no form cues when this is false.
  final bool formTracked;

  @override
  bool operator ==(Object other) =>
      other is TrackedExercise &&
      other.name == name &&
      other.formTracked == formTracked;

  @override
  int get hashCode => Object.hash(name, formTracked);
}

/// A single completed repetition reported by the active source.
class RepEvent {
  const RepEvent({
    required this.index,
    required this.timestamp,
    this.confidence,
  });

  /// 1-based position within the current set. Resets on each
  /// [WorkoutSensorSource.startTracking].
  final int index;

  /// When the rep completed.
  final DateTime timestamp;

  /// Detection confidence in `0..1`, or null if the source doesn't score reps.
  final double? confidence;

  @override
  bool operator ==(Object other) =>
      other is RepEvent &&
      other.index == index &&
      other.timestamp == timestamp &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(index, timestamp, confidence);
}

/// How urgent a [FormCue] is.
enum FormSeverity {
  /// Reassurance — the user is doing well.
  good,

  /// A small correction worth mentioning.
  minor,

  /// A correction that matters for safety or effectiveness.
  major,
}

/// A piece of form feedback for the exercise currently being tracked.
class FormCue {
  const FormCue({required this.severity, required this.message});

  final FormSeverity severity;

  /// Human-readable coaching line, e.g. "Keep your back straight".
  final String message;

  @override
  bool operator ==(Object other) =>
      other is FormCue &&
      other.severity == severity &&
      other.message == message;

  @override
  int get hashCode => Object.hash(severity, message);
}

/// The hardware abstraction every rep/form feature depends on.
///
/// Feature code NEVER talks to the Meta DAT SDK (or any wearable) directly — it
/// goes through this interface, so the same session engine, focus-mode UI, and
/// logging all run unchanged whether the active source is the real glasses
/// ([MetaGlassesSensorSource], M7) or [MockSensorSource]. Every rep/form
/// feature must build and run fully against the mock with no hardware attached.
abstract interface class WorkoutSensorSource {
  /// What this source can do — read before surfacing capability-gated UI.
  SensorCapabilities get capabilities;

  /// Completed reps for the exercise currently being tracked. Broadcast, so the
  /// rep counter and the post-workout summary can both listen.
  Stream<RepEvent> get reps;

  /// Form feedback for the exercise currently being tracked. Empty for sources
  /// or exercises without [SensorCapabilities.formTracking]. Broadcast.
  Stream<FormCue> get formCues;

  /// Establishes the underlying sensor connection and reports whether it's
  /// usable. Safe to call more than once.
  Future<SensorAvailability> connect();

  /// Begins watching [exercise], resetting the rep count to zero.
  Future<void> startTracking(TrackedExercise exercise);

  /// Stops watching the current exercise (e.g. on rest or set completion).
  Future<void> stopTracking();

  /// Speaks a short coaching cue through the glasses' speakers — the first
  /// *output* path back to the hardware (everything else here is input). It
  /// lives on this same seam, rather than a sibling interface, so the
  /// session/coach layer reaches the speakers through the one resolved source
  /// the rest of the hardware already goes through.
  ///
  /// Best-effort and must never throw on a delivery failure: a source with no
  /// speakers ([MockSensorSource], the fallback whenever glasses are absent)
  /// implements this as a silent no-op, so callers can fire cues
  /// unconditionally and they degrade gracefully with no hardware attached.
  Future<void> playCue(String message);

  /// Releases all resources and closes the event streams. The source must not
  /// be used afterwards.
  Future<void> dispose();
}

/// The app's active sensor source.
///
/// Defaults to [MockSensorSource] so rep/form features build and run with no
/// glasses attached (the mock-first rule). M7 overrides this with the real
/// DAT-SDK-backed source, which itself falls back to the mock when the glasses
/// report [SensorAvailability.unavailable].
final workoutSensorSourceProvider = Provider<WorkoutSensorSource>((ref) {
  final source = MockSensorSource();
  ref.onDispose(source.dispose);
  return source;
});
