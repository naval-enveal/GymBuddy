import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/app_info.dart';
import 'package:gymbuddy/core/design/design.dart';
import 'package:gymbuddy/features/auth/auth_controller.dart';

/// The app's first screen when no session exists: GymBuddy branding plus a
/// single call to action into the app.
///
/// This is the transitional signed-out landing. The dedicated login / signup
/// screens wired to the M1 endpoints land in the next M2 task and will replace
/// the [PrimaryButton] action here; for now it calls
/// [AuthController.signInForPreview] so the auth gate can be exercised
/// end-to-end. Branding (name + tagline) is read from [appInfoProvider] rather
/// than hardcoded.
class SignedOutScreen extends ConsumerWidget {
  const SignedOutScreen({super.key});

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
                onPressed: () => ref
                    .read(authControllerProvider.notifier)
                    .signInForPreview(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
