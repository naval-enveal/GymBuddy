package com.gymbuddy.gymbuddy.glasses

import android.content.Context
import android.util.Log

/** Whether the glasses can be used for tracking right now. Mirrors the Dart
 *  `SensorAvailability` enum so the wire contract is symmetric. */
enum class GlassesAvailability {
    AVAILABLE,
    UNAVAILABLE,
}

/** What the connected glasses can do. Mirrors Dart `SensorCapabilities`. */
data class GlassesCapabilities(
    val repCounting: Boolean,
    val formTracking: Boolean,
)

/** The exercise the glasses are being asked to watch. Mirrors Dart
 *  `TrackedExercise`: a minimal, feature-agnostic descriptor. */
data class TrackedExercise(
    val name: String,
    val formTracked: Boolean,
)

/** A single completed rep observed by the glasses pipeline. */
data class RepSample(
    /** 1-based position within the current set; resets on each [DatSdkClient.startTracking]. */
    val index: Int,
    val timestampMs: Long,
    /** Detection confidence in 0..1, or null if the pipeline doesn't score reps. */
    val confidence: Double?,
)

/** A piece of form feedback for the exercise being tracked. `severity` is one of
 *  `good` / `minor` / `major` to match the Dart `FormSeverity` enum names. */
data class FormCueSample(
    val severity: String,
    val message: String,
)

/** A wake-word trigger from the glasses' always-on mic. Mirrors the Dart
 *  `WakeEvent`: a control signal (not a tracking one) that opens a hands-free
 *  Q&A turn. */
data class WakeSample(
    val timestampMs: Long,
    /** The recognized wake phrase that fired the trigger. */
    val phrase: String,
    /** Detection confidence in 0..1, or null if the pipeline doesn't score it. */
    val confidence: Double?,
)

/** Callbacks the [DatSdkClient] invokes as the glasses pipeline produces events.
 *  The channel forwards these to the Flutter event sinks. */
interface TrackingListener {
    fun onRep(sample: RepSample)
    fun onFormCue(cue: FormCueSample)
}

/** Callback the [DatSdkClient] invokes when the always-on mic detects the wake
 *  phrase. Separate from [TrackingListener] because wake detection is a control
 *  signal independent of tracking — the mic listens between sets too. */
interface WakeListener {
    fun onWake(sample: WakeSample)
}

/**
 * Thin wrapper over the Meta Device Access Toolkit (DAT SDK) — the seam that
 * owns the glasses' camera/audio/mic for rep & form tracking.
 *
 * Feature code (and even the rest of the native app) never talks to the DAT SDK
 * directly; everything goes through this interface, exactly as Flutter feature
 * code goes through `WorkoutSensorSource`. The real implementation is created by
 * [create]; it must degrade gracefully when the SDK isn't bundled or no glasses
 * are paired, reporting [GlassesAvailability.UNAVAILABLE] so the Dart layer falls
 * back to `MockSensorSource` and the workout still runs with no hardware.
 */
interface DatSdkClient {
    /** Establishes the glasses link (camera/audio/mic) and reports whether it's usable. */
    fun connect(): GlassesAvailability

    /** What the connected glasses can do; meaningful only after a successful [connect]. */
    fun capabilities(): GlassesCapabilities

    /** Begins watching [exercise], resetting the rep count to zero. Events arrive on [listener]. */
    fun startTracking(exercise: TrackedExercise, listener: TrackingListener)

    /** Stops watching the current exercise (rest or set completion). */
    fun stopTracking()

    /**
     * Registers (or clears, with null) the listener for wake-phrase triggers from
     * the always-on mic. Independent of [startTracking] — once a [WakeListener] is
     * set the client may fire [WakeListener.onWake] at any time while connected,
     * including between sets. A client with no mic ([UnavailableDatSdkClient])
     * simply never calls back, so the wake stream stays empty with no hardware.
     */
    fun setWakeListener(listener: WakeListener?)

    /**
     * Speaks a short coaching cue through the glasses' speakers — the first output
     * path back to the hardware. Best-effort: a client with no audio route (e.g.
     * [UnavailableDatSdkClient]) does nothing, so the Dart layer can fire cues
     * unconditionally and they degrade silently with no hardware.
     */
    fun playCue(message: String)

    /** Releases the glasses link and all resources. The client must not be used afterwards. */
    fun dispose()

