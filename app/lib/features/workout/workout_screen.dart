import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/design/design.dart';
import 'package:gymbuddy/features/plans/active_plan_controller.dart';
import 'package:gymbuddy/features/plans/plan_models.dart';
import 'package:gymbuddy/features/workout/session_mapper.dart';
import 'package:gymbuddy/features/workout/session_models.dart';
import 'package:gymbuddy/features/workout/workout_session_controller.dart';
import 'package:gymbuddy/sensors/sensor_source.dart';

/// Workout tab — focus mode for a live session (M6).
///
/// Pure presentation over [workoutSessionControllerProvider]: it renders the
/// [WorkoutSessionState] and forwards the controller's manual actions
/// (`completeSet`/`skipRest`/`stop`). Per the no-logic-in-widgets rule the
/// session engine owns all state and timing; this screen only reads and
/// dispatches.
///
/// The body switches on [SessionStatus]:
/// * idle → a start screen sourced from the user's active plan,
/// * exercising → the rep counter + latest form cue + set/exercise progress,
/// * resting → a depleting [RestTimer] with a skip action,
/// * completed → the finished-sets summary.
///
/// Against [MockSensorSource] (the provider default, `autoSimulate: true`) reps
/// tick automatically, so focus mode animates with no glasses attached.
class WorkoutScreen extends ConsumerWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutSessionControllerProvider);
    final controller = ref.read(workoutSessionControllerProvider.notifier);

    final Widget body = switch (session.status) {
      SessionStatus.idle => const _StartView(),
      SessionStatus.exercising => _ExercisingView(
          state: session,
          onCompleteSet: controller.completeSet,
          onSetReps: controller.setReps,
          onSetWeight: controller.setWeight,
          onStop: controller.stop,
        ),
      SessionStatus.resting => _RestingView(
          state: session,
          onSkipRest: controller.skipRest,
          onStop: controller.stop,
        ),
      SessionStatus.completed => _CompletedView(
          state: session,
          onDone: controller.stop,
        ),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(session.isIdle ? 'Workout' : session.plan.name),
      ),
      body: SafeArea(child: body),
    );
  }
}

/// Idle entry point: offers to start a session from the user's active plan, or
/// shows an empty state when there's no plan adopted yet. Watches
/// [activePlanControllerProvider] so the network read only happens at rest.
class _StartView extends ConsumerWidget {
  const _StartView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activePlanControllerProvider);
    return async.when(
      loading: () => const Center(
        key: Key('workout-loading'),
        child: CircularProgressIndicator(),
      ),
      error: (_e, _) => _StartError(
        onRetry: () => ref.invalidate(activePlanControllerProvider),
      ),
      data: (plan) {
        final workout = _firstWorkout(plan);
        if (plan == null || workout == null) return const _NoPlan();
        return _StartReady(
          plan: plan,
          workout: workout,
          onStart: () => ref
              .read(workoutSessionControllerProvider.notifier)
              .start(workout.toSessionPlan()),
        );
      },
    );
  }

  /// The first training day with at least one exercise, or null.
  static PlanWorkout? _firstWorkout(PlanTemplate? plan) {
    if (plan == null) return null;
    for (final w in plan.workouts) {
      if (w.exercises.isNotEmpty) return w;
    }
    return null;
  }
}

/// Active plan present: show the day to be trained and a start action.
class _StartReady extends StatelessWidget {
  const _StartReady({
    required this.plan,
    required this.workout,
    required this.onStart,
  });

  final PlanTemplate plan;
  final PlanWorkout workout;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = workout.exercises.length;
    return Center(
      key: const Key('workout-start'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.fitness_center,
              size: 56,
              color: AppColors.accent,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(plan.name, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              workout.name,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '$count ${count == 1 ? 'exercise' : 'exercises'}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              key: const Key('workout-start-button'),
              label: 'Start workout',
              icon: Icons.play_arrow,
              onPressed: onStart,
            ),
          ],
        ),
      ),
    );
  }
}

/// No active plan adopted yet — point the user at the Plans tab.
class _NoPlan extends StatelessWidget {
  const _NoPlan();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('workout-empty'),
      child: StateMessage(
        icon: Icons.fitness_center_outlined,
        title: 'No active plan yet',
        message: 'Adopt a plan from the Plans tab to start a guided workout.',
      ),
    );
  }
}

