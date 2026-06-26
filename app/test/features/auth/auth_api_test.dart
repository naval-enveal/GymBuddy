// AuthApi maps the M1 /auth/* JSON onto typed AuthSession values. A MockClient
// stands in for the backend.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/network/api_client.dart';
import 'package:gymbuddy/core/storage/token_store.dart';
import 'package:gymbuddy/features/auth/auth_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

AuthApi _api(MockClientHandler handler) {
  return AuthApi(
    ApiClient(
      baseUrl: 'http://test',
      tokenStore: InMemoryTokenStore(),
      httpClient: MockClient(handler),
    ),
  );
}

void main() {
  test('login parses the user and token pair', () async {
    final api = _api((req) async {
      expect(req.url.path, '/auth/login');
      expect(jsonDecode(req.body), {'email': 'a@b.com', 'password': 'pw'});
      return http.Response(
        jsonEncode({
          'user': {'id': 'u1', 'email': 'a@b.com', 'displayName': 'Ann'},
          'accessToken': 'AT',
          'refreshToken': 'RT',
        }),
        200,
      );
    });

    final session = await api.login(email: 'a@b.com', password: 'pw');

    expect(session.user.id, 'u1');
    expect(session.user.email, 'a@b.com');
    expect(session.user.displayName, 'Ann');
    expect(
      session.tokens,
      const AuthTokens(accessToken: 'AT', refreshToken: 'RT'),
    );
  });

  test('register forwards displayName only when non-empty', () async {
    Map<String, dynamic>? sent;
    final api = _api((req) async {
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'user': {'id': 'u2', 'email': 'c@d.com'},
          'accessToken': 'AT',
          'refreshToken': 'RT',
        }),
        201,
      );
    });

    await api.register(email: 'c@d.com', password: 'pw', displayName: '');

    expect(sent, {'email': 'c@d.com', 'password': 'pw'});
  });

  test('logout posts the refresh token', () async {
    String? body;
    final api = _api((req) async {
      expect(req.url.path, '/auth/logout');
      body = req.body;
      return http.Response('', 204);
    });

    await api.logout('RT');

    expect(jsonDecode(body!), {'refreshToken': 'RT'});
  });
}
