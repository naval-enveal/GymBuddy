import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/health/health_permission_service.dart';
import 'package:gymbuddy/core/health/vitals_reader.dart';
import 'package:gymbuddy/features/vitals/vitals_controller.dart';
import 'package:gymbuddy/features/vitals/vitals_permission_controller.dart';

/// Fake reader returning a configured snapshot and counting reads.
class _FakeVitalsReader implements VitalsReader {
  _FakeVitalsReader(this._reading);

  VitalsReading _reading;
  int reads = 0;

  set reading(VitalsReading r) => _reading = r;

  @override
  Future<VitalsReading> read() async {
    reads++;
    return _reading;
  }
}

/// Grants on request, so a test can flip the permission gate to granted.
class _GrantingPermissionService implements HealthPermissionService {
  @override
  Future<HealthPermissionStatus> request() async =>
      HealthPermissionStatus.granted;
}

ProviderContainer _containerWith(_FakeVitalsReader reader) {
  final container = ProviderContainer(
    overrides: [
      vitalsReaderProvider.overrideWithValue(reader),
      healthPermissionServiceProvider
          .overrideWithValue(_GrantingPermissionService()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _grant(ProviderContainer container) =>
    container.read(vitalsPermissionControllerProvider.notifier).request();

void main() {
  group('computeReadiness', () {
    test('blends HRV, resting HR, and sleep into 0–100', () {
      // HRV 60 → (60-20)/80 = 50; RHR 60 → (60-80)/(40-80) = 50; sleep 4 → 50.
      const reading = VitalsReading(
        restingHeartRate: 60,
        hrv: 60,
        sleepHours: 4,
      );
      expect(computeReadiness(reading), 50);
    });

    test('high recovery signals score near the top', () {
      const reading = VitalsReading(
        restingHeartRate: 40,
        hrv: 100,
        sleepHours: 8,
      );
      expect(computeReadiness(reading), 100);
    });

    test('averages only the metrics that are present', () {
      // Only sleep present: 8h → 100.
      expect(computeReadiness(const VitalsReading(sleepHours: 8)), 100);
    });

    test('clamps out-of-range inputs', () {
      // Absurdly high HRV and very low RHR both clamp to 100; 12h sleep → 100.
      const reading = VitalsReading(
        restingHeartRate: 30,
        hrv: 200,
        sleepHours: 12,
      );
      expect(computeReadiness(reading), 100);
    });

    test('null when no recovery metric is available', () {
      // Steps alone is activity, not recovery — no readiness.
      expect(computeReadiness(const VitalsReading(steps: 5000)), isNull);
      expect(computeReadiness(VitalsReading.empty), isNull);
    });
  });

  group('VitalsController', () {
    test('stays empty and reads nothing until access is granted', () async {
      final reader = _FakeVitalsReader(const VitalsReading(steps: 10));
      final container = _containerWith(reader);

      final snapshot =
          await container.read(vitalsControllerProvider.future);

      expect(snapshot, VitalsSnapshot.empty);
      expect(reader.reads, 0);
    });

    test('reads and computes readiness once granted', () async {
      final reader = _FakeVitalsReader(const VitalsReading(
        restingHeartRate: 60,
        hrv: 60,
        sleepHours: 4,
        steps: 3000,
      ));
      final container = _containerWith(reader);

      await _grant(container);
      final snapshot =
          await container.read(vitalsControllerProvider.future);

      expect(reader.reads, 1);
      expect(snapshot.reading.steps, 3000);
      expect(snapshot.readiness, 50);
    });

    test('keeps missing metrics empty while computing from what is present',
        () async {
      final reader = _FakeVitalsReader(const VitalsReading(sleepHours: 8));
      final container = _containerWith(reader);

      await _grant(container);
      final snapshot =
          await container.read(vitalsControllerProvider.future);

      expect(snapshot.reading.restingHeartRate, isNull);
      expect(snapshot.reading.steps, isNull);
      expect(snapshot.readiness, 100); // from sleep alone
    });

    test('refresh re-reads when granted', () async {
      final reader = _FakeVitalsReader(const VitalsReading(steps: 100));
      final container = _containerWith(reader);

      await _grant(container);
      await container.read(vitalsControllerProvider.future);
      expect(reader.reads, 1);

      reader.reading = const VitalsReading(steps: 200);
      await container.read(vitalsControllerProvider.notifier).refresh();

      final snapshot = container.read(vitalsControllerProvider).requireValue;
      expect(reader.reads, 2);
      expect(snapshot.reading.steps, 200);
    });

    test('refresh is a no-op while access is not granted', () async {
      final reader = _FakeVitalsReader(const VitalsReading(steps: 100));
      final container = _containerWith(reader);

      await container.read(vitalsControllerProvider.future);
      await container.read(vitalsControllerProvider.notifier).refresh();

      expect(reader.reads, 0);
    });
  });
}
