import 'package:flutter/material.dart';

void main() {
  runApp(const GymBuddyApp());
}

/// Root application widget.
///
/// Intentionally minimal for M0: it proves the app boots and renders a frame.
/// The design system, Riverpod scope, routing, and feature screens are layered
/// on in later milestones (see docs/PLAN.md).
class GymBuddyApp extends StatelessWidget {
  const GymBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymBuddy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5A0),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const BootScreen(),
    );
  }
}

/// Placeholder landing screen shown until the app shell ships in M2.
class BootScreen extends StatelessWidget {
  const BootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            Text('GymBuddy', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Your AI training buddy',
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
