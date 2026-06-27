import Flutter
import Foundation

/// The iOS side of the glasses platform channel — the native counterpart of the
/// Dart `MetaGlassesSensorSource` (M7) and the mirror of the Android
/// `GlassesChannel`. It exposes a single control `FlutterMethodChannel` plus two
/// streaming `FlutterEventChannel`s (reps + form cues), all backed by a
/// `DatSdkClient` that wraps the Meta DAT SDK's camera/audio/mic.
///
/// Wire contract (kept identical on Android and in the Dart binding):
///  - method channel `gymbuddy/glasses`:
///      `connect`       -> { availability: "available"|"unavailable",
///                           capabilities: { repCounting: Bool, formTracking: Bool } }
///      `startTracking` (args { name: String, formTracked: Bool }) -> null
///      `stopTracking`  -> null
///      `playCue`       (args { message: String }) -> null
///      `dispose`       -> null
///  - event channel `gymbuddy/glasses/reps`     -> { index: Int, timestampMs: Int, confidence: Double? }
///  - event channel `gymbuddy/glasses/formCues` -> { severity: String, message: String }
///  - event channel `gymbuddy/glasses/wake`     -> { timestampMs: Int, phrase: String, confidence: Double? }
///
/// Because the DAT SDK isn't bundled in a no-hardware build, `connect` resolves to
/// `unavailable` and no events are emitted — the Dart layer then falls back to the
/// mock, so the channel is always safe to wire up regardless of hardware.
final class GlassesChannel: NSObject {
  static let methodChannelName = "gymbuddy/glasses"
  static let repsChannelName = "gymbuddy/glasses/reps"
  static let formCuesChannelName = "gymbuddy/glasses/formCues"
  static let wakeChannelName = "gymbuddy/glasses/wake"

  private let client: DatSdkClient
  private let methodChannel: FlutterMethodChannel
  private let repsChannel: FlutterEventChannel
  private let formCuesChannel: FlutterEventChannel
  private let wakeChannel: FlutterEventChannel

  private let repsStreamHandler = QueuingStreamHandler()
  private let formCuesStreamHandler = QueuingStreamHandler()
  // The wake channel is its own stream because wake detection is always-on and
  // independent of tracking; the listener is armed only while Flutter is
  // listening, and torn down on cancel.
  private var wakeStreamHandler: QueuingStreamHandler!

  init(messenger: FlutterBinaryMessenger) {
    self.client = DatSdkClientFactory.create()
    self.methodChannel = FlutterMethodChannel(
      name: GlassesChannel.methodChannelName, binaryMessenger: messenger)
    self.repsChannel = FlutterEventChannel(
      name: GlassesChannel.repsChannelName, binaryMessenger: messenger)
    self.formCuesChannel = FlutterEventChannel(
      name: GlassesChannel.formCuesChannelName, binaryMessenger: messenger)
    self.wakeChannel = FlutterEventChannel(
      name: GlassesChannel.wakeChannelName, binaryMessenger: messenger)
    super.init()

    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    repsChannel.setStreamHandler(repsStreamHandler)
    formCuesChannel.setStreamHandler(formCuesStreamHandler)
    wakeStreamHandler = QueuingStreamHandler(
      onListen: { [weak self] in self.map { $0.client.setWakeListener($0) } },
      onCancel: { [weak self] in self?.client.setWakeListener(nil) })
    wakeChannel.setStreamHandler(wakeStreamHandler)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "connect":
      let availability = client.connect()
      let caps = client.capabilities()
      result([
        "availability": availability.rawValue,
        "capabilities": [
          "repCounting": caps.repCounting,
          "formTracking": caps.formTracking,
        ],
      ])

    case "startTracking":
      let args = call.arguments as? [String: Any]
      guard let name = args?["name"] as? String else {
        result(
          FlutterError(
            code: "bad_args", message: "startTracking requires a 'name'", details: nil))
        return
      }
      let formTracked = args?["formTracked"] as? Bool ?? false
      client.startTracking(
        TrackedExercise(name: name, formTracked: formTracked), listener: self)
      result(nil)

    case "stopTracking":
      client.stopTracking()
      result(nil)

    case "playCue":
      let args = call.arguments as? [String: Any]
      guard let message = args?["message"] as? String else {
        result(
          FlutterError(
            code: "bad_args", message: "playCue requires a 'message'", details: nil))
        return
      }
      client.playCue(message)
      result(nil)

    case "dispose":
      client.dispose()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Tears down all channels and the underlying client; call from the app's engine teardown.
  func dispose() {
    methodChannel.setMethodCallHandler(nil)
    repsChannel.setStreamHandler(nil)
    formCuesChannel.setStreamHandler(nil)
    wakeChannel.setStreamHandler(nil)
    client.setWakeListener(nil)
    client.dispose()
  }
}

// MARK: - TrackingListener

extension GlassesChannel: TrackingListener {
  func onRep(_ sample: RepSample) {
    // Flutter event sinks must be invoked on the platform (main) thread.
    DispatchQueue.main.async { [weak self] in
      self?.repsStreamHandler.send([
        "index": sample.index,
        "timestampMs": sample.timestampMs,
        "confidence": sample.confidence as Any,
      ])
    }
  }

  func onFormCue(_ cue: FormCueSample) {
    DispatchQueue.main.async { [weak self] in
      self?.formCuesStreamHandler.send([
        "severity": cue.severity,
        "message": cue.message,
      ])
    }
  }
}

// MARK: - WakeListener

extension GlassesChannel: WakeListener {
  func onWake(_ sample: WakeSample) {
    DispatchQueue.main.async { [weak self] in
      self?.wakeStreamHandler.send([
        "timestampMs": sample.timestampMs,
        "phrase": sample.phrase,
        "confidence": sample.confidence as Any,
      ])
    }
  }
}

// MARK: - QueuingStreamHandler

/// A minimal `FlutterStreamHandler` that holds the active sink between
/// `onListen`/`onCancel`, mirroring the Android channel's nullable sink fields.
/// Emissions before a listener attaches (or after it cancels) are dropped — the
/// same posture as the Android `EventSink?`.
final class QueuingStreamHandler: NSObject, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private let onListenCallback: (() -> Void)?
  private let onCancelCallback: (() -> Void)?

  /// `onListen`/`onCancel` fire as a Flutter listener attaches/detaches — used by
  /// the wake channel to arm and tear down the always-on mic only while someone
  /// is listening.
  init(onListen: (() -> Void)? = nil, onCancel: (() -> Void)? = nil) {
    self.onListenCallback = onListen
    self.onCancelCallback = onCancel
  }

  func send(_ event: Any) {
    sink?(event)
  }

  func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    sink = events
    onListenCallback?()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    onCancelCallback?()
    return nil
  }
}
