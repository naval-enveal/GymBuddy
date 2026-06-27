package com.gymbuddy.gymbuddy

import com.gymbuddy.gymbuddy.glasses.GlassesChannel
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// Extends FlutterFragmentActivity (not FlutterActivity) so the health package's
// Health Connect permission flow can use the AndroidX activity-result APIs,
// which require a FragmentActivity host.
class MainActivity : FlutterFragmentActivity() {
    private var glassesChannel: GlassesChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The glasses platform channel (DAT SDK: camera/audio/mic). Safe to wire
        // up with no hardware — it reports `unavailable` and the Dart layer falls
        // back to MockSensorSource.
        glassesChannel = GlassesChannel(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        glassesChannel?.dispose()
        glassesChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
