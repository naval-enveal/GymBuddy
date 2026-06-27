import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/sensors/meta_glasses_sensor_source.dart';
import 'package:gymbuddy/sensors/sensor_source.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;

  const methodChannel = MethodChannel(kGlassesMethodChannel);
  const repsChannel = EventChannel(kGlassesRepsChannel);
  const formCuesChannel = EventChannel(kGlassesFormCuesChannel);

  // Records the control-channel traffic the source emits, and replies with
  // whatever the current test queued up.
  late List<MethodCall> calls;
  Object? Function(MethodCall call)? methodReply;

  setUp(() {
    calls = <MethodCall>[];
    methodReply = (_) => null;
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      calls.add(call);
      return methodReply?.call(call);
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockStreamHandler(repsChannel, null);
    messenger.setMockStreamHandler(formCuesChannel, null);
  });

  group('connect', () {
    test('maps an available handshake onto availability + capabilities',
        () async {
      methodReply = (call) => <String, Object?>{
            'availability': 'available',
            'capabilities': <String, Object?>{
              'repCounting': true,
              'formTracking': true,
            },
          };
      final source = MetaGlassesSensorSource();

      final availability = await source.connect();

      expect(availability, SensorAvailability.available);
      expect(
        source.capabilities,
        const SensorCapabilities(repCounting: true, formTracking: true),
      );
      expect(calls.single.method, 'connect');
    });

    test('surfaces unavailable faithfully when the native side says so',
        () async {
      methodReply = (call) => <String, Object?>{
            'availability': 'unavailable',
            'capabilities': <String, Object?>{
              'repCounting': false,
              'formTracking': false,
            },
          };
      final source = MetaGlassesSensorSource();

      expect(await source.connect(), SensorAvailability.unavailable);
      expect(
        source.capabilities,
        const SensorCapabilities(repCounting: false, formTracking: false),
      );
    });

    test('reflects partial capabilities (rep counting only)', () async {
      methodReply = (call) => <String, Object?>{
            'availability': 'available',
            'capabilities': <String, Object?>{
              'repCounting': true,
              'formTracking': false,
            },
          };
      final source = MetaGlassesSensorSource();

      await source.connect();
      expect(
        source.capabilities,
        const SensorCapabilities(repCounting: true, formTracking: false),
      );
    });

    test('degrades to unavailable when the native call throws', () async {
      methodReply = (call) => throw PlatformException(code: 'no_sdk');
      final source = MetaGlassesSensorSource();

      expect(await source.connect(), SensorAvailability.unavailable);
      expect(
        source.capabilities,
        const SensorCapabilities(repCounting: false, formTracking: false),
      );
    });

    test('capabilities are conservatively empty before connect', () {
      final source = MetaGlassesSensorSource();
      expect(
        source.capabilities,
        const SensorCapabilities(repCounting: false, formTracking: false),
      );
    });
  });

  group('lifecycle control channel', () {
    test('startTracking forwards the exercise name and form flag', () async {
      final source = MetaGlassesSensorSource();
      await source.startTracking(
        const TrackedExercise(name: 'Squat', formTracked: true),
      );

      expect(calls.single.method, 'startTracking');
      expect(calls.single.arguments, <String, Object?>{
        'name': 'Squat',
        'formTracked': true,
      });
    });

    test('stopTracking and dispose invoke their native methods', () async {
      final source = MetaGlassesSensorSource();
      await source.stopTracking();
      await source.dispose();

      expect(calls.map((c) => c.method), ['stopTracking', 'dispose']);
    });

    test('dispose is idempotent and swallows native failures', () async {
      methodReply = (call) => throw PlatformException(code: 'boom');
      final source = MetaGlassesSensorSource();

      await source.dispose();
      await source.dispose();

      // Only the first dispose reaches the channel; the second is a no-op.
      expect(calls.map((c) => c.method), ['dispose']);
    });

    test('using the source after dispose throws', () async {
      final source = MetaGlassesSensorSource();
      await source.dispose();

      await expectLater(source.connect(), throwsStateError);
      await expectLater(
        source.startTracking(const TrackedExercise(name: 'Squat')),
        throwsStateError,
      );
      await expectLater(source.stopTracking(), throwsStateError);
    });
  });

  group('rep event stream', () {
    test('decodes native rep maps onto RepEvent', () {
      messenger.setMockStreamHandler(
        repsChannel,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            sink
              ..success(<String, Object?>{
                'index': 1,
                'timestampMs': 1000,
                'confidence': 0.9,
              })
              ..success(<String, Object?>{
                'index': 2,
                'timestampMs': 2000,
              });
          },
        ),
      );
      final source = MetaGlassesSensorSource();

      expect(
        source.reps,
        emitsInOrder(<RepEvent>[
          RepEvent(
            index: 1,
            timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
            confidence: 0.9,
          ),
          RepEvent(
            index: 2,
            timestamp: DateTime.fromMillisecondsSinceEpoch(2000),
          ),
        ]),
      );
    });

    test('reps is a broadcast stream', () {
      messenger.setMockStreamHandler(
        repsChannel,
        MockStreamHandler.inline(onListen: (arguments, sink) {}),
      );
      final source = MetaGlassesSensorSource();
      expect(source.reps.isBroadcast, isTrue);
    });
  });

  group('form cue stream', () {
    test('decodes each severity name onto FormSeverity', () {
      messenger.setMockStreamHandler(
        formCuesChannel,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            sink
              ..success(<String, Object?>{
                'severity': 'good',
                'message': 'Nice depth',
              })
              ..success(<String, Object?>{
                'severity': 'minor',
                'message': 'Slow down',
              })
              ..success(<String, Object?>{
                'severity': 'major',
                'message': 'Back flat',
              });
          },
        ),
      );
      final source = MetaGlassesSensorSource();

      expect(
        source.formCues,
        emitsInOrder(<FormCue>[
          const FormCue(severity: FormSeverity.good, message: 'Nice depth'),
          const FormCue(severity: FormSeverity.minor, message: 'Slow down'),
          const FormCue(severity: FormSeverity.major, message: 'Back flat'),
        ]),
      );
    });

    test('an unknown severity defaults to minor rather than dropping the cue',
        () {
      messenger.setMockStreamHandler(
        formCuesChannel,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            sink.success(<String, Object?>{
              'severity': 'wat',
              'message': 'Unmapped',
            });
          },
        ),
      );
      final source = MetaGlassesSensorSource();

      expect(
        source.formCues,
        emits(
          const FormCue(severity: FormSeverity.minor, message: 'Unmapped'),
        ),
      );
    });

    test('formCues is a broadcast stream', () {
      messenger.setMockStreamHandler(
        formCuesChannel,
        MockStreamHandler.inline(onListen: (arguments, sink) {}),
      );
      final source = MetaGlassesSensorSource();
      expect(source.formCues.isBroadcast, isTrue);
    });
  });
}
