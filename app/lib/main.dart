import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/analytics/analytics_service.dart';
import 'package:gymbuddy/core/analytics/firebase_analytics_service.dart';
import 'package:gymbuddy/core/design/design.dart';
import 'package:gymbuddy/core/health/health_package_permission_service.dart';
import 'package:gymbuddy/core/health/health_permission_service.dart';
import 'package:gymbuddy/core/health/vitals_reader.dart';
import 'package:gymbuddy/core/network/api_client.dart';
import 'package:gymbuddy/features/auth/auth_controller.dart';
import 'package:gymbuddy/features/auth/auth_gate.dart';
import 'package:gymbuddy/features/premium/premium_service.dart';
import 'package:gymbuddy/features/premium/revenuecat_premium_service.dart';
import 'package:gymbuddy/sensors/sensor_source.dart';
import 'package:gymbuddy/sensors/sensor_source_resolver.dart';

/// The RevenueCat **public** SDK key, injected at build time via
/// `--dart-define=REVENUECAT_API_KEY=...`. This is not a secret (unlike the
/// Claude API key, which never leaves the server). When unset — as in dev/test
/// — the premium service stays the [MockPremiumService] default, so the app and
/// paywall run end to end with no store configured.
const String _revenueCatApiKey =
    String.fromEnvironment('REVENUECAT_API_KEY');

Future<void> main() async {
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
  WidgetsFlutterBinding.ensureInitialized();

  // M10 analytics + crash reporting: try the Firebase-backed service. When
  // Firebase is configured, `configure()` also routes Flutter's uncaught-error
  // hooks straight into Crashlytics and returns a ready service. Otherwise — no
  // Firebase project, or a dev/headless build — it returns null and we keep the
  // [MockAnalyticsService] default, wiring the generic crash handlers onto it so
  // uncaught errors are still observed. Telemetry never blocks startup.
  final firebaseAnalytics = await FirebaseAnalyticsService.configure();
  final AnalyticsService analytics = firebaseAnalytics ?? MockAnalyticsService();
  if (firebaseAnalytics == null) {
    installCrashHandlers(analytics);
  }

  // M7 capability detection: probe the real glasses source once at the
  // composition root and override the (synchronous) sensor provider with
  // whatever it resolves to — the glasses when they're available, otherwise the
  // mock. The session controller reads `workoutSensorSourceProvider` unchanged.
  //
  // M10 glasses release channel: the resolver is gated by `kGlassesChannelEnabled`
  // (`--dart-define=GLASSES_ENABLED=true`). The default consumer build keeps the
  // channel off, so this returns the mock without ever touching the native
  // glasses channel; only the glasses-channel build target opts into the probe.
  final sensorSource = await resolveWorkoutSensorSource();

  // M9 premium: when a RevenueCat public SDK key is provided, configure the SDK
  // and use the real entitlement service; otherwise leave the mock default so
  // dev/test builds and the paywall keep working with no store attached.
  PremiumService? premiumService;
  if (_revenueCatApiKey.isNotEmpty) {
    await RevenueCatPremiumService.configure(apiKey: _revenueCatApiKey);
    premiumService = RevenueCatPremiumService();
  }

  runApp(
    ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(analytics),
        if (premiumService != null)
          premiumServiceProvider.overrideWithValue(premiumService),
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
        workoutSensorSourceProvider.overrideWith((ref) {
          ref.onDispose(sensorSource.dispose);
          return sensorSource;
        }),
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
