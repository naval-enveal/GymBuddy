import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gymbuddy/core/storage/token_store.dart';
import 'package:http/http.dart' as http;

/// A non-2xx response from the API.
///
/// [message] is lifted from the backend's shared `{ error: { message } }`
/// envelope when present, so UI can surface a server-authored reason; otherwise
/// it falls back to a generic, status-coded string.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Invoked when the session can no longer be refreshed (the refresh token is
/// expired/revoked). The auth layer wires this to sign the user out.
typedef SessionExpiredCallback = void Function();

/// Thin JSON-over-HTTP client for the GymBuddy backend.
///
/// Responsibilities beyond a raw `http` call:
///  - Attaches `Authorization: Bearer <access>` to authenticated requests.
///  - Refresh interceptor: on a `401` it transparently exchanges the refresh
///    token for a new pair (via `/auth/refresh`), persists it, and replays the
///    original request exactly once. Concurrent 401s share a single in-flight
///    refresh so the token isn't rotated twice.
///  - If the refresh itself fails, it clears the stored tokens and fires
///    [SessionExpiredCallback]; the original 401 then surfaces as an
///    [ApiException].
///
/// Bodies are decoded JSON (`Map`/`List`), or `null` for an empty (e.g. 204)
/// response. Non-2xx responses throw [ApiException].
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.tokenStore,
    this.onSessionExpired,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// Origin (scheme + host + port), no trailing slash, e.g. `http://host:4000`.
  final String baseUrl;
  final TokenStore tokenStore;
  final SessionExpiredCallback? onSessionExpired;
  final http.Client _http;

  /// De-duplicates concurrent refreshes (see class doc).
  Future<AuthTokens?>? _refreshInFlight;

  Future<dynamic> get(String path, {bool authenticated = true}) =>
      _send('GET', path, authenticated: authenticated);

  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) =>
      _send('POST', path, body: body, authenticated: authenticated);

  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) =>
      _send('PUT', path, body: body, authenticated: authenticated);

  Future<dynamic> delete(String path, {bool authenticated = true}) =>
      _send('DELETE', path, authenticated: authenticated);

  /// Releases the underlying HTTP connection pool.
  void close() => _http.close();

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    required bool authenticated,
  }) async {
    final tokens = authenticated ? await tokenStore.read() : null;
    var response = await _dispatch(method, path, body, tokens?.accessToken);

    // Refresh interceptor: a single retry after a transparent token refresh.
    if (response.statusCode == 401 && authenticated && tokens != null) {
      final refreshed = await _refresh();
      if (refreshed == null) {
        onSessionExpired?.call();
        throw _exceptionFor(response);
      }
      response = await _dispatch(method, path, body, refreshed.accessToken);
    }

    return _decode(response);
  }

  Future<http.Response> _dispatch(
    String method,
    String path,
    Object? body,
    String? accessToken,
  ) {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    final encoded = body == null ? null : jsonEncode(body);
    switch (method) {
      case 'GET':
        return _http.get(uri, headers: headers);
      case 'POST':
        return _http.post(uri, headers: headers, body: encoded);
      case 'PUT':
        return _http.put(uri, headers: headers, body: encoded);
      case 'DELETE':
        return _http.delete(uri, headers: headers, body: encoded);
      default:
        throw ArgumentError('Unsupported method: $method');
    }
  }

  /// Exchanges the stored refresh token for a fresh pair, persisting it on
  /// success. Returns `null` (and clears storage) on any failure. Shared across
  /// concurrent callers so the refresh token rotates at most once.
  Future<AuthTokens?> _refresh() {
    return _refreshInFlight ??=
        _performRefresh().whenComplete(() => _refreshInFlight = null);
  }

  Future<AuthTokens?> _performRefresh() async {
    final current = await tokenStore.read();
    if (current == null) return null;

    final http.Response response;
    try {
      response = await _http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': current.refreshToken}),
      );
    } catch (_) {
      // Network error mid-refresh: keep the tokens, let the caller surface the
      // original 401. Don't sign the user out over a transient failure.
      return null;
    }

    if (response.statusCode != 200) {
      // The refresh token is rejected (expired/revoked) — the session is dead.
      await tokenStore.clear();
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tokens = AuthTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    await tokenStore.save(tokens);
    return tokens;
  }

  dynamic _decode(http.Response response) {
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw _exceptionFor(response, decoded: body);
  }

  ApiException _exceptionFor(http.Response response, {Object? decoded}) {
    final body = decoded ??
        (response.body.isEmpty ? null : _tryDecode(response.body));
    if (body is Map &&
        body['error'] is Map &&
        (body['error'] as Map)['message'] is String) {
      return ApiException(
        response.statusCode,
        (body['error'] as Map)['message'] as String,
      );
    }
    return ApiException(
      response.statusCode,
      'Request failed (${response.statusCode})',
    );
  }

  Object? _tryDecode(String source) {
    try {
      return jsonDecode(source);
    } catch (_) {
      return null;
    }
  }
}

/// Backend origin.
/// - Android emulator: use `http://10.0.2.2:4000` (maps to host localhost)
/// - Physical device: use `http://<mac-lan-ip>:4000` (e.g. 192.168.100.51)
/// Both device and Mac must be on the same WiFi network.
final apiBaseUrlProvider =
    Provider<String>((ref) => 'http://192.168.100.51:4000');

/// Hook fired when a refresh fails and the session is dead. Defaults to a
/// no-op so `core/` carries no dependency on the auth feature; the auth layer
/// overrides this (in `main.dart`) to drive sign-out. Kept here so the
/// [apiClientProvider] can wire it without an upward import.
final sessionExpiredProvider = Provider<SessionExpiredCallback>(
  (ref) => () {},
);

/// App-wide [ApiClient], backed by the secure [tokenStoreProvider] and the
/// configured [apiBaseUrlProvider]. A dead session routes through
/// [sessionExpiredProvider].
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    baseUrl: ref.watch(apiBaseUrlProvider),
    tokenStore: ref.watch(tokenStoreProvider),
    onSessionExpired: () => ref.read(sessionExpiredProvider)(),
  );
  ref.onDispose(client.close);
  return client;
});
