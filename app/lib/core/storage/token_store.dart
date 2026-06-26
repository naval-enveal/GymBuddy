import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The access + refresh JWT pair issued by the M1 `/auth/*` endpoints.
///
/// The access token is short-lived (sent as the `Authorization: Bearer`
/// header); the refresh token is long-lived and exchanged for a fresh pair when
/// the access token expires (see the `ApiClient` refresh interceptor).
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  AuthTokens copyWith({String? accessToken, String? refreshToken}) {
    return AuthTokens(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AuthTokens &&
      other.accessToken == accessToken &&
      other.refreshToken == refreshToken;

  @override
  int get hashCode => Object.hash(accessToken, refreshToken);
}

/// Persistence for the session token pair.
///
/// Abstracted so feature/auth code depends on the contract, not a concrete
/// backend: production uses [SecureTokenStore] (OS keychain / keystore); tests
/// inject [InMemoryTokenStore] to stay platform-free.
abstract class TokenStore {
  /// Returns the stored pair, or `null` when no complete session is persisted.
  Future<AuthTokens?> read();

  /// Overwrites any existing pair with [tokens].
  Future<void> save(AuthTokens tokens);

  /// Removes the persisted pair (sign-out / failed refresh).
  Future<void> clear();
}

/// Keychain/Keystore-backed [TokenStore] using `flutter_secure_storage`.
///
/// Reads and clears are defensive: a platform that can't service secure storage
/// (e.g. a unit-test host with no plugin, or a read failure) is treated as "no
/// session" rather than crashing the app, so launch-time session restore
/// degrades to the signed-out flow instead of throwing.
class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _accessKey = 'gymbuddy.access_token';
  static const String _refreshKey = 'gymbuddy.refresh_token';

  @override
  Future<AuthTokens?> read() async {
    try {
      final access = await _storage.read(key: _accessKey);
      final refresh = await _storage.read(key: _refreshKey);
      if (access == null ||
          refresh == null ||
          access.isEmpty ||
          refresh.isEmpty) {
        return null;
      }
      return AuthTokens(accessToken: access, refreshToken: refresh);
    } catch (_) {
      // Storage unavailable / unreadable → behave as a signed-out session.
      return null;
    }
  }

  @override
  Future<void> save(AuthTokens tokens) async {
    await _storage.write(key: _accessKey, value: tokens.accessToken);
    await _storage.write(key: _refreshKey, value: tokens.refreshToken);
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    } catch (_) {
      // Nothing persisted / storage unavailable — clearing is a no-op.
    }
  }
}

/// In-memory [TokenStore] for tests and previews. Not persistent.
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this._tokens]);

  AuthTokens? _tokens;

  @override
  Future<AuthTokens?> read() async => _tokens;

  @override
  Future<void> save(AuthTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}

/// App-wide token store. Production resolves to [SecureTokenStore]; tests
/// override this with an [InMemoryTokenStore].
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());
