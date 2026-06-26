// ActivePlanController loads the user's active plan and adopts a template as
// the active one through PlanApi, capturing success/failure into its state.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/network/api_client.dart';
import 'package:gymbuddy/features/plans/active_plan_controller.dart';
import 'package:gymbuddy/features/plans/plan_api.dart';
import 'package:gymbuddy/features/plans/plan_models.dart';

PlanTemplate _plan({
  required String id,
  String name = 'A Plan',
  String? sourceTemplate,
}) {
  return PlanTemplate(
    id: id,
    name: name,
    matchScore: 0,
    equipment: const [],
    workouts: const [],
    sourceTemplate: sourceTemplate,
  );
}

/// A controllable [PlanApi]: serves a starting active plan and records adopts,
/// optionally failing them.
class _FakePlanApi implements PlanApi {
  _FakePlanApi({this.active, this.adoptThrows = false});

  PlanTemplate? active;
  bool adoptThrows;
  final List<String> adopted = [];

  @override
  Future<List<PlanTemplate>> fetchTemplates() async => const [];

  @override
  Future<PlanTemplate?> fetchActivePlan() async => active;

  @override
  Future<PlanTemplate> adoptPlan(String templateId) async {
    adopted.add(templateId);
    if (adoptThrows) throw const ApiException(500, 'boom');
    // The server returns an owned copy whose sourceTemplate is the template id.
    final result = _plan(
      id: 'owned-$templateId',
      name: 'Owned $templateId',
      sourceTemplate: templateId,
    );
    active = result;
    return result;
  }
}

ProviderContainer _container(PlanApi api) {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [planApiProvider.overrideWithValue(api)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('build loads the current active plan', () async {
    final container = _container(
      _FakePlanApi(active: _plan(id: 'owned-1', sourceTemplate: 't1')),
    );

    final active = await container.read(activePlanControllerProvider.future);

    expect(active, isNotNull);
    expect(active!.sourceTemplate, 't1');
  });

  test('build resolves to null when no plan is adopted', () async {
    final container = _container(_FakePlanApi());
    expect(await container.read(activePlanControllerProvider.future), isNull);
  });

  test('adopt swaps the resolved owned plan into state', () async {
    final api = _FakePlanApi();
    final container = _container(api);
    await container.read(activePlanControllerProvider.future);

    await container.read(activePlanControllerProvider.notifier).adopt('t1');

    final state = container.read(activePlanControllerProvider);
    expect(api.adopted, ['t1']);
    expect(state.hasValue, isTrue);
    expect(state.value!.sourceTemplate, 't1');
  });

  test('a failed adopt is captured as an error in state', () async {
    final api = _FakePlanApi(adoptThrows: true);
    final container = _container(api);
    await container.read(activePlanControllerProvider.future);

    await container.read(activePlanControllerProvider.notifier).adopt('t1');

    final state = container.read(activePlanControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<ApiException>());
  });
}
