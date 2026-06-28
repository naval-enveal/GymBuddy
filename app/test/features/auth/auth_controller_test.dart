// AuthController owns session lifecycle: launch-time restore from the token
// store, credential exchange that persists tokens, and sign-out that clears
// them. The API is faked with a MockClient-backed ApiClient so no network or
// platform storage is touched.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/analytics/analytics_service.dart';
import 'package:gymbuddy/core/network/api_client.dart';
import 'package:gymbuddy/core/storage/token_store.dart';
import 'package:gymbuddy/features/auth/auth_controller.dart';
import 'package:gymbuddy/features/auth/auth_status.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Drains pending microtasks so the async restore/sign-in settles.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

ProviderContainer _container(
  TokenStore store, {
  MockClientHandler? handler,
  MockAnalyticsService? analytics,
}) {
  final container = ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(store),
      if (analytics != null)
        analyticsServiceProvider.overrideWithValue(analytics),
      if (handler != null)
        apiClientProvider.overrideWithValue(
          ApiClient(
            baseUrl: 'http://test',
            tokenStore: store,
            httpClient: MockClient(handler),
          ),
        ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('restores an authenticated session when tokens are persisted', () async {
    final container = _container(
      InMemoryTokenStore(
        const AuthTokens(accessToken: 'AT', refreshToken: 'RT'),
      ),
    );

    // Starts pending while storage is read.
    expect(container.read(authControllerProvider), AuthStatus.unknown);
    await _settle();
    expect(container.read(authControllerProvider), AuthStatus.authenticated);
  });

  test('resolves to unauthenticated when no tokens are persisted', () async {
    final container = _container(InMemoryTokenStore());

    container.read(authControllerProvider);
    await _settle();
    expect(container.read(authControllerProvider), AuthStatus.unauthenticated);
  });

  test('signIn exchanges credentials, persists tokens, authenticates',
      () async {
    final store = InMemoryTokenStore();
    final container = _container(
      store,
      handler: (req) async {
        expect(req.url.path, '/auth/login');
        return http.Response(
          jsonEncode({
            'user': {'id': 'u1', 'email': 'a@b.com'},
            'accessToken': 'AT',
            'refreshToken': 'RT',
          }),
          200,
        );
      },
    );
    await _settle(); // initial restore → unauthenticated

    await container
        .read(authControllerProvider.notifier)
        .signIn(email: 'a@b.com', password: 'pw');

    expect(container.read(authControllerProvider), AuthStatus.authenticated);
    expect(await store.read(),
        const AuthTokens(accessToken: 'AT', refreshToken: 'RT'));
  });

  test('failed signIn surfaces the error and leaves state unauthenticated',
      () async {
    final store = InMemoryTokenStore();
    final container = _container(
      store,
      handler: (req) async => http.Response(
        jsonEncode({
          'error': {'message': 'Invalid credentials'},
        }),
        401,
      ),
    );
    await _settle();

    await expectLater(
      container
          .read(authControllerProvider.notifier)
          .signIn(email: 'a@b.com', password: 'bad'),
      throwsA(isA<ApiException>()),
    );
    expect(container.read(authControllerProvider), AuthStatus.unauthenticated);
    expect(await store.read(), isNull);
  });

  test('signOut clears tokens and revokes server-side', () async {
    final store = InMemoryTokenStore(
      const AuthTokens(accessToken: 'AT', refreshToken: 'RT'),
    );
    var loggedOut = false;
    final container = _container(
      store,
      handler: (req) async {
        if (req.url.path == '/auth/logout') {
          loggedOut = true;
          expect(jsonDecode(req.body), {'refreshToken': 'RT'});
          return http.Response('', 204);
        }
        return http.Response('', 404);
      },
    );
    await _settle(); // restore → authenticated

    await container.read(authControllerProvider.notifier).signOut();

    expect(container.read(authControllerProvider), AuthStatus.unauthenticated);
    expect(await store.read(), isNull);
    expect(loggedOut, isTrue);
  });

  test('signIn logs the login event and identifies the user', () async {
    final analytics = MockAnalyticsService();
    final container = _container(
      InMemoryTokenStore(),
      analytics: analytics,
      handler: (req) async => http.Response(
        jsonEncode({
          'user': {'id': 'u1', 'email': 'a@b.com'},
          'accessToken': 'AT',
          'refreshToken': 'RT',
        }),
        200,
      ),
    );
    await _settle();

    await container
        .read(authControllerProvider.notifier)
        .signIn(email: 'a@b.com', password: 'pw');

    expect(analytics.userId, 'u1');
    expect(
      analytics.events.map((e) => e.name),
      contains(AnalyticsEvents.login),
    );
  });

  test('register logs the sign_up event and identifies the user', () async {
    final analytics = MockAnalyticsService();
    final container = _container(
      InMemoryTokenStore(),
      analytics: analytics,
      handler: (req) async {
        expect(req.url.path, '/auth/register');
        return http.Response(
          jsonEncode({
            'user': {'id': 'new-user', 'email': 'a@b.com'},
            'accessToken': 'AT',
            'refreshToken': 'RT',
          }),
          201,
        );
      },
    );
    await _settle();

    await container
        .read(authControllerProvider.notifier)
        .register(email: 'a@b.com', password: 'pw');

    expect(analytics.userId, 'new-user');
    expect(
      analytics.events.map((e) => e.name),
      contains(AnalyticsEvents.signUp),
    );
  });

  test('signOut detaches the analytics user id', () async {
    final analytics = MockAnalyticsService()..userId = 'u1';
    final container = _container(
      InMemoryTokenStore(
        const AuthTokens(accessToken: 'AT', refreshToken: 'RT'),
      ),
      analytics: analytics,
      handler: (req) async => http.Response('', 204),
    );
    await _settle();

    await container.read(authControllerProvider.notifier).signOut();

    expect(analytics.userId, isNull);
  });
}
