import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/network/api_client.dart';
import 'package:gymbuddy/features/workout/session_models.dart';

/// Typed wrapper over the backend WorkoutLog API (`POST /workout-logs`).
///
/// Keeps the network call and wire encoding out of the widgets and the session
/// controller (per the no-logic-in-widgets rule), mirroring
/// `features/plans/plan_api.dart` and `features/onboarding/profile_api.dart`.
class WorkoutLogApi {
  WorkoutLogApi(this._client);

  final ApiClient _client;

  /// Persists a finished workout's summary. The flat [sets] list (oldest first,
  /// as accumulated by the session engine) is grouped back into per-exercise
  /// blocks for the log's `{ name, sets: [...] }` shape, preserving order.
  /// `durationSeconds` is derived from the two timestamps (never negative).
  /// Throws [ApiException] on a non-2xx response (surfaced/swallowed by the
  /// caller).
  Future<void> saveLog({
    required DateTime startedAt,
    required DateTime completedAt,
    required List<CompletedSet> sets,
  }) async {
    final seconds = completedAt.difference(startedAt).inSeconds;
    await _client.post('/workout-logs', body: <String, dynamic>{
      'startedAt': startedAt.toUtc().toIso8601String(),
      'completedAt': completedAt.toUtc().toIso8601String(),
      'durationSeconds': seconds < 0 ? 0 : seconds,
      'exercises': _groupExercises(sets),
    });
  }

  /// Group consecutive [CompletedSet]s sharing an exercise name into the log's
  /// per-exercise shape. `weight` is nullable (bodyweight / unlogged), so
  /// `weightKg` is omitted when there's no load to record.
  static List<Map<String, dynamic>> _groupExercises(List<CompletedSet> sets) {
    final exercises = <Map<String, dynamic>>[];
    for (final set in sets) {
      if (exercises.isEmpty || exercises.last['name'] != set.exerciseName) {
        exercises.add(<String, dynamic>{
          'name': set.exerciseName,
          'sets': <Map<String, dynamic>>[],
        });
      }
      (exercises.last['sets'] as List<Map<String, dynamic>>).add(
        <String, dynamic>{
          'reps': set.reps,
          if (set.weight != null) 'weightKg': set.weight,
          'completed': true,
        },
      );
    }
    return exercises;
  }
}

/// App-wide [WorkoutLogApi] over the shared [apiClientProvider]. Overridden in
/// tests with a fake.
final workoutLogApiProvider = Provider<WorkoutLogApi>(
  (ref) => WorkoutLogApi(ref.watch(apiClientProvider)),
);
