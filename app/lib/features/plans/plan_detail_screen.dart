import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/design/design.dart';
import 'package:gymbuddy/core/pose/pose_exercise_catalog.dart';
import 'package:gymbuddy/features/plans/active_plan_controller.dart';
import 'package:gymbuddy/features/plans/plan_models.dart';

/// Detail view for a single template [plan]: its training days and the
/// exercises within each, with every exercise marked form-tracked vs
/// rep-tracked-only (the glasses are first-person POV, so form correction ships
/// only for mirror/POV-visible movements).
///
/// The plan content is loaded by the Plans list, but the screen watches
/// [activePlanControllerProvider] to drive the "Use this plan" action and to
/// surface whether this plan is already the user's active one. All I/O stays in
/// the controller (no logic in widgets).
class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({required this.plan, super.key});

  final PlanTemplate plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(plan.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (plan.description case final description?
                when description.isNotEmpty) ...[
              Text(description, style: theme.textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.md),
            ],
            _MetaChips(plan: plan),
            const SizedBox(height: AppSpacing.xl),
            for (final workout in plan.workouts) ...[
              _WorkoutSection(workout: workout),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _AdoptBar(plan: plan),
    );
  }
}

/// Bottom action bar: adopts this plan as the active one, or shows that it
/// already is. The active plan is an owned copy of a template, so it's matched
/// back to the template currently shown via [PlanTemplate.sourceTemplate].
class _AdoptBar extends ConsumerWidget {
  const _AdoptBar({required this.plan});

  final PlanTemplate plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activePlanControllerProvider);
    final isActive = active.value?.sourceTemplate == plan.id;

    return SafeArea(
      minimum: const EdgeInsets.all(AppSpacing.lg),
      child: isActive
          ? const _ActivePlanIndicator()
          : PrimaryButton(
              key: const Key('plan-adopt'),
              label: 'Use this plan',
              icon: Icons.check_circle_outline,
              isLoading: active.isLoading,
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await ref
                    .read(activePlanControllerProvider.notifier)
                    .adopt(plan.id);
                if (ref.read(activePlanControllerProvider).hasError) {
                  messenger.showSnackBar(
                    const SnackBar(
                      key: Key('plan-adopt-error'),
                      content: Text(
                        "Couldn't set this as your active plan. Try again.",
                      ),
                    ),
                  );
                }
              },
            ),
    );
  }
}

/// Shown in place of the adopt button once this plan is the active one.
class _ActivePlanIndicator extends StatelessWidget {
  const _ActivePlanIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('plan-active'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.accentDim,
        borderRadius: AppRadii.cardRadius,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: AppColors.accent),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Your active plan',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The plan's match attributes — goal, experience, days/week, equipment — as a
/// wrapped row of chips.
class _MetaChips extends StatelessWidget {
  const _MetaChips({required this.plan});

  final PlanTemplate plan;

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      if (plan.goalLabel != null) plan.goalLabel!,
      if (plan.experienceLabel != null) plan.experienceLabel!,
      if (plan.daysPerWeek case final days?)
        '$days ${days == 1 ? 'day' : 'days'}/week',
      ...plan.equipmentLabels,
    ];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [for (final label in labels) _MetaChip(label: label)],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.outline),
      ),
      child: Text(label, style: theme.textTheme.bodySmall),
    );
  }
}

/// One training day: its name + estimated time, then a card per exercise.
class _WorkoutSection extends StatelessWidget {
  const _WorkoutSection({required this.workout});

  final PlanWorkout workout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(workout.name, style: theme.textTheme.titleLarge),
            ),
            if (workout.estimatedMinutes case final minutes?)
              Text(
                '~$minutes min',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        if (workout.description case final description?
            when description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        for (final exercise in workout.exercises)
          _ExerciseRow(exercise: exercise),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise});

  final PlanExercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.cardRadius,
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                _TrackingBadge(tracking: poseTrackingFor(exercise.name)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                if (exercise.prescription.isNotEmpty)
                  Text(
                    exercise.prescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (exercise.restSeconds case final rest?) ...[
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '${rest}s rest',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            if (exercise.notes case final notes? when notes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                notes,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A small badge marking how the glasses track an exercise, keyed off the pose
/// catalog's three-way [PoseTracking] classification (the single source of
/// truth — see [poseTrackingFor]) rather than the server's two-state flag:
/// form-tracked (the buddy watches your form), rep-tracked-only, or not
/// pose-trackable at all (reps fall back to native/manual logging).
class _TrackingBadge extends StatelessWidget {
  const _TrackingBadge({required this.tracking});

  final PoseTracking tracking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (key, label, icon, color) = switch (tracking) {
      PoseTracking.formTracked => (
        'exercise-form-tracked',
        'Form tracked',
        Icons.visibility_outlined,
        AppColors.accent,
      ),
      PoseTracking.repsOnly => (
        'exercise-reps-only',
        'Reps only',
        Icons.numbers,
        AppColors.textMuted,
      ),
      PoseTracking.none => (
        'exercise-not-tracked',
        'Not tracked',
        Icons.visibility_off_outlined,
        AppColors.textMuted,
      ),
    };
    return Container(
      key: Key(key),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
