import 'dart:async';

import 'package:flutter/services.dart';
import 'package:gymbuddy/core/pose/pose_detector.dart';
import 'package:gymbuddy/core/pose/tflite_pose_detector.dart';
import 'package:gymbuddy/sensors/sensor_source.dart';

/// Control channel — `connect`/`startTracking`/`stopTracking`/`dispose`.
const String kGlassesMethodChannel = 'gymbuddy/glasses';

/// Streaming rep events: `{index, timestampMs, confidence?}`.
const String kGlassesRepsChannel = 'gymbuddy/glasses/reps';

/// Streaming form cues: `{severity, message}`.
const String kGlassesFormCuesChannel = 'gymbuddy/glasses/formCues';

/// Streaming wake-word triggers from the always-on mic: `{timestampMs, phrase,
/// confidence?}`. Independent of tracking — the second input path from the
/// glasses, a control signal that opens a hands-free Q&A turn.
const String kGlassesWakeChannel = 'gymbuddy/glasses/wake';

/// Streaming raw POV camera frames for on-device pose estimation:
/// `{rgb (bytes), width, height, timestampMs?}`. Feeds the [PoseDetector] (M8).
/// Native emits nothing until the DAT SDK camera stream is live, so the pose
/// detector simply stays idle (its [PoseDetector.frames] never fires).
const String kGlassesCameraChannel = 'gymbuddy/glasses/camera';

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
    EventChannel? wakeChannel,
    EventChannel? cameraChannel,
    PoseDetector? poseDetector,
  })  : _methods = methodChannel ?? const MethodChannel(kGlassesMethodChannel),
        _repsChannel = repsChannel ?? const EventChannel(kGlassesRepsChannel),
        _formCuesChannel =
            formCuesChannel ?? const EventChannel(kGlassesFormCuesChannel),
        _wakeChannel = wakeChannel ?? const EventChannel(kGlassesWakeChannel),
        _cameraChannel =
            cameraChannel ?? const EventChannel(kGlassesCameraChannel) {
    // The real camera path: on-device MoveNet fed by the glasses' POV camera
    // frames. Injectable so tests run with a MockPoseDetector and no FFI.
    _poseDetector = poseDetector ?? TflitePoseDetector(frameSource: cameraFrames);
  }

  final MethodChannel _methods;
  final EventChannel _repsChannel;
  final EventChannel _formCuesChannel;
  final EventChannel _wakeChannel;
  final EventChannel _cameraChannel;
  late final PoseDetector _poseDetector;

  /// Populated by [connect] from the native handshake; conservatively empty
  /// until then so capability-gated UI never shows before we've connected.
  SensorCapabilities _capabilities =
      const SensorCapabilities(repCounting: false, formTracking: false);

  Stream<RepEvent>? _reps;
  Stream<FormCue>? _formCues;
  Stream<WakeEvent>? _wake;
  Stream<PoseInput>? _cameraFrames;
  bool _disposed = false;

  @override
  SensorCapabilities get capabilities => _capabilities;

  /// The on-device pose detector fed by the glasses' POV camera. The rep/form
  /// pipeline (M8 task 2+) listens to its [PoseDetector.frames]; it stays idle
  /// (model not ready, or no camera frames) until both the model is bundled and
  /// the native camera stream is live.
  PoseDetector get poseDetector => _poseDetector;

  /// Raw POV camera frames decoded off the native camera channel, fed to the
  /// pose detector. Lazily cached so a single broadcast subscription is shared.
  Stream<PoseInput> get cameraFrames => _cameraFrames ??=
      _cameraChannel.receiveBroadcastStream().map(_decodeFrame);

  @override
  Stream<RepEvent> get reps =>
      _reps ??= _repsChannel.receiveBroadcastStream().map(_decodeRep);

  @override
  Stream<FormCue> get formCues =>
      _formCues ??= _formCuesChannel.receiveBroadcastStream().map(_decodeFormCue);

  @override
  Stream<WakeEvent> get wakeEvents =>
      _wake ??= _wakeChannel.receiveBroadcastStream().map(_decodeWake);

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
    if (result?['availability'] == 'available') {
      // Bring up on-device pose now that the glasses are connected. Best-effort:
      // a missing model (init returns false) just leaves pose idle — the rep
      // path falls back — and never blocks the connection.
      await _poseDetector.init();
      return SensorAvailability.available;
    }
    return SensorAvailability.unavailable;
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
  Future<void> playCue(String message) async {
    _ensureActive();
    try {
      await _methods.invokeMethod<void>('playCue', <String, Object?>{
        'message': message,
      });
    } on PlatformException {
      // Best-effort output: if the glasses can't speak the cue (no speaker
      // route, transient SDK error) swallow it rather than surfacing a
      // blocking error mid-workout — the cue is coaching, not control flow.
    } on MissingPluginException {
      // Channel never registered — nothing to play.
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _poseDetector.dispose();
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

  PoseInput _decodeFrame(dynamic event) {
    final map = (event as Map).cast<Object?, Object?>();
    final ts = (map['timestampMs'] as num?)?.toInt();
    return PoseInput(
      rgb: map['rgb'] as Uint8List,
      width: (map['width'] as num).toInt(),
      height: (map['height'] as num).toInt(),
      timestamp:
          ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts),
    );
  }

  WakeEvent _decodeWake(dynamic event) {
    final map = (event as Map).cast<Object?, Object?>();
    return WakeEvent(
      // The native side fires only on the configured phrase; default to
      // [kWakePhrase] if it omits it so a trigger is never dropped for a missing
      // label.
      phrase: (map['phrase'] as String?) ?? kWakePhrase,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestampMs'] as num).toInt(),
      ),
      confidence: (map['confidence'] as num?)?.toDouble(),
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
