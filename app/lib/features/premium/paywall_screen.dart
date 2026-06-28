import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/design/design.dart';
import 'package:gymbuddy/features/premium/premium_controller.dart';

/// The GymBuddy Premium paywall.
///
/// Pushed when a free user reaches a premium-only entry point (see
/// [PremiumGate]). Renders the [premiumControllerProvider] state — a spinner
/// while entitlement/offering load, a retryable error, the premium upsell with
/// purchase options, or (once premium) a confirmation. All purchase/restore I/O
/// lives in the controller; this widget only renders state and forwards taps.
///
/// Entitlement shown here is informational; the server independently enforces
/// premium gating (M9 task 4), so unlocking here is a UX affordance, not the
/// security boundary.
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(premiumControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('GymBuddy Premium'),
        leading: IconButton(
          key: const Key('paywall-close'),
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: premium.when(
          loading: () => const Center(
            child: CircularProgressIndicator(key: Key('paywall-loading')),
          ),
          error: (_, _) => _PaywallError(
            onRetry: () =>
                ref.read(premiumControllerProvider.notifier).refresh(),
          ),
          data: (state) => state.isPremium
              ? const _PremiumActive()
              : _PaywallOffer(state: state),
        ),
      ),
    );
  }
}

/// The upsell: benefits, purchase options, and a restore action.
class _PaywallOffer extends ConsumerWidget {
  const _PaywallOffer({required this.state});

  final PremiumState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(premiumControllerProvider.notifier);
    final packages = state.offering.packages;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const Icon(Icons.auto_awesome, size: 56, color: AppColors.accent),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Train with your AI buddy',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Unlock the AI features that turn your glasses into a real coach.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _Benefit(
          icon: Icons.fitness_center,
          title: 'AI-personalised plans',
          body: 'Plans generated from your profile, history, and recovery.',
        ),
        const _Benefit(
          icon: Icons.record_voice_over,
          title: 'Real-time form coaching',
          body: 'Short spoken cues in your ear as you lift, hands-free.',
        ),
        const SizedBox(height: AppSpacing.lg),
        if (packages.isEmpty)
          Text(
            key: const Key('paywall-unavailable'),
            'Purchases are unavailable right now. Already subscribed? '
            'Restore below.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final package in packages)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: PrimaryButton(
                key: Key('paywall-package-${package.id}'),
                label: '${package.title}  ·  ${package.priceString}',
                isLoading: state.purchasing,
                onPressed: () => controller.purchase(package.id),
              ),
            ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          key: const Key('paywall-restore'),
          onPressed: state.purchasing ? null : controller.restore,
          child: const Text('Restore purchases'),
        ),
      ],
    );
  }
}

/// One premium benefit row.
class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown once entitlement is active — confirmation + a way back.
class _PremiumActive extends StatelessWidget {
  const _PremiumActive();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      key: const Key('paywall-active'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, size: 56, color: AppColors.accent),
            const SizedBox(height: AppSpacing.md),
            Text(
              "You're Premium",
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'The AI features are unlocked. Time to train.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              key: const Key('paywall-done'),
              label: 'Done',
              icon: Icons.check,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The entitlement-load-failed state: a message and a retry.
class _PaywallError extends StatelessWidget {
  const _PaywallError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              "Couldn't load Premium",
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              key: const Key('paywall-retry'),
              label: 'Try again',
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
