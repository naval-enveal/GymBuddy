// OnboardingController owns the flow logic: selection, the per-step advance
// gate, and step navigation. These tests drive it directly (no widgets) to pin
// the rules the screen relies on.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/health/health_permission_service.dart';
import 'package:gymbuddy/features/onboarding/onboarding_controller.dart';
import 'package:gymbuddy/features/onboarding/onboarding_options.dart';

/// A health-permission service returning a fixed [status], for driving the
/// onboarding step's outcomes without touching a real platform store.
class _FakeHealthPermissionService implements HealthPermissionService {
  _FakeHealthPermissionService(this.status);

  final HealthPermissionStatus status;
  int calls = 0;

  @override
  Future<HealthPermissionStatus> request() async {
    calls++;
    return status;
  }
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  OnboardingController controller() =>
      container.read(onboardingControllerProvider.notifier);
  OnboardingState state() => container.read(onboardingControllerProvider);

  test('starts on the first step with an empty draft', () {
    expect(state().step, OnboardingStep.goals);
    expect(state().stepNumber, 1);
    expect(state().stepCount, OnboardingStep.values.length);
    expect(state().draft.goals, isEmpty);
    expect(state().completed, isFalse);
  });

  test('toggleGoal adds then removes a goal', () {
    controller().toggleGoal(FitnessGoal.buildMuscle);
    expect(state().draft.goals, {FitnessGoal.buildMuscle});
    controller().toggleGoal(FitnessGoal.buildMuscle);
    expect(state().draft.goals, isEmpty);
  });

  test('goals step gates advance on at least one selection', () {
    expect(controller().canAdvance, isFalse);
    controller().toggleGoal(FitnessGoal.loseWeight);
    expect(controller().canAdvance, isTrue);
  });

  test('next is a no-op until the current step is satisfied', () {
    controller().next();
    expect(state().step, OnboardingStep.goals);
    controller().toggleGoal(FitnessGoal.loseWeight);
    controller().next();
    expect(state().step, OnboardingStep.experience);
  });

  test('back returns to the previous step and no-ops on the first', () {
    controller().toggleGoal(FitnessGoal.loseWeight);
    controller().next();
    expect(state().step, OnboardingStep.experience);
    controller().back();
    expect(state().step, OnboardingStep.goals);
    controller().back();
    expect(state().step, OnboardingStep.goals);
  });

  test('setDaysPerWeek clamps to the valid range', () {
    controller().setDaysPerWeek(99);
    expect(state().draft.daysPerWeek, OnboardingLimits.maxDaysPerWeek);
    controller().setDaysPerWeek(0);
    expect(state().draft.daysPerWeek, OnboardingLimits.minDaysPerWeek);
  });

  test('selecting "none" equipment clears specific items and vice versa', () {
    controller().toggleEquipment(Equipment.dumbbells);
    controller().toggleEquipment(Equipment.barbell);
    expect(state().draft.equipment, {Equipment.dumbbells, Equipment.barbell});

    controller().toggleEquipment(Equipment.none);
    expect(state().draft.equipment, {Equipment.none});

    controller().toggleEquipment(Equipment.dumbbells);
    expect(state().draft.equipment, {Equipment.dumbbells});
  });

  test('addInjury trims, dedupes, truncates, and ignores blanks', () {
    controller().addInjury('  lower back  ');
    controller().addInjury('lower back');
    controller().addInjury('   ');
    expect(state().draft.injuries, ['lower back']);

    final long = 'x' * (OnboardingLimits.maxInjuryLength + 10);
    controller().addInjury(long);
    expect(state().draft.injuries.last.length, OnboardingLimits.maxInjuryLength);
  });

  test('removeInjury drops the matching entry', () {
    controller().addInjury('knee');
    controller().addInjury('shoulder');
    controller().removeInjury('knee');
    expect(state().draft.injuries, ['shoulder']);
  });

  test('injuries and body stats never block advance', () {
    // Walk to the injuries step.
    controller().toggleGoal(FitnessGoal.loseWeight);
    controller().next();
    controller().setExperience(ExperienceLevel.beginner);
    controller().next();
    controller().setDaysPerWeek(3);
    controller().next();
    controller().toggleEquipment(Equipment.bodyweight);
    controller().next();
    expect(state().step, OnboardingStep.injuries);
    expect(controller().canAdvance, isTrue);
    controller().next();
    expect(state().step, OnboardingStep.bodyStats);
    expect(controller().canAdvance, isTrue);
  });

  test('complete flips completed only when the last step is satisfied', () {
    // Reach the last step (health permission).
    controller().toggleGoal(FitnessGoal.loseWeight);
    controller().next();
    controller().setExperience(ExperienceLevel.beginner);
    controller().next();
    controller().setDaysPerWeek(3);
    controller().next();
    controller().toggleEquipment(Equipment.bodyweight);
    controller().next();
    controller().next();
    controller().next();
    expect(state().step, OnboardingStep.healthPermission);
    controller().complete();
    expect(state().completed, isTrue);
  });

  test('health permission is optional and starts unrequested', () {
    expect(
      state().draft.healthPermission,
      HealthPermissionStatus.notRequested,
    );
    // The health step never blocks advancing.
    controller().toggleGoal(FitnessGoal.loseWeight);
    controller().next();
    controller().setExperience(ExperienceLevel.beginner);
    controller().next();
    controller().setDaysPerWeek(3);
    controller().next();
    controller().toggleEquipment(Equipment.bodyweight);
    controller().next();
    controller().next();
    controller().next();
    expect(state().step, OnboardingStep.healthPermission);
    expect(controller().canAdvance, isTrue);
  });

  test('requestHealthPermission records the service outcome', () async {
    final fake = _FakeHealthPermissionService(HealthPermissionStatus.granted);
    final c = ProviderContainer(
      overrides: [
        healthPermissionServiceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(c.dispose);

    final ctrl = c.read(onboardingControllerProvider.notifier);
    await ctrl.requestHealthPermission();

    expect(fake.calls, 1);
    expect(
      c.read(onboardingControllerProvider).draft.healthPermission,
      HealthPermissionStatus.granted,
    );
    expect(c.read(onboardingControllerProvider).requestingHealth, isFalse);
  });

  test('requestHealthPermission records a denial too', () async {
    final fake = _FakeHealthPermissionService(HealthPermissionStatus.denied);
    final c = ProviderContainer(
      overrides: [
        healthPermissionServiceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(c.dispose);

    final ctrl = c.read(onboardingControllerProvider.notifier);
    await ctrl.requestHealthPermission();

    expect(
      c.read(onboardingControllerProvider).draft.healthPermission,
      HealthPermissionStatus.denied,
    );
  });
}
