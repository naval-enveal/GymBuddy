import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/health/health_data_types.dart';
import 'package:health/health.dart';

/// One numeric health reading, normalized off the `health` package's
/// `HealthDataPoint` so the read/reduce logic stays testable without the
/// platform method channel (absent under `flutter test`).
@immutable
class HealthSample {
  const HealthSample({
    required this.value,
    required this.start,
    required this.end,
  });

  /// The numeric value (bpm, ms, step count, or — for sleep — ignored in favour
  /// of [start]/[end] duration).
  final double value;

  /// When the sample's interval began.
  final DateTime start;

  /// When the sample's interval ended (== [start] for instantaneous samples).
  final DateTime end;
}

/// The vitals the dashboard surfaces, each nullable so a metric the user hasn't
/// recorded simply shows an empty state rather than a fabricated zero.
@immutable
class VitalsReading {
  const VitalsReading({
    this.restingHeartRate,
    this.hrv,
    this.sleepHours,
    this.steps,
  });

  /// Most recent resting heart rate, in bpm.
  final double? restingHeartRate;

  /// Most recent heart-rate variability, in ms (SDNN on iOS, RMSSD on Android).
  final double? hrv;

  /// Last night's total time asleep, in hours.
  final double? sleepHours;

  /// Steps recorded so far today.
  final int? steps;

  /// No data — the default before a read and whenever access isn't granted.
  static const VitalsReading empty = VitalsReading();

  /// Whether any metric is present (drives the dashboard's overall empty state).
  bool get hasAny =>
      restingHeartRate != null ||
      hrv != null ||
      sleepHours != null ||
      steps != null;

  @override
  bool operator ==(Object other) =>
      other is VitalsReading &&
      other.restingHeartRate == restingHeartRate &&
      other.hrv == hrv &&
      other.sleepHours == sleepHours &&
      other.steps == steps;

  @override
  int get hashCode => Object.hash(restingHeartRate, hrv, sleepHours, steps);
}

/// Recent daily history for each metric, feeding the dashboard sparklines.
///
/// Each list holds one value per day-with-data over the recent window, ordered
/// oldest→newest; resting HR / HRV are the latest reading on each day, sleep is
/// that day's summed asleep hours, steps that day's total. An empty list means
/// there's no history to chart — the dashboard shows the metric without a trend.
@immutable
class VitalsSeries {
  const VitalsSeries({
    this.restingHeartRate = const <double>[],
    this.hrv = const <double>[],
    this.sleepHours = const <double>[],
    this.steps = const <double>[],
  });

  /// Daily resting heart rate (bpm), oldest→newest.
  final List<double> restingHeartRate;

  /// Daily heart-rate variability (ms), oldest→newest.
  final List<double> hrv;

  /// Daily sleep totals (hours), oldest→newest.
  final List<double> sleepHours;

  /// Daily step totals, oldest→newest.
  final List<double> steps;

  /// No history — the default before a read and whenever access isn't granted.
  static const VitalsSeries empty = VitalsSeries();

  @override
  bool operator ==(Object other) =>
      other is VitalsSeries &&
      listEquals(other.restingHeartRate, restingHeartRate) &&
      listEquals(other.hrv, hrv) &&
      listEquals(other.sleepHours, sleepHours) &&
      listEquals(other.steps, steps);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(restingHeartRate),
        Object.hashAll(hrv),
        Object.hashAll(sleepHours),
        Object.hashAll(steps),
      );
}

/// Low-level seam over the `health` package's read API. Returns normalized
/// [HealthSample]s so the windowing/reduction in [HealthPackageVitalsReader] is
/// unit-testable with a hand fake, the same approach the permission service
/// takes over its `HealthClient` seam.
abstract interface class VitalsReadClient {
  /// Numeric samples for [type] in `[start, end]`. Order is not guaranteed.
  Future<List<HealthSample>> samples({
    required HealthDataType type,
    required DateTime start,
    required DateTime end,
  });
}

/// Production [VitalsReadClient] backed by the real `health` package, talking to
/// HealthKit (iOS) / Health Connect (Android) over the plugin's method channel.
class LiveVitalsReadClient implements VitalsReadClient {
  LiveVitalsReadClient([Health? health]) : _health = health ?? Health();

  final Health _health;
  bool _configured = false;

