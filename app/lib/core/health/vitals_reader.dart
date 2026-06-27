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
}

/// The app's vitals reader. Overridden at the composition root (`main.dart`)
/// with [HealthPackageVitalsReader]; defaults to [MockVitalsReader] so feature
/// code and tests have a working dependency with no hardware.
final vitalsReaderProvider = Provider<VitalsReader>(
  (ref) => const MockVitalsReader(),
);
