// The auth gate is the only place the app branches on auth. These tests walk
// the full gate flow: signed-out landing → open the auth screen → submit
// credentials → app shell → sign out → back to the landing. The backend is
// faked with a MockClient-backed ApiClient so no network is touched.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gymbuddy/core/network/api_client.dart';
import 'package:gymbuddy/core/storage/token_store.dart';
import 'package:gymbuddy/main.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _sessionJson() => jsonEncode({
      'user': {'id': 'u1', 'email': 'a@b.com'},
      'accessToken': 'AT',
      'refreshToken': 'RT',
    });

/// Boots the app with an empty (in-memory) token store, so launch-time session
/// restore resolves to the signed-out flow without touching platform storage.
/// An optional [handler] backs the API client for the auth exchange.
Future<void> _pumpApp(
  WidgetTester tester, {
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
      child: const GymBuddyApp(),
    ),
  );
  // Let the restore splash resolve before driving the gate.
  await tester.pumpAndSettle();
}

/// Drives the signed-out landing → auth screen → submitted credentials, leaving
/// the app on the shell. Defaults to the "Get started" (register) entry point.
Future<void> _signIn(WidgetTester tester) async {
  await tester.tap(find.text('Get started'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('auth-email-field')), 'a@b.com');
  await tester.enterText(
      find.byKey(const Key('auth-password-field')), 'password123');
  await tester.tap(find.byKey(const Key('auth-submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts signed out: shows the landing, not the shell',
      (WidgetTester tester) async {
    await _pumpApp(tester);

    expect(find.text('Get started'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('"Get started" opens the auth screen', (WidgetTester tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
    expect(find.byKey(const Key('auth-password-field')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('submitting valid credentials reveals the shell with all tabs',
      (WidgetTester tester) async {
    await _pumpApp(
      tester,
      handler: (req) async => http.Response(_sessionJson(), 201),
    );

    await _signIn(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    // Each label appears twice: once as a nav destination, once as the tab's
    // (IndexedStack-retained) app-bar title.
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Plans'), findsWidgets);
    expect(find.text('Workout'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Get started'), findsNothing);
  });

  testWidgets('signing out from Profile returns to the landing',
      (WidgetTester tester) async {
    await _pumpApp(
      tester,
      handler: (req) async {
        if (req.url.path == '/auth/logout') return http.Response('', 204);
        return http.Response(_sessionJson(), 201);
      },
    );

    await _signIn(tester);

    // Switch to the Profile tab via its nav destination (scoped to the bar so
    // the matching ComingSoon/icon glyphs elsewhere don't make it ambiguous).
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.person_outline),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Get started'), findsOneWidget);
  });
}
