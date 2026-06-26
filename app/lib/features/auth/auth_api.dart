import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/network/api_client.dart';
import 'package:gymbuddy/core/storage/token_store.dart';

/// The authenticated account, as returned by the backend `user` payload
/// (`user.toJSON()` — `passwordHash` is never sent).
class AuthUser {
  const AuthUser({required this.id, required this.email, this.displayName});

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['_id']) as String?;
    return AuthUser(
      id: id ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String?,
    );
  }

  final String id;
  final String email;
  final String? displayName;
}

/// A freshly authenticated session: the account plus its token pair.
class AuthSession {
  const AuthSession({required this.user, required this.tokens});

  final AuthUser user;
  final AuthTokens tokens;
}

/// Typed wrapper over the M1 `/auth/*` endpoints.
///
/// `register`/`login` return an [AuthSession]; persisting its tokens and
/// flipping auth state is the controller's job (see `AuthController`). These
/// calls are unauthenticated — they mint the session rather than consume one —
/// so they bypass the access-token header and the refresh interceptor.
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  Future<AuthSession> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final data = await _client.post(
      '/auth/register',
      authenticated: false,
      body: {
        'email': email,
        'password': password,
        if (displayName != null && displayName.isNotEmpty)
          'displayName': displayName,
      },
    ) as Map<String, dynamic>;
    return _sessionFrom(data);
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final data = await _client.post(
      '/auth/login',
      authenticated: false,
      body: {'email': email, 'password': password},
    ) as Map<String, dynamic>;
    return _sessionFrom(data);
  }

  /// Server-side revocation of the refresh token. Best-effort: the caller
  /// clears local tokens regardless of the outcome.
  Future<void> logout(String refreshToken) async {
    await _client.post(
      '/auth/logout',
      authenticated: false,
      body: {'refreshToken': refreshToken},
    );
  }

  AuthSession _sessionFrom(Map<String, dynamic> data) {
    return AuthSession(
      user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
      tokens: AuthTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      ),
    );
  }
}

/// App-wide [AuthApi] over the shared [apiClientProvider].
final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);
