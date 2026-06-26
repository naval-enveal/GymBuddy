import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/design/design.dart';
import 'package:gymbuddy/core/health/health_permission_service.dart';
import 'package:gymbuddy/features/onboarding/onboarding_controller.dart';
import 'package:gymbuddy/features/onboarding/onboarding_gate.dart';
import 'package:gymbuddy/features/onboarding/onboarding_options.dart';

/// The multi-step onboarding flow — goals, experience, days/week, equipment,
/// injuries, and body stats.
///
/// All flow logic (selection, validation gating, step navigation) lives in
/// [onboardingControllerProvider] per the no-logic-in-widgets rule; this widget
/// only renders [OnboardingState] and forwards taps. The body-stats step keeps
/// local [TextEditingController]s for its text inputs and does presentation-level
/// range parsing before handing values to the controller (mirroring the pattern
/// in `AuthScreen`). The final health-permission step forwards its "Connect" tap
/// to the controller, which drives the platform prompt through
/// [healthPermissionServiceProvider].
///
/// Finishing persists the answers to the Profile API via
/// [OnboardingController.complete] (which flips [OnboardingState.completed] on
/// success, or surfaces an inline error to retry). On that flip the screen tells
/// the [onboardingGateProvider] to advance to the app shell — the routing the
/// `AuthGate` reads — so the user lands on Home.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    // Once the flow completes (draft persisted), flip the gate so the AuthGate
    // routes on to the shell. Done via a listener rather than in the controller
    // so the flow stays decoupled from the routing layer.
    ref.listen(
      onboardingControllerProvider.select((s) => s.completed),
      (_, completed) {
        if (completed) {
          ref.read(onboardingGateProvider.notifier).markComplete();
        }
      },
    );
    // Watching the full state above already rebuilds on every change, so reading
    // the derived gate off the controller here stays in sync.
    final canAdvance = controller.canAdvance;

    return Scaffold(
      appBar: AppBar(
        leading: state.isFirstStep
            ? null
            : IconButton(
                key: const Key('onboarding-back'),
                icon: const Icon(Icons.arrow_back),
                onPressed: controller.back,
              ),
        title: Text('Step ${state.stepNumber} of ${state.stepCount}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            key: const Key('onboarding-progress'),
            value: state.stepNumber / state.stepCount,
            minHeight: 4,
            backgroundColor: AppColors.surfaceBright,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: _StepBody(state: state, controller: controller),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.saveError case final error?) ...[
                    Text(
                      key: const Key('onboarding-save-error'),
                      error,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  PrimaryButton(
                    key: const Key('onboarding-next'),
                    label: state.isLastStep ? 'Finish' : 'Continue',
                    isLoading: state.saving,
                    onPressed: canAdvance && !state.saving
                        ? (state.isLastStep
                            ? () => unawaited(controller.complete())
                            : controller.next)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Switches the visible step's content. Stateless steps render inline; the
/// body-stats step needs text controllers, so it's its own stateful widget.
class _StepBody extends StatelessWidget {
  const _StepBody({required this.state, required this.controller});

  final OnboardingState state;
  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    switch (state.step) {
      case OnboardingStep.goals:
        return _GoalsStep(state: state, controller: controller);
      case OnboardingStep.experience:
        return _ExperienceStep(state: state, controller: controller);
      case OnboardingStep.daysPerWeek:
        return _DaysPerWeekStep(state: state, controller: controller);
      case OnboardingStep.equipment:
        return _EquipmentStep(state: state, controller: controller);
      case OnboardingStep.injuries:
        return _InjuriesStep(state: state, controller: controller);
      case OnboardingStep.bodyStats:
        return _BodyStatsStep(state: state, controller: controller);
      case OnboardingStep.healthPermission:
        return _HealthPermissionStep(state: state, controller: controller);
    }
  }
}

/// Shared heading block for every step: a title and a clarifying line.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

/// A tappable option row used by the select steps. Shows a [label] with an
/// optional [subtitle] and a trailing check when [selected]; the border and
/// fill shift to the accent when active.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: selected ? AppColors.accentDim : AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.cardRadius,
          child: Container(
            constraints:
                const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadii.cardRadius,
              border: Border.all(
                color: selected ? AppColors.accent : AppColors.outline,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.titleMedium),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle, color: AppColors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalsStep extends StatelessWidget {
  const _GoalsStep({required this.state, required this.controller});

  final OnboardingState state;
  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'What are your goals?',
          subtitle: 'Pick everything that applies — you can train for more '
              'than one.',
        ),
        for (final goal in FitnessGoal.values)
          _OptionTile(
            key: Key('goal-${goal.wire}'),
            label: goal.label,
            selected: state.draft.goals.contains(goal),
            onTap: () => controller.toggleGoal(goal),
          ),
      ],
    );
  }
}

class _ExperienceStep extends StatelessWidget {
  const _ExperienceStep({required this.state, required this.controller});

  final OnboardingState state;
  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'How much training experience do you have?',
          subtitle: 'This sets the starting difficulty of your plan.',
        ),
        for (final level in ExperienceLevel.values)
          _OptionTile(
            key: Key('experience-${level.wire}'),
            label: level.label,
            subtitle: level.description,
            selected: state.draft.experience == level,
            onTap: () => controller.setExperience(level),
          ),
      ],
    );
  }
}

