import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/network/api_client.dart';
import 'package:gymbuddy/features/onboarding/onboarding_controller.dart';

/// Typed wrapper over the backend Profile API (`PUT /profile`).
///
/// Maps an [OnboardingDraft] onto the Profile model's wire shape — each answer
/// enum is sent as its `wire` value (mirroring `server/src/models/constants.js`)
/// so the client and server speak the same vocabulary. The health-permission
/// outcome is deliberately NOT sent: it's a device-level grant the M5 vitals
/// layer reads from the platform, not part of the persisted profile.
class ProfileApi {
  ProfileApi(this._client);

  final ApiClient _client;

  /// Persists the gathered onboarding answers and marks onboarding complete.
  /// Throws [ApiException] on a non-2xx response (surfaced by the caller).
  Future<void> saveOnboarding(OnboardingDraft draft) async {
    await _client.put('/profile', body: _toWire(draft));
  }

  /// Whether the signed-in user has finished onboarding, read from
  /// `GET /profile` (response shape `{ profile: {...} | null }`). A user with no
  /// profile yet — or one whose `onboardingComplete` flag is not set — still
  /// needs onboarding, so both map to `false`. Throws [ApiException] on a
  /// non-2xx response (the gate surfaces it as a retryable error).
  Future<bool> fetchOnboardingComplete() async {
    final response = await _client.get('/profile');
    final profile = response is Map ? response['profile'] : null;
    if (profile is! Map) return false;
    return profile['onboardingComplete'] == true;
  }

  Map<String, dynamic> _toWire(OnboardingDraft draft) {
    final stats = draft.bodyStats;
    final bodyStats = <String, dynamic>{
      if (stats.heightCm != null) 'heightCm': stats.heightCm,
      if (stats.weightKg != null) 'weightKg': stats.weightKg,
      if (stats.age != null) 'age': stats.age,
      if (stats.sex != null) 'sex': stats.sex!.wire,
    };
    return <String, dynamic>{
      'goals': [for (final g in draft.goals) g.wire],
      if (draft.experience != null) 'experience': draft.experience!.wire,
      if (draft.daysPerWeek != null) 'daysPerWeek': draft.daysPerWeek,
      'equipment': [for (final e in draft.equipment) e.wire],
      'injuries': draft.injuries,
      'bodyStats': bodyStats,
      'onboardingComplete': true,
    };
  }
}

/// App-wide [ProfileApi] over the shared [apiClientProvider]. Overridden in
/// tests with a fake client.
final profileApiProvider = Provider<ProfileApi>(
  (ref) => ProfileApi(ref.watch(apiClientProvider)),
);
