// Widget tests for the focus-mode Workout tab. The presentation views are
// driven by a seeded session controller (no sensors/timers) so each
// SessionStatus renders deterministically and action-forwarding is asserted by
// call counts. The idle → start path uses the real controller over a manual
// MockSensorSource to check the tab wires to the active plan.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gymbuddy/core/design/design.dart';
import 'package:gymbuddy/features/plans/plan_api.dart';
import 'package:gymbuddy/features/plans/plan_models.dart';
import 'package:gymbuddy/features/workout/session_models.dart';
import 'package:gymbuddy/features/workout/workout_screen.dart';
import 'package:gymbuddy/features/workout/workout_session_controller.dart';
import 'package:gymbuddy/sensors/mock_sensor_source.dart';
import 'package:gymbuddy/sensors/sensor_source.dart';

/// A session controller seeded with a fixed [WorkoutSessionState] and no-op,
/// call-counting actions — so presentation views render without touching the
/// sensor source or any timers.
class _SeededController extends WorkoutSessionController {
  _SeededController(this._seed);

  final WorkoutSessionState _seed;
  int completeSetCalls = 0;
  int skipRestCalls = 0;
  int stopCalls = 0;

  @override
  WorkoutSessionState build() => _seed;

  @override
  Future<void> completeSet() async => completeSetCalls++;

  @override
  Future<void> skipRest() async => skipRestCalls++;

  @override
  Future<void> stop() async => stopCalls++;
}

/// A [PlanApi] returning a fixed active plan (and never reaching the network).
class _FakePlanApi implements PlanApi {
  _FakePlanApi({this.active, this.throwOnActive = false});

  final PlanTemplate? active;
  final bool throwOnActive;

  @override
  Future<PlanTemplate?> fetchActivePlan() async {
    if (throwOnActive) throw StateError('boom');
    return active;
  }

  @override
  Future<List<PlanTemplate>> fetchTemplates() async => const [];

  @override
  Future<PlanTemplate> adoptPlan(String templateId) =>
      throw UnimplementedError();
}

PlanTemplate _planWith(List<PlanWorkout> workouts) => PlanTemplate(
      id: 'p1',
      name: 'Push / Pull / Legs',
      equipment: const [],
      workouts: workouts,
      matchScore: 0,
    );

const _seedPlan = SessionPlan(
  name: 'Test Day',
  exercises: [
    SessionExercise(
      exercise: TrackedExercise(name: 'Squat'),
      sets: 2,
      targetReps: 12,
      restSeconds: 60,
    ),
    SessionExercise(
      exercise: TrackedExercise(name: 'Bench'),
      sets: 2,
      targetReps: 10,
      restSeconds: 60,
    ),
  ],
);

Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: WorkoutScreen()),
    ),
  );
}

