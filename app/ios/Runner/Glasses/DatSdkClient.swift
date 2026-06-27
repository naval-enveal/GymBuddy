import Foundation

/// Whether the glasses can be used for tracking right now. Mirrors the Dart
/// `SensorAvailability` enum (and the Android `GlassesAvailability`) so the wire
/// contract is symmetric across both platforms.
enum GlassesAvailability: String {
  case available
  case unavailable
}

/// What the connected glasses can do. Mirrors Dart `SensorCapabilities`.
struct GlassesCapabilities {
  let repCounting: Bool
  let formTracking: Bool
}

/// The exercise the glasses are being asked to watch. Mirrors Dart
/// `TrackedExercise`: a minimal, feature-agnostic descriptor.
struct TrackedExercise {
  let name: String
  let formTracked: Bool
}

/// A single completed rep observed by the glasses pipeline.
struct RepSample {
  /// 1-based position within the current set; resets on each `startTracking`.
  let index: Int
  let timestampMs: Int64
  /// Detection confidence in 0..1, or nil if the pipeline doesn't score reps.
  let confidence: Double?
}

/// A piece of form feedback for the exercise being tracked. `severity` is one of
/// `good` / `minor` / `major` to match the Dart `FormSeverity` enum names.
struct FormCueSample {
  let severity: String
  let message: String
}

/// A wake-word trigger from the glasses' always-on mic. Mirrors the Dart
/// `WakeEvent`: a control signal (not a tracking one) that opens a hands-free
/// Q&A turn.
struct WakeSample {
  let timestampMs: Int64
  /// The recognized wake phrase that fired the trigger.
  let phrase: String
  /// Detection confidence in 0..1, or nil if the pipeline doesn't score it.
  let confidence: Double?
}

/// Callbacks the `DatSdkClient` invokes as the glasses pipeline produces events.
/// The channel forwards these to the Flutter event sinks.
protocol TrackingListener: AnyObject {
  func onRep(_ sample: RepSample)
  func onFormCue(_ cue: FormCueSample)
}

/// Callback the `DatSdkClient` invokes when the always-on mic detects the wake
/// phrase. Separate from `TrackingListener` because wake detection is a control
/// signal independent of tracking — the mic listens between sets too.
protocol WakeListener: AnyObject {
  func onWake(_ sample: WakeSample)
}

/// Thin wrapper over the Meta Device Access Toolkit (DAT SDK) — the seam that
/// owns the glasses' camera/audio/mic for rep & form tracking.
///
/// Feature code (and even the rest of the native app) never talks to the DAT SDK
/// directly; everything goes through this protocol, exactly as Flutter feature
/// code goes through `WorkoutSensorSource`. The active implementation is created
/// by `DatSdkClientFactory.create()`; it must degrade gracefully when the SDK
/// isn't bundled or no glasses are paired, reporting `.unavailable` so the Dart
/// layer falls back to `MockSensorSource` and the workout still runs with no
/// hardware.
protocol DatSdkClient: AnyObject {
  /// Establishes the glasses link (camera/audio/mic) and reports whether it's usable.
  func connect() -> GlassesAvailability

  /// What the connected glasses can do; meaningful only after a successful `connect`.
  func capabilities() -> GlassesCapabilities

  /// Begins watching `exercise`, resetting the rep count to zero. Events arrive on `listener`.
  func startTracking(_ exercise: TrackedExercise, listener: TrackingListener)

  /// Stops watching the current exercise (rest or set completion).
  func stopTracking()

  /// Registers (or clears, with nil) the listener for wake-phrase triggers from
  /// the always-on mic. Independent of `startTracking` — once a `WakeListener` is
  /// set the client may fire `onWake` at any time while connected, including
  /// between sets. A client with no mic (`UnavailableDatSdkClient`) simply never
  /// calls back, so the wake stream stays empty with no hardware.
  func setWakeListener(_ listener: WakeListener?)

  /// Speaks a short coaching cue through the glasses' speakers — the first output
  /// path back to the hardware. Best-effort: a client with no audio route (e.g.
  /// `UnavailableDatSdkClient`) does nothing, so the Dart layer can fire cues
  /// unconditionally and they degrade silently with no hardware.
  func playCue(_ message: String)

  /// Releases the glasses link and all resources. The client must not be used afterwards.
  func dispose()
}