  @override
  Future<List<HealthSample>> samples({
    required HealthDataType type,
    required DateTime start,
    required DateTime end,
  }) async {
    if (!_configured) {
      await _health.configure();
      _configured = true;
    }
    final points = await _health.getHealthDataFromTypes(
      types: <HealthDataType>[type],
      startTime: start,
      endTime: end,
    );
    return points
        .where((p) => p.value is NumericHealthValue)
        .map(
          (p) => HealthSample(
            value: (p.value as NumericHealthValue).numericValue.toDouble(),
            start: p.dateFrom,
            end: p.dateTo,
          ),
        )
        .toList();
  }
}

/// Reads the vitals the dashboard shows. The real implementation is
/// [HealthPackageVitalsReader]; [MockVitalsReader] stays the provider default so
/// tests and hardware-free dev builds get a populated dashboard with no platform
/// health store attached — the same mock-first posture as the permission layer.
abstract interface class VitalsReader {
  /// Reads the current vitals snapshot. Never throws — a platform failure
  /// degrades to whatever metrics were readable (or [VitalsReading.empty]).
  Future<VitalsReading> read();

  /// Reads recent daily history for each metric, for the sparklines. Never
  /// throws — a failing metric degrades to an empty series.
  Future<VitalsSeries> readSeries();
}

/// Real [VitalsReader] over a [VitalsReadClient]. Each metric is read
/// independently and guarded on its own, so one unsupported/failing type leaves
/// the others intact instead of blanking the whole dashboard.
class HealthPackageVitalsReader implements VitalsReader {
  HealthPackageVitalsReader({
    VitalsReadClient? client,
    DateTime Function()? clock,
  })  : _client = client ?? LiveVitalsReadClient(),
        _now = clock ?? DateTime.now;

  final VitalsReadClient _client;
  final DateTime Function() _now;

  /// How far back to look for the latest resting-HR / HRV reading.
  static const Duration _recentWindow = Duration(days: 7);

  /// How many days of daily history the sparklines chart.
  static const int _seriesDays = 7;

  @override
  Future<VitalsReading> read() async {
    final now = _now();
    final results = await Future.wait(<Future<Object?>>[
      _latest(restingHeartRateType, now.subtract(_recentWindow), now),
      _latest(hrvType, now.subtract(_recentWindow), now),
      _sleepHours(now),
      _stepsToday(now),
    ]);
    return VitalsReading(
      restingHeartRate: results[0] as double?,
      hrv: results[1] as double?,
      sleepHours: results[2] as double?,
      steps: results[3] as int?,
    );
  }

  @override
  Future<VitalsSeries> readSeries() async {
    final now = _now();
    // Start at local midnight `_seriesDays` ago so each bucket is a full day.
    final startOfToday = DateTime(now.year, now.month, now.day);
    final start = startOfToday.subtract(const Duration(days: _seriesDays - 1));
    final results = await Future.wait(<Future<List<double>>>[
      _dailyLatest(restingHeartRateType, start, now),
      _dailyLatest(hrvType, start, now),
      _dailySleepHours(start, now),
      _dailySteps(start, now),
    ]);
    return VitalsSeries(
      restingHeartRate: results[0],
      hrv: results[1],
      sleepHours: results[2],
      steps: results[3],
    );
  }

