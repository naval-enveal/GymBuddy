package com.gymbuddy.gymbuddy.glasses

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The Android side of the glasses platform channel — the native counterpart of
 * the Dart `MetaGlassesSensorSource` (M7). It exposes a single control
 * [MethodChannel] plus two streaming [EventChannel]s (reps + form cues), all
 * backed by a [DatSdkClient] that wraps the Meta DAT SDK's camera/audio/mic.
 *
 * Wire contract (kept identical on iOS and in the Dart binding):
 *  - method channel `gymbuddy/glasses`:
 *      `connect`       -> { availability: "available"|"unavailable",
 *                           capabilities: { repCounting: Bool, formTracking: Bool } }
 *      `startTracking` (args { name: String, formTracked: Bool }) -> null
 *      `stopTracking`  -> null
 *      `playCue`       (args { message: String }) -> null
 *      `dispose`       -> null
 *  - event channel `gymbuddy/glasses/reps`     -> { index: Int, timestampMs: Long, confidence: Double? }
 *  - event channel `gymbuddy/glasses/formCues` -> { severity: String, message: String }
 *
 * Because the DAT SDK isn't bundled in a no-hardware build, [connect] resolves to
 * `unavailable` and no events are emitted — the Dart layer then falls back to the
 * mock, so the channel is always safe to wire up regardless of hardware.
 */
class GlassesChannel(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val client: DatSdkClient = DatSdkClient.create(context.applicationContext)
    private val mainHandler = Handler(Looper.getMainLooper())

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL).apply {
        setMethodCallHandler(this@GlassesChannel)
    }

    private var repsSink: EventChannel.EventSink? = null
    private val repsChannel = EventChannel(messenger, REPS_CHANNEL).apply {
        setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                repsSink = events
            }

            override fun onCancel(arguments: Any?) {
                repsSink = null
            }
        })
    }

    private var formCuesSink: EventChannel.EventSink? = null
    private val formCuesChannel = EventChannel(messenger, FORM_CUES_CHANNEL).apply {
        setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                formCuesSink = events
            }

            override fun onCancel(arguments: Any?) {
                formCuesSink = null
            }
        })
    }

    /** Forwards DAT SDK events onto the Flutter sinks; sink calls must hit the main thread. */
    private val trackingListener = object : TrackingListener {
        override fun onRep(sample: RepSample) {
            mainHandler.post {
                repsSink?.success(
                    mapOf(
                        "index" to sample.index,
                        "timestampMs" to sample.timestampMs,
                        "confidence" to sample.confidence,
                    ),
                )
            }
        }

        override fun onFormCue(cue: FormCueSample) {
            mainHandler.post {
                formCuesSink?.success(
                    mapOf(
                        "severity" to cue.severity,
                        "message" to cue.message,
                    ),
                )
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> {
                val availability = client.connect()
                val caps = client.capabilities()
                result.success(
                    mapOf(
                        "availability" to availability.name.lowercase(),
                        "capabilities" to mapOf(
                            "repCounting" to caps.repCounting,
                            "formTracking" to caps.formTracking,
                        ),
                    ),
                )
            }

            "startTracking" -> {
                val name = call.argument<String>("name")
                if (name == null) {
                    result.error("bad_args", "startTracking requires a 'name'", null)
                    return
                }
                val formTracked = call.argument<Boolean>("formTracked") ?: false
                client.startTracking(TrackedExercise(name, formTracked), trackingListener)
                result.success(null)
            }

            "stopTracking" -> {
                client.stopTracking()
                result.success(null)
            }

            "playCue" -> {
                val message = call.argument<String>("message")
                if (message == null) {
                    result.error("bad_args", "playCue requires a 'message'", null)
                    return
                }
                client.playCue(message)
                result.success(null)
            }

            "dispose" -> {
                client.dispose()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    /** Tears down all channels and the underlying client; call from the activity's engine teardown. */
    fun dispose() {
        methodChannel.setMethodCallHandler(null)
        repsChannel.setStreamHandler(null)
        formCuesChannel.setStreamHandler(null)
        repsSink = null
        formCuesSink = null
        client.dispose()
    }

    companion object {
        const val METHOD_CHANNEL = "gymbuddy/glasses"
        const val REPS_CHANNEL = "gymbuddy/glasses/reps"
        const val FORM_CUES_CHANNEL = "gymbuddy/glasses/formCues"
    }
}
