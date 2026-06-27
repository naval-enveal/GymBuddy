package com.gymbuddy.gymbuddy

import io.flutter.embedding.android.FlutterFragmentActivity

// Extends FlutterFragmentActivity (not FlutterActivity) so the health package's
// Health Connect permission flow can use the AndroidX activity-result APIs,
// which require a FragmentActivity host.
class MainActivity : FlutterFragmentActivity()