/// Builds the active `DatSdkClient`. The DAT SDK is Meta-proprietary and is not
/// distributed through a public package manager, so it is not a compile-time
/// dependency of this build. We detect it reflectively at runtime: when the SDK
/// classes are absent (every build until the SDK framework is dropped in) we
/// return a client that reports `.unavailable`, guaranteeing the app builds and
/// runs with no hardware. Once the SDK is vendored, swap the body of
/// `DatSdkAvailableClient` for real DAT SDK calls without touching the channel.
enum DatSdkClientFactory {
  /// The wake phrase the always-on mic listens for to open a hands-free Q&A turn.
  /// Fixed for now (Q&A lands in M9); kept here as the single native source of
  /// truth, mirroring the Dart `kWakePhrase`, so it has one place to grow into
  /// per-user config later.
  static let wakePhrase = "hey buddy"

  /// The DAT SDK entry-point class name. Detected, never linked at compile time.
  private static let datSdkClassName = "MetaWearablesDAT.DeviceAccessToolkit"

  static func create() -> DatSdkClient {
    let present = isDatSdkPresent()
    NSLog("[GymBuddyGlasses] DAT SDK present in runtime: \(present)")
    return present ? DatSdkAvailableClient() : UnavailableDatSdkClient()
  }

  /// The Objective-C runtime exposes every loaded class by name; `NSClassFromString`
  /// returns nil when the DAT SDK framework isn't linked in, so detection itself
  /// can never crash the host app.
  private static func isDatSdkPresent() -> Bool {
    return NSClassFromString(datSdkClassName) != nil
  }
}

/// The no-hardware client: used on every build where the DAT SDK isn't bundled
/// (or the device has no glasses paired). It connects to nothing, advertises no
/// capabilities, and emits no events — the Dart `MetaGlassesSensorSource` reads
/// the `.unavailable` result and falls back to `MockSensorSource`.
final class UnavailableDatSdkClient: DatSdkClient {
  func connect() -> GlassesAvailability { .unavailable }

  func capabilities() -> GlassesCapabilities {
    GlassesCapabilities(repCounting: false, formTracking: false)
  }

  func startTracking(_ exercise: TrackedExercise, listener: TrackingListener) {
    // No glasses, no events. Intentionally a no-op.
  }

  func stopTracking() {}

  func setWakeListener(_ listener: WakeListener?) {
    // No mic, no wake events. The wake stream stays empty with no hardware.
  }

  func playCue(_ message: String) {
    // No glasses, no speakers. Cues degrade to a silent no-op.
  }

  func dispose() {}
}

/// The real DAT-SDK-backed client. Instantiated only when the Meta DAT SDK is
/// present at runtime, i.e. once the framework is vendored into the iOS build.
/// Until then this code path is never taken, so it conservatively reports
/// `.unavailable` rather than pretending to be connected.
///
/// Integration TODO (when the SDK is added): wire `connect` to the DAT session +
/// camera/audio/mic streams, feed the on-device pose pipeline (M8) into
/// `startTracking`, and surface rep/form events through the `TrackingListener`.
final class DatSdkAvailableClient: DatSdkClient {
  private weak var listener: TrackingListener?
  private weak var wakeListener: WakeListener?

  func connect() -> GlassesAvailability {
    // Real DAT session/handshake goes here once the SDK is vendored. Until the
    // camera/audio/mic streams are confirmed live, stay unavailable so the app
    // never claims a glasses connection it can't back.
    return .unavailable
  }

  func capabilities() -> GlassesCapabilities {
    GlassesCapabilities(repCounting: true, formTracking: true)
  }

  func startTracking(_ exercise: TrackedExercise, listener: TrackingListener) {
    self.listener = listener
    // Real impl: open the glasses camera/mic for `exercise` and start the
    // rep/form pipeline, calling listener.onRep / listener.onFormCue per event.
  }

  func stopTracking() {
    self.listener = nil
    // Real impl: pause the camera/mic pipeline. The wake listener stays
    // registered — the mic keeps listening between sets.
  }

  func setWakeListener(_ listener: WakeListener?) {
    self.wakeListener = listener
    // Real impl: arm the DAT SDK's always-on mic / wake-word engine for
    // DatSdkClientFactory.wakePhrase and call wakeListener?.onWake on each
    // detection (independent of startTracking); clear it when listener is nil.
  }

  func playCue(_ message: String) {
    // Real impl: speak `message` through the glasses' speaker route (DAT SDK
    // audio output / TTS). No-op until the SDK is vendored.
  }

  func dispose() {
    self.listener = nil
    self.wakeListener = nil
    // Real impl: tear down the DAT session and release camera/audio/mic.
  }
}
