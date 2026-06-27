import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/design/design.dart';
import 'package:gymbuddy/core/health/health_permission_service.dart';
import 'package:gymbuddy/features/vitals/vitals_permission_controller.dart';

/// Gates the vitals dashboard on health-data access.
///
/// Renders [child] (the live dashboard — StatRings + sparklines land in the
/// following M5 task) only once access is granted. Otherwise it surfaces a
/// graceful locked state for each non-granted outcome — un-asked, declined, or
/// no health store on the device — each offering the user a way to connect (or
/// retry). The dashboard never blocks the app: declining just leaves vitals
/// locked, exactly the empty-state posture the rest of the app takes when a
/// dependency (hardware, network) is absent.
///
/// All permission I/O lives in [vitalsPermissionControllerProvider]; this widget
/// only renders the resulting state and forwards the connect tap.
class VitalsPermissionGate extends ConsumerWidget {
  const VitalsPermissionGate({required this.child, super.key});

  /// The granted-state content — the live vitals dashboard.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vitalsPermissionControllerProvider);
    void request() =>
        ref.read(vitalsPermissionControllerProvider.notifier).request();

    switch (state.status) {
      case HealthPermissionStatus.granted:
        return child;
      case HealthPermissionStatus.notRequested:
        return _VitalsLocked(
          key: const Key('vitals-permission-prompt'),
          icon: Icons.favorite_outline,
          title: 'Connect your health data',
          body: 'GymBuddy reads your resting heart rate, HRV, sleep, and '
              'steps to gauge how recovered you are. It only ever reads — '
              'nothing is written back.',
          actionLabel: 'Connect health data',
          requesting: state.requesting,
          onAction: request,
        );
      case HealthPermissionStatus.denied:
        return _VitalsLocked(
          key: const Key('vitals-permission-denied'),
          icon: Icons.lock_outline,
          title: 'Health access is off',
          body: "Your vitals stay empty until you grant read access. You can "
              'connect any time — the rest of GymBuddy works without it.',
          actionLabel: 'Try again',
          requesting: state.requesting,
          onAction: request,
        );
      case HealthPermissionStatus.unavailable:
        return _VitalsLocked(
          key: const Key('vitals-permission-unavailable'),
          icon: Icons.heart_broken_outlined,
          title: 'No health data on this device',
          body: 'There’s no health store available here, so vitals can’t be '
              'shown. Everything else in GymBuddy still works.',
          // Still offer a retry: the store may become reachable later (e.g.
          // Health Connect installed) without restarting the app.
          actionLabel: 'Check again',
          requesting: state.requesting,
          onAction: request,
        );
    }
  }
}

/// The shared locked-state layout for every non-granted permission outcome: an
/// icon, an explanation, and a single connect/retry action.
class _VitalsLocked extends StatelessWidget {
  const _VitalsLocked({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.requesting,
    required this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final bool requesting;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              key: const Key('vitals-permission-action'),
              label: actionLabel,
              icon: Icons.health_and_safety_outlined,
              isLoading: requesting,
              onPressed: onAction,
            ),
          ],
        ),
      ),
    );
  }
}