  /// Local-midnight day bucket for [time].
  static DateTime _dayOf(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  /// One value per day-with-data, taking the latest sample on each day.
  Future<List<double>> _dailyLatest(
    HealthDataType type,
    DateTime start,
    DateTime end,
  ) async {
    return _guardList(() async {
      final samples = await _client.samples(type: type, start: start, end: end);
      final byDay = <DateTime, HealthSample>{};
      for (final s in samples) {
        final day = _dayOf(s.end);
        final existing = byDay[day];
        if (existing == null || s.end.isAfter(existing.end)) byDay[day] = s;
      }
      return _orderedValues(byDay, (s) => s.value);
    });
  }

  /// One value per day-with-data: that day's summed asleep hours.
  Future<List<double>> _dailySleepHours(DateTime start, DateTime end) async {
    return _guardList(() async {
      final samples =
          await _client.samples(type: sleepAsleepType, start: start, end: end);
      final minutesByDay = <DateTime, double>{};
      for (final s in samples) {
        final minutes = s.end.difference(s.start).inSeconds / 60.0;
        if (minutes <= 0) continue;
        final day = _dayOf(s.start);
        minutesByDay[day] = (minutesByDay[day] ?? 0) + minutes;
      }
      return _orderedValues(minutesByDay, (m) => m / 60.0);
    });
  }

  /// One value per day-with-data: that day's total steps.
  Future<List<double>> _dailySteps(DateTime start, DateTime end) async {
    return _guardList(() async {
      final samples =
          await _client.samples(type: stepsType, start: start, end: end);
      final totalsByDay = <DateTime, double>{};
      for (final s in samples) {
        final day = _dayOf(s.start);
        totalsByDay[day] = (totalsByDay[day] ?? 0) + s.value;
      }
      return _orderedValues(totalsByDay, (v) => v);
    });
  }

  /// Flattens a day→entry map into oldest→newest values via [project].
  static List<double> _orderedValues<V>(
    Map<DateTime, V> byDay,
    double Function(V) project,
  ) {
    final days = byDay.keys.toList()..sort();
    return days.map((d) => project(byDay[d] as V)).toList();
  }

  /// The value of the most recent sample for [type], or null if none.
  Future<double?> _latest(
    HealthDataType type,
    DateTime start,
    DateTime end,
  ) async {
    return _guard(() async {
      final samples = await _client.samples(type: type, start: start, end: end);
      if (samples.isEmpty) return null;
      samples.sort((a, b) => a.end.compareTo(b.end));
      return samples.last.value;
    });
  }

  /// Last night's total sleep in hours — the summed duration of SLEEP_ASLEEP
  /// segments over the past day. Null when nothing was recorded.
  Future<double?> _sleepHours(DateTime now) async {
    return _guard(() async {
      final samples = await _client.samples(
        type: sleepAsleepType,
        start: now.subtract(const Duration(days: 1)),
        end: now,
      );
      if (samples.isEmpty) return null;
      final minutes = samples.fold<double>(
        0,
        (sum, s) => sum + s.end.difference(s.start).inSeconds / 60.0,
      );
      if (minutes <= 0) return null;
      return minutes / 60.0;
    });
  }

  /// Steps recorded since local midnight. Null when nothing was recorded.
  Future<int?> _stepsToday(DateTime now) async {
    return _guard(() async {
      final startOfDay = DateTime(now.year, now.month, now.day);
      final samples = await _client.samples(
        type: stepsType,
        start: startOfDay,
        end: now,
      );
      if (samples.isEmpty) return null;
      final total = samples.fold<double>(0, (sum, s) => sum + s.value);
      return total.round();
    });
  }

  /// Runs [read] but never throws — a per-metric platform failure resolves to
  /// null so the rest of the snapshot still loads.
  Future<T?> _guard<T>(Future<T?> Function() read) async {
    try {
      return await read();
    } catch (error, stackTrace) {
      debugPrint('HealthPackageVitalsReader read failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  /// Like [_guard] but for a series read — a per-metric failure resolves to an
  /// empty list so the other sparklines still load.
  Future<List<double>> _guardList(Future<List<double>> Function() read) async {
    try {
      return await read();
    } catch (error, stackTrace) {
      debugPrint('HealthPackageVitalsReader series read failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const <double>[];
    }
  }
}

/// Default, integration-free [VitalsReader]. Returns a fixed, plausible snapshot
/// so the dashboard is populated in tests and hardware-free dev builds with no
/// platform health store attached — mirroring how `MockHealthPermissionService`
/// grants and `MockSensorSource` runs rep features with no glasses present.
class MockVitalsReader implements VitalsReader {
  const MockVitalsReader();

  @override
  Future<VitalsReading> read() async => const VitalsReading(
        restingHeartRate: 58,
        hrv: 62,
        sleepHours: 7.4,
        steps: 4820,
      );

  @override
  Future<VitalsSeries> readSeries() async => const VitalsSeries(
        restingHeartRate: <double>[60, 59, 61, 58, 57, 59, 58],
        hrv: <double>[55, 58, 60, 57, 63, 61, 62],
        sleepHours: <double>[6.8, 7.1, 7.5, 6.9, 7.8, 7.2, 7.4],
        steps: <double>[5200, 6100, 4800, 7300, 5600, 8100, 4820],
      );
}

/// The app's vitals reader. Overridden at the composition root (`main.dart`)
/// with [HealthPackageVitalsReader]; defaults to [MockVitalsReader] so feature
/// code and tests have a working dependency with no hardware.
final vitalsReaderProvider = Provider<VitalsReader>(
  (ref) => const MockVitalsReader(),
);
