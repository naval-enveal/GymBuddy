import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The client's view of whether the user is entitled to GymBuddy Premium.
///
/// Premium unlocks the AI features — server-side Claude plan generation and
/// real-time form coaching. This state is **informational only**: it drives UX
/// (which entry points to offer, when to show the paywall), but the server is
/// the source of truth and enforces gating independently (M9 task 4). A client
/// that claims premium it doesn't have still gets rejected by the API.
enum PremiumStatus {
  /// No active premium entitlement — the paywall is offered.
  free,

  /// An active premium entitlement — AI features are offered.
  premium,
}

/// One purchasable subscription option to render on the paywall.
///
/// A RevenueCat-agnostic projection of a store package, so the paywall and the
/// controller never import `purchases_flutter` types — only
/// [RevenueCatPremiumService] does. [id] is handed back to
/// [PremiumService.purchase] to buy this option.
@immutable
class PremiumPackage {
  const PremiumPackage({
    required this.id,
    required this.title,
    required this.priceString,
  });

  /// The store package identifier, passed back to [PremiumService.purchase].
  final String id;

  /// Human-readable plan name (e.g. "Monthly", "Annual").
  final String title;

  /// Localized, store-formatted price (e.g. r"$9.99 / mo").
  final String priceString;

  @override
  bool operator ==(Object other) =>
      other is PremiumPackage &&
      other.id == id &&
      other.title == title &&
      other.priceString == priceString;

  @override
  int get hashCode => Object.hash(id, title, priceString);
}

/// The set of purchase options shown on the paywall. [empty] is the graceful
/// fallback when offerings can't be loaded — the paywall then degrades to a
/// "restore" affordance rather than blocking.
@immutable
class PremiumOffering {
  const PremiumOffering({this.packages = const []});

  final List<PremiumPackage> packages;

  static const PremiumOffering empty = PremiumOffering();

  @override
  bool operator ==(Object other) =>
      other is PremiumOffering && listEquals(other.packages, packages);

  @override
  int get hashCode => Object.hashAll(packages);
}

/// Abstraction over the in-app purchase / entitlement provider (RevenueCat).
///
/// Feature code never talks to `purchases_flutter` directly — it goes through
/// this interface, the same way sensor features go through `WorkoutSensorSource`
/// and health features go through `HealthPermissionService`. The real
/// RevenueCat-backed implementation ([RevenueCatPremiumService]) is wired at the
/// composition root; [MockPremiumService] stays the default so tests and
/// store-free dev builds work end to end, per the mock-first rule.
///
/// Every method is contracted **never to throw** — a store/network failure
/// degrades to [PremiumStatus.free] / [PremiumOffering.empty], and a user
/// cancelling a purchase returns the unchanged current status. Premium is a
/// best-effort UX signal, not control flow.
abstract interface class PremiumService {
  /// The current entitlement, read from the store.
  Future<PremiumStatus> current();

  /// The available purchase options for the paywall.
  Future<PremiumOffering> offering();

  /// Buys the package with id [packageId] and resolves to the resulting
  /// entitlement. A user cancellation resolves to the unchanged current status.
  Future<PremiumStatus> purchase(String packageId);

  /// Restores prior purchases (e.g. on a new device) and resolves to the
  /// resulting entitlement.
  Future<PremiumStatus> restore();
}

/// Default, store-free implementation used until the composition root wires the
/// real RevenueCat service, and in every test.
///
/// Starts [PremiumStatus.free] (so the paywall is exercisable in dev) and offers
/// a fixed, plausible set of packages; [purchase] flips the in-memory status to
/// premium so the unlock flow can be driven end to end with no store attached —
/// mirroring how `MockSensorSource` lets rep/form features run with no glasses.
class MockPremiumService implements PremiumService {
  MockPremiumService({PremiumStatus initial = PremiumStatus.free})
      : _status = initial;

  PremiumStatus _status;

  static const PremiumOffering _offering = PremiumOffering(
    packages: [
      PremiumPackage(id: 'monthly', title: 'Monthly', priceString: r'$9.99 / mo'),
      PremiumPackage(id: 'annual', title: 'Annual', priceString: r'$79.99 / yr'),
    ],
  );

  @override
  Future<PremiumStatus> current() async => _status;

  @override
  Future<PremiumOffering> offering() async => _offering;

  @override
  Future<PremiumStatus> purchase(String packageId) async {
    _status = PremiumStatus.premium;
    return _status;
  }

  @override
  Future<PremiumStatus> restore() async => _status;
}

/// The app's premium service. Overridden at the composition root with the
/// RevenueCat-backed implementation when a public SDK key is configured;
/// defaults to [MockPremiumService] so feature code and tests have a working
/// dependency today.
final premiumServiceProvider = Provider<PremiumService>(
  (ref) => MockPremiumService(),
);
