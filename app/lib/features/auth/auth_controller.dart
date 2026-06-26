import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/features/auth/auth_status.dart';

/// Single source of truth for whether the user is signed in.
///
/// The `AuthGate` watches this to decide between the app shell and the
/// signed-out flow; feature screens never branch on auth themselves.
///
/// Scope for this task is deliberately thin: status lives in memory and
/// [signIn]/[signOut] flip it so the gate is real and testable now. The next
/// M2 tasks replace these stubs with credential exchange against the M1
/// endpoints and secure token storage — at which point launch-time session
/// restore can resolve [build] asynchronously from [AuthStatus.unknown].
class AuthController extends Notifier<AuthStatus> {
  @override
  AuthStatus build() => AuthStatus.unauthenticated;

  /// Marks the session authenticated. Wired to the login endpoint + token
  /// persistence in a later M2 task.
  void signIn() => state = AuthStatus.authenticated;

  /// Clears the session and returns to the signed-out flow.
  void signOut() => state = AuthStatus.unauthenticated;
}

/// Exposes the current [AuthStatus] and the controller that mutates it.
final authControllerProvider =
    NotifierProvider<AuthController, AuthStatus>(AuthController.new);
