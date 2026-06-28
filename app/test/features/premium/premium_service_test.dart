// MockPremiumService is the store-free default: it starts free, offers a fixed
// set of packages, and a purchase flips it to premium so the unlock flow runs
// end to end with no store. Also covers value equality of the wire-agnostic
// PremiumPackage / PremiumOffering types and the provider default.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy/features/premium/premium_service.dart';

void main() {
  group('PremiumPackage / PremiumOffering value equality', () {
    test('packages with the same fields are equal', () {
      const a = PremiumPackage(id: 'm', title: 'Monthly', priceString: r'$1');
      const b = PremiumPackage(id: 'm', title: 'Monthly', priceString: r'$1');
      const c = PremiumPackage(id: 'm', title: 'Monthly', priceString: r'$2');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('offerings compare by package list', () {
      const p = PremiumPackage(id: 'm', title: 'Monthly', priceString: r'$1');
      const q = PremiumPackage(id: 'y', title: 'Annual', priceString: r'$9');
      expect(
        const PremiumOffering(packages: [p, q]),
        equals(const PremiumOffering(packages: [p, q])),
      );
      expect(
        const PremiumOffering(packages: [p]),
        isNot(equals(const PremiumOffering(packages: [p, q]))),
      );
      expect(PremiumOffering.empty.packages, isEmpty);
    });
  });

  group('MockPremiumService', () {
    test('starts free by default and offers packages', () async {
      final service = MockPremiumService();
      expect(await service.current(), PremiumStatus.free);
      final offering = await service.offering();
      expect(offering.packages, isNotEmpty);
      // Every offered package carries an id, title, and price for the paywall.
      for (final package in offering.packages) {
        expect(package.id, isNotEmpty);
        expect(package.title, isNotEmpty);
        expect(package.priceString, isNotEmpty);
      }
    });

    test('honors an initial premium status', () async {
      final service = MockPremiumService(initial: PremiumStatus.premium);
      expect(await service.current(), PremiumStatus.premium);
    });

    test('purchase flips the entitlement to premium and persists it', () async {
      final service = MockPremiumService();
      expect(await service.purchase('monthly'), PremiumStatus.premium);
      // The new status sticks for subsequent reads (and a restore).
      expect(await service.current(), PremiumStatus.premium);
      expect(await service.restore(), PremiumStatus.premium);
    });

    test('restore reports the unchanged status when nothing was bought',
        () async {
      final service = MockPremiumService();
      expect(await service.restore(), PremiumStatus.free);
    });
  });

  test('premiumServiceProvider defaults to the mock (free)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final service = container.read(premiumServiceProvider);
    expect(service, isA<MockPremiumService>());
    expect(await service.current(), PremiumStatus.free);
  });
}
