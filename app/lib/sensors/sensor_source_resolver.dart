import 'package:gymbuddy/sensors/meta_glasses_sensor_source.dart';
import 'package:gymbuddy/sensors/mock_sensor_source.dart';
import 'package:gymbuddy/sensors/sensor_source.dart';

/// Probes the real glasses source once and decides which [WorkoutSensorSource]
/// the app should run with — the M7 capability-detection + fallback step.
///
/// The flow mirrors the graceful posture the rest of the hardware layer takes:
/// construct the glasses-backed source, [WorkoutSensorSource.connect] to it, and
///   * keep it when it reports [SensorAvailability.available], or
///   * dispose it and hand back a [MockSensorSource] when it reports
///     [SensorAvailability.unavailable] (no DAT SDK, channel unregistered, or the
///     native side simply has no glasses paired) — every build until the SDK is
///     vendored and a real pair is connected.
///
/// Any unexpected throw from the probe is also treated as "unavailable" so a
/// flaky native handshake can never block the workout: the app always ends up
/// with a usable source. The returned source is already `connect()`ed when it's
/// the glasses one; the mock's own `connect()` is a no-op that always succeeds,
/// so the session controller can call `connect()` again unconditionally.
///
/// Factories are injectable so this can be unit-tested with no platform
/// channels; they default to the real glasses source and the mock.
Future<WorkoutSensorSource> resolveWorkoutSensorSource({
  WorkoutSensorSource Function() glassesFactory =
      MetaGlassesSensorSource.new,
  WorkoutSensorSource Function() mockFactory = MockSensorSource.new,
}) async {
  final glasses = glassesFactory();
  SensorAvailability availability;
  try {
    availability = await glasses.connect();
  } catch (_) {
    // Defensive: the source contract degrades to `unavailable` rather than
    // throwing, but a misbehaving native side must never crash startup.
    availability = SensorAvailability.unavailable;
  }

  if (availability == SensorAvailability.available) {
    return glasses;
  }

  await glasses.dispose();
  return mockFactory();
}
