import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/design/design.dart';
import 'package:gymbuddy/features/plans/plan_detail_screen.dart';
import 'package:gymbuddy/features/plans/plan_models.dart';
import 'package:gymbuddy/features/plans/plans_controller.dart';

/// Plans tab — the profile-ranked template library. Each plan is tappable
/// through to a [PlanDetailScreen] showing its training days and exercises.
///
/// All loading/fetch logic lives in [plansControllerProvider] (per the
/// no-logic-in-widgets rule); this widget renders the resulting [AsyncValue] —
/// a spinner while loading, a retryable error state, an empty state, or the
/// ranked list — and forwards taps.
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Plans')),
      body: SafeArea(
        child: plans.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              key: Key('plans-loading'),
            ),
          ),
          error: (error, _) => _PlansError(
            onRetry: () =>
                ref.read(plansControllerProvider.notifier).refresh(),
          ),
          data: (templates) => _PlansList(templates: templates),
        ),
      ),
    );
  }
}

/// The ranked list of templates, or an empty state when the library is empty.
class _PlansList extends ConsumerWidget {
  const _PlansList({required this.templates});

  final List<PlanTemplate> templates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (templates.isEmpty) {
      return const _PlansEmpty();
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(plansControllerProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: templates.length,
        itemBuilder: (context, index) {
          final plan = templates[index];
          // The library arrives best-match-first; flag the top plan when the
          // profile actually produced a ranking (score 0 means un-onboarded).
          final recommended = index == 0 && plan.matchScore > 0;
          return _PlanCard(plan: plan, recommended: recommended);
        },
      ),
    );
  }
}

/// A tappable summary card for one template plan.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.recommended});

  final PlanTemplate plan;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = <String>[
      ?plan.experienceLabel,
      if (plan.daysPerWeek case final days?)
        '$days ${days == 1 ? 'day' : 'days'}/week',
      '${plan.workouts.length} '
          '${plan.workouts.length == 1 ? 'workout' : 'workouts'}',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        child: InkWell(
          key: Key('plan-${plan.id}'),
          borderRadius: AppRadii.cardRadius,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PlanDetailScreen(plan: plan),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: AppRadii.cardRadius,
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recommended) ...[
                  const _RecommendedBadge(),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(plan.name, style: theme.textTheme.titleLarge),
                    ),
                    if (plan.goalLabel case final goal?)
                      Text(
                        goal,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.accent,
                        ),
                      ),
                  ],
                ),
                if (plan.description case final description?
                    when description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text(
                  meta.join('  ·  '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecommendedBadge extends StatelessWidget {
  const _RecommendedBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('plan-recommended'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentDim,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 14, color: AppColors.accent),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            'Best match for you',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the library comes back empty (e.g. before any templates are
/// seeded). Wrapped in a scroll view so pull-to-refresh still works.
class _PlansEmpty extends ConsumerWidget {
  const _PlansEmpty();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(plansControllerProvider.notifier).refresh(),
      child: ListView(
        key: const Key('plans-empty'),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
          const StateMessage(
            icon: Icons.list_alt_outlined,
            title: 'No plans available yet',
            message: 'Pull to refresh once your library is ready.',
          ),
        ],
      ),
    );
  }
}

/// The fetch-failed state: a message and a retry button.
class _PlansError extends StatelessWidget {
  const _PlansError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: StateMessage(
        icon: Icons.cloud_off_outlined,
        title: "Couldn't load plans",
        message: 'Check your connection and try again.',
        actionKey: const Key('plans-retry'),
        actionLabel: 'Try again',
        actionIcon: Icons.refresh,
        onAction: onRetry,
      ),
    );
  }
}
