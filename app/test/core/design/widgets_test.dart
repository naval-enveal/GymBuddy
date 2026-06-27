// Behavior tests for the design-system widgets. These assert what the widgets
// actually do — fire callbacks, gate taps while loading, format values, clamp
// out-of-range input — rather than just that they render.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gymbuddy/core/design/design.dart';

/// Wraps a widget in the app theme + a Scaffold so styles resolve as they do in
/// the real app.
Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('PrimaryButton', () {
    testWidgets('renders its label and fires onPressed when tapped',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          PrimaryButton(
            label: 'Start workout',
            onPressed: () => taps++,
          ),
        ),
      );

      expect(find.text('Start workout'), findsOneWidget);
      await tester.tap(find.byType(PrimaryButton));
      expect(taps, 1);
    });

    testWidgets('is disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(
        _host(const PrimaryButton(label: 'Disabled', onPressed: null)),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('while loading, shows a spinner and ignores taps',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          PrimaryButton(
            label: 'Submitting',
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The label is replaced by the spinner while loading.
      expect(find.text('Submitting'), findsNothing);
      await tester.tap(find.byType(PrimaryButton));
      expect(taps, 0);
    });
  });

  group('MetricTile', () {
    testWidgets('renders label, value, and unit', (tester) async {
      await tester.pumpWidget(
        _host(
          const MetricTile(label: 'Resting HR', value: '58', unit: 'bpm'),
        ),
      );

      expect(find.text('Resting HR'), findsOneWidget);
      expect(find.text('58'), findsOneWidget);
      expect(find.text('bpm'), findsOneWidget);
    });

    testWidgets('omits the unit when none is given', (tester) async {
      await tester.pumpWidget(
        _host(const MetricTile(label: 'Steps', value: '8,420')),
      );

      expect(find.text('8,420'), findsOneWidget);
    });
  });

  group('StatRing', () {
    testWidgets('renders its center value and label', (tester) async {
      await tester.pumpWidget(
        _host(
          const StatRing(progress: 0.5, value: '82', label: 'Readiness'),
        ),
      );

      expect(find.text('82'), findsOneWidget);
      expect(find.text('Readiness'), findsOneWidget);
    });

    testWidgets('accepts out-of-range progress without throwing',
        (tester) async {
      // Over- and under-shoot are clamped internally; the build must not throw.
      await tester.pumpWidget(_host(const StatRing(progress: 1.8)));
      await tester.pumpWidget(_host(const StatRing(progress: -0.5)));
      expect(tester.takeException(), isNull);
    });
  });

  group('RepCounter', () {
    testWidgets('shows the rep count and target', (tester) async {
      await tester.pumpWidget(_host(const RepCounter(reps: 8, target: 12)));

      expect(find.text('8'), findsOneWidget);
      expect(find.text(' / 12'), findsOneWidget);
    });

    testWidgets('omits the target divider when none is given', (tester) async {
      await tester.pumpWidget(_host(const RepCounter(reps: 5)));

      expect(find.text('5'), findsOneWidget);
      expect(find.textContaining('/'), findsNothing);
    });
  });

  group('RestTimer', () {
    testWidgets('formats remaining time as m:ss', (tester) async {
      await tester.pumpWidget(
        _host(
          const RestTimer(
            remaining: Duration(seconds: 65),
            total: Duration(seconds: 90),
          ),
        ),
      );

      expect(find.text('1:05'), findsOneWidget);
    });

    testWidgets('clamps a negative remaining to 0:00', (tester) async {
      await tester.pumpWidget(
        _host(
          const RestTimer(
            remaining: Duration(seconds: -3),
            total: Duration(seconds: 90),
          ),
        ),
      );

      expect(find.text('0:00'), findsOneWidget);
    });

    testWidgets('handles a zero total without dividing by zero',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const RestTimer(remaining: Duration.zero, total: Duration.zero),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('0:00'), findsOneWidget);
    });
  });

  group('Sparkline', () {
    testWidgets('renders a multi-point series without error', (tester) async {
      await tester.pumpWidget(
        _host(const Sparkline(values: [1, 4, 2, 8, 5])),
      );

      expect(find.byType(Sparkline), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles fewer than two points without error', (tester) async {
      await tester.pumpWidget(_host(const Sparkline(values: [5])));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_host(const Sparkline(values: [])));
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles a constant series without dividing by zero',
        (tester) async {
      await tester.pumpWidget(
        _host(const Sparkline(values: [7, 7, 7, 7])),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
