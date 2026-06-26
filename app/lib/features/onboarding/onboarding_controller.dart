import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/health/health_permission_service.dart';
import 'package:gymbuddy/core/network/api_client.dart';
import 'package:gymbuddy/features/onboarding/onboarding_options.dart';
import 'package:gymbuddy/features/onboarding/profile_api.dart';

/// Valid ranges for body-stat inputs, mirrored from the Profile model's schema
/// bounds (`server/src/models/profile.model.js`) so the client rejects what the
/// backend would.
abstract final class OnboardingLimits {
  static const int minHeightCm = 50;
  static const int maxHeightCm = 300;
  static const int minWeightKg = 20;
  static const int maxWeightKg = 500;
  static const int minAge = 13;
  static const int maxAge = 120;
  static const int minDaysPerWeek = 1;
  static const int maxDaysPerWeek = 7;

  /// Per-injury character cap (server stores `maxlength: 120`).
  static const int maxInjuryLength = 120;
}

/// The ordered steps of the onboarding flow. The flow renders these in
/// declaration order; [OnboardingState.stepIndex] points at one of them.
enum OnboardingStep {
  goals,
  experience,
  daysPerWeek,
  equipment,
  injuries,
  bodyStats,
  healthPermission,
}

/// Optional physical stats captured on the final step. Every field is
/// nullable: the user may skip any of them, and only in-range values are ever
/// stored here (the screen validates before handing them over).
class BodyStats {
  const BodyStats({this.heightCm, this.weightKg, this.age, this.sex});

  final int? heightCm;
  final int? weightKg;
  final int? age;
  final BiologicalSex? sex;

  bool get isEmpty =>
      heightCm == null && weightKg == null && age == null && sex == null;

  BodyStats copyWith({
    int? heightCm,
    int? weightKg,
    int? age,
    BiologicalSex? sex,
  }) =>
      BodyStats(
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        age: age ?? this.age,
        sex: sex ?? this.sex,
      );

  @override
  bool operator ==(Object other) =>
      other is BodyStats &&
      other.heightCm == heightCm &&
      other.weightKg == weightKg &&
      other.age == age &&
      other.sex == sex;

  @override
  int get hashCode => Object.hash(heightCm, weightKg, age, sex);
}

/// The answers gathered across the flow. This is the payload a later task maps
/// onto the Profile API; until then it's the flow's single source of truth.
class OnboardingDraft {
  const OnboardingDraft({
    this.goals = const {},
    this.experience,
    this.daysPerWeek,
    this.equipment = const {},
    this.injuries = const [],
    this.bodyStats = const BodyStats(),
    this.healthPermission = HealthPermissionStatus.notRequested,
  });

  final Set<FitnessGoal> goals;
  final ExperienceLevel? experience;
  final int? daysPerWeek;
  final Set<Equipment> equipment;
  final List<String> injuries;
  final BodyStats bodyStats;

  /// Result of the health-data permission ask. A device-level grant, so it's
  /// kept here for the flow but isn't part of the Profile API payload.
  final HealthPermissionStatus healthPermission;

  OnboardingDraft copyWith({
    Set<FitnessGoal>? goals,
    ExperienceLevel? experience,
    int? daysPerWeek,
    Set<Equipment>? equipment,
    List<String>? injuries,
    BodyStats? bodyStats,
    HealthPermissionStatus? healthPermission,
  }) =>
      OnboardingDraft(
        goals: goals ?? this.goals,
        experience: experience ?? this.experience,
        daysPerWeek: daysPerWeek ?? this.daysPerWeek,
        equipment: equipment ?? this.equipment,
        injuries: injuries ?? this.injuries,
        bodyStats: bodyStats ?? this.bodyStats,
        healthPermission: healthPermission ?? this.healthPermission,
      );
}

