import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Product analytics + crash reporting, behind a mock-first seam (M10).
///
/// Feature code never talks to Firebase directly — it goes through this
/// interface, the same way sensor features go through `WorkoutSensorSource`,
/// health features through `HealthPermissionService`, and entitlement through
/// `PremiumService`. The real Firebase-backed implementation
/// ([FirebaseAnalyticsService]) is wired at the composition root;
/// [MockAnalyticsService] stays the default so tests and Firebase-free dev
/// builds work end to end, per the mock-first rule.
///
/// Every method is contracted **never to throw** — telemetry is observation,
/// not control flow, so a transport/SDK failure is swallowed rather than ever
/// surfacing to the user or breaking a feature path. No personal health data,
/// vitals, or secrets are ever logged through here; events carry only coarse,
/// non-identifying counts (see the call sites).
abstract interface class AnalyticsService {
  /// Records a product event. [name] should be a stable snake_case identifier
  /// (see [AnalyticsEvents]); [parameters] are small, non-identifying scalars
  /// (String or num) — null values are dropped by the backend.
  Future<void> logEvent(String name, {Map<String, Object?>? parameters});

  /// Associates subsequent events + crash reports with [id] (the backend user
  /// id), or clears the association when [id] is null (e.g. on sign-out). Never
  /// pass an email or other PII.
  Future<void> setUserId(String? id);

  /// Reports a non-fatal or fatal error to crash reporting. [fatal] marks an
  /// uncaught crash (vs. a handled exception); [reason] is an optional
  /// human-readable context label.
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  });
}

/// Stable event names. Centralized so call sites and dashboards can't drift —
/// one source of truth for the analytics taxonomy.
abstract final class AnalyticsEvents {
  /// A workout session began. Parameters: `plan`, `exercises`.
  static const String workoutStarted = 'workout_started';

  /// A workout session ran to completion. Parameters: `plan`, `sets`, `reps`.
  static const String workoutCompleted = 'workout_completed';

  /// A new account was created.
  static const String signUp = 'sign_up';

  /// An existing user signed in.
  static const String login = 'login';
}

/// Default, Firebase-free implementation used until the composition root wires
/// the real service, and in every test.
///
/// Buffers each call in memory so tests can assert what the app reported —
/// mirroring how `MockSensorSource` lets rep/form features run with no glasses.
/// Honors the never-throw contract trivially (it only appends to lists).
class MockAnalyticsService implements AnalyticsService {
  /// Events logged so far, in order: `(name, parameters)`.
  final List<({String name, Map<String, Object?> parameters})> events =
      <({String name, Map<String, Object?> parameters})>[];

  /// Errors reported so far, in order.
  final List<({Object error, StackTrace? stack, bool fatal, String? reason})>
      errors =
      <({Object error, StackTrace? stack, bool fatal, String? reason})>[];

  /// The most recent user id set (null = cleared / never set).
  String? userId;

  @override
  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) async {
    events.add((name: name, parameters: parameters ?? const {}));
  }

  @override
  Future<void> setUserId(String? id) async {
    userId = id;
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) async {
    errors.add((error: error, stack: stack, fatal: fatal, reason: reason));
  }
}

/// The app's analytics + crash-reporting service. Overridden at the composition
/// root with the Firebase-backed implementation when Firebase initializes;
/// defaults to [MockAnalyticsService] so feature code and tests have a working
/// dependency with no Firebase project attached.
final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => MockAnalyticsService(),
);

/// Routes Flutter's two top-level error hooks into [analytics] so uncaught
/// errors become crash reports — the "crash reporting" half of M10 task 3.
///
/// - [FlutterError.onError] catches errors thrown inside the framework (build/
///   layout/paint, gesture & timer callbacks). The previous handler is still
///   invoked first, so the default console dump in debug is preserved.
/// - [PlatformDispatcher.instance.onError] catches everything else that reaches
///   the root zone (async errors with no local catch). Returning `true` marks
///   them handled so the process isn't also killed by the default handler.
///
/// Both forward `fatal: true` — these are uncaught. Call once at startup, after
/// `WidgetsFlutterBinding.ensureInitialized()`.
void installCrashHandlers(AnalyticsService analytics) {
  final FlutterExceptionHandler? priorOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    priorOnError?.call(details);
    unawaited(
      analytics.recordError(
        details.exception,
        details.stack,
        fatal: true,
        reason: details.context?.toString(),
      ),
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    unawaited(analytics.recordError(error, stack, fatal: true));
    return true;
  };
}
