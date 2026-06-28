import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'package:gymbuddy/core/analytics/analytics_service.dart';

/// The real [AnalyticsService], backed by Firebase Analytics + Crashlytics.
///
/// Wired at the composition root via [configure], which initializes Firebase
/// and routes Flutter's uncaught-error hooks straight into Crashlytics. When
/// Firebase can't initialize — no `google-services.json` /
/// `GoogleService-Info.plist`, or running headless/dev — [configure] returns
/// null and the app keeps the [MockAnalyticsService] default (plus the generic
/// [installCrashHandlers] hooks), so nothing breaks without a Firebase project.
///
/// Honors the [AnalyticsService] never-throw contract: every method swallows
/// SDK/transport failures. Telemetry is observation, not control flow.
class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService._(this._analytics, this._crashlytics);

  final FirebaseAnalytics _analytics;
  final FirebaseCrashlytics _crashlytics;

  /// Initializes Firebase and wires Crashlytics as the crash sink, returning a
  /// ready service — or null if Firebase isn't configured/available, in which
  /// case the caller falls back to the mock. Best-effort: never throws.
  ///
  /// Both Flutter error hooks are pointed at Crashlytics here (rather than the
  /// generic [installCrashHandlers]) so native symbolication and the richer
  /// `recordFlutterError` payload are used when Firebase is present.
  static Future<FirebaseAnalyticsService?> configure() async {
    try {
      await Firebase.initializeApp();
      final crashlytics = FirebaseCrashlytics.instance;

      FlutterError.onError = crashlytics.recordFlutterError;
      PlatformDispatcher.instance.onError = (error, stack) {
        crashlytics.recordError(error, stack, fatal: true);
        return true;
      };

      return FirebaseAnalyticsService._(
        FirebaseAnalytics.instance,
        crashlytics,
      );
    } catch (error, stackTrace) {
      debugPrint('Firebase analytics configure failed: $error\n$stackTrace');
      return null;
    }
  }

  @override
  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: _coerceParameters(parameters),
      );
    } catch (error) {
      debugPrint('Firebase logEvent failed: $error');
    }
  }

  @override
  Future<void> setUserId(String? id) async {
    try {
      await _analytics.setUserId(id: id);
      await _crashlytics.setUserIdentifier(id ?? '');
    } catch (error) {
      debugPrint('Firebase setUserId failed: $error');
    }
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) async {
    try {
      await _crashlytics.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
      );
    } catch (e) {
      debugPrint('Firebase recordError failed: $e');
    }
  }

  /// Firebase only accepts String/num parameter values (and rejects nulls), so
  /// drop null entries and stringify anything that isn't already a num — the
  /// interface allows richer values than the transport does.
  static Map<String, Object>? _coerceParameters(
    Map<String, Object?>? parameters,
  ) {
    if (parameters == null || parameters.isEmpty) return null;
    final result = <String, Object>{};
    parameters.forEach((key, value) {
      if (value == null) return;
      result[key] = value is num ? value : value.toString();
    });
    return result.isEmpty ? null : result;
  }
}
