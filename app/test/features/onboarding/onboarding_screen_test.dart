// OnboardingScreen renders the multi-step flow driven by OnboardingController.
// These tests assert the advance gate (Continue disabled until a step is
// satisfied), step navigation (forward + back + progress), and that finishing
// the last step flips the flow to completed.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/health/health_permission_service.dart';
import 'package:gymbuddy/features/onboarding/onboarding_controller.dart';
import 'package:gymbuddy/features/onboarding/onboarding_options.dart';
import 'package:gymbuddy/features/onboarding/onboarding_screen.dart';

/// A health-permission service returning a fixed [status].
class _FakeHealthPermissionService implements HealthPermissionService {
  _FakeHealthPermissionService(this.status);

  final HealthPermissionStatus status;

  @override
  Future<HealthPermissionStatus> request() async => status;
}

Future<void> _mount(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: OnboardingScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _pump(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await _mount(tester, container);
  return container;
}

OnboardingState _state(ProviderContainer c) =>
    c.read(onboardingControllerProvider);

bool _continueEnabled(WidgetTester tester) {
  final button = tester.widget<FilledButton>(
    find.descendant(
      of: find.byKey(const Key('onboarding-next')),
      matching: find.byType(FilledButton),
    ),
  );
  return button.onPressed != null;
}

void main() {
  testWidgets('Continue is gated until a goal is selected',
      (WidgetTester tester) async {
    await _pump(tester);

    expect(find.text('What are your goals?'), findsOneWidget);
    expect(find.text('Step 1 of 7'), findsOneWidget);
    expect(_continueEnabled(tester), isFalse);

    await tester.tap(find.byKey(const Key('goal-build_muscle')));
    await tester.pumpAndSettle();

    expect(_continueEnabled(tester), isTrue);
  });

  testWidgets('back button is hidden on the first step, present after advancing',
      (WidgetTester tester) async {
    await _pump(tester);

    expect(find.byKey(const Key('onboarding-back')), findsNothing);

    await tester.tap(find.byKey(const Key('goal-build_muscle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 7'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-back')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-back')));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 7'), findsOneWidget);
  });

  testWidgets('walks every step and finishing flips completed',
      (WidgetTester tester) async {
    final container = await _pump(tester);

    // 1 · Goals
    await tester.tap(find.byKey(const Key('goal-lose_weight')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    // 2 · Experience
    await tester.tap(find.byKey(const Key('experience-beginner')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    // 3 · Days per week
    await tester.tap(find.byKey(const Key('days-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    // 4 · Equipment
    await tester.tap(find.byKey(const Key('equipment-bodyweight')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    // 5 · Injuries (optional) — Continue is enabled immediately.
    expect(find.text('Step 5 of 7'), findsOneWidget);
    expect(_continueEnabled(tester), isTrue);
    await tester.enterText(find.byKey(const Key('injury-field')), 'lower back');
    await tester.tap(find.byKey(const Key('injury-add')));
    await tester.pumpAndSettle();
    expect(find.text('lower back'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    // 6 · Body stats (optional) — Continue on to the final step.
    expect(find.text('Step 6 of 7'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('bodystat-height')), '180');
    await tester.enterText(find.byKey(const Key('bodystat-weight')), '78');
    await tester.tap(find.byKey(const Key('sex-male')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    // 7 · Health permission (optional) — connect, then finish.
    expect(find.text('Step 7 of 7'), findsOneWidget);
    expect(find.text('Connect your health data'), findsOneWidget);
    await tester.tap(find.byKey(const Key('health-connect')));
    await tester.pumpAndSettle();
    // The default MockHealthPermissionService grants.
    expect(
      _state(container).draft.healthPermission,
      HealthPermissionStatus.granted,
    );

    expect(_state(container).completed, isFalse);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    final state = _state(container);
    expect(state.completed, isTrue);
    expect(state.draft.goals, contains(FitnessGoal.loseWeight));
    expect(state.draft.experience, ExperienceLevel.beginner);
    expect(state.draft.daysPerWeek, 3);
    expect(state.draft.equipment, contains(Equipment.bodyweight));
    expect(state.draft.injuries, ['lower back']);
    expect(state.draft.bodyStats.heightCm, 180);
    expect(state.draft.bodyStats.weightKg, 78);
    expect(state.draft.bodyStats.sex, BiologicalSex.male);
  });

  testWidgets('out-of-range body stats are dropped to null',
      (WidgetTester tester) async {
    final container = await _pump(tester);
    final controller = container.read(onboardingControllerProvider.notifier);

    // Fast-forward to the body-stats step via the controller.
    controller
      ..toggleGoal(FitnessGoal.loseWeight)
      ..next()
      ..setExperience(ExperienceLevel.beginner)
      ..next()
      ..setDaysPerWeek(3)
      ..next()
      ..toggleEquipment(Equipment.bodyweight)
      ..next()
      ..next();
    await tester.pumpAndSettle();
    expect(_state(container).step, OnboardingStep.bodyStats);

    // 5 is below the minimum age (13) — it must not be stored.
    await tester.enterText(find.byKey(const Key('bodystat-age')), '5');
    await tester.pumpAndSettle();

    expect(_state(container).draft.bodyStats.age, isNull);
  });

  testWidgets('health step surfaces a denial without blocking finish',
      (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        healthPermissionServiceProvider.overrideWithValue(
          _FakeHealthPermissionService(HealthPermissionStatus.denied),
        ),
      ],
    );
    addTearDown(container.dispose);
    await _mount(tester, container);
    final controller = container.read(onboardingControllerProvider.notifier);

    // Fast-forward to the final (health) step via the controller.
    controller
      ..toggleGoal(FitnessGoal.loseWeight)
      ..next()
      ..setExperience(ExperienceLevel.beginner)
      ..next()
      ..setDaysPerWeek(3)
      ..next()
      ..toggleEquipment(Equipment.bodyweight)
      ..next()
      ..next()
      ..next();
    await tester.pumpAndSettle();
    expect(_state(container).step, OnboardingStep.healthPermission);

    // A denial is recorded and shown, but the step is still finishable.
    await tester.tap(find.byKey(const Key('health-connect')));
    await tester.pumpAndSettle();
    expect(
      _state(container).draft.healthPermission,
      HealthPermissionStatus.denied,
    );
    expect(find.byKey(const Key('health-status')), findsOneWidget);

    expect(_continueEnabled(tester), isTrue);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(_state(container).completed, isTrue);
  });
}