/// Retryable error for the active-plan read.
class _StartError extends StatelessWidget {
  const _StartError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('workout-error'),
      child: StateMessage(
        icon: Icons.error_outline,
        title: 'Couldn’t load your plan',
        actionKey: const Key('workout-error-retry'),
        actionLabel: 'Try again',
        actionIcon: Icons.refresh,
        onAction: onRetry,
      ),
    );
  }
}

/// The active set: progress, the big rep counter, the latest form cue, and the
/// manual "complete set" action (the only way to end a "to failure"/time-based
/// set, and an override for the auto-counted ones).
class _ExercisingView extends StatelessWidget {
  const _ExercisingView({
    required this.state,
    required this.onCompleteSet,
    required this.onSetReps,
    required this.onSetWeight,
    required this.onStop,
  });

  final WorkoutSessionState state;
  final Future<void> Function() onCompleteSet;
  final void Function(int) onSetReps;
  final void Function(double?) onSetWeight;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercise = state.currentExercise;
    return Padding(
      key: const Key('workout-exercising'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          _SessionProgress(state: state),
          const SizedBox(height: AppSpacing.sm),
          Text(
            exercise?.exercise.name ?? '',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          if (exercise != null)
            Text(
              'Set ${state.setNumber} of ${exercise.sets}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textMuted),
            ),
          const Spacer(),
          // Rep counter flanked by manual +/- so the lifter can correct a
          // miscount or log reps by hand when no sensor is counting.
          _RepStepper(
            reps: state.reps,
            target: state.targetReps,
            onSetReps: onSetReps,
          ),
          const SizedBox(height: AppSpacing.lg),
          // Weight is never sensed — the lifter logs it. Keyed by position so a
          // new set starts with a fresh, empty field.
          _WeightInput(
            key: Key('weight-${state.exerciseIndex}-${state.setNumber}'),
            initialWeight: state.weight,
            onChanged: onSetWeight,
          ),
          const SizedBox(height: AppSpacing.md),
          _FormCueBanner(cue: state.formCue),
          const Spacer(),
          PrimaryButton(
            key: const Key('complete-set-button'),
            label: 'Complete set',
            icon: Icons.check,
            onPressed: () => onCompleteSet(),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StopButton(onStop: onStop),
        ],
      ),
    );
  }
}

/// The big [RepCounter] with manual decrement/increment controls — the
/// no-glasses logging path and an override for a sensor miscount. All it does
/// is dispatch the new count to the controller (no local state).
class _RepStepper extends StatelessWidget {
  const _RepStepper({
    required this.reps,
    required this.target,
    required this.onSetReps,
  });

  final int reps;
  final int? target;
  final void Function(int) onSetReps;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          key: const Key('rep-decrement'),
          iconSize: 32,
          onPressed: reps > 0 ? () => onSetReps(reps - 1) : null,
          icon: const Icon(Icons.remove),
          tooltip: 'Remove a rep',
        ),
        const SizedBox(width: AppSpacing.lg),
        RepCounter(reps: reps, target: target),
        const SizedBox(width: AppSpacing.lg),
        IconButton.filledTonal(
          key: const Key('rep-increment'),
          iconSize: 32,
          onPressed: () => onSetReps(reps + 1),
          icon: const Icon(Icons.add),
          tooltip: 'Add a rep',
        ),
      ],
    );
  }
}

/// Manual weight entry for the current set. Keeps a local [TextEditingController]
/// for the text field but owns no session state — every edit is forwarded to
/// the controller via [onChanged] (null when the field is empty/invalid).
class _WeightInput extends StatefulWidget {
  const _WeightInput({
    required this.initialWeight,
    required this.onChanged,
    super.key,
  });

  final double? initialWeight;
  final void Function(double?) onChanged;

  @override
  State<_WeightInput> createState() => _WeightInputState();
}

class _WeightInputState extends State<_WeightInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialWeight == null ? '' : _format(widget.initialWeight!),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    final trimmed = raw.trim();
    widget.onChanged(trimmed.isEmpty ? null : double.tryParse(trimmed));
  }

  static String _format(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: TextField(
        key: const Key('weight-input'),
        controller: _controller,
        onChanged: _onChanged,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          labelText: 'Weight',
          suffixText: 'kg',
          isDense: true,
        ),
      ),
    );
  }
}

