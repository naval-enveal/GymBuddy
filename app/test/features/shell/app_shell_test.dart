// The shell owns bottom-nav tab selection via shellTabProvider. These tests
// drive it with an already-authenticated controller so the shell renders.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gymbuddy/core/design/design.dart';
import 'package:gymbuddy/features/auth/auth_controller.dart';
import 'package:gymbuddy/features/auth/auth_gate.dart';
import 'package:gymbuddy/features/auth/auth_status.dart';
import 'package:gymbuddy/features/onboarding/onboarding_gate.dart';
import 'package:gymbuddy/features/plans/plan_api.dart';
import 'package:gymbuddy/features/plans/plan_models.dart';
import 'package:gymbuddy/features/shell/app_shell.dart';

/// An [AuthController] that boots already authenticated, so the gate renders
/// the shell without exercising the signed-out landing first.
class _AuthedController extends AuthController {
  @override
  AuthStatus build() => AuthStatus.authenticated;
}

/// A [PlanApi] returning an empty library, so the Plans tab (built eagerly in
/// the shell's IndexedStack) doesn't reach for the real network.
class _StubPlanApi implements PlanApi {
  @override
  Future<List<PlanTemplate>> fetchTemplates() async => const [];

  @override
  Future<PlanTemplate?> fetchActivePlan() async => null;

  @override
  Future<PlanTemplate> adoptPlan(String templateId) =>
      throw UnimplementedError();
}

/// An onboarding gate that reports onboarding already complete, so the auth gate
/// routes straight to the shell without a profile round-trip.
class _OnboardedGate extends OnboardingGateController {
  @override
  Future<bool> build() async => true;
}

ProviderContainer _authenticatedContainer() {
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(_AuthedController.new),
      onboardingGateProvider.overrideWith(_OnboardedGate.new),
      planApiProvider.overrideWithValue(_StubPlanApi()),
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
    // Let the onboarding gate resolve (to onboarded) so the shell renders.
    await tester.pumpAndSettle();

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
    // Let the onboarding gate resolve (to onboarded) so the shell renders.
    await tester.pumpAndSettle();

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
