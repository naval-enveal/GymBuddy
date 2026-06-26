import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/storage/token_store.dart';
import 'package:gymbuddy/features/auth/auth_api.dart';
import 'package:gymbuddy/features/auth/auth_status.dart';

/// Single source of truth for whether the user is signed in.
///
/// The `AuthGate` watches this to decide between the app shell, the signed-out
/// flow, and the launch splash; feature screens never branch on auth.
///
/// State starts at [AuthStatus.unknown] while [_restore] reads any persisted
/// session from the secure [TokenStore]. A complete token pair resolves to
/// [AuthStatus.authenticated] (optimistic — an expired access token is repaired
/// by the API client's refresh interceptor on the first protected call; a dead
/// refresh token then routes back through [signOut]); otherwise it resolves to
/// [AuthStatus.unauthenticated].
///
/// Credential exchange ([signIn]/[register]) goes through [AuthApi] and persists
/// the issued tokens; the login/signup screens drive these via the
/// `AuthFormController`.
class AuthController extends Notifier<AuthStatus> {
  @override
  AuthStatus build() {
    unawaited(_restore());
    return AuthStatus.unknown;
  }

  Future<void> _restore() async {
    final tokens = await ref.read(tokenStoreProvider).read();
    state = tokens == null
        ? AuthStatus.unauthenticated
        : AuthStatus.authenticated;
  }

  /// Authenticates with the backend, persists the issued tokens, and marks the
  /// session authenticated. Throws [ApiException] on bad credentials; state is
  /// left untouched on failure so the caller can surface the error.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final session = await ref.read(authApiProvider).login(
          email: email,
          password: password,
        );
    await _persist(session);
  }

  /// Registers a new account, persists the issued tokens, and marks the session
  /// authenticated. Throws [ApiException] (e.g. 409 email-in-use) on failure.
  Future<void> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final session = await ref.read(authApiProvider).register(
          email: email,
          password: password,
          displayName: displayName,
        );
    await _persist(session);
  }

  /// Clears the local session immediately, then best-effort revokes the refresh
  /// token server-side. Always returns to the signed-out flow, even if the
  /// network call fails.
  Future<void> signOut() async {
    final store = ref.read(tokenStoreProvider);
    final tokens = await store.read();
    state = AuthStatus.unauthenticated;
    await store.clear();
    if (tokens != null) {
      try {
        await ref.read(authApiProvider).logout(tokens.refreshToken);
      } catch (_) {
        // Local sign-out already happened; a failed revocation is non-fatal.
      }
    }
  }

  Future<void> _persist(AuthSession session) async {
    await ref.read(tokenStoreProvider).save(session.tokens);
    state = AuthStatus.authenticated;
  }
}

/// Exposes the current [AuthStatus] and the controller that mutates it.
final authControllerProvider =
    NotifierProvider<AuthController, AuthStatus>(AuthController.new);
