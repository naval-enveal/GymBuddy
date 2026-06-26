import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/design/design.dart';
import 'package:gymbuddy/features/auth/auth_controller.dart';
import 'package:gymbuddy/features/auth/auth_status.dart';
import 'package:gymbuddy/features/auth/signed_out_screen.dart';
import 'package:gymbuddy/features/onboarding/onboarding_gate.dart';
import 'package:gymbuddy/features/onboarding/onboarding_screen.dart';
import 'package:gymbuddy/features/shell/app_shell.dart';

/// The single place the app branches on authentication.
///
/// Authenticated → the [_OnboardingRouter], which sends first-run users through
/// onboarding before the shell. Unauthenticated → the [SignedOutScreen].
/// Unknown (session restore pending) → a brief splash. Feature screens stay
/// auth-agnostic and assume they only render once past this gate.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authControllerProvider);
    switch (status) {
      case AuthStatus.authenticated:
        return const _OnboardingRouter();
      case AuthStatus.unauthenticated:
        return const SignedOutScreen();
      case AuthStatus.unknown:
        return const _AuthSplash();
    }
  }
}

/// Routes an authenticated user to onboarding or the shell based on whether
/// they've completed onboarding (see [onboardingGateProvider]). While the
/// profile loads it shows the splash; if the check fails it offers a retry
/// rather than guessing.
class _OnboardingRouter extends ConsumerWidget {
  const _OnboardingRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(onboardingGateProvider).when(
          data: (onboardingComplete) =>
              onboardingComplete ? const AppShell() : const OnboardingScreen(),
          loading: () => const _AuthSplash(),
          error: (_, _) => _OnboardingGateError(
            onRetry: () => ref.invalidate(onboardingGateProvider),
          ),
        );
  }
}

/// Shown when the onboarding-status check fails (e.g. a network error). Lets the
/// user retry the [onboardingGateProvider] fetch.
class _OnboardingGateError extends StatelessWidget {
  const _OnboardingGateError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "We couldn't load your profile.",
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
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                key: const Key('onboarding-gate-retry'),
                label: 'Retry',
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown while session restore is in flight (see [AuthStatus.unknown]).
class _AuthSplash extends StatelessWidget {
  const _AuthSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
