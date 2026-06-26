// Smoke tests: the app boots into the auth gate, which (signed out by default)
// renders the branded signed-out landing from Riverpod state.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gymbuddy/core/app_info.dart';
import 'package:gymbuddy/core/storage/token_store.dart';
import 'package:gymbuddy/main.dart';

void main() {
  testWidgets('GymBuddy app boots and shows the signed-out landing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        ],
        child: const GymBuddyApp(),
      ),
    );
    // Launch shows a splash while the (empty) token store is read, then
    // resolves to the signed-out landing.
    await tester.pumpAndSettle();

    expect(find.text('GymBuddy'), findsOneWidget);
    expect(find.text('Your AI training buddy'), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('signed-out landing renders branding from appInfoProvider',
      (WidgetTester tester) async {
    // Overriding the provider proves the screen reads from Riverpod rather than
    // hardcoding its copy — i.e. the ProviderScope wiring is actually used.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          appInfoProvider.overrideWithValue(
            const AppInfo(name: 'Overridden', tagline: 'From a provider'),
          ),
        ],
        child: const GymBuddyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Overridden'), findsOneWidget);
    expect(find.text('From a provider'), findsOneWidget);
    expect(find.text('GymBuddy'), findsNothing);
  });
}
