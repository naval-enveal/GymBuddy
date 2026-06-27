import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/health/health_permission_service.dart';

/// The vitals dashboard's view of health-data access.
///
/// [status] is the last known [HealthPermissionStatus] (it starts
/// [HealthPermissionStatus.notRequested] — the dashboard hasn't asked yet);
/// [requesting] is a transient in-flight flag set while a prompt is awaiting the
/// user, so the UI can show a spinner and block a second tap.
class VitalsPermissionState {
  const VitalsPermissionState({
    this.status = HealthPermissionStatus.notRequested,
    this.requesting = false,
  });

  /// The last resolved health-permission status.
  final HealthPermissionStatus status;

  /// Whether a permission prompt is currently in flight.
  final bool requesting;

  /// Whether the dashboard can read vitals — i.e. access has been granted.
  bool get isGranted => status == HealthPermissionStatus.granted;

  VitalsPermissionState copyWith({
    HealthPermissionStatus? status,
    bool? requesting,
  }) {
    return VitalsPermissionState(
      status: status ?? this.status,
      requesting: requesting ?? this.requesting,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VitalsPermissionState &&
      other.status == status &&
      other.requesting == requesting;

  @override
  int get hashCode => Object.hash(status, requesting);
}

/// Owns the vitals dashboard's health-permission state, on top of the real
/// [healthPermissionServiceProvider] (HealthKit / Health Connect, overridden in
/// at the composition root; the mock stays the default for tests + hardware-free
/// dev).
///
/// The dashboard starts at [HealthPermissionStatus.notRequested] and prompts
/// only when the user opts in (via [request]) — Home doesn't fire a platform
/// dialog the moment it loads. Whatever the outcome, the reads keep working: a
/// `denied` / `unavailable` result leaves the dashboard in a graceful
/// locked/empty state rather than blocking the app, per the mock-first posture
/// the rest of the app takes. All I/O lives here, never in the widgets.
class VitalsPermissionController extends Notifier<VitalsPermissionState> {
  @override
  VitalsPermissionState build() => const VitalsPermissionState();

  /// Prompts for read access and records the outcome. A no-op if a request is
  /// already in flight (so a double-tap can't fire two platform prompts). The
  /// in-flight flag is always cleared, even if the service throws — though the
  /// service contract degrades platform failures to
  /// [HealthPermissionStatus.unavailable] rather than throwing.
  Future<void> request() async {
    if (state.requesting) return;
    state = state.copyWith(requesting: true);
    try {
      final status = await ref.read(healthPermissionServiceProvider).request();
      state = VitalsPermissionState(status: status);
    } catch (_) {
      // Defensive: the service is contracted not to throw, but never leave the
      // UI stuck in a spinner if it does — fall back to unavailable.
      state = const VitalsPermissionState(
        status: HealthPermissionStatus.unavailable,
      );
    }
  }
}

/// The vitals dashboard's health-permission state. See
/// [VitalsPermissionController].
final vitalsPermissionControllerProvider =
    NotifierProvider<VitalsPermissionController, VitalsPermissionState>(
  VitalsPermissionController.new,
);
