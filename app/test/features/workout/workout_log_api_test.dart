// WorkoutLogApi encodes a finished session's flat completed-set list onto the
// backend POST /workout-logs wire shape. A MockClient captures the request body.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/network/api_client.dart';
import 'package:gymbuddy/core/storage/token_store.dart';
import 'package:gymbuddy/features/workout/session_models.dart';
import 'package:gymbuddy/features/workout/workout_log_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

WorkoutLogApi _api(MockClientHandler handler) {
  return WorkoutLogApi(
    ApiClient(
      baseUrl: 'http://test',
      tokenStore: InMemoryTokenStore(),
      httpClient: MockClient(handler),
    ),
  );
}

void main() {
  final started = DateTime.utc(2026, 6, 27, 9);
  final completed = DateTime.utc(2026, 6, 27, 9, 42);

  test('groups consecutive sets by exercise and derives duration', () async {
    Map<String, dynamic>? sent;
    final api = _api((req) async {
      expect(req.url.path, '/workout-logs');
      expect(req.method, 'POST');
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({'log': <String, dynamic>{}}), 201);
    });

    await api.saveLog(
      startedAt: started,
      completedAt: completed,
      sets: const [
        CompletedSet(exerciseName: 'Squat', setNumber: 1, reps: 8, weight: 60),
        CompletedSet(exerciseName: 'Squat', setNumber: 2, reps: 8, weight: 60),
        CompletedSet(exerciseName: 'Push-up', setNumber: 1, reps: 15),
      ],
    );

    expect(sent!['startedAt'], '2026-06-27T09:00:00.000Z');
    expect(sent!['completedAt'], '2026-06-27T09:42:00.000Z');
    expect(sent!['durationSeconds'], 42 * 60);

    final exercises = sent!['exercises'] as List<dynamic>;
    expect(exercises, hasLength(2));

    final squat = exercises[0] as Map<String, dynamic>;
    expect(squat['name'], 'Squat');
    expect(squat['sets'], [
      {'reps': 8, 'weightKg': 60, 'completed': true},
      {'reps': 8, 'weightKg': 60, 'completed': true},
    ]);

    // Bodyweight set: weight omitted rather than sent as zero.
    final pushup = exercises[1] as Map<String, dynamic>;
    expect(pushup['name'], 'Push-up');
    expect(pushup['sets'], [
      {'reps': 15, 'completed': true},
    ]);
  });

  test('clamps a negative duration to zero', () async {
    Map<String, dynamic>? sent;
    final api = _api((req) async {
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({'log': <String, dynamic>{}}), 201);
    });

    await api.saveLog(
      startedAt: completed,
      completedAt: started, // completed before started (clock skew guard)
      sets: const [CompletedSet(exerciseName: 'Squat', setNumber: 1, reps: 5)],
    );

    expect(sent!['durationSeconds'], 0);
  });

  test('throws ApiException on a non-2xx response', () async {
    final api = _api(
      (req) async => http.Response(
        jsonEncode({
          'error': {'message': 'nope'},
        }),
        500,
      ),
    );

    expect(
      () => api.saveLog(
        startedAt: started,
        completedAt: completed,
        sets: const [CompletedSet(exerciseName: 'Squat', setNumber: 1, reps: 5)],
      ),
      throwsA(isA<ApiException>()),
    );
  });
}
