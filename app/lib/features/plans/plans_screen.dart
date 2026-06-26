import 'package:flutter/material.dart';

import 'package:gymbuddy/features/shell/coming_soon.dart';

/// Plans tab — the workout-plan library and active plan. Built out in M4.
class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoon(title: 'Plans', icon: Icons.list_alt_outlined);
  }
}
