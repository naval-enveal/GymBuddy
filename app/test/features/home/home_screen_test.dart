// Widget tests for the Home vitals dashboard. They drive the screen with the
// permission gate already granted (a seeded controller) and a fake reader, so
// the dashboard renders without a platform health store. Auto-retry is disabled
// on the container so the error path stays deterministic.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gymbuddy/core/design/design.dart';
import 'package:gymbuddy/core/health/health_permission_service.dart';
import 'package:gymbuddy/core/health/vitals_reader.dart';
import 'package:gymbuddy/features/home/home_screen.dart';
import 'package:gymbuddy/features/vitals/vitals_permission_controller.dart';

/// Configurable fake reader: returns a fixed reading/series, can delay or throw,
/// and counts reads so pull-to-refresh can be asserted.
class _FakeReader implements VitalsReader {
  _FakeReader({
    this.reading = const VitalsReading(
      restingHeartRate: 58,
      hrv: 62,
      sleepHours: 7.4,
      steps: 4820,
    ),
    this.series = const VitalsSeries(
      restingHeartRate: <double>[60, 59, 58],
      hrv: <double>[55, 60, 62],
      sleepHours: <double>[6.9, 7.2, 7.4],
      steps: <double>[5200, 6100, 4820],
    ),
    this.throwOnRead = false,
    this.gate,
  });

  VitalsReading reading;
  VitalsSeries series;
  bool throwOnRead;

  /// When set, [read] awaits this before returning — lets a test hold the
  /// loading state open.
  Future<void>? gate;

  int reads = 0;

  @override
  Future<VitalsReading> read() async {
    reads++;
    if (gate != null) await gate;
    if (throwOnRead) throw StateError('boom');
    return reading;
  }

  @override
  Future<VitalsSeries> readSeries() async => series;
}

/// Permission gate seeded to granted, so the dashboard child builds directly.
class _GrantedPermission extends VitalsPermissionController {
  @override
  VitalsPermissionState build() =>
      const VitalsPermissionState(status: HealthPermissionStatus.granted);
}

ProviderContainer _container(_FakeReader reader) {
  final container = ProviderContainer(
    // Disable Riverpod 3.x auto-retry so the error path doesn't loop under
    // pumpAndSettle.
    retry: (_, _) => null,
    overrides: [
      vitalsReaderProvider.overrideWithValue(reader),
      vitalsPermissionControllerProvider.overrideWith(_GrantedPermission.new),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  // A tall surface so the whole (lazy) dashboard list builds without scrolling.
  await tester.binding.setSurfaceSize(const Size(1000, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
}

void main() {
  group('Home vitals dashboard', () {
    testWidgets('renders the readiness ring, a card + sparkline per metric',
        (tester) async {
      final container = _container(_FakeReader());
      await _pump(tester, container);
      await tester.pumpAndSettle();

      // Readiness hero + four metric rings.
      expect(find.byType(StatRing), findsNWidgets(5));
      // Each of the four metrics has history → four sparklines.
      expect(find.byType(Sparkline), findsNWidgets(4));

      expect(find.text('Readiness'), findsOneWidget);
      expect(find.text('Resting HR'), findsOneWidget);
      expect(find.text('HRV'), findsOneWidget);
      expect(find.text('Sleep'), findsOneWidget);
      expect(find.text('Steps'), findsOneWidget);

      // Formatted current values.
      expect(find.text('58'), findsOneWidget); // resting HR
      expect(find.text('62'), findsOneWidget); // HRV
      expect(find.text('7.4'), findsOneWidget); // sleep hours
      expect(find.text('4820'), findsOneWidget); // steps
      expect(find.text('67'), findsOneWidget); // computed readiness
    });

    testWidgets('shows a per-metric empty state when a metric is null',
        (tester) async {
      final container = _container(
        _FakeReader(
          reading: const VitalsReading(hrv: 62, sleepHours: 7.4, steps: 4820),
          series: const VitalsSeries(
            hrv: <double>[55, 60, 62],
            sleepHours: <double>[6.9, 7.2, 7.4],
            steps: <double>[5200, 6100, 4820],
          ),
        ),
      );
      await _pump(tester, container);
      await tester.pumpAndSettle();

      // Resting HR not recorded → its own empty state, not a fake zero.
      expect(find.byKey(const Key('vital-empty-resting-hr')), findsOneWidget);
      expect(find.text('No data yet'), findsOneWidget);
      // The other three still show values + sparklines.
      expect(find.byType(Sparkline), findsNWidgets(3));
      expect(find.text('62'), findsOneWidget);
    });

    testWidgets('all metrics empty → dashes and per-metric empty states',
        (tester) async {
      final container = _container(
        _FakeReader(reading: VitalsReading.empty, series: VitalsSeries.empty),
      );
      await _pump(tester, container);
      await tester.pumpAndSettle();

      // No recovery signal → readiness shows an em dash, not a zero.
      expect(find.text('—'), findsOneWidget);
      // Every metric card is in its empty state; no sparklines.
      expect(find.text('No data yet'), findsNWidgets(4));
      expect(find.byType(Sparkline), findsNothing);
    });

    testWidgets('pull-to-refresh re-reads the vitals', (tester) async {
      final reader = _FakeReader();
      final container = _container(reader);
      await _pump(tester, container);
      await tester.pumpAndSettle();
      expect(reader.reads, 1);

      await tester.drag(
        find.byKey(const Key('vitals-dashboard')),
        const Offset(0, 400),
      );
      await tester.pump(); // start the refresh indicator
      await tester.pump(const Duration(seconds: 1)); // let it arm + fire
      await tester.pumpAndSettle();

      expect(reader.reads, 2);
    });

    testWidgets('shows a spinner while the read is in flight', (tester) async {
      final completer = Completer<void>();
      final reader = _FakeReader(gate: completer.future);
      final container = _container(reader);
      await _pump(tester, container);
      await tester.pump(); // build runs; read is still gated

      expect(find.byKey(const Key('vitals-loading')), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vitals-dashboard')), findsOneWidget);
    });

    testWidgets('error state offers a retry that recovers', (tester) async {
      final reader = _FakeReader(throwOnRead: true);
      final container = _container(reader);
      await _pump(tester, container);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vitals-error')), findsOneWidget);

      reader.throwOnRead = false;
      await tester.tap(find.byKey(const Key('vitals-error-retry')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vitals-dashboard')), findsOneWidget);
    });
  });
}
