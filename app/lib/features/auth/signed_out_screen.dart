import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/app_info.dart';
import 'package:gymbuddy/core/design/design.dart';
import 'package:gymbuddy/features/auth/auth_form_controller.dart';
import 'package:gymbuddy/features/auth/auth_screen.dart';

/// The app's first screen when no session exists: GymBuddy branding plus the
/// entry points into the auth flow.
///
/// "Get started" opens the [AuthScreen] in register mode; "I already have an
/// account" opens it in sign-in mode. The screen itself owns the credential
/// exchange (via [authFormControllerProvider]); this landing only routes into
/// it. Branding (name + tagline) is read from [appInfoProvider] rather than
/// hardcoded.
class SignedOutScreen extends ConsumerWidget {
  const SignedOutScreen({super.key});

  void _openAuth(BuildContext context, AuthFormMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AuthScreen(initialMode: mode),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appInfo = ref.watch(appInfoProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const Spacer(),
              Icon(
                Icons.fitness_center,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(appInfo.name, style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                appInfo.tagline,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Get started',
                onPressed: () => _openAuth(context, AuthFormMode.register),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => _openAuth(context, AuthFormMode.signIn),
                child: const Text('I already have an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
