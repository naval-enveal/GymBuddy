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
}

/// App-wide [PlanApi] over the shared [apiClientProvider]. Overridden in tests
/// with a fake.
final planApiProvider = Provider<PlanApi>(
  (ref) => PlanApi(ref.watch(apiClientProvider)),
);
