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

  group('HealthPackageVitalsReader.readSeries', () {
    test('buckets samples by day — latest HR/HRV, summed sleep/steps', () async {
      final client = _FakeVitalsReadClient(
        data: {
          restingHeartRateType: [
            HealthSample(value: 60, start: DateTime(2026, 6, 22, 8), end: DateTime(2026, 6, 22, 8)),
            // Same day, later → wins for 06-22.
            HealthSample(value: 62, start: DateTime(2026, 6, 22, 20), end: DateTime(2026, 6, 22, 20)),
            HealthSample(value: 58, start: DateTime(2026, 6, 25, 7), end: DateTime(2026, 6, 25, 7)),
          ],
          stepsType: [
            HealthSample(value: 1000, start: DateTime(2026, 6, 23, 9), end: DateTime(2026, 6, 23, 9)),
            HealthSample(value: 500, start: DateTime(2026, 6, 23, 12), end: DateTime(2026, 6, 23, 12)),
            HealthSample(value: 2000, start: DateTime(2026, 6, 26, 9), end: DateTime(2026, 6, 26, 9)),
          ],
          sleepAsleepType: [
            // 06-24: 2h + 1h = 3h.
            HealthSample(value: 0, start: DateTime(2026, 6, 24, 1), end: DateTime(2026, 6, 24, 3)),
            HealthSample(value: 0, start: DateTime(2026, 6, 24, 4), end: DateTime(2026, 6, 24, 5)),
            // Zero-duration → dropped, so 06-26 contributes no point.
            HealthSample(value: 0, start: DateTime(2026, 6, 26, 2), end: DateTime(2026, 6, 26, 2)),
          ],
        },
      );

      final series = await readerWith(client).readSeries();

      expect(series.restingHeartRate, [62, 58]); // oldest→newest
      expect(series.steps, [1500, 2000]);
      expect(series.sleepHours.length, 1);
      expect(series.sleepHours.single, closeTo(3.0, 0.001));
      expect(series.hrv, isEmpty); // no HRV recorded
    });

    test('a failing metric degrades to an empty series, not a throw', () async {
      final client = _FakeVitalsReadClient(
        data: {
          restingHeartRateType: [
            HealthSample(value: 52, start: DateTime(2026, 6, 25, 6), end: DateTime(2026, 6, 25, 6)),
          ],
        },
        throwFor: {hrvType},
      );

      final series = await readerWith(client).readSeries();

      expect(series.restingHeartRate, [52]);
      expect(series.hrv, isEmpty);
    });

    test('no data at all yields an empty series', () async {
      final series = await readerWith(_FakeVitalsReadClient()).readSeries();
      expect(series, VitalsSeries.empty);
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

    test('returns plausible multi-day series for sparklines', () async {
      const reader = MockVitalsReader();
      final series = await reader.readSeries();
      expect(series.restingHeartRate.length, greaterThanOrEqualTo(2));
      expect(series.hrv.length, greaterThanOrEqualTo(2));
      expect(series.sleepHours.length, greaterThanOrEqualTo(2));
      expect(series.steps.length, greaterThanOrEqualTo(2));
    });
  });
}
