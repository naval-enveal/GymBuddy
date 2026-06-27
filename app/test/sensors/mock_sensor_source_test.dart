import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/sensors/mock_sensor_source.dart';
import 'package:gymbuddy/sensors/sensor_source.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 6, 27, 9);

  test('workoutSensorSourceProvider defaults to a MockSensorSource', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(workoutSensorSourceProvider),
      isA<MockSensorSource>(),
    );
  });

  group('value types', () {
    test('SensorCapabilities has value equality', () {
      expect(
        const SensorCapabilities(repCounting: true, formTracking: false),
        const SensorCapabilities(repCounting: true, formTracking: false),
      );
      expect(
        const SensorCapabilities(repCounting: true, formTracking: false),
        isNot(const SensorCapabilities(repCounting: true, formTracking: true)),
      );
    });

    test('TrackedExercise defaults to not form-tracked and has equality', () {
      const exercise = TrackedExercise(name: 'Bench Press');
      expect(exercise.formTracked, isFalse);
      expect(exercise, const TrackedExercise(name: 'Bench Press'));
      expect(
        exercise,
        isNot(const TrackedExercise(name: 'Bench Press', formTracked: true)),
      );
    });

    test('RepEvent and FormCue have value equality', () {
      expect(
        RepEvent(index: 1, timestamp: fixedNow, confidence: 0.9),
        RepEvent(index: 1, timestamp: fixedNow, confidence: 0.9),
      );
      expect(
        const FormCue(severity: FormSeverity.minor, message: 'Slow down'),
        const FormCue(severity: FormSeverity.minor, message: 'Slow down'),
      );
      expect(
        const FormCue(severity: FormSeverity.minor, message: 'Slow down'),
        isNot(const FormCue(severity: FormSeverity.major, message: 'Slow down')),
      );
    });
  });

  group('MockSensorSource contract', () {
    test('advertises rep counting and form tracking', () {
      final source = MockSensorSource(autoSimulate: false);
      addTearDown(source.dispose);
      expect(
        source.capabilities,
        const SensorCapabilities(repCounting: true, formTracking: true),
      );
    });

    test('connect reports available', () async {
      final source = MockSensorSource(autoSimulate: false);
      addTearDown(source.dispose);
      expect(await source.connect(), SensorAvailability.available);
    });

    test('emitRep before tracking is a no-op', () async {
      final source = MockSensorSource(autoSimulate: false);
      addTearDown(source.dispose);
      final reps = <RepEvent>[];
      final sub = source.reps.listen(reps.add);
      source.emitRep();
      await pumpEventQueue();
      expect(reps, isEmpty);
      await sub.cancel();
    });

    test('emitRep increments a 1-based index with the injected timestamp',
        () async {
      final source =
          MockSensorSource(autoSimulate: false, clock: () => fixedNow);
      addTearDown(source.dispose);
      final reps = <RepEvent>[];
      final sub = source.reps.listen(reps.add);

      await source.startTracking(const TrackedExercise(name: 'Squat'));
      source.emitRep(confidence: 0.8);
      source.emitRep();
      await pumpEventQueue();

      expect(reps, [
        RepEvent(index: 1, timestamp: fixedNow, confidence: 0.8),
        RepEvent(index: 2, timestamp: fixedNow),
      ]);
      await sub.cancel();
    });

    test('startTracking resets the rep count', () async {
      final source = MockSensorSource(autoSimulate: false, clock: () => fixedNow);
      addTearDown(source.dispose);
      final reps = <RepEvent>[];
      final sub = source.reps.listen(reps.add);

      await source.startTracking(const TrackedExercise(name: 'Squat'));
      source.emitRep();
      source.emitRep();
      await source.stopTracking();
      await source.startTracking(const TrackedExercise(name: 'Squat'));
      source.emitRep();
      await pumpEventQueue();

      expect(reps.map((r) => r.index), [1, 2, 1]);
      await sub.cancel();
    });

    test('form cues only emit for a form-tracked exercise', () async {
      final source = MockSensorSource(autoSimulate: false);
      addTearDown(source.dispose);
      final cues = <FormCue>[];
      final sub = source.formCues.listen(cues.add);
      const cue = FormCue(severity: FormSeverity.major, message: 'Back flat');

      await source.startTracking(const TrackedExercise(name: 'Plank'));
      source.emitFormCue(cue);
      await pumpEventQueue();
      expect(cues, isEmpty, reason: 'rep-only exercise gets no form cues');

      await source.startTracking(
        const TrackedExercise(name: 'Squat', formTracked: true),
      );
      source.emitFormCue(cue);
      await pumpEventQueue();
      expect(cues, [cue]);
      await sub.cancel();
    });

    test('using the source after dispose throws', () async {
      final source = MockSensorSource(autoSimulate: false);
      await source.dispose();
      await expectLater(
        source.startTracking(const TrackedExercise(name: 'Squat')),
        throwsStateError,
      );
    });
  });

  // Auto-simulation is timer-driven, so these run under `fakeAsync` for
  // deterministic control of the rep-interval clock. (They deliberately avoid
  // `testWidgets`/`tester.pump`: awaiting a broadcast `StreamController.close()`
  // inside that binding's fake-async zone never resolves and hangs the runner.)
  group('MockSensorSource auto-simulation', () {
    test('emits reps on the rep interval while tracking', () {
      fakeAsync((async) {
        final source = MockSensorSource(
          repInterval: const Duration(seconds: 1),
          clock: () => fixedNow,
        );
        final reps = <RepEvent>[];
        final sub = source.reps.listen(reps.add);

        unawaited(source.startTracking(const TrackedExercise(name: 'Squat')));
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(reps.map((r) => r.index), [1]);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(reps.map((r) => r.index), [1, 2]);

        unawaited(source.stopTracking());
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        expect(reps, hasLength(2), reason: 'no reps after stopTracking');
        unawaited(sub.cancel());
      });
    });

    test('auto-simulates form cues only for form-tracked exercises', () {
      fakeAsync((async) {
        final tracked = MockSensorSource(
          repInterval: const Duration(seconds: 1),
          clock: () => fixedNow,
        );
        final trackedCues = <FormCue>[];
        final trackedSub = tracked.formCues.listen(trackedCues.add);
        unawaited(tracked.startTracking(
          const TrackedExercise(name: 'Squat', formTracked: true),
        ));
        async.elapse(const Duration(seconds: 2)); // reps 1 and 2
        async.flushMicrotasks();
        expect(trackedCues, isNotEmpty);
        unawaited(trackedSub.cancel());
        unawaited(tracked.stopTracking());

        final repOnly = MockSensorSource(
          repInterval: const Duration(seconds: 1),
          clock: () => fixedNow,
        );
        final repOnlyCues = <FormCue>[];
        final repOnlySub = repOnly.formCues.listen(repOnlyCues.add);
        unawaited(
          repOnly.startTracking(const TrackedExercise(name: 'Bench Press')),
        );
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(repOnlyCues, isEmpty);
        unawaited(repOnlySub.cancel());
        unawaited(repOnly.stopTracking());
      });
    });
  });
}
