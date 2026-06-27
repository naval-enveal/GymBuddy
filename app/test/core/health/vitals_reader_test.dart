import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/health/health_data_types.dart';
import 'package:gymbuddy/core/health/vitals_reader.dart';
import 'package:health/health.dart';

/// Hand fake over the [VitalsReadClient] seam so the reader's windowing and
/// reduction are tested without the platform method channel (absent under
/// `flutter test`).
class _FakeVitalsReadClient implements VitalsReadClient {
  _FakeVitalsReadClient({
    Map<HealthDataType, List<HealthSample>>? data,
    this.throwFor = const <HealthDataType>{},
  }) : data = data ?? <HealthDataType, List<HealthSample>>{};

  final Map<HealthDataType, List<HealthSample>> data;
  final Set<HealthDataType> throwFor;
  final List<HealthDataType> queried = <HealthDataType>[];

  @override
  Future<List<HealthSample>> samples({
    required HealthDataType type,
    required DateTime start,
    required DateTime end,
  }) async {
    queried.add(type);
    if (throwFor.contains(type)) throw StateError('read failed for $type');
    return data[type] ?? <HealthSample>[];
  }
}

void main() {
  // A fixed "now" so windowing is deterministic.
  final now = DateTime(2026, 6, 27, 9); // 9am
  HealthPackageVitalsReader readerWith(_FakeVitalsReadClient client) =>
      HealthPackageVitalsReader(client: client, clock: () => now);

  group('HealthPackageVitalsReader', () {
    test('reads all metrics, picking the latest HR/HRV and summing sleep/steps',
        () async {
      final client = _FakeVitalsReadClient(
        data: {
          restingHeartRateType: [
            HealthSample(value: 60, start: now.subtract(const Duration(days: 3)), end: now.subtract(const Duration(days: 3))),
            // Most recent (latest end) — should win.
            HealthSample(value: 55, start: now.subtract(const Duration(days: 1)), end: now.subtract(const Duration(days: 1))),
          ],
          hrvType: [
            HealthSample(value: 70, start: now.subtract(const Duration(hours: 8)), end: now.subtract(const Duration(hours: 8))),
          ],
          sleepAsleepType: [
            // 6h + 1h of sleep last night = 7h total.
            HealthSample(value: 0, start: now.subtract(const Duration(hours: 9)), end: now.subtract(const Duration(hours: 3))),
            HealthSample(value: 0, start: now.subtract(const Duration(hours: 2, minutes: 30)), end: now.subtract(const Duration(hours: 1, minutes: 30))),
          ],
          stepsType: [
            HealthSample(value: 1200, start: now.subtract(const Duration(hours: 5)), end: now.subtract(const Duration(hours: 5))),
            HealthSample(value: 800, start: now.subtract(const Duration(hours: 1)), end: now.subtract(const Duration(hours: 1))),
          ],
        },
      );

      final reading = await readerWith(client).read();

      expect(reading.restingHeartRate, 55);
      expect(reading.hrv, 70);
      expect(reading.sleepHours, closeTo(7.0, 0.001));
      expect(reading.steps, 2000);
      expect(reading.hasAny, isTrue);
    });

    test('missing metrics surface as null, not zero', () async {
      final client = _FakeVitalsReadClient(
        data: {
          stepsType: [
            HealthSample(value: 500, start: now.subtract(const Duration(hours: 2)), end: now.subtract(const Duration(hours: 2))),
          ],
        },
      );

      final reading = await readerWith(client).read();

      expect(reading.restingHeartRate, isNull);
      expect(reading.hrv, isNull);
      expect(reading.sleepHours, isNull);
      expect(reading.steps, 500);
    });

    test('no data at all yields an empty reading', () async {
      final reading = await readerWith(_FakeVitalsReadClient()).read();

      expect(reading.hasAny, isFalse);
      expect(reading, VitalsReading.empty);
    });

    test('a failing metric is isolated — others still load', () async {
      final client = _FakeVitalsReadClient(
        data: {
          restingHeartRateType: [
            HealthSample(value: 52, start: now.subtract(const Duration(hours: 6)), end: now.subtract(const Duration(hours: 6))),
          ],
        },
        throwFor: {hrvType},
      );

      final reading = await readerWith(client).read();

      expect(reading.restingHeartRate, 52);
      expect(reading.hrv, isNull); // the throwing read degraded to null
    });

    test('zero-duration sleep counts as no sleep recorded', () async {
      final client = _FakeVitalsReadClient(
        data: {
          sleepAsleepType: [
            HealthSample(value: 0, start: now, end: now),
          ],
        },
      );

      final reading = await readerWith(client).read();
      expect(reading.sleepHours, isNull);
    });
  });

  group('MockVitalsReader', () {
    test('returns a populated snapshot for hardware-free dev/test', () async {
      const reader = MockVitalsReader();
      final reading = await reader.read();
      expect(reading.hasAny, isTrue);
      expect(reading.restingHeartRate, isNotNull);
      expect(reading.hrv, isNotNull);
      expect(reading.sleepHours, isNotNull);
      expect(reading.steps, isNotNull);
    });
  });
}