/// Where the flow is right now: the current step plus the answers so far and
/// whether the user has finished.
class OnboardingState {
  const OnboardingState({
    this.stepIndex = 0,
    this.draft = const OnboardingDraft(),
    this.completed = false,
    this.requestingHealth = false,
    this.saving = false,
    this.saveError,
  });

  /// Index into [OnboardingStep.values] for the visible step.
  final int stepIndex;

  /// Answers collected so far.
  final OnboardingDraft draft;

  /// True once the user finishes the last step AND the draft has been persisted
  /// via the Profile API. Routing onward (to Home) is wired in the next M3 task;
  /// this flag marks the handoff.
  final bool completed;

  /// True while the health-permission prompt is in flight, so the step's
  /// "Connect" button shows a spinner and can't be re-fired.
  final bool requestingHealth;

  /// True while [OnboardingController.complete] is persisting the draft, so the
  /// "Finish" button shows a spinner and can't be re-fired.
  final bool saving;

  /// A server- or network-authored message if the last save attempt failed;
  /// null otherwise. The user can retry by tapping "Finish" again.
  final String? saveError;

  OnboardingStep get step => OnboardingStep.values[stepIndex];

  bool get isFirstStep => stepIndex == 0;

  bool get isLastStep => stepIndex == OnboardingStep.values.length - 1;

  /// 1-based step number for display ("Step 2 of 6").
  int get stepNumber => stepIndex + 1;

  int get stepCount => OnboardingStep.values.length;

  OnboardingState copyWith({
    int? stepIndex,
    OnboardingDraft? draft,
    bool? completed,
    bool? requestingHealth,
    bool? saving,
    String? saveError,
    bool clearSaveError = false,
  }) =>
      OnboardingState(
        stepIndex: stepIndex ?? this.stepIndex,
        draft: draft ?? this.draft,
        completed: completed ?? this.completed,
        requestingHealth: requestingHealth ?? this.requestingHealth,
        saving: saving ?? this.saving,
        saveError: clearSaveError ? null : (saveError ?? this.saveError),
      );
}

