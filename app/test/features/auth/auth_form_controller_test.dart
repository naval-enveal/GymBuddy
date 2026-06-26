// AuthFormController drives a single login/signup submission through
// AuthController and reports the outcome to the screen. These tests fake the
// backend with a MockClient-backed ApiClient so no network or platform storage
// is touched, and assert on the returned bool, the surfaced error, and the
// resulting session state.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/network/api_client.dart';
import 'package:gymbuddy/core/storage/token_store.dart';
import 'package:gymbuddy/features/auth/auth_controller.dart';
import 'package:gymbuddy/features/auth/auth_form_controller.dart';
import 'package:gymbuddy/features/auth/auth_status.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Drains pending microtasks so async restore/submit settles.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

ProviderContainer _container(
  TokenStore store,
  MockClientHandler handler,
) {
  final container = ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(store),
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

String _sessionJson() => jsonEncode({
      'user': {'id': 'u1', 'email': 'a@b.com'},
      'accessToken': 'AT',
      'refreshToken': 'RT',
    });

void main() {
  test('register submit hits /auth/register, persists tokens, authenticates',
      () async {
    final store = InMemoryTokenStore();
    String? hitPath;
    final container = _container(store, (req) async {
      hitPath = req.url.path;
      return http.Response(_sessionJson(), 201);
    });
    await _settle(); // restore → unauthenticated

    final ok = await container.read(authFormControllerProvider.notifier).submit(
          mode: AuthFormMode.register,
          email: 'a@b.com',
          password: 'password123',
          displayName: 'Ada',
        );

    expect(ok, isTrue);
    expect(hitPath, '/auth/register');
    expect(container.read(authControllerProvider), AuthStatus.authenticated);
    expect(await store.read(),
        const AuthTokens(accessToken: 'AT', refreshToken: 'RT'));
    // On success submitting stays true so the button can't re-fire before the
    // gate tears the screen down.
    expect(container.read(authFormControllerProvider).submitting, isTrue);
    expect(container.read(authFormControllerProvider).errorMessage, isNull);
  });

  test('signIn submit hits /auth/login and authenticates', () async {
    final store = InMemoryTokenStore();
    String? hitPath;
    final container = _container(store, (req) async {
      hitPath = req.url.path;
      return http.Response(_sessionJson(), 200);
    });
    await _settle();

    final ok = await container.read(authFormControllerProvider.notifier).submit(
          mode: AuthFormMode.signIn,
          email: 'a@b.com',
          password: 'password123',
        );

    expect(ok, isTrue);
    expect(hitPath, '/auth/login');
    expect(container.read(authControllerProvider), AuthStatus.authenticated);
  });

  test('failed submit surfaces the server message and returns false', () async {
    final store = InMemoryTokenStore();
    final container = _container(
      store,
      (req) async => http.Response(
        jsonEncode({
          'error': {'message': 'Invalid credentials'},
        }),
        401,
      ),
    );
    await _settle();

    final ok = await container.read(authFormControllerProvider.notifier).submit(
          mode: AuthFormMode.signIn,
          email: 'a@b.com',
          password: 'wrong',
        );

    expect(ok, isFalse);
    final formState = container.read(authFormControllerProvider);
    expect(formState.errorMessage, 'Invalid credentials');
    expect(formState.submitting, isFalse);
    expect(container.read(authControllerProvider), AuthStatus.unauthenticated);
    expect(await store.read(), isNull);
  });

  test('clearError wipes a surfaced error', () async {
    final store = InMemoryTokenStore();
    final container = _container(
      store,
      (req) async => http.Response(
        jsonEncode({
          'error': {'message': 'Invalid credentials'},
        }),
        401,
      ),
    );
    await _settle();

    final notifier = container.read(authFormControllerProvider.notifier);
    await notifier.submit(
      mode: AuthFormMode.signIn,
      email: 'a@b.com',
      password: 'wrong',
    );
    expect(container.read(authFormControllerProvider).errorMessage, isNotNull);

    notifier.clearError();
    expect(container.read(authFormControllerProvider).errorMessage, isNull);
  });

  test('a second submit is ignored while one is in flight', () async {
    final store = InMemoryTokenStore();
    var calls = 0;
    final container = _container(store, (req) async {
      calls++;
      // Hold the first request open so the second submit overlaps it.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return http.Response(_sessionJson(), 200);
    });
    await _settle();

    final notifier = container.read(authFormControllerProvider.notifier);
    final first = notifier.submit(
      mode: AuthFormMode.signIn,
      email: 'a@b.com',
      password: 'password123',
    );
    final second = notifier.submit(
      mode: AuthFormMode.signIn,
      email: 'a@b.com',
      password: 'password123',
    );

    expect(await first, isTrue);
    expect(await second, isFalse); // rejected: already submitting
    expect(calls, 1);
  });
}
