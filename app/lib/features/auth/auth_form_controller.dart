import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/network/api_client.dart';
import 'package:gymbuddy/features/auth/auth_controller.dart';

/// Which credential exchange the auth form performs.
enum AuthFormMode {
  /// Log in to an existing account (`POST /auth/login`).
  signIn,

  /// Create a new account (`POST /auth/register`).
  register,
}

/// Transient UI state for the login / signup form: whether a submission is in
/// flight and the last server-authored error to surface, if any.
///
/// Field-level (empty/format) validation is handled by the form itself; this
/// only carries the outcome of the network exchange.
class AuthFormState {
  const AuthFormState({this.submitting = false, this.errorMessage});

  /// True while a submit is awaiting the backend; the form disables input and
  /// the button shows its loading state.
  final bool submitting;

  /// The message from a failed submit (lifted from [ApiException.message]),
  /// or `null` when there's nothing to show.
  final String? errorMessage;

  @override
  bool operator ==(Object other) =>
      other is AuthFormState &&
      other.submitting == submitting &&
      other.errorMessage == errorMessage;

  @override
  int get hashCode => Object.hash(submitting, errorMessage);
}

/// Drives a single login/signup submission through [AuthController].
///
/// Logic lives here, not in the screen widget (per the no-logic-in-widgets
/// rule): the widget owns only its text controllers and field validation, then
/// delegates the network exchange to [submit]. On success the [AuthController]
/// flips to authenticated and the `AuthGate` swaps in the shell; this notifier
/// just reports success so the screen can dismiss itself. On an [ApiException]
/// it captures the server message for display and stays put.
///
/// `autoDispose`: when the auth screen is dismissed the form state resets, so a
/// later visit starts clean.
class AuthFormController extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  /// Clears any surfaced error — e.g. when the user toggles mode or edits a
  /// field after a rejected attempt. No-op when there's nothing to clear.
  void clearError() {
    if (state.errorMessage != null) {
      state = AuthFormState(submitting: state.submitting);
    }
  }

  /// Exchanges [email]/[password] (and [displayName] when registering) for a
  /// session. Returns `true` on success, `false` on failure (with
  /// [AuthFormState.errorMessage] set). Concurrent calls while a submit is in
  /// flight are ignored. On success [AuthFormState.submitting] is left `true`:
  /// the gate is about to replace this screen, so the button stays disabled
  /// rather than flickering back to idle.
  Future<bool> submit({
    required AuthFormMode mode,
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (state.submitting) return false;
    state = const AuthFormState(submitting: true);

    final auth = ref.read(authControllerProvider.notifier);
    try {
      switch (mode) {
        case AuthFormMode.signIn:
          await auth.signIn(email: email, password: password);
        case AuthFormMode.register:
          await auth.register(
            email: email,
            password: password,
            displayName: displayName,
          );
      }
      return true;
    } on ApiException catch (e) {
      state = AuthFormState(errorMessage: e.message);
      return false;
    } catch (_) {
      state = const AuthFormState(
        errorMessage: 'Something went wrong. Please check your connection and '
            'try again.',
      );
      return false;
    }
  }
}

/// The login/signup form's submission state and controller.
final authFormControllerProvider =
    NotifierProvider.autoDispose<AuthFormController, AuthFormState>(
  AuthFormController.new,
);
