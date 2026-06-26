import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/features/onboarding/onboarding_options.dart';

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
  });

  final Set<FitnessGoal> goals;
  final ExperienceLevel? experience;
  final int? daysPerWeek;
  final Set<Equipment> equipment;
  final List<String> injuries;
  final BodyStats bodyStats;

  OnboardingDraft copyWith({
    Set<FitnessGoal>? goals,
    ExperienceLevel? experience,
    int? daysPerWeek,
    Set<Equipment>? equipment,
    List<String>? injuries,
    BodyStats? bodyStats,
  }) =>
      OnboardingDraft(
        goals: goals ?? this.goals,
        experience: experience ?? this.experience,
        daysPerWeek: daysPerWeek ?? this.daysPerWeek,
        equipment: equipment ?? this.equipment,
        injuries: injuries ?? this.injuries,
        bodyStats: bodyStats ?? this.bodyStats,
      );
}

/// Where the flow is right now: the current step plus the answers so far and
/// whether the user has finished.
class OnboardingState {
  const OnboardingState({
    this.stepIndex = 0,
    this.draft = const OnboardingDraft(),
    this.completed = false,
  });

  /// Index into [OnboardingStep.values] for the visible step.
  final int stepIndex;

  /// Answers collected so far.
  final OnboardingDraft draft;

  /// True once the user finishes the last step. Persisting the [draft] and
  /// routing onward are wired in later M3 tasks; this flag marks the handoff.
  final bool completed;

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
  }) =>
      OnboardingState(
        stepIndex: stepIndex ?? this.stepIndex,
        draft: draft ?? this.draft,
        completed: completed ?? this.completed,
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

  /// Marks the flow finished. Persisting the draft and routing onward land in
  /// later M3 tasks.
  void complete() {
    if (!canAdvance) return;
    state = state.copyWith(completed: true);
  }
}

/// The onboarding flow's state and controller. `autoDispose` so leaving and
/// re-entering the flow starts fresh.
final onboardingControllerProvider =
    NotifierProvider.autoDispose<OnboardingController, OnboardingState>(
  OnboardingController.new,
);
