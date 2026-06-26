// AuthScreen is the login/signup form. These tests assert client-side
// validation (no network call on bad input), mode toggling, and that a
// server-rejected submit surfaces the backend message. The backend is faked
// with a MockClient-backed ApiClient.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/network/api_client.dart';
import 'package:gymbuddy/core/storage/token_store.dart';
import 'package:gymbuddy/features/auth/auth_form_controller.dart';
import 'package:gymbuddy/features/auth/auth_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<void> _pumpScreen(
  WidgetTester tester, {
  AuthFormMode initialMode = AuthFormMode.register,
  MockClientHandler? handler,
}) async {
  final store = InMemoryTokenStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(store),
        apiClientProvider.overrideWithValue(
          ApiClient(
            baseUrl: 'http://test',
            tokenStore: store,
            httpClient: MockClient(
              (req) async => handler?.call(req) ?? http.Response('', 404),
            ),
          ),
        ),
      ],
      child: MaterialApp(home: AuthScreen(initialMode: initialMode)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('blocks submit and skips the network on empty fields',
      (WidgetTester tester) async {
    var requests = 0;
    final store = InMemoryTokenStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(store),
          apiClientProvider.overrideWithValue(
            ApiClient(
              baseUrl: 'http://test',
              tokenStore: store,
              httpClient: MockClient((req) async {
                requests++;
                return http.Response('', 404);
              }),
            ),
          ),
        ],
        child: const MaterialApp(home: AuthScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(requests, 0);
  });

  testWidgets('register rejects a password shorter than 8 characters',
      (WidgetTester tester) async {
    await _pumpScreen(tester);

    await tester.enterText(
        find.byKey(const Key('auth-email-field')), 'a@b.com');
    await tester.enterText(
        find.byKey(const Key('auth-password-field')), 'short');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Use at least 8 characters'), findsOneWidget);
  });

  testWidgets('toggling switches mode and shows/hides the name field',
      (WidgetTester tester) async {
    await _pumpScreen(tester);

    // Register mode: optional name field present.
    expect(find.byKey(const Key('auth-name-field')), findsOneWidget);
    expect(find.text('Create your account'), findsOneWidget);

    await tester.tap(find.byKey(const Key('auth-toggle')));
    await tester.pumpAndSettle();

    // Sign-in mode: no name field, login copy.
    expect(find.byKey(const Key('auth-name-field')), findsNothing);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('surfaces the backend error message on a rejected login',
      (WidgetTester tester) async {
    await _pumpScreen(
      tester,
      initialMode: AuthFormMode.signIn,
      handler: (req) async => http.Response(
        jsonEncode({
          'error': {'message': 'Invalid credentials'},
        }),
        401,
      ),
    );

    await tester.enterText(
        find.byKey(const Key('auth-email-field')), 'a@b.com');
    await tester.enterText(
        find.byKey(const Key('auth-password-field')), 'password123');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-error')), findsOneWidget);
    expect(find.text('Invalid credentials'), findsOneWidget);
  });
}
