import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/core/network/api_client.dart';
import 'package:gymbuddy/features/plans/plan_models.dart';

/// Typed wrapper over the backend plans API (`GET /plans/templates`).
///
/// Keeps the network call and wire decoding out of the widgets and the
/// controller (per the no-logic-in-widgets rule), mirroring
/// `features/onboarding/profile_api.dart`.
class PlanApi {
  PlanApi(this._client);

  final ApiClient _client;

  /// Fetches the profile-ranked template library, best-match-first. The wire
  /// shape is `{ templates: [ { ...plan, matchScore } ] }`; a missing or
  /// malformed list decodes to empty rather than throwing. Throws
  /// [ApiException] on a non-2xx response (surfaced by the caller).
  Future<List<PlanTemplate>> fetchTemplates() async {
    final response = await _client.get('/plans/templates');
    final templates = response is Map ? response['templates'] : null;
    if (templates is! List) return const <PlanTemplate>[];
    return <PlanTemplate>[
      for (final t in templates)
        if (t is Map<String, dynamic>) PlanTemplate.fromJson(t),
    ];
  }

  /// Fetches the user's currently active plan, or `null` if none is adopted.
  /// Wire shape is `{ plan: {...} | null }`. Throws [ApiException] on a non-2xx
  /// response.
  Future<PlanTemplate?> fetchActivePlan() async {
    final response = await _client.get('/plans/active');
    final plan = response is Map ? response['plan'] : null;
    if (plan is! Map<String, dynamic>) return null;
    return PlanTemplate.fromJson(plan);
  }

  /// Adopts the template [templateId] as the user's active plan. The server
  /// writes an owned, active copy and deactivates any prior active plan (one
  /// active plan per user, enforced server-side). Returns the resolved owned
  /// plan. Wire shape is `{ plan: {...} }`. Throws [ApiException] on a non-2xx
  /// response.
  Future<PlanTemplate> adoptPlan(String templateId) async {
    final response = await _client.post('/plans/$templateId/adopt');
    final plan = response is Map ? response['plan'] : null;
    if (plan is! Map<String, dynamic>) {
      throw const ApiException(500, 'Adopting the plan returned no plan');
    }
    return PlanTemplate.fromJson(plan);
  }
}

/// App-wide [PlanApi] over the shared [apiClientProvider]. Overridden in tests
/// with a fake.
final planApiProvider = Provider<PlanApi>(
  (ref) => PlanApi(ref.watch(apiClientProvider)),
);
