// PremiumController owns the client's entitlement state on top of
// PremiumService: build() reads status + offering, purchase/restore fold the
// resulting status back behind a single-flight `purchasing` flag, and the flag
// is always cleared — even when the service throws. isPremiumProvider derives a
// plain bool for gating UX.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/features/premium/premium_controller.dart';
import 'package:gymbuddy/features/premium/premium_service.dart';

/// Fully controllable [PremiumService] for the controller tests.
class _FakePremiumService implements PremiumService {
  _FakePremiumService({
    this.status = PremiumStatus.free,
    this.throwOnAction = false,
    this.purchaseGate,
  });

  PremiumStatus status;
  PremiumOffering offeringValue = const PremiumOffering(
    packages: [
      PremiumPackage(id: 'monthly', title: 'Monthly', priceString: r'$9'),
    ],
  );
  PremiumStatus purchaseResult = PremiumStatus.premium;
  bool throwOnAction;

  /// When set, [purchase] awaits this before resolving — lets a test pin the
  /// in-flight `purchasing` state.
  final Future<void>? purchaseGate;

  int purchaseCalls = 0;
  int restoreCalls = 0;
  String? lastPackageId;

  @override
  Future<PremiumStatus> current() async => status;

  @override
  Future<PremiumOffering> offering() async => offeringValue;

  @override
  Future<PremiumStatus> purchase(String packageId) async {
    purchaseCalls++;
    lastPackageId = packageId;
    if (purchaseGate != null) await purchaseGate;
    if (throwOnAction) throw StateError('boom');
    status = purchaseResult;
    return status;
  }

  @override
  Future<PremiumStatus> restore() async {
    restoreCalls++;
    if (throwOnAction) throw StateError('boom');
    return status;
  }
}

ProviderContainer _containerWith(_FakePremiumService service) {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [premiumServiceProvider.overrideWithValue(service)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('build() reads the current status and the offering', () async {
    final service = _FakePremiumService(status: PremiumStatus.free);
    final container = _containerWith(service);

    final state = await container.read(premiumControllerProvider.future);

    expect(state.status, PremiumStatus.free);
    expect(state.isPremium, isFalse);
    expect(state.purchasing, isFalse);
    expect(state.offering.packages, hasLength(1));
  });

  test('isPremiumProvider reflects the loaded entitlement', () async {
    final container = _containerWith(
      _FakePremiumService(status: PremiumStatus.premium),
    );
    // False until the async load resolves (features stay locked until confirmed).
    expect(container.read(isPremiumProvider), isFalse);
    await container.read(premiumControllerProvider.future);
    expect(container.read(isPremiumProvider), isTrue);
  });

  test('purchase folds in premium and clears the purchasing flag', () async {
    final service = _FakePremiumService(status: PremiumStatus.free);
    final container = _containerWith(service);
    await container.read(premiumControllerProvider.future);

    await container.read(premiumControllerProvider.notifier).purchase('annual');

    final state = container.read(premiumControllerProvider).requireValue;
    expect(service.lastPackageId, 'annual');
    expect(state.status, PremiumStatus.premium);
    expect(state.purchasing, isFalse);
    // The offering is preserved across a purchase.
    expect(state.offering.packages, hasLength(1));
    expect(container.read(isPremiumProvider), isTrue);
  });

  test('a purchase in flight sets purchasing and single-flights a second tap',
      () async {
    final gate = Completer<void>();
    final service = _FakePremiumService(purchaseGate: gate.future);
    final container = _containerWith(service);
    await container.read(premiumControllerProvider.future);
    final notifier = container.read(premiumControllerProvider.notifier);

    final first = notifier.purchase('monthly');
    // Mid-flight: the flag is set...
    expect(
      container.read(premiumControllerProvider).requireValue.purchasing,
      isTrue,
    );
    // ...and a second tap is ignored while the first is pending.
    final second = notifier.purchase('monthly');
    await second;
    expect(service.purchaseCalls, 1);

    gate.complete();
    await first;
    expect(
      container.read(premiumControllerProvider).requireValue.purchasing,
      isFalse,
    );
    expect(service.purchaseCalls, 1);
  });

  test('restore folds in the restored entitlement', () async {
    final service = _FakePremiumService(
      status: PremiumStatus.premium,
    );
    final container = _containerWith(service);
    // Load shows premium already; force free then restore back to premium.
    await container.read(premiumControllerProvider.future);
    expect(container.read(isPremiumProvider), isTrue);
    await container.read(premiumControllerProvider.notifier).restore();
    expect(service.restoreCalls, 1);
    expect(container.read(isPremiumProvider), isTrue);
  });

  test('a throwing service clears purchasing and keeps the status', () async {
    final service = _FakePremiumService(
      status: PremiumStatus.free,
      throwOnAction: true,
    );
    final container = _containerWith(service);
    await container.read(premiumControllerProvider.future);

    await container.read(premiumControllerProvider.notifier).purchase('monthly');

    final state = container.read(premiumControllerProvider).requireValue;
    expect(state.purchasing, isFalse);
    expect(state.status, PremiumStatus.free);
  });

  test('refresh re-reads status and offering', () async {
    final service = _FakePremiumService(status: PremiumStatus.free);
    final container = _containerWith(service);
    await container.read(premiumControllerProvider.future);
    expect(container.read(isPremiumProvider), isFalse);

    service.status = PremiumStatus.premium;
    await container.read(premiumControllerProvider.notifier).refresh();

    expect(container.read(isPremiumProvider), isTrue);
  });
}
