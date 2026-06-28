import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gymbuddy/features/premium/premium_service.dart';

/// The premium feature's loaded state: the current [status], the purchasable
/// [offering] for the paywall, and a transient [purchasing] flag set while a
/// purchase or restore is in flight (so the paywall can show progress and block
/// a second tap).
@immutable
class PremiumState {
  const PremiumState({
    this.status = PremiumStatus.free,
    this.offering = PremiumOffering.empty,
    this.purchasing = false,
  });

  /// The last resolved entitlement.
  final PremiumStatus status;

  /// The purchase options to render on the paywall.
  final PremiumOffering offering;

  /// Whether a purchase/restore is currently in flight.
  final bool purchasing;

  /// Whether premium features should be offered to the user.
  bool get isPremium => status == PremiumStatus.premium;

  PremiumState copyWith({
    PremiumStatus? status,
    PremiumOffering? offering,
    bool? purchasing,
  }) {
    return PremiumState(
      status: status ?? this.status,
      offering: offering ?? this.offering,
      purchasing: purchasing ?? this.purchasing,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PremiumState &&
      other.status == status &&
      other.offering == offering &&
      other.purchasing == purchasing;

  @override
  int get hashCode => Object.hash(status, offering, purchasing);
}

/// Owns the client's premium entitlement state on top of
/// [premiumServiceProvider].
///
/// `build()` reads the current entitlement and the paywall offering
/// concurrently. [purchase] / [restore] run through the service and fold the
/// resulting status back into state behind the [PremiumState.purchasing] flag;
/// both are no-ops while a request is already in flight, and the flag is always
/// cleared — even if the service throws (it's contracted not to, but the paywall
/// must never strand the user mid-purchase). All store I/O lives here, never in
/// the widgets.
class PremiumController extends AsyncNotifier<PremiumState> {
  @override
  Future<PremiumState> build() => _read();

  Future<PremiumState> _read() async {
    final service = ref.read(premiumServiceProvider);
    final statusFuture = service.current();
    final offeringFuture = service.offering();
    return PremiumState(
      status: await statusFuture,
      offering: await offeringFuture,
    );
  }

  /// Buys [packageId] and folds the resulting entitlement into state.
  Future<void> purchase(String packageId) =>
      _run((service) => service.purchase(packageId));

  /// Restores prior purchases and folds the resulting entitlement into state.
  Future<void> restore() => _run((service) => service.restore());

  Future<void> _run(
    Future<PremiumStatus> Function(PremiumService service) action,
  ) async {
    final current = state.value;
    // Ignore until the initial load has resolved, and single-flight so a
    // double-tap can't fire two store flows.
    if (current == null || current.purchasing) return;
    state = AsyncData(current.copyWith(purchasing: true));
    try {
      final status = await action(ref.read(premiumServiceProvider));
      state = AsyncData(current.copyWith(status: status, purchasing: false));
    } catch (error, stackTrace) {
      // The service is contracted not to throw, but never leave the paywall
      // stuck showing a spinner if it does — clear the flag, keep the status.
      debugPrint('Premium action failed: $error\n$stackTrace');
      state = AsyncData(current.copyWith(purchasing: false));
    }
  }

  /// Re-reads entitlement + offering (e.g. retry after a transient load error).
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_read);
  }
}

/// The client's premium entitlement state. See [PremiumController].
final premiumControllerProvider =
    AsyncNotifierProvider<PremiumController, PremiumState>(
  PremiumController.new,
);

/// Convenience read of "is the user premium right now" for gating UX. Resolves
/// to `false` while the entitlement is still loading or errored — features stay
/// locked until premium is positively confirmed (the safe default; the server
/// enforces the real gate regardless).
final isPremiumProvider = Provider<bool>(
  (ref) =>
      ref.watch(premiumControllerProvider).value?.isPremium ?? false,
);
