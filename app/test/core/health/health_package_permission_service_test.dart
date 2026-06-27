import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/health/health_package_permission_service.dart';
import 'package:gymbuddy/core/health/health_permission_service.dart';
import 'package:health/health.dart';

/// Hand fake over the [HealthClient] seam so the service's status mapping is
/// tested without the platform method channel (absent under `flutter test`).
class _FakeHealthClient implements HealthClient {
  _FakeHealthClient({
    this.available = true,
    this.granted = true,
    this.throwOn,
  });

  bool available;
  bool granted;

  /// Which call should throw, if any: 'configure' | 'isAvailable' | 'request'.
  String? throwOn;

  bool configured = false;
  List<HealthDataType>? requestedTypes;

  @override
  Future<void> configure() async {
    if (throwOn == 'configure') throw StateError('configure failed');
    configured = true;
  }

  @override
  Future<bool> isAvailable() async {
    if (throwOn == 'isAvailable') throw StateError('availability failed');
    return available;
  }

  @override
  Future<bool> requestReadAuthorization(List<HealthDataType> types) async {
    if (throwOn == 'request') throw StateError('request failed');
    requestedTypes = types;
    return granted;
  }
}

void main() {
  group('HealthPackagePermissionService', () {
    test('granted when the store is available and access is granted', () async {
      final client = _FakeHealthClient(available: true, granted: true);
      final service = HealthPackagePermissionService(client: client);

      expect(await service.request(), HealthPermissionStatus.granted);
      expect(client.configured, isTrue);
    });

    test('denied when available but the user declines', () async {
      final client = _FakeHealthClient(available: true, granted: false);
      final service = HealthPackagePermissionService(client: client);

      expect(await service.request(), HealthPermissionStatus.denied);
    });

    test('unavailable when no health store is present', () async {
      final client = _FakeHealthClient(available: false);
      final service = HealthPackagePermissionService(client: client);

      expect(await service.request(), HealthPermissionStatus.unavailable);
      // Never reaches the authorization prompt if the store is unavailable.
      expect(client.requestedTypes, isNull);
    });

    test('requests read access to the vitals types', () async {
      final client = _FakeHealthClient();
      final service = HealthPackagePermissionService(client: client);

      await service.request();

      expect(client.requestedTypes, isNotNull);
      expect(
        client.requestedTypes,
        contains(HealthDataType.RESTING_HEART_RATE),
      );
      expect(client.requestedTypes, contains(HealthDataType.STEPS));
      expect(client.requestedTypes, contains(HealthDataType.SLEEP_ASLEEP));
    });

    test('degrades to unavailable when the platform call throws', () async {
      for (final stage in <String>['configure', 'isAvailable', 'request']) {
        final client = _FakeHealthClient(throwOn: stage);
        final service = HealthPackagePermissionService(client: client);

        expect(
          await service.request(),
          HealthPermissionStatus.unavailable,
          reason: 'a throw at "$stage" should not crash the flow',
        );
      }
    });
  });
}
