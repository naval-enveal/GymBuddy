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
import 'package:gymbuddy/features/onboarding/onboarding_controller.dart';
import 'package:gymbuddy/features/onboarding/onboarding_options.dart';
import 'package:gymbuddy/main.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _sessionJson() => jsonEncode({
      'user': {'id': 'u1', 'email': 'a@b.com'},
      'accessToken': 'AT',
      'refreshToken': 'RT',
    });

String _profileJson({required bool onboardingComplete}) => jsonEncode({
      'profile': {'onboardingComplete': onboardingComplete},
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

/// Boots the app already authenticated (token store seeded), so the gate lands
/// straight on the post-auth onboarding router. Returns the container so a test
/// can drive providers directly. [handler] backs the API client (the gate's
/// `GET /profile` check, plus any save).
Future<ProviderContainer> _pumpAuthed(
  WidgetTester tester, {
  required MockClientHandler handler,
}) async {
  final store = InMemoryTokenStore(
    const AuthTokens(accessToken: 'AT', refreshToken: 'RT'),
  );
  final container = ProviderContainer(
    // Disable Riverpod 3's automatic retry of errored providers so the gate's
    // error/retry path is deterministic under test (production keeps auto-retry
    // on top of the manual retry button).
    retry: (_, _) => null,
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
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const GymBuddyApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
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
      // Onboarding already done, so the gate routes past it to the shell.
      handler: (req) async {
        if (req.url.path == '/profile') {
          return http.Response(_profileJson(onboardingComplete: true), 200);
        }
        return http.Response(_sessionJson(), 201);
      },
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
        if (req.url.path == '/profile') {
          return http.Response(_profileJson(onboardingComplete: true), 200);
        }
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

  testWidgets('authenticated but onboarding-incomplete lands on the flow',
      (WidgetTester tester) async {
    await _pumpAuthed(
      tester,
      handler: (req) async {
        if (req.url.path == '/profile') {
          return http.Response(_profileJson(onboardingComplete: false), 200);
        }
        return http.Response('', 404);
      },
    );

    // The onboarding flow, not the shell, is shown.
    expect(find.text('What are your goals?'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('finishing onboarding routes on to the shell',
      (WidgetTester tester) async {
    final container = await _pumpAuthed(
      tester,
      handler: (req) async {
        if (req.url.path == '/profile') {
          // GET (gate check) → not yet done; PUT (save) → done.
          return http.Response(
            _profileJson(onboardingComplete: req.method == 'PUT'),
            200,
          );
        }
        return http.Response('', 404);
      },
    );

    // Starts in the flow.
    expect(find.byType(NavigationBar), findsNothing);

    // Fill a valid draft and finish via the controller; on success the screen
    // flips the gate and the AuthGate routes to the shell.
    container.read(onboardingControllerProvider.notifier)
      ..toggleGoal(FitnessGoal.buildMuscle)
      ..setExperience(ExperienceLevel.beginner)
      ..setDaysPerWeek(3)
      ..toggleEquipment(Equipment.bodyweight);
    await container.read(onboardingControllerProvider.notifier).complete();
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('a failed onboarding-status check shows a retry that recovers',
      (WidgetTester tester) async {
    var attempts = 0;
    await _pumpAuthed(
      tester,
      handler: (req) async {
        if (req.url.path == '/profile') {
          attempts++;
          if (attempts == 1) return http.Response('', 500);
          return http.Response(_profileJson(onboardingComplete: true), 200);
        }
        return http.Response('', 404);
      },
    );

    // The first check failed: a retry is offered instead of guessing.
    expect(find.byKey(const Key('onboarding-gate-retry')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byKey(const Key('onboarding-gate-retry')));
    await tester.pumpAndSettle();

    // The retry refetched (onboarding complete) → the shell.
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
