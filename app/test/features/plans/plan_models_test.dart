// PlanTemplate.fromJson decodes the `GET /plans/templates` wire shape — a
// populated template Plan JSON annotated with matchScore — into the view models
// the Plans UI renders, defaulting gracefully on missing/wrong-typed fields.

import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/features/plans/plan_models.dart';

Map<String, dynamic> _wireTemplate() => <String, dynamic>{
      '_id': 'plan-1',
      'name': 'Lean Burn Circuit',
      'description': 'Four short circuit days.',
      'goal': 'lose_weight',
      'experience': 'beginner',
      'daysPerWeek': 4,
      'equipment': ['dumbbells', 'bodyweight'],
      'isTemplate': true,
      'owner': null,
      'matchScore': 155,
      'workouts': [
        {
          '_id': 'w-1',
          'name': 'Circuit A',
          'description': 'High density.',
          'estimatedMinutes': 30,
          'exercises': [
            {
              '_id': 'e-1',
              'name': 'Goblet Squat',
              'sets': 3,
              'reps': 15,
              'restSeconds': 45,
              'formTracked': true,
            },
            {
              '_id': 'e-2',
              'name': 'Mountain Climbers',
              'sets': 3,
              'restSeconds': 30,
              'formTracked': false,
              'notes': '30s on.',
            },
          ],
        },
      ],
    };

void main() {
  test('parses the full template wire shape', () {
    final plan = PlanTemplate.fromJson(_wireTemplate());

    expect(plan.id, 'plan-1');
    expect(plan.name, 'Lean Burn Circuit');
    expect(plan.goal, 'lose_weight');
    expect(plan.daysPerWeek, 4);
    expect(plan.matchScore, 155);
    expect(plan.equipment, ['dumbbells', 'bodyweight']);
    expect(plan.workouts, hasLength(1));

    final workout = plan.workouts.single;
    expect(workout.name, 'Circuit A');
    expect(workout.estimatedMinutes, 30);
    expect(workout.exercises, hasLength(2));
  });

  test('humanizes wire enums for display', () {
    final plan = PlanTemplate.fromJson(_wireTemplate());

    expect(plan.goalLabel, 'Lose weight');
    expect(plan.experienceLabel, 'Beginner');
    expect(plan.equipmentLabels, ['Dumbbells', 'Bodyweight']);
  });

  test('carries the per-exercise formTracked flag and prescription', () {
    final plan = PlanTemplate.fromJson(_wireTemplate());
    final exercises = plan.workouts.single.exercises;

    expect(exercises[0].formTracked, isTrue);
    expect(exercises[0].prescription, '3 × 15');
    expect(exercises[0].restSeconds, 45);

    // No reps → time/failure based: shows the set count, not a "× null".
    expect(exercises[1].formTracked, isFalse);
    expect(exercises[1].reps, isNull);
    expect(exercises[1].prescription, '3 sets');
    expect(exercises[1].notes, '30s on.');
  });

  test('defaults gracefully on a sparse / malformed payload', () {
    final plan = PlanTemplate.fromJson(<String, dynamic>{'name': 'Bare'});

    expect(plan.id, '');
    expect(plan.name, 'Bare');
    expect(plan.goal, isNull);
    expect(plan.goalLabel, isNull);
    expect(plan.matchScore, 0);
    expect(plan.equipment, isEmpty);
    expect(plan.workouts, isEmpty);
  });
}
