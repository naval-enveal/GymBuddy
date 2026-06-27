import 'package:flutter/material.dart';

import 'package:gymbuddy/core/design/design.dart';
import 'package:gymbuddy/features/vitals/vitals_permission_gate.dart';

/// Home tab — the vitals dashboard.
///
/// Access to health data is gated by [VitalsPermissionGate]: until the user
/// connects, Home shows the graceful locked state; once granted it renders the
/// dashboard. The live StatRings + sparklines land in the next M5 task — for now
/// the granted state is a placeholder so the permission flow is wired end to end.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const SafeArea(
        child: VitalsPermissionGate(
          child: _VitalsDashboardPlaceholder(),
        ),
      ),
    );
  }
}

/// Granted-state placeholder. Replaced by the StatRings + sparklines dashboard
/// in the following M5 task; present now so the permission gate has live content
/// to reveal.
class _VitalsDashboardPlaceholder extends StatelessWidget {
  const _VitalsDashboardPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      key: const Key('vitals-dashboard'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.favorite,
              size: 56,
              color: AppColors.accent,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Health data connected',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your vitals dashboard appears here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
