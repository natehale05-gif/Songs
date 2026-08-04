import 'billing_config.dart';
import 'entitlement.dart';

/// Base URL of the service that holds accounts and entitlements, e.g.
/// `https://billing.songsofthechurch.app`. Injected at build time:
///
///   flutter build ... --dart-define=BILLING_URL=https://your-billing.example
///
/// Empty by default, and that is deliberate: with no billing service there is
/// nothing that could verify a purchase, so the app must not pretend to sell
/// anything. See [billingConfigured].
const String kBillingApiUrl = String.fromEnvironment('BILLING_URL');

/// Whether this build can sell and verify a subscription.
///
/// When false the paid features stay **unlocked**. A build that cannot check
/// an entitlement must not lock people out on the strength of a paywall it
/// has no way to honour — that would turn a missing config value into a
/// broken app for everyone.
bool get billingConfigured => kBillingApiUrl.trim().isNotEmpty;

/// Buying and restoring, whichever store this platform uses.
///
/// Implementations differ per platform — StoreKit and Play Billing through
/// `in_app_purchase`, Stripe Checkout on web and desktop — but the app only
/// ever sees this.
abstract class PurchaseService {
  /// The offer to show, with the store's own localised price where possible.
  Future<PlusOffer> loadOffer();

  /// Runs the platform's purchase flow. Returns the resulting entitlement, or
  /// null if the user cancelled.
  ///
  /// Should throw only when something actually went wrong; a cancelled
  /// purchase is a normal outcome and not an error to report.
  Future<Entitlement?> subscribe();

  /// Re-checks for a subscription this account already has, after a reinstall
  /// or on a second device. Returns null when there is nothing to restore.
  Future<Entitlement?> restore();
}

/// Stands in wherever billing has not been set up. Never sells anything.
///
/// Reachable only through a bug, since [billingConfigured] is false in that
/// situation and the gate lets everyone through without asking this.
class UnconfiguredPurchaseService implements PurchaseService {
  const UnconfiguredPurchaseService();

  @override
  Future<PlusOffer> loadOffer() async => const PlusOffer.fallback();

  @override
  Future<Entitlement?> subscribe() async =>
      throw StateError('This build has no billing service configured.');

  @override
  Future<Entitlement?> restore() async =>
      throw StateError('This build has no billing service configured.');
}
