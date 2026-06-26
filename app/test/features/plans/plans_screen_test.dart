// PlansScreen renders the profile-ranked template library from
// plansControllerProvider: a spinner while loading, a retryable error state, an
// empty state, and the ranked list — each card tappable through to the detail
// view showing training days and form-tracked vs rep-tracked-only exercises.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/network/api_client.dart';
import 'package:gymbuddy/features/plans/plan_api.dart';
import 'package:gymbuddy/features/plans/plan_models.dart';
import 'package:gymbuddy/features/plans/plans_screen.dart';

PlanTemplate _plan({
  required String id,
  required String name,
  required int matchScore,
}) {
  return PlanTemplate(
    id: id,
    name: name,
    description: 'A solid plan.',
    goal: 'build_muscle',
    experience: 'intermediate',
    daysPerWeek: 4,
    matchScore: matchScore,
    equipment: const ['dumbbells'],
    workouts: const [
      PlanWorkout(
        name: 'Day One',
        estimatedMinutes: 45,
        exercises: [
          PlanExercise(name: 'Goblet Squat', formTracked: true, sets: 3, reps: 10),
          PlanExercise(name: 'Overhead Press', formTracked: false, sets: 3, reps: 8),
        ],
      ),
    ],
  );
}

/// A [PlanApi] whose response is fully controllable per test.
class _FakePlanApi implements PlanApi {
  _FakePlanApi({this.templates = const [], this.future});

  final List<PlanTemplate> templates;

  /// When set, [fetchTemplates] returns this future instead (used to pin the
  /// loading state).
  final Future<List<PlanTemplate>>? future;

  int calls = 0;

  @override
  Future<List<PlanTemplate>> fetchTemplates() {
    calls++;
    if (future != null) return future!;
    return Future<List<PlanTemplate>>.value(templates);
  }

  @override
  Future<PlanTemplate?> fetchActivePlan() async => null;

  @override
  Future<PlanTemplate> adoptPlan(String templateId) =>
      throw UnimplementedError();
}

/// A [PlanApi] that fails the first call and succeeds afterward, to drive the
/// error → retry → recovered path.
class _FlakyPlanApi implements PlanApi {
  _FlakyPlanApi(this.templates);

  final List<PlanTemplate> templates;
  int calls = 0;

  @override
  Future<List<PlanTemplate>> fetchTemplates() async {
    calls++;
    if (calls == 1) throw const ApiException(500, 'boom');
    return templates;
  }

  @override
  Future<PlanTemplate?> fetchActivePlan() async => null;

  @override
  Future<PlanTemplate> adoptPlan(String templateId) =>
      throw UnimplementedError();
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  PlanApi api,
) async {
  final container = ProviderContainer(
    // Riverpod 3.x auto-retries errored providers with backoff; disable it so
    // the error path is deterministic (the screen offers its own retry).
    retry: (_, _) => null,
    overrides: [planApiProvider.overrideWithValue(api)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PlansScreen()),
    ),
  );
  return container;
}

void main() {
  testWidgets('shows a spinner while the library loads',
      (WidgetTester tester) async {
    final completer = Completer<List<PlanTemplate>>();
    await _mount(tester, _FakePlanApi(future: completer.future));
    await tester.pump();

    expect(find.byKey(const Key('plans-loading')), findsOneWidget);

    completer.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('renders the ranked list, flagging the top match',
      (WidgetTester tester) async {
    await _mount(
      tester,
      _FakePlanApi(
        templates: [
          _plan(id: 'a', name: 'Push Pull Legs', matchScore: 175),
          _plan(id: 'b', name: 'Full Body', matchScore: 100),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Push Pull Legs'), findsOneWidget);
    expect(find.text('Full Body'), findsOneWidget);
    // Only the best-match (top, score > 0) plan is badged.
    expect(find.byKey(const Key('plan-recommended')), findsOneWidget);
  });

  testWidgets('does not flag a top match when nothing is ranked',
      (WidgetTester tester) async {
    await _mount(
      tester,
      _FakePlanApi(
        templates: [_plan(id: 'a', name: 'Push Pull Legs', matchScore: 0)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('plan-recommended')), findsNothing);
  });

  testWidgets('tapping a plan opens the detail with its exercises and tracking',
      (WidgetTester tester) async {
    await _mount(
      tester,
      _FakePlanApi(
        templates: [_plan(id: 'a', name: 'Push Pull Legs', matchScore: 175)],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('plan-a')));
    await tester.pumpAndSettle();

    // Detail shows the training day and its exercises (only present here).
    expect(find.text('Day One'), findsOneWidget);
    expect(find.text('Goblet Squat'), findsOneWidget);
    expect(find.text('Overhead Press'), findsOneWidget);
    // Form-tracked vs rep-tracked-only badges per exercise.
    expect(find.byKey(const Key('exercise-form-tracked')), findsOneWidget);
    expect(find.byKey(const Key('exercise-reps-only')), findsOneWidget);
  });

  testWidgets('shows an empty state when the library is empty',
      (WidgetTester tester) async {
    await _mount(tester, _FakePlanApi());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('plans-empty')), findsOneWidget);
  });

  testWidgets('shows a retryable error and recovers on retry',
      (WidgetTester tester) async {
    final api = _FlakyPlanApi(
      [_plan(id: 'a', name: 'Push Pull Legs', matchScore: 175)],
    );
    await _mount(tester, api);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('plans-retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('plans-retry')));
    await tester.pumpAndSettle();

    expect(api.calls, 2);
    expect(find.byKey(const Key('plans-retry')), findsNothing);
    expect(find.text('Push Pull Legs'), findsOneWidget);
  });
}
