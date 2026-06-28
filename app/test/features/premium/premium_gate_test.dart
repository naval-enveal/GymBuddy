// PremiumGate reveals its child only when the user is premium; otherwise it
// renders a locked call-to-action that opens the paywall. Premium state comes
// from isPremiumProvider (the client's informational view — the server enforces
// the real gate).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/features/premium/premium_controller.dart';
import 'package:gymbuddy/features/premium/premium_gate.dart';
import 'package:gymbuddy/features/premium/premium_service.dart';

/// Controller seeded into a fixed resolved state so the gate can be asserted
/// without driving a real store read.
class _SeededPremiumController extends PremiumController {
  _SeededPremiumController(this._seed);

  final PremiumState _seed;

  @override
  Future<PremiumState> build() async => _seed;
}

const _child = Text('PREMIUM FEATURE', key: Key('premium-child'));

Future<void> _pumpGate(WidgetTester tester, PremiumStatus status) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        premiumControllerProvider.overrideWith(
          () => _SeededPremiumController(PremiumState(status: status)),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: PremiumGate(child: _child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('reveals the child when premium', (tester) async {
    await _pumpGate(tester, PremiumStatus.premium);

    expect(find.byKey(const Key('premium-child')), findsOneWidget);
    expect(find.byKey(const Key('premium-locked')), findsNothing);
  });

  testWidgets('shows the locked CTA when free', (tester) async {
    await _pumpGate(tester, PremiumStatus.free);

    expect(find.byKey(const Key('premium-child')), findsNothing);
    expect(find.byKey(const Key('premium-locked')), findsOneWidget);
  });

  testWidgets('tapping the locked CTA opens the paywall', (tester) async {
    await _pumpGate(tester, PremiumStatus.free);

    await tester.tap(find.byKey(const Key('premium-locked')));
    await tester.pumpAndSettle();

    // The paywall route is pushed (its close affordance is present).
    expect(find.byKey(const Key('paywall-close')), findsOneWidget);
  });
}
