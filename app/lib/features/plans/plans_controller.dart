import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/features/plans/plan_api.dart';
import 'package:gymbuddy/features/plans/plan_models.dart';

/// Loads the profile-ranked template library for the Plans tab.
///
/// [build] fetches once through [planApiProvider]; the screen renders the
/// resulting [AsyncValue] (spinner / error-with-retry / list). A fetch failure
/// surfaces as an [AsyncError] so the UI can offer a retry rather than showing
/// an empty library. [refresh] re-runs the fetch for pull-to-refresh and the
/// error-state retry, keeping all I/O out of the widgets.
class PlansController extends AsyncNotifier<List<PlanTemplate>> {
  @override
  Future<List<PlanTemplate>> build() {
    return ref.read(planApiProvider).fetchTemplates();
  }

  /// Re-fetches the library, moving back through loading so the UI reflects the
  /// in-flight state. Errors are captured into the state, not thrown.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(planApiProvider).fetchTemplates(),
    );
  }
}

/// The ranked template library. See [PlansController].
final plansControllerProvider =
    AsyncNotifierProvider<PlansController, List<PlanTemplate>>(
  PlansController.new,
);
