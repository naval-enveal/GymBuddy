import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The outcome of asking the platform for read access to the user's health
/// data (resting HR, HRV, sleep, steps — surfaced by the M5 vitals dashboard).
enum HealthPermissionStatus {
  /// Not asked yet — the onboarding step's starting state.
  notRequested,

  /// The user granted read access.
  granted,

  /// The user declined. The app keeps working; vitals features fall back to
  /// empty states (wired in M5).
  denied,

  /// Health data isn't available on this device/platform at all.
  unavailable,
}

/// Abstraction over the platform health-data permission prompt.
///
/// Feature code (the onboarding flow here, the M5 vitals dashboard later) never
/// talks to HealthKit / Health Connect directly — it goes through this
/// interface, the same way sensor features go through `WorkoutSensorSource`.
/// The real HealthKit / Health Connect implementations land in M5 (the `health`
/// package); until then [MockHealthPermissionService] keeps the flow working
/// with no platform integration, per the mock-first rule.
abstract interface class HealthPermissionService {
  /// Prompts the user for read access and resolves to the resulting status.
  Future<HealthPermissionStatus> request();
}

/// Default, integration-free implementation used until M5 wires the real
/// `health` package. Grants immediately so the onboarding flow and dev builds
/// work end to end with no platform health store attached — mirroring how
/// `MockSensorSource` lets rep/form features run with no glasses present.
class MockHealthPermissionService implements HealthPermissionService {
  const MockHealthPermissionService();

  @override
  Future<HealthPermissionStatus> request() async =>
      HealthPermissionStatus.granted;
}

/// The app's health-permission service. Overridden in M5 with the HealthKit /
/// Health Connect implementations; defaults to [MockHealthPermissionService]
/// so feature code and tests have a working dependency today.
final healthPermissionServiceProvider = Provider<HealthPermissionService>(
  (ref) => const MockHealthPermissionService(),
);
