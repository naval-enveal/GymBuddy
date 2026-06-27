import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/pose/pose_detector.dart';
import 'package:gymbuddy/sensors/meta_glasses_sensor_source.dart';
import 'package:gymbuddy/sensors/sensor_source.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;

  const methodChannel = MethodChannel(kGlassesMethodChannel);
  const repsChannel = EventChannel(kGlassesRepsChannel);
  const formCuesChannel = EventChannel(kGlassesFormCuesChannel);
  const wakeChannel = EventChannel(kGlassesWakeChannel);
  const cameraChannel = EventChannel(kGlassesCameraChannel);

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
    messenger.setMockStreamHandler(wakeChannel, null);
    messenger.setMockStreamHandler(cameraChannel, null);
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
      final source = MetaGlassesSensorSource(poseDetector: MockPoseDetector());

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
      final source = MetaGlassesSensorSource(poseDetector: MockPoseDetector());

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
      await expectLater(source.playCue('Go'), throwsStateError);
    });
  });

  group('playCue (audio output)', () {
    test('forwards the message over the control channel', () async {
      final source = MetaGlassesSensorSource();
      await source.playCue('Keep your back straight');

      expect(calls.single.method, 'playCue');
      expect(calls.single.arguments, <String, Object?>{
        'message': 'Keep your back straight',
      });
    });

    test('swallows a native failure rather than blocking the workout',
        () async {
      methodReply = (call) => throw PlatformException(code: 'no_speaker');
      final source = MetaGlassesSensorSource();

      // Best-effort output: a delivery failure must not surface as an error.
      await expectLater(source.playCue('Nice rep'), completes);
    });

    test('swallows a missing-plugin failure on an unsupported platform',
        () async {
      messenger.setMockMethodCallHandler(methodChannel, null);
      final source = MetaGlassesSensorSource();

      await expectLater(source.playCue('Nice rep'), completes);
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

  group('wake event stream', () {
    test('decodes native wake maps onto WakeEvent', () {
      messenger.setMockStreamHandler(
        wakeChannel,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            sink
              ..success(<String, Object?>{
                'timestampMs': 1000,
                'phrase': 'hey buddy',
                'confidence': 0.88,
              })
              ..success(<String, Object?>{
                'timestampMs': 2000,
                'phrase': 'hey buddy',
              });
          },
        ),
      );
      final source = MetaGlassesSensorSource();

      expect(
        source.wakeEvents,
        emitsInOrder(<WakeEvent>[
          WakeEvent(
            phrase: 'hey buddy',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
            confidence: 0.88,
          ),
          WakeEvent(
            phrase: 'hey buddy',
            timestamp: DateTime.fromMillisecondsSinceEpoch(2000),
          ),
        ]),
      );
    });

    test('defaults to the wake phrase when the native side omits it', () {
      messenger.setMockStreamHandler(
        wakeChannel,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            sink.success(<String, Object?>{'timestampMs': 1000});
          },
        ),
      );
      final source = MetaGlassesSensorSource();

      expect(
        source.wakeEvents,
        emits(
          WakeEvent(
            phrase: kWakePhrase,
            timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
          ),
        ),
      );
    });

    test('wakeEvents is a broadcast stream', () {
      messenger.setMockStreamHandler(
        wakeChannel,
        MockStreamHandler.inline(onListen: (arguments, sink) {}),
      );
      final source = MetaGlassesSensorSource();
      expect(source.wakeEvents.isBroadcast, isTrue);
    });
  });

  group('camera frames + pose detector', () {
    test('decodes native camera frame maps onto PoseInput', () {
      messenger.setMockStreamHandler(
        cameraChannel,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            sink.success(<String, Object?>{
              'rgb': Uint8List.fromList(List<int>.filled(2 * 1 * 3, 7)),
              'width': 2,
              'height': 1,
              'timestampMs': 1000,
            });
          },
        ),
      );
      final source = MetaGlassesSensorSource(poseDetector: MockPoseDetector());

      expect(
        source.cameraFrames,
        emits(
          predicate<PoseInput>(
            (p) =>
                p.width == 2 &&
                p.height == 1 &&
                p.rgb.length == 6 &&
                p.timestamp == DateTime.fromMillisecondsSinceEpoch(1000),
          ),
        ),
      );
    });

    test('connect initialises the pose detector when available', () async {
      methodReply = (call) => <String, Object?>{
            'availability': 'available',
            'capabilities': <String, Object?>{
              'repCounting': true,
              'formTracking': true,
            },
          };
      final pose = MockPoseDetector();
      final source = MetaGlassesSensorSource(poseDetector: pose);

      expect(pose.isReady, isFalse);
      await source.connect();
      expect(pose.isReady, isTrue);
      expect(source.poseDetector, same(pose));
    });

    test('connect leaves the pose detector idle when unavailable', () async {
      methodReply = (call) => <String, Object?>{'availability': 'unavailable'};
      final pose = MockPoseDetector();
      final source = MetaGlassesSensorSource(poseDetector: pose);

      await source.connect();
      expect(pose.isReady, isFalse);
    });

    test('dispose tears down the pose detector', () async {
      final pose = MockPoseDetector();
      final source = MetaGlassesSensorSource(poseDetector: pose);

      await source.dispose();

      // A disposed MockPoseDetector rejects further use.
      expect(
        () => pose.emitFrame(const PoseFrame(keypoints: [])),
        throwsStateError,
      );
    });
  });
}