class _DaysPerWeekStep extends StatelessWidget {
  const _DaysPerWeekStep({required this.state, required this.controller});

  final OnboardingState state;
  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = state.draft.daysPerWeek;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'How many days a week can you train?',
          subtitle: 'Be realistic — a plan you can keep beats an ideal one you '
              "can't.",
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var days = OnboardingLimits.minDaysPerWeek;
                days <= OnboardingLimits.maxDaysPerWeek;
                days++)
              _DayChip(
                key: Key('days-$days'),
                days: days,
                selected: selected == days,
                onTap: () => controller.setDaysPerWeek(days),
              ),
          ],
        ),
        if (selected != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            '$selected ${selected == 1 ? 'day' : 'days'} per week',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.days,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final int days;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? AppColors.accent : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: BorderSide(
          color: selected ? AppColors.accent : AppColors.outline,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: SizedBox(
          width: AppSpacing.minTouchTarget,
          height: AppSpacing.minTouchTarget,
          child: Center(
            child: Text(
              '$days',
              style: theme.textTheme.titleLarge?.copyWith(
                color: selected ? AppColors.onAccent : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EquipmentStep extends StatelessWidget {
  const _EquipmentStep({required this.state, required this.controller});

  final OnboardingState state;
  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'What equipment can you use?',
          subtitle: 'Select all you have access to. Choosing "None" clears the '
              'rest.',
        ),
        for (final item in Equipment.values)
          _OptionTile(
            key: Key('equipment-${item.wire}'),
            label: item.label,
            selected: state.draft.equipment.contains(item),
            onTap: () => controller.toggleEquipment(item),
          ),
      ],
    );
  }
}

class _InjuriesStep extends StatefulWidget {
  const _InjuriesStep({required this.state, required this.controller});

  final OnboardingState state;
  final OnboardingController controller;

  @override
  State<_InjuriesStep> createState() => _InjuriesStepState();
}

class _InjuriesStepState extends State<_InjuriesStep> {
  final _injuryController = TextEditingController();

  @override
  void dispose() {
    _injuryController.dispose();
    super.dispose();
  }

  void _add() {
    widget.controller.addInjury(_injuryController.text);
    _injuryController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final injuries = widget.state.draft.injuries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'Any injuries or limitations?',
          subtitle: 'Optional. We use these to avoid risky movements. Add one '
              'at a time.',
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const Key('injury-field'),
                controller: _injuryController,
                maxLength: OnboardingLimits.maxInjuryLength,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'e.g. lower back, left knee',
                  counterText: '',
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              key: const Key('injury-add'),
              icon: const Icon(Icons.add),
              onPressed: _add,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (injuries.isEmpty)
          Text(
            'No injuries added.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final injury in injuries)
                Chip(
                  key: Key('injury-chip-$injury'),
                  label: Text(injury),
                  onDeleted: () => widget.controller.removeInjury(injury),
                ),
            ],
          ),
      ],
    );
  }
}

class _BodyStatsStep extends StatefulWidget {
  const _BodyStatsStep({required this.state, required this.controller});

  final OnboardingState state;
  final OnboardingController controller;

  @override
  State<_BodyStatsStep> createState() => _BodyStatsStepState();
}

class _BodyStatsStepState extends State<_BodyStatsStep> {
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _ageController;