void main() {
  group('idle / start', () {
    testWidgets('shows the start screen for the active plan and starts a '
        'session', (tester) async {
      final container = ProviderContainer(
        overrides: [
          planApiProvider.overrideWithValue(
            _FakePlanApi(
              active: _planWith(const [
                PlanWorkout(
                  name: 'Lower body',
                  exercises: [
                    PlanExercise(name: 'Plank', formTracked: false),
                  ],
                ),
              ]),
            ),
          ),
          workoutSensorSourceProvider
              .overrideWithValue(MockSensorSource(autoSimulate: false)),
        ],
      );
      addTearDown(container.dispose);

      await _pump(tester, container);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('workout-start')), findsOneWidget);
      expect(find.text('Push / Pull / Legs'), findsOneWidget);
      expect(find.text('Lower body'), findsOneWidget);

      await tester.tap(find.byKey(const Key('workout-start-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('workout-exercising')), findsOneWidget);
      expect(find.text('Plank'), findsOneWidget);
    });

    testWidgets('shows the empty state when no plan is active', (tester) async {
      final container = ProviderContainer(
        overrides: [
          planApiProvider.overrideWithValue(_FakePlanApi(active: null)),
        ],
      );
      addTearDown(container.dispose);

      await _pump(tester, container);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('workout-empty')), findsOneWidget);
      expect(find.byKey(const Key('workout-start')), findsNothing);
    });

    testWidgets('shows a retryable error when the active-plan read fails',
        (tester) async {
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          planApiProvider.overrideWithValue(_FakePlanApi(throwOnActive: true)),
        ],
      );
      addTearDown(container.dispose);

      await _pump(tester, container);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('workout-error')), findsOneWidget);
      expect(find.byKey(const Key('workout-error-retry')), findsOneWidget);
    });
  });

  group('exercising view', () {
    ProviderContainer seeded(WorkoutSessionState state) {
      final container = ProviderContainer(
        overrides: [
          workoutSessionControllerProvider
              .overrideWith(() => _SeededController(state)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    testWidgets('renders the rep counter, progress, and forwards complete set',
        (tester) async {
      final container = seeded(const WorkoutSessionState(
        status: SessionStatus.exercising,
        plan: _seedPlan,
        exerciseIndex: 0,
        setNumber: 1,
        reps: 5,
        restRemaining: 0,
        completedSets: [],
      ));

      await _pump(tester, container);

      expect(find.byKey(const Key('workout-exercising')), findsOneWidget);
      expect(find.byType(RepCounter), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text(' / 12'), findsOneWidget);
      expect(find.text('Exercise 1 of 2'), findsOneWidget);
      expect(find.text('Set 1 of 2'), findsOneWidget);

      await tester.tap(find.byKey(const Key('complete-set-button')));
      await tester.pump();

      final controller = container.read(
        workoutSessionControllerProvider.notifier,
      ) as _SeededController;
      expect(controller.completeSetCalls, 1);
    });

    testWidgets('surfaces the latest form cue', (tester) async {
      final container = seeded(const WorkoutSessionState(
        status: SessionStatus.exercising,
        plan: _seedPlan,
        exerciseIndex: 0,
        setNumber: 1,
        reps: 3,
        restRemaining: 0,
        completedSets: [],
        formCue: FormCue(
          severity: FormSeverity.major,
          message: 'Keep your back flat',
        ),
      ));

      await _pump(tester, container);

      expect(find.byKey(const Key('form-cue')), findsOneWidget);
      expect(find.text('Keep your back flat'), findsOneWidget);
    });
  });

  group('resting view', () {
    testWidgets('renders the rest timer and forwards skip', (tester) async {
      final container = ProviderContainer(
        overrides: [
          workoutSessionControllerProvider.overrideWith(
            () => _SeededController(const WorkoutSessionState(
              status: SessionStatus.resting,
              plan: _seedPlan,
              exerciseIndex: 0,
              setNumber: 1,
              reps: 0,
              restRemaining: 30,
              completedSets: [],
            )),
          ),
        ],
      );
      addTearDown(container.dispose);

      await _pump(tester, container);

      expect(find.byKey(const Key('workout-resting')), findsOneWidget);
      expect(find.byType(RestTimer), findsOneWidget);
      expect(find.text('0:30'), findsOneWidget);

      await tester.tap(find.byKey(const Key('skip-rest-button')));
      await tester.pump();

      final controller = container.read(
        workoutSessionControllerProvider.notifier,
      ) as _SeededController;
      expect(controller.skipRestCalls, 1);
    });
  });

  group('completed view', () {
    testWidgets('lists completed sets and forwards done', (tester) async {
      final container = ProviderContainer(
        overrides: [
          workoutSessionControllerProvider.overrideWith(
            () => _SeededController(const WorkoutSessionState(
              status: SessionStatus.completed,
              plan: _seedPlan,
              exerciseIndex: 1,
              setNumber: 2,
              reps: 0,
              restRemaining: 0,
              completedSets: [
                CompletedSet(exerciseName: 'Squat', setNumber: 1, reps: 12),
                CompletedSet(exerciseName: 'Squat', setNumber: 2, reps: 11),
                CompletedSet(exerciseName: 'Bench', setNumber: 1, reps: 10),
              ],
            )),
          ),
        ],
      );
      addTearDown(container.dispose);

      await _pump(tester, container);

      expect(find.byKey(const Key('workout-complete')), findsOneWidget);
      expect(find.text('Workout complete'), findsOneWidget);
      // Three set rows summarised (2 Squat + 1 Bench).
      expect(find.byType(RepCounter), findsNothing);
      expect(find.text('3 sets · 33 reps'), findsOneWidget);
      expect(find.text('Bench'), findsOneWidget);

      await tester.tap(find.byKey(const Key('workout-done-button')));
      await tester.pump();

      final controller = container.read(
        workoutSessionControllerProvider.notifier,
      ) as _SeededController;
      expect(controller.stopCalls, 1);
    });
  });
}
