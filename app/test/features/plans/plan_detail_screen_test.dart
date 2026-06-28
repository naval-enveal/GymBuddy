// PlanDetailScreen's adopt action: a "Use this plan" button that adopts the
// template as the active plan (surfacing it as active afterward), and surfacing
// when the displayed plan is already the user's active plan.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/network/api_client.dart';
import 'package:gymbuddy/features/plans/plan_api.dart';
import 'package:gymbuddy/features/plans/plan_detail_screen.dart';
import 'package:gymbuddy/features/plans/plan_models.dart';

PlanTemplate _plan({
  required String id,
  String name = 'Push Pull Legs',
  String? sourceTemplate,
}) {
  return PlanTemplate(
    id: id,
    name: name,
    matchScore: 0,
    equipment: const ['dumbbells'],
    workouts: const [
      PlanWorkout(
        name: 'Day One',
        exercises: [PlanExercise(name: 'Squat', formTracked: true, sets: 3, reps: 5)],
      ),
    ],
    sourceTemplate: sourceTemplate,
  );
}

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
    final result = _plan(
      id: 'owned-$templateId',
      name: 'Owned',
      sourceTemplate: templateId,
    );
    active = result;
    return result;
  }
}

Future<void> _mount(WidgetTester tester, PlanTemplate plan, PlanApi api) async {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [planApiProvider.overrideWithValue(api)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: PlanDetailScreen(plan: plan)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offers "Use this plan" when not active, and adopts on tap',
      (WidgetTester tester) async {
    final api = _FakePlanApi();
    await _mount(tester, _plan(id: 't1'), api);

    expect(find.byKey(const Key('plan-adopt')), findsOneWidget);
    expect(find.byKey(const Key('plan-active')), findsNothing);

    await tester.tap(find.byKey(const Key('plan-adopt')));
    await tester.pumpAndSettle();

    // Adopt hit the API for this template, and the plan now reads as active.
    expect(api.adopted, ['t1']);
    expect(find.byKey(const Key('plan-active')), findsOneWidget);
    expect(find.byKey(const Key('plan-adopt')), findsNothing);
  });

  testWidgets('surfaces the plan as active when it is already the active one',
      (WidgetTester tester) async {
    // The active plan is an owned copy whose sourceTemplate points at this one.
    final api = _FakePlanApi(
      active: _plan(id: 'owned-t1', name: 'Owned', sourceTemplate: 't1'),
    );
    await _mount(tester, _plan(id: 't1'), api);

    expect(find.byKey(const Key('plan-active')), findsOneWidget);
    expect(find.byKey(const Key('plan-adopt')), findsNothing);
  });

  testWidgets('does not mark active when a different plan is active',
      (WidgetTester tester) async {
    final api = _FakePlanApi(
      active: _plan(id: 'owned-other', sourceTemplate: 'other'),
    );
    await _mount(tester, _plan(id: 't1'), api);

    expect(find.byKey(const Key('plan-adopt')), findsOneWidget);
    expect(find.byKey(const Key('plan-active')), findsNothing);
  });

  testWidgets('shows an error and stays adoptable when adopt fails',
      (WidgetTester tester) async {
    final api = _FakePlanApi(adoptThrows: true);
    await _mount(tester, _plan(id: 't1'), api);

    await tester.tap(find.byKey(const Key('plan-adopt')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('plan-adopt-error')), findsOneWidget);
    // Still adoptable for a retry; not falsely marked active.
    expect(find.byKey(const Key('plan-adopt')), findsOneWidget);
    expect(find.byKey(const Key('plan-active')), findsNothing);
  });

  testWidgets(
      'badges each exercise by the pose catalog three-way classification',
      (WidgetTester tester) async {
    // Names chosen to span the catalog: "Back Squat" → form-tracked,
    // "Bicep Curl" → reps-only (angle config, no form rules), "Plank" →
    // not pose-trackable at all.
    const plan = PlanTemplate(
      id: 't1',
      name: 'Push Pull Legs',
      matchScore: 0,
      equipment: ['dumbbells'],
      workouts: [
        PlanWorkout(
          name: 'Day One',
          exercises: [
            PlanExercise(name: 'Back Squat', formTracked: false, sets: 3, reps: 5),
            PlanExercise(name: 'Bicep Curl', formTracked: true, sets: 3, reps: 10),
            PlanExercise(name: 'Plank', formTracked: true, sets: 3, reps: 1),
          ],
        ),
      ],
    );
    await _mount(tester, plan, _FakePlanApi());

    // The catalog, not the server flag, decides the badge: "Back Squat" reads
    // form-tracked despite its false server flag, and "Bicep Curl"/"Plank" read
    // reps-only / not-tracked despite their true flags.
    expect(find.byKey(const Key('exercise-form-tracked')), findsOneWidget);
    expect(find.byKey(const Key('exercise-reps-only')), findsOneWidget);
    expect(find.byKey(const Key('exercise-not-tracked')), findsOneWidget);
    expect(find.text('Form tracked'), findsOneWidget);
    expect(find.text('Reps only'), findsOneWidget);
    expect(find.text('Not tracked'), findsOneWidget);
  });
}
