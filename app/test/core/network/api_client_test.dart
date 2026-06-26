// ApiClient tests — the refresh interceptor is the load-bearing behavior here,
// so a MockClient stands in for the network and lets us assert exactly which
// requests go out, in what order, and with which Authorization header.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/network/api_client.dart';
import 'package:gymbuddy/core/storage/token_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _base = 'http://test';

ApiClient _client(
  MockClientHandler handler, {
  required TokenStore store,
  SessionExpiredCallback? onSessionExpired,
}) {
  return ApiClient(
    baseUrl: _base,
    tokenStore: store,
    httpClient: MockClient(handler),
    onSessionExpired: onSessionExpired,
  );
}

void main() {
  test('attaches the access token to authenticated requests', () async {
    String? seenAuth;
    final client = _client(
      (req) async {
        seenAuth = req.headers['authorization'];
        return http.Response(jsonEncode({'ok': true}), 200);
      },
      store: InMemoryTokenStore(
        const AuthTokens(accessToken: 'AT', refreshToken: 'RT'),
      ),
    );

    final body = await client.get('/me');

    expect(seenAuth, 'Bearer AT');
    expect(body, {'ok': true});
  });

  test('omits the Authorization header on unauthenticated requests', () async {
    String? seenAuth = 'unset';
    final client = _client(
      (req) async {
        seenAuth = req.headers['authorization'];
        return http.Response(jsonEncode({'ok': true}), 200);
      },
      store: InMemoryTokenStore(
        const AuthTokens(accessToken: 'AT', refreshToken: 'RT'),
      ),
    );

    await client.post('/auth/login', authenticated: false, body: {'a': 1});

    expect(seenAuth, isNull);
  });

  test('decodes an empty 204 body as null', () async {
    final client = _client(
      (req) async => http.Response('', 204),
      store: InMemoryTokenStore(),
    );

    expect(await client.post('/auth/logout', authenticated: false), isNull);
  });

  test('surfaces the backend error message on non-2xx', () async {
    final client = _client(
      (req) async => http.Response(
        jsonEncode({
          'error': {'message': 'Email already registered'},
        }),
        409,
      ),
      store: InMemoryTokenStore(),
    );

    await expectLater(
      client.post('/auth/register', authenticated: false, body: {}),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.message, 'message', 'Email already registered'),
      ),
    );
  });

  test('on 401, refreshes the token pair and replays the request', () async {
    final store = InMemoryTokenStore(
      const AuthTokens(accessToken: 'old', refreshToken: 'r1'),
    );
    final authHeaders = <String>[];
    var refreshCalls = 0;

    final client = _client(
      (req) async {
        if (req.url.path == '/auth/refresh') {
          refreshCalls++;
          expect(jsonDecode(req.body), {'refreshToken': 'r1'});
          return http.Response(
            jsonEncode({'accessToken': 'new', 'refreshToken': 'r2'}),
            200,
          );
        }
        final auth = req.headers['authorization'];
        authHeaders.add(auth ?? '');
        // The stale access token is rejected; the refreshed one is accepted.
        return auth == 'Bearer new'
            ? http.Response(jsonEncode({'ok': true}), 200)
            : http.Response('', 401);
      },
      store: store,
    );

    final body = await client.get('/protected');

    expect(body, {'ok': true});
    expect(refreshCalls, 1);
    expect(authHeaders, ['Bearer old', 'Bearer new']);
    // The rotated pair is persisted for subsequent calls.
    expect(await store.read(),
        const AuthTokens(accessToken: 'new', refreshToken: 'r2'));
  });

  test('concurrent 401s share a single refresh', () async {
    final store = InMemoryTokenStore(
      const AuthTokens(accessToken: 'old', refreshToken: 'r1'),
    );
    var refreshCalls = 0;

    final client = _client(
      (req) async {
        if (req.url.path == '/auth/refresh') {
          refreshCalls++;
          return http.Response(
            jsonEncode({'accessToken': 'new', 'refreshToken': 'r2'}),
            200,
          );
        }
        return req.headers['authorization'] == 'Bearer new'
            ? http.Response(jsonEncode({'ok': true}), 200)
            : http.Response('', 401);
      },
      store: store,
    );

    final results = await Future.wait([
      client.get('/a'),
      client.get('/b'),
    ]);

    expect(results, [
      {'ok': true},
      {'ok': true},
    ]);
    expect(refreshCalls, 1);
  });

  test('a failed refresh clears tokens, fires the callback, and throws',
      () async {
    final store = InMemoryTokenStore(
      const AuthTokens(accessToken: 'old', refreshToken: 'dead'),
    );
    var expired = 0;

    final client = _client(
      (req) async {
        if (req.url.path == '/auth/refresh') {
          return http.Response('', 401);
        }
        return http.Response('', 401);
      },
      store: store,
      onSessionExpired: () => expired++,
    );

    await expectLater(
      client.get('/protected'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
    expect(expired, 1);
    expect(await store.read(), isNull);
  });
}
