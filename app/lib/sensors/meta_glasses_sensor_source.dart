import 'dart:async';

import 'package:flutter/services.dart';
import 'package:gymbuddy/sensors/sensor_source.dart';

/// Control channel — `connect`/`startTracking`/`stopTracking`/`dispose`.
const String kGlassesMethodChannel = 'gymbuddy/glasses';

/// Streaming rep events: `{index, timestampMs, confidence?}`.
const String kGlassesRepsChannel = 'gymbuddy/glasses/reps';

/// Streaming form cues: `{severity, message}`.
const String kGlassesFormCuesChannel = 'gymbuddy/glasses/formCues';

/// The real, glasses-backed [WorkoutSensorSource]: a thin Dart binding over the
/// platform channels the Android (Kotlin) and iOS (Swift) sides expose for the
/// Meta DAT SDK.
///
/// It owns no rep/form logic of its own — it forwards lifecycle calls to the
/// native [MethodChannel] and decodes the two native [EventChannel]s onto the
/// `sensor_source.dart` value types. The native sides detect the DAT SDK
/// reflectively and report [SensorAvailability.unavailable] (emitting no events)
/// whenever it's absent — every build until the SDK framework is vendored — so
/// this source surfaces `unavailable` faithfully and the capability-detection
/// layer (M7 task 4) can fall back to [MockSensorSource]. Until then no feature
/// code talks to this class directly; it all goes through [WorkoutSensorSource].
class MetaGlassesSensorSource implements WorkoutSensorSource {
  MetaGlassesSensorSource({
    MethodChannel? methodChannel,
    EventChannel? repsChannel,
    EventChannel? formCuesChannel,
  })  : _methods = methodChannel ?? const MethodChannel(kGlassesMethodChannel),
        _repsChannel = repsChannel ?? const EventChannel(kGlassesRepsChannel),
        _formCuesChannel =
            formCuesChannel ?? const EventChannel(kGlassesFormCuesChannel);

  final MethodChannel _methods;
  final EventChannel _repsChannel;
  final EventChannel _formCuesChannel;

  /// Populated by [connect] from the native handshake; conservatively empty
  /// until then so capability-gated UI never shows before we've connected.
  SensorCapabilities _capabilities =
      const SensorCapabilities(repCounting: false, formTracking: false);

  Stream<RepEvent>? _reps;
  Stream<FormCue>? _formCues;
  bool _disposed = false;

  @override
  SensorCapabilities get capabilities => _capabilities;

  @override
  Stream<RepEvent> get reps =>
      _reps ??= _repsChannel.receiveBroadcastStream().map(_decodeRep);

  @override
  Stream<FormCue> get formCues =>
      _formCues ??= _formCuesChannel.receiveBroadcastStream().map(_decodeFormCue);

  @override
  Future<SensorAvailability> connect() async {
    _ensureActive();
    final Map<String, Object?>? result;
    try {
      result = await _methods.invokeMapMethod<String, Object?>('connect');
    } on PlatformException {
      // No usable connection — degrade gracefully (the same posture as the
      // health layer) so the fallback can take over rather than crashing.
      _capabilities =
          const SensorCapabilities(repCounting: false, formTracking: false);
      return SensorAvailability.unavailable;
    } on MissingPluginException {
      // The native channel isn't registered (e.g. an unsupported platform).
      _capabilities =
          const SensorCapabilities(repCounting: false, formTracking: false);
      return SensorAvailability.unavailable;
    }

    final caps = (result?['capabilities'] as Map?)?.cast<Object?, Object?>();
    _capabilities = SensorCapabilities(
      repCounting: caps?['repCounting'] == true,
      formTracking: caps?['formTracking'] == true,
    );
    return result?['availability'] == 'available'
        ? SensorAvailability.available
        : SensorAvailability.unavailable;
  }

  @override
  Future<void> startTracking(TrackedExercise exercise) async {
    _ensureActive();
    await _methods.invokeMethod<void>('startTracking', <String, Object?>{
      'name': exercise.name,
      'formTracked': exercise.formTracked,
    });
  }

  @override
  Future<void> stopTracking() async {
    _ensureActive();
    await _methods.invokeMethod<void>('stopTracking');
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _methods.invokeMethod<void>('dispose');
    } on PlatformException {
      // Best-effort native teardown; nothing useful to do if it fails.
    } on MissingPluginException {
      // Channel never registered — nothing to tear down.
    }
  }

  RepEvent _decodeRep(dynamic event) {
    final map = (event as Map).cast<Object?, Object?>();
    return RepEvent(
      index: (map['index'] as num).toInt(),
      timestamp:
          DateTime.fromMillisecondsSinceEpoch((map['timestampMs'] as num).toInt()),
      confidence: (map['confidence'] as num?)?.toDouble(),
    );
  }

  FormCue _decodeFormCue(dynamic event) {
    final map = (event as Map).cast<Object?, Object?>();
    return FormCue(
      severity: _severityFrom(map['severity'] as String?),
      message: (map['message'] as String?) ?? '',
    );
  }

  /// Maps the native severity name onto [FormSeverity], defaulting to
  /// [FormSeverity.minor] for an unrecognized value (surface it, don't drop it).
  FormSeverity _severityFrom(String? name) {
    switch (name) {
      case 'good':
        return FormSeverity.good;
      case 'major':
        return FormSeverity.major;
      case 'minor':
        return FormSeverity.minor;
      default:
        return FormSeverity.minor;
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('MetaGlassesSensorSource used after dispose()');
    }
  }
}
