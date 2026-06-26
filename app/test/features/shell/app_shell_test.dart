// The shell owns bottom-nav tab selection via shellTabProvider. These tests
// drive it with an already-authenticated controller so the shell renders.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gymbuddy/core/design/design.dart';
import 'package:gymbuddy/features/auth/auth_controller.dart';
import 'package:gymbuddy/features/auth/auth_gate.dart';
import 'package:gymbuddy/features/shell/app_shell.dart';

ProviderContainer _authenticatedContainer() {
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith((ref) => AuthController()..signIn()),
    ],
  );
}

void main() {
  testWidgets('renders four navigation destinations, Home selected first',
      (WidgetTester tester) async {
    final container = _authenticatedContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.dark, home: const AuthGate()),
      ),
    );

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(container.read(shellTabProvider), 0);
  });

  testWidgets('tapping a destination updates the selected tab',
      (WidgetTester tester) async {
    final container = _authenticatedContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.dark, home: const AuthGate()),
      ),
    );

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.fitness_center_outlined),
      ),
    );
    await tester.pumpAndSettle();

    // Workout is the third destination (index 2).
    expect(container.read(shellTabProvider), 2);
  });
}
