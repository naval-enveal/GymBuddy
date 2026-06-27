import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/health/vitals_reader.dart';
import 'package:gymbuddy/features/vitals/vitals_permission_controller.dart';

/// The dashboard's loaded vitals: the raw [reading] plus the derived [readiness]
/// proxy. [readiness] is null when no recovery metric (HRV, resting HR, or
/// sleep) is available to base it on.
@immutable
class VitalsSnapshot {
  const VitalsSnapshot({
    required this.reading,
    this.series = VitalsSeries.empty,
    this.readiness,
  });

  /// The current metrics read from the health store.
  final VitalsReading reading;

  /// Recent daily history per metric, feeding the dashboard sparklines.
  final VitalsSeries series;

  /// A 0–100 readiness proxy derived from [reading], or null when there's no
  /// recovery signal to compute it from.
  final int? readiness;

  /// Empty snapshot — before any read, and whenever access isn't granted.
  static const VitalsSnapshot empty = VitalsSnapshot(reading: VitalsReading.empty);

  @override
  bool operator ==(Object other) =>
      other is VitalsSnapshot &&
      other.reading == reading &&
      other.series == series &&
      other.readiness == readiness;

  @override
  int get hashCode => Object.hash(reading, series, readiness);
}

/// Derives a rough 0–100 "readiness" proxy from recovery signals.
///
/// It is deliberately a *proxy*, not a clinical score: with no personal baseline
/// the best we can do is blend each available recovery metric against a generic
/// healthy-adult range, then average the sub-scores that are present. Higher HRV
/// and more sleep raise it; a higher resting heart rate lowers it. Steps are
/// activity, not recovery, so they're intentionally excluded. Returns null when
/// none of the three inputs were recorded.
int? computeReadiness(VitalsReading reading) {
  final scores = <double>[];

  final hrv = reading.hrv;
  if (hrv != null) {
    // RMSSD/SDNN broadly span ~20–100ms in healthy adults; map onto 0–100.
    scores.add(_scale(hrv, low: 20, high: 100));
  }

  final rhr = reading.restingHeartRate;
  if (rhr != null) {
    // Lower resting HR is better: ~40bpm → 100, ~80bpm → 0.
    scores.add(_scale(rhr, low: 80, high: 40));
  }

  final sleep = reading.sleepHours;
  if (sleep != null) {
    // 8h of sleep is a full score; less scales down linearly from 0h.
    scores.add(_scale(sleep, low: 0, high: 8));
  }

  if (scores.isEmpty) return null;
  final mean = scores.reduce((a, b) => a + b) / scores.length;
  return mean.round();
}

/// Linearly maps [value] onto 0–100 between [low] (→0) and [high] (→100),
/// clamped. [low] may exceed [high] for "lower is better" metrics.
double _scale(double value, {required double low, required double high}) {
  if (low == high) return 0;
  final t = (value - low) / (high - low);
  return (math.min(1.0, math.max(0.0, t))) * 100.0;
}

/// Loads the vitals dashboard's data once health access is granted.
///
/// `build()` watches [vitalsPermissionControllerProvider] and only reads when
/// access [isGranted] — until then it stays [VitalsSnapshot.empty] and fires no
/// platform read (the gate shows the connect prompt). When permission flips to
/// granted the controller rebuilds, reads through [vitalsReaderProvider], and
/// computes the readiness proxy. The reader never throws, so missing metrics
/// just surface as empty states. All I/O lives here, never in the widgets.
class VitalsController extends AsyncNotifier<VitalsSnapshot> {
  @override
  Future<VitalsSnapshot> build() async {
    final granted =
        ref.watch(vitalsPermissionControllerProvider).isGranted;
    if (!granted) return VitalsSnapshot.empty;
    return _load();
  }

  /// Re-reads the vitals (pull-to-refresh / retry). A no-op while access isn't
  /// granted — the gate, not the dashboard, drives connecting.
  Future<void> refresh() async {
    if (!ref.read(vitalsPermissionControllerProvider).isGranted) return;
    state = await AsyncValue.guard(_load);
  }

  Future<VitalsSnapshot> _load() async {
    final reader = ref.read(vitalsReaderProvider);
    // Read the current values and the daily history concurrently.
    final readingFuture = reader.read();
    final seriesFuture = reader.readSeries();
    final reading = await readingFuture;
    final series = await seriesFuture;
    return VitalsSnapshot(
      reading: reading,
      series: series,
      readiness: computeReadiness(reading),
    );
  }
}

/// The vitals dashboard's data. See [VitalsController].
final vitalsControllerProvider =
    AsyncNotifierProvider<VitalsController, VitalsSnapshot>(
  VitalsController.new,
);
