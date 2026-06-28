import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/design/design.dart';
import 'package:gymbuddy/features/premium/paywall_screen.dart';
import 'package:gymbuddy/features/premium/premium_controller.dart';

/// Pushes the [PaywallScreen] as a full-screen route. The single entry point to
/// the paywall, shared by [PremiumGate] and any premium-only affordance.
Future<void> openPaywall(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const PaywallScreen()),
  );
}

/// Gates a premium-only entry point (e.g. AI plan generation, AI coaching)
/// behind the paywall.
///
/// Reveals [child] only when the user is premium; otherwise it renders a locked
/// call-to-action that opens the [PaywallScreen]. Premium state comes from
/// [isPremiumProvider] (the client's informational view — the server enforces
/// the real gate). Mirrors `VitalsPermissionGate`: the gate, not the gated
/// feature, drives unlocking.
class PremiumGate extends ConsumerWidget {
  const PremiumGate({
    required this.child,
    this.lockedLabel = 'Unlock with Premium',
    super.key,
  });

  /// The premium-only content, shown once entitlement is active.
  final Widget child;

  /// Label for the locked call-to-action.
  final String lockedLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isPremiumProvider)) return child;
    return PrimaryButton(
      key: const Key('premium-locked'),
      label: lockedLabel,
      icon: Icons.lock_outline,
      onPressed: () => openPaywall(context),
    );
  }
}
