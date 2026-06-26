import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/features/onboarding/profile_api.dart';

/// Decides, for an authenticated user, whether the onboarding flow still needs
/// to run. The `AuthGate` watches this once past auth and routes to the
/// `OnboardingScreen` while the value is `false`, or the app shell once it's
/// `true`.
///
/// [build] reads the current state from the backend (`GET /profile`): a user
/// with no profile, or one whose `onboardingComplete` flag isn't set, still
/// needs onboarding. A fetch failure surfaces as an `AsyncError` so the gate can
/// offer a retry rather than silently guessing.
///
/// When the user finishes the flow, `OnboardingScreen` calls [markComplete] to
/// flip the gate locally — no extra round-trip, since the just-completed save
/// already persisted the flag server-side.
class OnboardingGateController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() {
    return ref.read(profileApiProvider).fetchOnboardingComplete();
  }

  /// Marks onboarding complete so the gate swaps to the shell. Called by the
  /// onboarding flow on a successful finish.
  void markComplete() {
    state = const AsyncData(true);
  }
}

/// Whether the authenticated user has completed onboarding. See
/// [OnboardingGateController].
final onboardingGateProvider =
    AsyncNotifierProvider<OnboardingGateController, bool>(
  OnboardingGateController.new,
);
