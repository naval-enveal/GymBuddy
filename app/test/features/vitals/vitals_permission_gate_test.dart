import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/health/health_permission_service.dart';
import 'package:gymbuddy/features/vitals/vitals_permission_controller.dart';
import 'package:gymbuddy/features/vitals/vitals_permission_gate.dart';

/// Fake service the gate's connect action drives through.
class _FakeHealthPermissionService implements HealthPermissionService {
  _FakeHealthPermissionService(this.result);

  HealthPermissionStatus result;

  @override
  Future<HealthPermissionStatus> request() async => result;
}

/// Controller seeded into a fixed state so each locked layout can be asserted
/// without driving a request first.
class _SeededController extends VitalsPermissionController {
  _SeededController(this._seed);

  final VitalsPermissionState _seed;

  @override
  VitalsPermissionState build() => _seed;
}

const _child = Text('LIVE DASHBOARD', key: Key('vitals-dashboard'));

/// Pumps the gate, seeding either a fixed controller state ([seed]) or a fake
/// service the connect action drives through ([service]). The overrides list is
/// built inline — Riverpod's `Override` type isn't part of its public API, so it
/// can't be named in a helper signature.
Future<void> _pumpGate(
  WidgetTester tester, {
  VitalsPermissionState? seed,
  HealthPermissionService? service,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (seed != null)
          vitalsPermissionControllerProvider.overrideWith(
            () => _SeededController(seed),
          ),
        if (service != null)
          healthPermissionServiceProvider.overrideWithValue(service),
      ],
      child: const MaterialApp(
        home: Scaffold(body: VitalsPermissionGate(child: _child)),
      ),
    ),
  );
}

void main() {
  group('VitalsPermissionGate', () {
    testWidgets('shows the connect prompt when not yet requested',
        (tester) async {
      await _pumpGate(
        tester,
        seed: const VitalsPermissionState(),
      );

      expect(find.byKey(const Key('vitals-permission-prompt')), findsOneWidget);
      expect(find.byKey(const Key('vitals-dashboard')), findsNothing);
      expect(find.byKey(const Key('vitals-permission-action')), findsOneWidget);
    });

    testWidgets('shows the denied state with a retry', (tester) async {
      await _pumpGate(
        tester,
        seed: const VitalsPermissionState(
          status: HealthPermissionStatus.denied,
        ),
      );

      expect(find.byKey(const Key('vitals-permission-denied')), findsOneWidget);
      expect(find.byKey(const Key('vitals-dashboard')), findsNothing);
    });

    testWidgets('shows the unavailable state', (tester) async {
      await _pumpGate(
        tester,
        seed: const VitalsPermissionState(
          status: HealthPermissionStatus.unavailable,
        ),
      );

      expect(
        find.byKey(const Key('vitals-permission-unavailable')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('vitals-dashboard')), findsNothing);
    });

    testWidgets('reveals the dashboard once granted', (tester) async {
      await _pumpGate(
        tester,
        seed: const VitalsPermissionState(
          status: HealthPermissionStatus.granted,
        ),
      );

      expect(find.byKey(const Key('vitals-dashboard')), findsOneWidget);
      expect(find.byKey(const Key('vitals-permission-prompt')), findsNothing);
    });

    testWidgets('tapping connect requests and reveals the dashboard on grant',
        (tester) async {
      await _pumpGate(
        tester,
        service: _FakeHealthPermissionService(HealthPermissionStatus.granted),
      );

      // Starts on the prompt.
      expect(find.byKey(const Key('vitals-permission-prompt')), findsOneWidget);

      await tester.tap(find.byKey(const Key('vitals-permission-action')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vitals-dashboard')), findsOneWidget);
    });

    testWidgets('a declined request leaves the dashboard locked',
        (tester) async {
      await _pumpGate(
        tester,
        service: _FakeHealthPermissionService(HealthPermissionStatus.denied),
      );

      await tester.tap(find.byKey(const Key('vitals-permission-action')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vitals-permission-denied')), findsOneWidget);
      expect(find.byKey(const Key('vitals-dashboard')), findsNothing);
    });
  });
}
