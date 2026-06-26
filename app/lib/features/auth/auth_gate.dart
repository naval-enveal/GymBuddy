import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/features/auth/auth_controller.dart';
import 'package:gymbuddy/features/auth/auth_status.dart';
import 'package:gymbuddy/features/auth/signed_out_screen.dart';
import 'package:gymbuddy/features/shell/app_shell.dart';

/// The single place the app branches on authentication.
///
/// Authenticated → the [AppShell] (bottom-nav home). Unauthenticated → the
/// [SignedOutScreen]. Unknown (session restore pending) → a brief splash.
/// Feature screens stay auth-agnostic and assume they only render once past
/// this gate.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authControllerProvider);
    switch (status) {
      case AuthStatus.authenticated:
        return const AppShell();
      case AuthStatus.unauthenticated:
        return const SignedOutScreen();
      case AuthStatus.unknown:
        return const _AuthSplash();
    }
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
