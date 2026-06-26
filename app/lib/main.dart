import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/app_info.dart';
import 'package:gymbuddy/core/design/design.dart';

void main() {
  // ProviderScope is the root of Riverpod's state graph; every provider read in
  // the app resolves against it. Wiring it here (M0) lets later milestones add
  // providers without touching bootstrap.
  runApp(const ProviderScope(child: GymBuddyApp()));
}

/// Root application widget.
///
/// Intentionally minimal for M0: it proves the app boots and renders a frame.
/// The design system, routing, and feature screens are layered on in later
/// milestones (see docs/PLAN.md).
class GymBuddyApp extends StatelessWidget {
  const GymBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymBuddy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const BootScreen(),
    );
  }
}

/// Placeholder landing screen shown until the app shell ships in M2.
///
/// A [ConsumerWidget] so it can read [appInfoProvider] — the first consumer of
/// Riverpod state in the app.
class BootScreen extends ConsumerWidget {
  const BootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appInfo = ref.watch(appInfoProvider);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fitness_center,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(appInfo.name, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              appInfo.tagline,
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