/// Drives the multi-step onboarding flow: holds the draft answers, gates
/// forward navigation on each step's requirement, and tracks the step index.
///
/// All flow logic lives here rather than in the screen (per the
/// no-logic-in-widgets rule); the widget only renders [state] and forwards user
/// actions. `autoDispose` so a fresh visit starts clean.
class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  /// Adds or removes [goal] from the selection.
  void toggleGoal(FitnessGoal goal) {
    final next = Set<FitnessGoal>.of(state.draft.goals);
    if (!next.add(goal)) next.remove(goal);
    state = state.copyWith(draft: state.draft.copyWith(goals: next));
  }

  void setExperience(ExperienceLevel experience) {
    state = state.copyWith(draft: state.draft.copyWith(experience: experience));
  }

  /// Sets training days per week, clamped to the valid [OnboardingLimits] range.
  void setDaysPerWeek(int days) {
    final clamped =
        days.clamp(OnboardingLimits.minDaysPerWeek, OnboardingLimits.maxDaysPerWeek);
    state = state.copyWith(draft: state.draft.copyWith(daysPerWeek: clamped));
  }

  /// Adds or removes [item] from the equipment selection. Selecting "none"
  /// clears everything else, and selecting anything else clears "none", since
  /// "I have no equipment" can't coexist with a specific item.
  void toggleEquipment(Equipment item) {
    final next = Set<Equipment>.of(state.draft.equipment);
    if (next.contains(item)) {
      next.remove(item);
    } else {
      if (item == Equipment.none) {
        next.clear();
      } else {
        next.remove(Equipment.none);
      }
      next.add(item);
    }
    state = state.copyWith(draft: state.draft.copyWith(equipment: next));
  }

  /// Adds a trimmed injury note. No-ops on blank or duplicate entries; longer
  /// entries are truncated to the server's per-injury cap.
  void addInjury(String injury) {
    var trimmed = injury.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.length > OnboardingLimits.maxInjuryLength) {
      trimmed = trimmed.substring(0, OnboardingLimits.maxInjuryLength);
    }
    if (state.draft.injuries.contains(trimmed)) return;
    state = state.copyWith(
      draft: state.draft.copyWith(
        injuries: [...state.draft.injuries, trimmed],
      ),
    );
  }

  void removeInjury(String injury) {
    if (!state.draft.injuries.contains(injury)) return;
    state = state.copyWith(
      draft: state.draft.copyWith(
        injuries: state.draft.injuries.where((i) => i != injury).toList(),
      ),
    );
  }

  /// Replaces the body stats with [stats]. The screen validates ranges before
  /// calling this, so only in-range (or null) values arrive here.
  void setBodyStats(BodyStats stats) {
    state = state.copyWith(draft: state.draft.copyWith(bodyStats: stats));
  }

  /// Prompts for health-data access via [healthPermissionServiceProvider] and
  /// records the outcome on the draft. The platform talks to HealthKit /
  /// Health Connect; feature code only sees the resulting status. No-ops if a
  /// request is already in flight. The step is optional, so a denial or an
  /// unavailable platform never blocks finishing.
  Future<void> requestHealthPermission() async {
    if (state.requestingHealth) return;
    state = state.copyWith(requestingHealth: true);
    final HealthPermissionStatus status;
    try {
      status = await ref.read(healthPermissionServiceProvider).request();
    } finally {
      // Always clear the in-flight flag, even if the platform call throws.
      state = state.copyWith(requestingHealth: false);
    }
    state = state.copyWith(
      draft: state.draft.copyWith(healthPermission: status),
    );
  }

  /// Whether the current step's requirement is met, gating the Next button.
  /// Injuries and body stats are optional, so they never block.
  bool get canAdvance {
    switch (state.step) {
      case OnboardingStep.goals:
        return state.draft.goals.isNotEmpty;
      case OnboardingStep.experience:
        return state.draft.experience != null;
      case OnboardingStep.daysPerWeek:
        return state.draft.daysPerWeek != null;
      case OnboardingStep.equipment:
        return state.draft.equipment.isNotEmpty;
      case OnboardingStep.injuries:
      case OnboardingStep.bodyStats:
      case OnboardingStep.healthPermission:
        return true;
    }
  }

  /// Advances to the next step. No-op if the current step isn't satisfied or
  /// we're already on the last step (use [complete] to finish).
  void next() {
    if (!canAdvance || state.isLastStep) return;
    state = state.copyWith(stepIndex: state.stepIndex + 1);
  }

  /// Returns to the previous step. No-op on the first step.
  void back() {
    if (state.isFirstStep) return;
    state = state.copyWith(stepIndex: state.stepIndex - 1);
  }

  /// Finishes the flow: persists the gathered answers to the Profile API, then
  /// flips [OnboardingState.completed] (the handoff point for the routing task
  /// that follows). On a failed save it records [OnboardingState.saveError] and
  /// leaves the flow on the last step so the user can retry; the
  /// device-level health-permission grant is intentionally not persisted (see
  /// [ProfileApi]). No-op if the last step isn't satisfied or a save is already
  /// in flight.
  Future<void> complete() async {
    if (!canAdvance || state.saving) return;
    state = state.copyWith(saving: true, clearSaveError: true);
    try {
      await ref.read(profileApiProvider).saveOnboarding(state.draft);
    } on ApiException catch (e) {
      state = state.copyWith(saving: false, saveError: e.message);
      return;
    } catch (_) {
      state = state.copyWith(
        saving: false,
        saveError: 'Something went wrong. Please try again.',
      );
      return;
    }
    state = state.copyWith(saving: false, completed: true);
  }
}

/// The onboarding flow's state and controller. `autoDispose` so leaving and
/// re-entering the flow starts fresh.
final onboardingControllerProvider =
    NotifierProvider.autoDispose<OnboardingController, OnboardingState>(
  OnboardingController.new,
);
