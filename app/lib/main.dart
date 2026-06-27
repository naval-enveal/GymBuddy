import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/design/design.dart';
import 'package:gymbuddy/core/health/health_package_permission_service.dart';
import 'package:gymbuddy/core/health/health_permission_service.dart';
import 'package:gymbuddy/core/health/vitals_reader.dart';
import 'package:gymbuddy/core/network/api_client.dart';
import 'package:gymbuddy/features/auth/auth_controller.dart';
import 'package:gymbuddy/features/auth/auth_gate.dart';

void main() {
  // ProviderScope is the root of Riverpod's state graph; every provider read in
  // the app resolves against it. Wiring it here (M0) lets later milestones add
  // providers without touching bootstrap.
  //
  // The session-expiry hook is overridden here (composition root) so `core/`
  // network code can sign the user out without an upward dependency on the auth
  // feature: a dead refresh token drives the gate back to the signed-out flow.
  //
  // The health-permission service and vitals reader are overridden to the real
  // HealthKit / Health Connect implementations here too; both providers default
  // to mocks so tests and hardware-free dev builds keep working untouched.
  runApp(
    ProviderScope(
      overrides: [
        sessionExpiredProvider.overrideWith(
          (ref) =>
              () => ref.read(authControllerProvider.notifier).signOut(),
        ),
        healthPermissionServiceProvider.overrideWithValue(
          HealthPackagePermissionService(),
        ),
        vitalsReaderProvider.overrideWithValue(
          HealthPackageVitalsReader(),
        ),
      ],
      child: const GymBuddyApp(),
    ),
  );
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
