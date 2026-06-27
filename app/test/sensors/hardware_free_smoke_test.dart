import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/sensors/meta_glasses_sensor_source.dart';
import 'package:gymbuddy/sensors/mock_sensor_source.dart';
import 'package:gymbuddy/sensors/sensor_source.dart';
import 'package:gymbuddy/sensors/sensor_source_resolver.dart';

/// Hardware-free smoke test for the M7 "App builds + runs with no hardware
/// present" task.
///
/// The native glasses code (Kotlin/Swift over the DAT SDK) can't be compiled or
/// linked headless, so the verifiable gate is the Dart seam: with no DAT SDK
/// vendored and no glasses paired — the state of *every* headless build, and of
/// any device the user hasn't connected glasses to — the app must resolve a
/// usable [WorkoutSensorSource] from its real defaults and run a whole workout
/// session through it without ever touching hardware. The resolver unit tests
/// prove the keep/dispose *decision*; this proves the resolved source is
/// actually drivable end to end, which is what "runs with no hardware" means.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('hardware-free smoke', () {
    setUp(() {
      // No native handler on the glasses control channel models "no DAT SDK /
      // no glasses paired": the real MetaGlassesSensorSource.connect() hits a
      // MissingPluginException and degrades to `unavailable`, exactly as on a
      // device with nothing attached.
      TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(kGlassesMethodChannel),
        null,
      );
    });

    test(
        'resolves the mock and runs a full session lifecycle with no glasses '
        'attached', () async {
      // The composition root (main.dart) calls this with its defaults at
      // startup; do the same here — no factory injection.
      final source = await resolveWorkoutSensorSource();
      addTearDown(source.dispose);

      // The fallback landed on the hardware-free source.
      expect(source, isA<MockSensorSource>());

      // Every path a real workout session drives — connect, capability read,
      // track, observe reps + form cues, take a wake trigger, push an output
      // cue, stop — must work with nothing attached.
      expect(await source.connect(), SensorAvailability.available);
      expect(source.capabilities.repCounting, isTrue);

      final reps = <RepEvent>[];
      final cues = <FormCue>[];
      final wakes = <WakeEvent>[];
      final repSub = source.reps.listen(reps.add);
      final cueSub = source.formCues.listen(cues.add);
      final wakeSub = source.wakeEvents.listen(wakes.add);
      addTearDown(repSub.cancel);
      addTearDown(cueSub.cancel);
      addTearDown(wakeSub.cancel);

      final mock = source as MockSensorSource;
      await source.startTracking(
        const TrackedExercise(name: 'Squat', formTracked: true),
      );
      mock.emitRep(confidence: 0.9);
      mock.emitFormCue(
        const FormCue(severity: FormSeverity.good, message: 'Nice depth'),
      );
      mock.emitWake();

      // The one *output* path back to the glasses' speakers is a safe no-op
      // when there are none — callers fire cues unconditionally.
      await source.playCue('Three reps to go');

      // Stop tracking before asserting so the mock's auto-simulation timer is
      // cancelled and can't add a stray rep.
      await source.stopTracking();
      await Future<void>.delayed(Duration.zero); // flush the broadcast streams

      expect(reps, hasLength(1));
      expect(reps.single.index, 1);
      expect(cues.single.severity, FormSeverity.good);
      expect(wakes.single.phrase, kWakePhrase);
    });
  });
}
