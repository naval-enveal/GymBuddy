import 'package:flutter/material.dart';

import 'package:gymbuddy/features/shell/coming_soon.dart';

/// Workout tab — the session engine and focus mode. Built out in M6.
class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoon(
      title: 'Workout',
      icon: Icons.fitness_center_outlined,
    );
  }
}
