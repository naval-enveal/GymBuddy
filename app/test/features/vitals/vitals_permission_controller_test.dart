import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/health/health_permission_service.dart';
import 'package:gymbuddy/features/vitals/vitals_permission_controller.dart';

/// Hand fake over [HealthPermissionService] so the controller's state
/// transitions are tested without any platform health store.
class _FakeHealthPermissionService implements HealthPermissionService {
  _FakeHealthPermissionService(this._result);

  final HealthPermissionStatus _result;
  int calls = 0;

  /// When non-null, [request] awaits this before resolving — lets a test pin the
  /// in-flight (`requesting`) state.
  Completer<void>? gate;

  @override
  Future<HealthPermissionStatus> request() async {
    calls++;
    if (gate != null) await gate!.future;
    return _result;
  }
}

ProviderContainer _containerWith(_FakeHealthPermissionService service) {
  final container = ProviderContainer(
    overrides: [
      healthPermissionServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('VitalsPermissionController', () {
    test('starts notRequested and not in flight', () {
      final container =
          _containerWith(_FakeHealthPermissionService(
        HealthPermissionStatus.granted,
      ));

      final state = container.read(vitalsPermissionControllerProvider);
      expect(state.status, HealthPermissionStatus.notRequested);
      expect(state.requesting, isFalse);
      expect(state.isGranted, isFalse);
    });

    test('request records a granted outcome and clears the in-flight flag',
        () async {
      final service =
          _FakeHealthPermissionService(HealthPermissionStatus.granted);
      final container = _containerWith(service);

      await container
          .read(vitalsPermissionControllerProvider.notifier)
          .request();

      final state = container.read(vitalsPermissionControllerProvider);
      expect(state.status, HealthPermissionStatus.granted);
      expect(state.isGranted, isTrue);
      expect(state.requesting, isFalse);
    });

    test('request records a denied outcome', () async {
      final service =
          _FakeHealthPermissionService(HealthPermissionStatus.denied);
      final container = _containerWith(service);

      await container
          .read(vitalsPermissionControllerProvider.notifier)
          .request();

      final state = container.read(vitalsPermissionControllerProvider);
      expect(state.status, HealthPermissionStatus.denied);
      expect(state.isGranted, isFalse);
      expect(state.requesting, isFalse);
    });

    test('request records an unavailable outcome', () async {
      final service =
          _FakeHealthPermissionService(HealthPermissionStatus.unavailable);
      final container = _containerWith(service);

      await container
          .read(vitalsPermissionControllerProvider.notifier)
          .request();

      expect(
        container.read(vitalsPermissionControllerProvider).status,
        HealthPermissionStatus.unavailable,
      );
    });

    test('sets requesting while the prompt is in flight', () async {
      final service =
          _FakeHealthPermissionService(HealthPermissionStatus.granted)
            ..gate = Completer<void>();
      final container = _containerWith(service);

      final future = container
          .read(vitalsPermissionControllerProvider.notifier)
          .request();

      // The prompt is awaiting the user: requesting is true, status unchanged.
      final inFlight = container.read(vitalsPermissionControllerProvider);
      expect(inFlight.requesting, isTrue);
      expect(inFlight.status, HealthPermissionStatus.notRequested);

      service.gate!.complete();
      await future;

      final done = container.read(vitalsPermissionControllerProvider);
      expect(done.requesting, isFalse);
      expect(done.status, HealthPermissionStatus.granted);
    });

    test('ignores a second request while one is already in flight', () async {
      final service =
          _FakeHealthPermissionService(HealthPermissionStatus.granted)
            ..gate = Completer<void>();
      final container = _containerWith(service);
      final notifier =
          container.read(vitalsPermissionControllerProvider.notifier);

      final first = notifier.request();
      await notifier.request(); // no-op: a request is in flight

      expect(service.calls, 1);

      service.gate!.complete();
      await first;
    });
  });
}
