import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/design/design.dart';
import 'package:gymbuddy/features/auth/auth_gate.dart';

void main() {
  // ProviderScope is the root of Riverpod's state graph; every provider read in
  // the app resolves against it. Wiring it here (M0) lets later milestones add
  // providers without touching bootstrap.
  runApp(const ProviderScope(child: GymBuddyApp()));
}

/// Root application widget.
///
/// Boots straight into the [AuthGate], which decides between the signed-out
/// flow and the authenticated app shell. Routing and feature screens are
/// layered on from there (see docs/PLAN.md).
class GymBuddyApp extends StatelessWidget {
  const GymBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymBuddy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AuthGate(),
    );
  }
}