    companion object {
        /**
         * Builds the active client for [context]. The DAT SDK is Meta-proprietary
         * and is not on a public Maven repo, so it is not a compile-time dependency
         * of this build. We detect it reflectively at runtime: when the SDK classes
         * are absent (every build until the SDK is dropped in) we return a client
         * that reports [GlassesAvailability.UNAVAILABLE], guaranteeing the app builds
         * and runs with no hardware. Once the SDK is vendored, swap the body of
         * [DatSdkAvailable] for real DAT SDK calls without touching the channel.
         */
        fun create(context: Context): DatSdkClient {
            val present = isDatSdkPresent()
            Log.i(TAG, "DAT SDK present on classpath: $present")
            return if (present) DatSdkAvailable(context) else UnavailableDatSdkClient()
        }

        /**
         * The wake phrase the always-on mic listens for to open a hands-free Q&A
         * turn. Fixed for now (Q&A lands in M9); kept here as the single native
         * source of truth, mirroring the Dart `kWakePhrase`, so it has one place
         * to grow into per-user config later.
         */
        const val WAKE_PHRASE = "hey buddy"

        /** The DAT SDK entry-point class name. Detected, never linked at compile time. */
        private const val DAT_SDK_CLASS = "com.meta.wearables.dat.DeviceAccessToolkit"
        private const val TAG = "GymBuddyGlasses"

        private fun isDatSdkPresent(): Boolean =
            try {
                Class.forName(DAT_SDK_CLASS, false, DatSdkClient::class.java.classLoader)
                true
            } catch (_: ClassNotFoundException) {
                false
            } catch (_: Throwable) {
                // Any other load failure (e.g. linkage error) is treated as "absent"
                // so detection itself can never crash the host app.
                false
            }
    }
}

/**
 * The no-hardware client: used on every build where the DAT SDK isn't bundled (or
 * the device has no glasses paired). It connects to nothing, advertises no
 * capabilities, and emits no events — the Dart `MetaGlassesSensorSource` reads the
 * `UNAVAILABLE` result and falls back to `MockSensorSource`.
 */
internal class UnavailableDatSdkClient : DatSdkClient {
    override fun connect(): GlassesAvailability = GlassesAvailability.UNAVAILABLE

    override fun capabilities(): GlassesCapabilities =
        GlassesCapabilities(repCounting = false, formTracking = false)

    override fun startTracking(exercise: TrackedExercise, listener: TrackingListener) {
        // No glasses, no events. Intentionally a no-op.
    }

    override fun stopTracking() {}

    override fun setWakeListener(listener: WakeListener?) {
        // No mic, no wake events. The wake stream stays empty with no hardware.
    }

    override fun playCue(message: String) {
        // No glasses, no speakers. Cues degrade to a silent no-op.
    }

    override fun dispose() {}
}

/**
 * The real DAT-SDK-backed client. Instantiated only when [DatSdkClient.isDatSdkPresent]
 * is true, i.e. once the Meta DAT SDK is vendored into the Android build. Until then
 * this code path is never taken at runtime, so it conservatively reports
 * [GlassesAvailability.UNAVAILABLE] rather than pretending to be connected.
 *
 * Integration TODO (when the SDK is added): wire [connect] to the DAT session +
 * camera/audio/mic streams, feed the on-device pose pipeline (M8) into [startTracking],
 * and surface rep/form events through the [TrackingListener].
 */
internal class DatSdkAvailable(private val context: Context) : DatSdkClient {
    @Volatile private var listener: TrackingListener? = null
    @Volatile private var wakeListener: WakeListener? = null

    override fun connect(): GlassesAvailability {
        // Real DAT session/handshake goes here once the SDK is vendored. Until the
        // camera/audio/mic streams are confirmed live, stay UNAVAILABLE so the app
        // never claims a glasses connection it can't back.
        return GlassesAvailability.UNAVAILABLE
    }

    override fun capabilities(): GlassesCapabilities =
        GlassesCapabilities(repCounting = true, formTracking = true)

    override fun startTracking(exercise: TrackedExercise, listener: TrackingListener) {
        this.listener = listener
        // Real impl: open the glasses camera/mic for `exercise` and start the
        // rep/form pipeline, calling listener.onRep / listener.onFormCue per event.
    }

    override fun stopTracking() {
        this.listener = null
        // Real impl: pause the camera/mic pipeline. The wake listener stays
        // registered — the mic keeps listening between sets.
    }

    override fun setWakeListener(listener: WakeListener?) {
        this.wakeListener = listener
        // Real impl: arm the DAT SDK's always-on mic / wake-word engine for
        // DatSdkClient.WAKE_PHRASE and call wakeListener.onWake on each detection
        // (independent of startTracking); clear the engine when listener is null.
    }

    override fun playCue(message: String) {
        // Real impl: speak `message` through the glasses' speaker route (DAT SDK
        // audio output / TTS). No-op until the SDK is vendored.
    }

    override fun dispose() {
        this.listener = null
        this.wakeListener = null
        // Real impl: tear down the DAT session and release camera/audio/mic.
    }
}
