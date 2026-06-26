// Smoke tests: the app boots, and the landing screen renders Riverpod state.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gymbuddy/core/app_info.dart';
import 'package:gymbuddy/main.dart';

void main() {
  testWidgets('GymBuddy app boots and shows the landing screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GymBuddyApp()));

    expect(find.text('GymBuddy'), findsOneWidget);
    expect(find.text('Your AI training buddy'), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center), findsOneWidget);
  });

  testWidgets('BootScreen renders text from appInfoProvider',
      (WidgetTester tester) async {
    // Overriding the provider proves the screen reads from Riverpod rather than
    // hardcoding its copy — i.e. the ProviderScope wiring is actually used.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appInfoProvider.overrideWithValue(
            const AppInfo(name: 'Overridden', tagline: 'From a provider'),
          ),
        ],
        child: const GymBuddyApp(),
      ),
    );

    expect(find.text('Overridden'), findsOneWidget);
    expect(find.text('From a provider'), findsOneWidget);
    expect(find.text('GymBuddy'), findsNothing);
  });
}
