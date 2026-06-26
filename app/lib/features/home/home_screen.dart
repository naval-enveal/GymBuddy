import 'package:flutter/material.dart';

import 'package:gymbuddy/features/shell/coming_soon.dart';

/// Home tab — the dashboard. Vitals rings + sparklines land in M5.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoon(title: 'Home', icon: Icons.home_outlined);
  }
}
