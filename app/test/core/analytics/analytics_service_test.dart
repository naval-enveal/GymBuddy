import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/core/analytics/analytics_service.dart';
import 'package:gymbuddy/core/analytics/firebase_analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MockAnalyticsService', () {
    test('records events in order with their parameters', () async {
      final analytics = MockAnalyticsService();

      await analytics.logEvent(AnalyticsEvents.login);
      await analytics.logEvent(
        AnalyticsEvents.workoutStarted,
        parameters: <String, Object?>{'plan': 'Push Day', 'exercises': 4},
      );

      expect(analytics.events, hasLength(2));
      expect(analytics.events.first.name, AnalyticsEvents.login);
      expect(analytics.events.first.parameters, isEmpty);
      expect(analytics.events.last.name, AnalyticsEvents.workoutStarted);
      expect(analytics.events.last.parameters['plan'], 'Push Day');
      expect(analytics.events.last.parameters['exercises'], 4);
    });

    test('tracks and clears the user id', () async {
      final analytics = MockAnalyticsService();
      expect(analytics.userId, isNull);

      await analytics.setUserId('user-123');
      expect(analytics.userId, 'user-123');

      await analytics.setUserId(null);
      expect(analytics.userId, isNull);
    });

    test('records reported errors with their fatal flag and reason', () async {
      final analytics = MockAnalyticsService();
      final stack = StackTrace.current;

      await analytics.recordError('boom', stack);
      await analytics.recordError(
        StateError('nope'),
        null,
        fatal: true,
        reason: 'while building',
      );

      expect(analytics.errors, hasLength(2));
      expect(analytics.errors.first.error, 'boom');
      expect(analytics.errors.first.fatal, isFalse);
      expect(analytics.errors.last.fatal, isTrue);
      expect(analytics.errors.last.reason, 'while building');
    });
  });

  group('analyticsServiceProvider', () {
    test('defaults to a MockAnalyticsService', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(analyticsServiceProvider),
        isA<MockAnalyticsService>(),
      );
    });
  });

  group('installCrashHandlers', () {
    // The two error hooks are process-global; snapshot and restore them so the
    // test harness's own handlers aren't clobbered for later tests.
    late FlutterExceptionHandler? priorFlutterOnError;
    late bool Function(Object, StackTrace)? priorPlatformOnError;

    setUp(() {
      priorFlutterOnError = FlutterError.onError;
      priorPlatformOnError = PlatformDispatcher.instance.onError;
    });

    tearDown(() {
      FlutterError.onError = priorFlutterOnError;
      PlatformDispatcher.instance.onError = priorPlatformOnError;
    });

    test('routes FlutterError.onError into recordError as fatal, preserving '
        'the prior handler', () {
      final analytics = MockAnalyticsService();
      var priorCalled = false;
      FlutterError.onError = (_) => priorCalled = true;

      installCrashHandlers(analytics);
      final details = FlutterErrorDetails(
        exception: StateError('framework boom'),
        stack: StackTrace.current,
      );
      FlutterError.onError!(details);

      expect(priorCalled, isTrue, reason: 'prior handler still runs');
      expect(analytics.errors, hasLength(1));
      expect(analytics.errors.single.error, details.exception);
      expect(analytics.errors.single.fatal, isTrue);
    });

    test('routes PlatformDispatcher.onError into recordError and marks it '
        'handled', () {
      final analytics = MockAnalyticsService();
      installCrashHandlers(analytics);

      final handled = PlatformDispatcher.instance.onError!(
        'async boom',
        StackTrace.current,
      );

      expect(handled, isTrue);
      expect(analytics.errors, hasLength(1));
      expect(analytics.errors.single.error, 'async boom');
      expect(analytics.errors.single.fatal, isTrue);
    });
  });

  group('FirebaseAnalyticsService', () {
    test('configure returns null when Firebase is unavailable, so the app '
        'falls back to the mock', () async {
      // No Firebase plugin is registered in the test binding, so
      // Firebase.initializeApp throws — configure must swallow it and return
      // null rather than break startup.
      expect(await FirebaseAnalyticsService.configure(), isNull);
    });
  });
}
