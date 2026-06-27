import 'dart:async';

import 'package:gymbuddy/sensors/sensor_source.dart';

/// Hardware-free [WorkoutSensorSource] used as the app default and in tests.
///
/// It lets every rep/form feature run end to end with no glasses attached (the
/// mock-first rule, mirroring how [MockHealthPermissionService] stands in for
/// the real health store). While tracking, and when [autoSimulate] is true, it
/// emits a steady stream of reps — plus the occasional "good form" cue for
/// form-tracked exercises — on a [repInterval] timer, so the focus-mode UI
/// actually animates in dev builds.
///
/// Tests construct it with `autoSimulate: false` and drive [emitRep] /
/// [emitFormCue] directly for deterministic assertions; a mock is meant to be
/// driven, so those emitters are part of its public surface.
class MockSensorSource implements WorkoutSensorSource {
  MockSensorSource({
    this.repInterval = const Duration(seconds: 3),
    this.autoSimulate = true,
    this.clock = DateTime.now,
  });

  /// Cadence of simulated reps while [autoSimulate] is on.
  final Duration repInterval;

  /// Whether to emit reps/cues automatically on a timer while tracking. Off in
  /// tests so emission is deterministic.
  final bool autoSimulate;

  /// Injectable clock for rep timestamps — overridden in tests for determinism.
  final DateTime Function() clock;

  final StreamController<RepEvent> _reps = StreamController<RepEvent>.broadcast();
  final StreamController<FormCue> _formCues =
      StreamController<FormCue>.broadcast();
  final StreamController<WakeEvent> _wakeEvents =
      StreamController<WakeEvent>.broadcast();

  Timer? _timer;
  TrackedExercise? _tracking;
  int _repCount = 0;
  bool _disposed = false;

  @override
  SensorCapabilities get capabilities =>
      const SensorCapabilities(repCounting: true, formTracking: true);

  @override
  Stream<RepEvent> get reps => _reps.stream;

  @override
  Stream<FormCue> get formCues => _formCues.stream;

  @override
  Stream<WakeEvent> get wakeEvents => _wakeEvents.stream;

  @override
  Future<SensorAvailability> connect() async {
    _ensureActive();
    return SensorAvailability.available;
  }

  @override
  Future<void> startTracking(TrackedExercise exercise) async {
    _ensureActive();
    _tracking = exercise;
    _repCount = 0;
    if (autoSimulate) {
      _timer?.cancel();
      _timer = Timer.periodic(repInterval, (_) => _tick());
    }
  }

  @override
  Future<void> stopTracking() async {
    _timer?.cancel();
    _timer = null;
    _tracking = null;
  }

  @override
  Future<void> playCue(String message) async {
    _ensureActive();
    // The mock has no speakers, so a cue degrades to a silent no-op. The
    // session/coach layer can fire cues unconditionally and they vanish
    // harmlessly when no glasses are attached (the mock-first rule).
  }

  /// Emits one rep for the exercise being tracked, advancing the set count.
  /// No-op when not tracking or after [dispose].
  void emitRep({double? confidence}) {
    if (_disposed || _tracking == null) return;
    _repCount += 1;
    _reps.add(
      RepEvent(index: _repCount, timestamp: clock(), confidence: confidence),
    );
  }

  /// Emits a form cue. No-op when not tracking, after [dispose], or when the
  /// tracked exercise isn't form-tracked (the source can't see form for
  /// rep-only movements).
  void emitFormCue(FormCue cue) {
    if (_disposed || _tracking?.formTracked != true) return;
    _formCues.add(cue);
  }

  /// Emits a wake-word trigger, as if the wearer said the wake phrase. Unlike
  /// [emitRep]/[emitFormCue] this is independent of tracking — the mic is
  /// always-on — so it fires whenever the source is live; only [dispose] stops
  /// it. Lets Q&A wiring be exercised end to end with no glasses attached.
  void emitWake({String phrase = kWakePhrase, double? confidence}) {
    if (_disposed) return;
    _wakeEvents.add(
      WakeEvent(phrase: phrase, timestamp: clock(), confidence: confidence),
    );
  }

  void _tick() {
    emitRep(confidence: 0.95);
    // A periodic reassurance cue keeps the form UI alive for form-tracked
    // exercises; emitFormCue no-ops for rep-only ones.
    if (_repCount.isEven) {
      emitFormCue(
        const FormCue(
          severity: FormSeverity.good,
          message: 'Good depth — keep it up',
        ),
      );
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('MockSensorSource used after dispose()');
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _tracking = null;
    await _reps.close();
    await _formCues.close();
    await _wakeEvents.close();
  }
}
