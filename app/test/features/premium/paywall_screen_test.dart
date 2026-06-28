// PaywallScreen renders the premiumControllerProvider state: a spinner while
// loading, a retryable error, the upsell with purchase options, or (once
// premium) a confirmation. Purchase/restore I/O lives in the controller; the
// widget only renders state and forwards taps.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/features/premium/paywall_screen.dart';
import 'package:gymbuddy/features/premium/premium_controller.dart';
import 'package:gymbuddy/features/premium/premium_service.dart';

/// A service with no offerings — exercises the "purchases unavailable" path.
class _EmptyOfferingService implements PremiumService {
  @override
  Future<PremiumStatus> current() async => PremiumStatus.free;

  @override
  Future<PremiumOffering> offering() async => PremiumOffering.empty;

  @override
  Future<PremiumStatus> purchase(String packageId) async =>
      PremiumStatus.free;

  @override
  Future<PremiumStatus> restore() async => PremiumStatus.premium;
}

/// Controller seeded into a fixed resolved/errored state.
class _SeededController extends PremiumController {
  _SeededController(this._build);

  final Future<PremiumState> Function() _build;

  @override
  Future<PremiumState> build() => _build();
}

/// Pumps the paywall, overriding either the backing [service] (the real
/// controller then drives through it) or seeding the controller's [build]
/// directly. The overrides list is built inline — Riverpod's `Override` type
/// isn't part of its public API, so it can't be named in a helper signature.
Future<void> _pump(
  WidgetTester tester, {
  PremiumService? service,
  Future<PremiumState> Function()? build,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (service != null)
          premiumServiceProvider.overrideWithValue(service),
        if (build != null)
          premiumControllerProvider.overrideWith(
            () => _SeededController(build),
          ),
      ],
      child: const MaterialApp(home: PaywallScreen()),
    ),
  );
}

void main() {
  testWidgets('renders the upsell with purchase options for a free user',
      (tester) async {
    await _pump(tester, service: MockPremiumService());
    await tester.pumpAndSettle();

    expect(find.text('Train with your AI buddy'), findsOneWidget);
    expect(find.byKey(const Key('paywall-package-monthly')), findsOneWidget);
    expect(find.byKey(const Key('paywall-package-annual')), findsOneWidget);
    expect(find.byKey(const Key('paywall-restore')), findsOneWidget);
  });

  testWidgets('buying a package unlocks the premium confirmation',
      (tester) async {
    await _pump(tester, service: MockPremiumService());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('paywall-package-monthly')));
    await tester.pumpAndSettle();

    // The mock flips to premium, so the confirmation replaces the offer.
    expect(find.byKey(const Key('paywall-active')), findsOneWidget);
    expect(find.byKey(const Key('paywall-package-monthly')), findsNothing);
  });

  testWidgets('shows the unavailable message + restore when no offerings load',
      (tester) async {
    await _pump(tester, service: _EmptyOfferingService());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('paywall-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('paywall-package-monthly')), findsNothing);
    expect(find.byKey(const Key('paywall-restore')), findsOneWidget);
  });

  testWidgets('renders the active confirmation when already premium',
      (tester) async {
    await _pump(
      tester,
      build: () async => const PremiumState(status: PremiumStatus.premium),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('paywall-active')), findsOneWidget);
  });

  testWidgets('shows a retry when entitlement fails to load', (tester) async {
    await _pump(tester, build: () => Future.error(Exception('offline')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('paywall-retry')), findsOneWidget);
  });
}
