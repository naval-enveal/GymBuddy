import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/design/design.dart';
import 'package:gymbuddy/features/auth/auth_controller.dart';
import 'package:gymbuddy/features/premium/premium_controller.dart';
import 'package:gymbuddy/features/premium/premium_gate.dart';

/// Profile tab — account and settings. The full profile view (body stats,
/// preferences) is fleshed out in later milestones; for now it hosts the
/// GymBuddy Premium section (entitlement status + paywall entry) and the
/// sign-out action so the auth gate has a way back to signed-out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const _PremiumSection(),
              const Spacer(),
              PrimaryButton(
                label: 'Sign out',
                icon: Icons.logout,
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Surfaces the user's premium entitlement: an "Active" badge once subscribed,
/// otherwise an upsell that opens the paywall. The client view is informational
/// (the server enforces the real gate); this just tells the user where they
/// stand and how to upgrade.
class _PremiumSection extends ConsumerWidget {
  const _PremiumSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isPremium = ref.watch(isPremiumProvider);
    return Container(
      key: const Key('profile-premium'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'GymBuddy Premium',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (isPremium)
                Text(
                  'Active',
                  key: const Key('profile-premium-active'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isPremium
                ? 'AI plans and real-time coaching are unlocked.'
                : 'Unlock AI-personalised plans and real-time form coaching.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (!isPremium) ...[
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              key: const Key('profile-premium-upgrade'),
              label: 'Upgrade to Premium',
              icon: Icons.auto_awesome,
              onPressed: () => openPaywall(context),
            ),
          ],
        ],
      ),
    );
  }
}
