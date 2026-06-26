// The auth gate is the only place the app branches on auth. These tests walk
// the full gate flow: signed-out landing → sign in → app shell → sign out →
// back to the landing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gymbuddy/core/storage/token_store.dart';
import 'package:gymbuddy/main.dart';

/// Boots the app with an empty (in-memory) token store, so launch-time session
/// restore resolves to the signed-out flow without touching platform storage.
Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      ],
      child: const GymBuddyApp(),
    ),
  );
  // Let the restore splash resolve before driving the gate.
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts signed out: shows the landing, not the shell',
      (WidgetTester tester) async {
    await _pumpApp(tester);

    expect(find.text('Get started'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('signing in reveals the shell with all four tabs',
      (WidgetTester tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

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
    await _pumpApp(tester);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

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
