import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gymbuddy/features/premium/premium_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// The RevenueCat entitlement identifier that maps to GymBuddy Premium.
///
/// Must match the entitlement configured in the RevenueCat dashboard and the
/// server's reconciliation (the server `Subscription` `tier: 'premium'`, the
/// real gate). Single source of truth for the client.
const String kPremiumEntitlementId = 'premium';

/// The real [PremiumService], backed by RevenueCat via `purchases_flutter`.
///
/// Configured at the composition root from the **public** RevenueCat SDK key —
/// which is not a secret (unlike the Claude API key, which never leaves the
/// server). Entitlement here is purely informational; the server independently
/// reconciles RevenueCat receipts and enforces premium gating (M9 task 4).
///
/// Honors the [PremiumService] contract: every method swallows store/platform
/// failures and degrades to a safe value rather than throwing — premium is a UX
/// signal, not control flow.
class RevenueCatPremiumService implements PremiumService {
  RevenueCatPremiumService();

  /// Configures the RevenueCat SDK with the platform [apiKey] (the public SDK
  /// key). Call once at startup before reading entitlement. Swallows failures so
  /// a misconfigured key degrades to the free/locked state rather than crashing
  /// the app.
  static Future<void> configure({required String apiKey}) async {
    try {
      await Purchases.configure(PurchasesConfiguration(apiKey));
    } catch (error, stackTrace) {
      debugPrint('RevenueCat configure failed: $error\n$stackTrace');
    }
  }

  bool _hasPremium(CustomerInfo info) =>
      info.entitlements.active.containsKey(kPremiumEntitlementId);

  PremiumStatus _statusOf(CustomerInfo info) =>
      _hasPremium(info) ? PremiumStatus.premium : PremiumStatus.free;

  @override
  Future<PremiumStatus> current() async {
    try {
      return _statusOf(await Purchases.getCustomerInfo());
    } catch (error) {
      debugPrint('RevenueCat getCustomerInfo failed: $error');
      return PremiumStatus.free;
    }
  }

  @override
  Future<PremiumOffering> offering() async {
    try {
      final current = (await Purchases.getOfferings()).current;
      if (current == null) return PremiumOffering.empty;
      return PremiumOffering(
        packages: [
          for (final package in current.availablePackages)
            PremiumPackage(
              id: package.identifier,
              title: package.storeProduct.title,
              priceString: package.storeProduct.priceString,
            ),
        ],
      );
    } catch (error) {
      debugPrint('RevenueCat getOfferings failed: $error');
      return PremiumOffering.empty;
    }
  }

  @override
  Future<PremiumStatus> purchase(String packageId) async {
    try {
      final package = _findPackage(
        (await Purchases.getOfferings()).current?.availablePackages,
        packageId,
      );
      if (package == null) return current();
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return _statusOf(result.customerInfo);
    } on PlatformException catch (error) {
      // A user cancellation is an expected outcome, not a failure — just report
      // the unchanged current entitlement.
      if (PurchasesErrorHelper.getErrorCode(error) !=
          PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('RevenueCat purchase failed: $error');
      }
      return current();
    } catch (error) {
      debugPrint('RevenueCat purchase failed: $error');
      return current();
    }
  }

  @override
  Future<PremiumStatus> restore() async {
    try {
      return _statusOf(await Purchases.restorePurchases());
    } catch (error) {
      debugPrint('RevenueCat restorePurchases failed: $error');
      return PremiumStatus.free;
    }
  }

  Package? _findPackage(List<Package>? packages, String id) {
    for (final package in packages ?? const <Package>[]) {
      if (package.identifier == id) return package;
    }
    return null;
  }
}
