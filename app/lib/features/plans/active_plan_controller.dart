import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/features/plans/plan_api.dart';
import 'package:gymbuddy/features/plans/plan_models.dart';

/// Tracks the user's currently active workout plan (M4).
///
/// [build] loads the active plan (`null` when none is adopted yet) through
/// [planApiProvider]; the detail screen watches this to know whether the plan
/// it's showing is the active one. [adopt] adopts a template server-side — which
/// writes an owned, active copy and deactivates any prior active plan (enforced
/// server-side) — and swaps the resolved owned plan into state, so the UI
/// reflects the new active plan without a refetch.
///
/// All I/O stays here (per the no-logic-in-widgets rule); the screen only reads
/// the resulting [AsyncValue] and forwards the adopt action.
class ActivePlanController extends AsyncNotifier<PlanTemplate?> {
  @override
  Future<PlanTemplate?> build() {
    return ref.read(planApiProvider).fetchActivePlan();
  }

  /// Adopts [templateId] as the active plan. Moves through loading so the UI can
  /// show progress, then captures the adopted owned plan (or the failure) into
  /// the state — the caller inspects the resulting state rather than catching.
  Future<void> adopt(String templateId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(planApiProvider).adoptPlan(templateId),
    );
  }

  /// Re-fetches the active plan (e.g. after a transient load error).
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(planApiProvider).fetchActivePlan(),
    );
  }
}

/// The user's active plan. See [ActivePlanController].
final activePlanControllerProvider =
    AsyncNotifierProvider<ActivePlanController, PlanTemplate?>(
  ActivePlanController.new,
);