  @override
  void initState() {
    super.initState();
    final stats = widget.state.draft.bodyStats;
    _heightController =
        TextEditingController(text: stats.heightCm?.toString() ?? '');
    _weightController =
        TextEditingController(text: stats.weightKg?.toString() ?? '');
    _ageController = TextEditingController(text: stats.age?.toString() ?? '');
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  /// Parses [text] to an int and keeps it only if it falls in [min, max];
  /// anything blank or out of range is dropped to null (the field is optional,
  /// and only valid values reach the controller — mirroring the server bounds).
  int? _inRange(String text, int min, int max) {
    final value = int.tryParse(text.trim());
    if (value == null || value < min || value > max) return null;
    return value;
  }

  void _push({BiologicalSex? sex}) {
    widget.controller.setBodyStats(
      BodyStats(
        heightCm: _inRange(
          _heightController.text,
          OnboardingLimits.minHeightCm,
          OnboardingLimits.maxHeightCm,
        ),
        weightKg: _inRange(
          _weightController.text,
          OnboardingLimits.minWeightKg,
          OnboardingLimits.maxWeightKg,
        ),
        age: _inRange(
          _ageController.text,
          OnboardingLimits.minAge,
          OnboardingLimits.maxAge,
        ),
        sex: sex ?? widget.state.draft.bodyStats.sex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sex = widget.state.draft.bodyStats.sex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'A few body stats',
          subtitle: 'Optional, but they help tailor your plan and targets.',
        ),
        _NumberField(
          fieldKey: const Key('bodystat-height'),
          controller: _heightController,
          label: 'Height (cm)',
          onChanged: (_) => _push(),
        ),
        const SizedBox(height: AppSpacing.md),
        _NumberField(
          fieldKey: const Key('bodystat-weight'),
          controller: _weightController,
          label: 'Weight (kg)',
          onChanged: (_) => _push(),
        ),
        const SizedBox(height: AppSpacing.md),
        _NumberField(
          fieldKey: const Key('bodystat-age'),
          controller: _ageController,
          label: 'Age',
          onChanged: (_) => _push(),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Sex', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final option in BiologicalSex.values)
          _OptionTile(
            key: Key('sex-${option.wire}'),
            label: option.label,
            selected: sex == option,
            onTap: () => _push(sex: option),
          ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    );
  }
}

/// The closing step: asks for read access to the device's health data so the
/// M5 vitals dashboard can show resting HR, HRV, sleep, and readiness. Optional
/// — the bottom "Finish" button completes the flow whether or not the user
/// connects, and a denial doesn't block. The actual prompt is driven by the
/// controller through [healthPermissionServiceProvider]; this step only renders
/// the rationale, the "Connect" action, and the recorded outcome.
class _HealthPermissionStep extends StatelessWidget {
  const _HealthPermissionStep({required this.state, required this.controller});

  final OnboardingState state;
  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = state.draft.healthPermission;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'Connect your health data',
          subtitle: 'Optional. GymBuddy reads vitals to gauge recovery and '
              'tailor each session. Your data stays on your device unless you '
              'choose to sync.',
        ),
        for (final line in const [
          'Resting heart rate & HRV',
          'Sleep & steps',
          'A daily readiness signal',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.check, color: AppColors.accent, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(line, style: theme.textTheme.bodyLarge)),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          key: const Key('health-connect'),
          label: status == HealthPermissionStatus.granted
              ? 'Connected'
              : 'Connect health data',
          icon: status == HealthPermissionStatus.granted
              ? Icons.check_circle
              : Icons.favorite_outline,
          isLoading: state.requestingHealth,
          // Once granted there's nothing more to ask; disable the re-tap.
          onPressed: status == HealthPermissionStatus.granted
              ? null
              : () => unawaited(controller.requestHealthPermission()),
        ),
        if (_feedback(status) case final message?) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            key: const Key('health-status'),
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  /// User-facing note for a recorded [status]; null before the first ask, when
  /// there's nothing to report.
  String? _feedback(HealthPermissionStatus status) {
    switch (status) {
      case HealthPermissionStatus.notRequested:
        return null;
      case HealthPermissionStatus.granted:
        return 'Health data connected. You can finish setting up.';
      case HealthPermissionStatus.denied:
        return "No problem — you can connect later in Settings. We'll show "
            'manual stats in the meantime.';
      case HealthPermissionStatus.unavailable:
        return "Health data isn't available on this device. You can finish "
            'and add stats manually.';
    }
  }
}
