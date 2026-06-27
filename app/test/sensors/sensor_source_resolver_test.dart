import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/sensors/meta_glasses_sensor_source.dart';
import 'package:gymbuddy/sensors/mock_sensor_source.dart';
import 'package:gymbuddy/sensors/sensor_source.dart';
import 'package:gymbuddy/sensors/sensor_source_resolver.dart';

/// A controllable [WorkoutSensorSource] that records its lifecycle so the
/// resolver's keep/dispose decision can be asserted without any platform
/// channels. [connect] either returns a fixed availability or throws.
class _FakeSensorSource implements WorkoutSensorSource {
  _FakeSensorSource({
    this.availability = SensorAvailability.available,
    this.throwOnConnect = false,
  });

  final SensorAvailability availability;
  final bool throwOnConnect;

  bool connected = false;
  bool disposed = false;

  @override
  Future<SensorAvailability> connect() async {
    connected = true;
    if (throwOnConnect) {
      throw StateError('boom');
    }
    return availability;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  SensorCapabilities get capabilities =>
      const SensorCapabilities(repCounting: false, formTracking: false);

  @override
  Stream<RepEvent> get reps => const Stream<RepEvent>.empty();

  @override
  Stream<FormCue> get formCues => const Stream<FormCue>.empty();

  @override
  Future<void> startTracking(TrackedExercise exercise) async {}

  @override
  Future<void> stopTracking() async {}
}

void main() {
  group('resolveWorkoutSensorSource', () {
    test('keeps the glasses source when it connects available', () async {
      final glasses = _FakeSensorSource();
      var mockBuilt = false;

      final resolved = await resolveWorkoutSensorSource(
        glassesFactory: () => glasses,
        mockFactory: () {
          mockBuilt = true;
          return _FakeSensorSource();
        },
      );

      expect(resolved, same(glasses));
      expect(glasses.connected, isTrue);
      expect(glasses.disposed, isFalse);
      expect(mockBuilt, isFalse, reason: 'no fallback when glasses available');
    });

    test('disposes the glasses and falls back to the mock when unavailable',
        () async {
      final glasses =
          _FakeSensorSource(availability: SensorAvailability.unavailable);
      final mock = _FakeSensorSource();

      final resolved = await resolveWorkoutSensorSource(
        glassesFactory: () => glasses,
        mockFactory: () => mock,
      );

      expect(resolved, same(mock));
      expect(glasses.connected, isTrue);
      expect(glasses.disposed, isTrue, reason: 'glasses released on fallback');
    });

    test('falls back to the mock when the probe throws', () async {
      final glasses = _FakeSensorSource(throwOnConnect: true);
      final mock = _FakeSensorSource();

      final resolved = await resolveWorkoutSensorSource(
        glassesFactory: () => glasses,
        mockFactory: () => mock,
      );

      expect(resolved, same(mock));
      expect(glasses.disposed, isTrue);
    });

    test('defaults resolve to a MockSensorSource with no glasses present',
        () async {
      // No native handler registered: the real MetaGlassesSensorSource hits a
      // MissingPluginException, degrades to unavailable, and the resolver hands
      // back the real MockSensorSource — the hardware-free path the app ships.
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel(kGlassesMethodChannel),
        null,
      );

      final resolved = await resolveWorkoutSensorSource();

      expect(resolved, isA<MockSensorSource>());
      await resolved.dispose();
    });
  });
}
