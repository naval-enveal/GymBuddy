import 'package:flutter/material.dart';

import 'package:gymbuddy/core/design/design.dart';
import 'package:gymbuddy/features/plans/plan_models.dart';

/// Detail view for a single template [plan]: its training days and the
/// exercises within each, with every exercise marked form-tracked vs
/// rep-tracked-only (the glasses are first-person POV, so form correction ships
/// only for mirror/POV-visible movements).
///
/// Purely presentational — it renders a [PlanTemplate] already loaded by the
/// Plans list, so it needs no provider of its own.
class PlanDetailScreen extends StatelessWidget {
  const PlanDetailScreen({required this.plan, super.key});

  final PlanTemplate plan;

  @override
  Widget build(BuildContext context) {
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
      ?plan.goalLabel,
      ?plan.experienceLabel,
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
                _TrackingBadge(formTracked: exercise.formTracked),
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

/// A small badge marking an exercise as form-tracked (the buddy watches your
/// form) or rep-tracked-only.
class _TrackingBadge extends StatelessWidget {
  const _TrackingBadge({required this.formTracked});

  final bool formTracked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = formTracked ? 'Form tracked' : 'Reps only';
    final color = formTracked ? AppColors.accent : AppColors.textMuted;
    return Container(
      key: Key(
        formTracked ? 'exercise-form-tracked' : 'exercise-reps-only',
      ),
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
          Icon(
            formTracked ? Icons.visibility_outlined : Icons.numbers,
            size: 14,
            color: color,
          ),
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
