/// Build-time configuration for the **Meta glasses release channel** — the M10
/// build target that opts the app into the glasses (DAT SDK) hardware path.
///
/// The Meta Device Access Toolkit is a proprietary framework that is large,
/// requires special entitlements, and is not on any public package repository.
/// The default consumer build (the ordinary App Store / Play Store artifact)
/// therefore ships **without** it and runs mock-only: it never bundles the SDK
/// and never even touches the native glasses channel. A distinct *release
/// channel* build — produced by the dedicated build target — vendors the SDK
/// and flips this flag on.
///
/// [kGlassesChannelEnabled] is the single source of truth for "is this a
/// glasses-enabled build", driven by `--dart-define=GLASSES_ENABLED=true`. It is
/// a compile-time constant (`bool.fromEnvironment` is `const`), so it can gate
/// the sensor-source resolver and be tree-shaken out of the default build. The
/// native build target mirrors it with `-Pglasses=true` / `GLASSES_ENABLED` so
/// the vendored SDK artifacts are linked only for this channel.
///
/// When false (the default), [resolveWorkoutSensorSource] short-circuits
/// straight to a [MockSensorSource] without constructing or probing the
/// glasses-backed source. When true, the resolver probes the real glasses and
/// still falls back to the mock if no SDK is vendored or no pair is connected —
/// so even a glasses-channel build degrades gracefully with no hardware.
const bool kGlassesChannelEnabled =
    bool.fromEnvironment('GLASSES_ENABLED', defaultValue: false);