/// Resting between sets: the depleting countdown ring plus a skip action.
class _RestingView extends StatelessWidget {
  const _RestingView({
    required this.state,
    required this.onSkipRest,
    required this.onStop,
  });

  final WorkoutSessionState state;
  final Future<void> Function() onSkipRest;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The full rest period drives the ring fraction; fall back to whatever's
    // remaining if the prescription is missing so the ring still reads full.
    final total = state.currentExercise?.restSeconds ?? state.restRemaining;
    return Padding(
      key: const Key('workout-resting'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          _SessionProgress(state: state),
          const Spacer(),
          Text('REST', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.md),
          RestTimer(
            remaining: Duration(seconds: state.restRemaining),
            total: Duration(seconds: total),
          ),
          const Spacer(),
          PrimaryButton(
            key: const Key('skip-rest-button'),
            label: 'Skip rest',
            icon: Icons.skip_next,
            onPressed: () => onSkipRest(),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StopButton(onStop: onStop),
        ],
      ),
    );
  }
}

/// Post-workout summary: every set that was completed, then a done action that
/// returns the session to idle. The session controller syncs this summary to
/// the backend WorkoutLog on completion (best-effort, off the UI path).
class _CompletedView extends StatelessWidget {
  const _CompletedView({required this.state, required this.onDone});

  final WorkoutSessionState state;
  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sets = state.completedSets;
    final totalReps =
        sets.fold<int>(0, (sum, s) => sum + s.reps);
    return Padding(
      key: const Key('workout-complete'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.emoji_events_outlined,
            size: 56,
            color: AppColors.accent,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Workout complete',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${sets.length} ${sets.length == 1 ? 'set' : 'sets'} · '
            '$totalReps reps',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: ListView.separated(
              itemCount: sets.length,
              separatorBuilder: (_i, _) =>
                  const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, i) => _CompletedSetTile(set: sets[i]),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            key: const Key('workout-done-button'),
            label: 'Done',
            icon: Icons.check,
            onPressed: () => onDone(),
          ),
        ],
      ),
    );
  }
}

/// One row in the completed-sets summary.
class _CompletedSetTile extends StatelessWidget {
  const _CompletedSetTile({required this.set});

  final CompletedSet set;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weight = set.weight;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              set.exerciseName,
              style: theme.textTheme.titleSmall,
            ),
          ),
          Text(
            'Set ${set.setNumber}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(width: AppSpacing.md),
          if (weight != null) ...[
            Text('${_formatWeight(weight)} kg',
                style: AppTypography.numericMedium),
            Text(
              ' × ',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ],
          Text('${set.reps} reps', style: AppTypography.numericMedium),
        ],
      ),
    );
  }

  static String _formatWeight(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
}

/// "Exercise n of m" progress line, shared by the exercising/resting views.
class _SessionProgress extends StatelessWidget {
  const _SessionProgress({required this.state});

  final WorkoutSessionState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Exercise ${state.exerciseNumber} of ${state.totalExercises}',
      key: const Key('session-progress'),
      style: theme.textTheme.labelSmall,
    );
  }
}

/// The latest form cue, colored by severity. Reserves no space when there's no
/// cue so the layout doesn't jump.
class _FormCueBanner extends StatelessWidget {
  const _FormCueBanner({required this.cue});

  final FormCue? cue;

  @override
  Widget build(BuildContext context) {
    final cue = this.cue;
    if (cue == null) return const SizedBox.shrink();
    final color = switch (cue.severity) {
      FormSeverity.good => AppColors.accent,
      FormSeverity.minor => AppColors.warning,
      FormSeverity.major => AppColors.error,
    };
    return Container(
      key: const Key('form-cue'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadii.cardRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(cue.severity), size: 18, color: color),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              cue.message,
              style: TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(FormSeverity severity) => switch (severity) {
        FormSeverity.good => Icons.check_circle_outline,
        FormSeverity.minor => Icons.info_outline,
        FormSeverity.major => Icons.warning_amber_outlined,
      };
}

/// A muted "stop workout" text action, shared by the active views.
class _StopButton extends StatelessWidget {
  const _StopButton({required this.onStop});

  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const Key('stop-workout-button'),
      onPressed: () => onStop(),
      child: const Text('Stop workout'),
    );
  }
}
