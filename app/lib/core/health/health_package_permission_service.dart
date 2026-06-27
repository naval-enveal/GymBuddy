import 'package:flutter/foundation.dart';

import 'package:gymbuddy/core/health/health_data_types.dart';
import 'package:gymbuddy/core/health/health_permission_service.dart';
import 'package:health/health.dart';

/// Minimal seam over the `health` package's [Health] plugin — only the calls the
/// permission flow needs. Wrapping it keeps [HealthPackagePermissionService]
/// unit-testable without the platform method channel (which isn't present under
/// `flutter test`), the same hand-fake approach the rest of the app uses for
/// platform dependencies.
abstract interface class HealthClient {
  /// Configures the plugin. Must run before any other call.
  Future<void> configure();

  /// Whether a health store is usable on this device. On Android this means
  /// Google Health Connect is installed and available; on iOS HealthKit is
  /// assumed present (the package returns `true`).
  Future<bool> isAvailable();

  /// Requests READ access to [types]. Returns `true` only if the request
  /// completed with every type granted.
  Future<bool> requestReadAuthorization(List<HealthDataType> types);
}

/// Production [HealthClient] backed by the real `health` package, talking to
/// HealthKit (iOS) / Health Connect (Android) over the plugin's method channel.
class LiveHealthClient implements HealthClient {
  LiveHealthClient([Health? health]) : _health = health ?? Health();

  final Health _health;

  @override
  Future<void> configure() => _health.configure();

  @override
  Future<bool> isAvailable() => _health.isHealthConnectAvailable();

  @override
  Future<bool> requestReadAuthorization(List<HealthDataType> types) =>
      _health.requestAuthorization(
        types,
        permissions: List<HealthDataAccess>.filled(
          types.length,
          HealthDataAccess.READ,
        ),
      );
}

/// Real [HealthPermissionService] backed by HealthKit (iOS) / Health Connect
/// (Android) via the `health` package.
///
/// Wired in at the composition root (`main.dart`); the
/// [MockHealthPermissionService] stays the provider default so tests and
/// hardware-free dev builds keep working with no platform health store attached.
/// It requests READ access to exactly [vitalsHealthTypes] — the metrics the M5
/// vitals dashboard reads.
class HealthPackagePermissionService implements HealthPermissionService {
  HealthPackagePermissionService({HealthClient? client})
      : _client = client ?? LiveHealthClient();

  final HealthClient _client;

  @override
  Future<HealthPermissionStatus> request() async {
    try {
      await _client.configure();
      if (!await _client.isAvailable()) {
        return HealthPermissionStatus.unavailable;
      }
      final granted =
          await _client.requestReadAuthorization(vitalsHealthTypes());
      return granted
          ? HealthPermissionStatus.granted
          : HealthPermissionStatus.denied;
    } catch (error, stackTrace) {
      // No reachable platform health store (e.g. a simulator without HealthKit,
      // Health Connect missing, or the method channel absent). Degrade to
      // "unavailable" rather than crashing the flow — the same graceful,
      // mock-first posture the sensor layer takes when no hardware is present.
      debugPrint('HealthPackagePermissionService.request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return HealthPermissionStatus.unavailable;
    }
  }
}
