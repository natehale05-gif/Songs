/// Product identifiers and the copy that has to appear next to a price.
///
/// The identifiers must match the products created in App Store Connect and
/// the Play Console exactly; a mismatch surfaces as an empty store listing
/// with no error, which is a miserable thing to debug.
library;

import 'package:flutter/foundation.dart';

/// The single paid tier. One product, one price, renewed yearly.
const String kPlusProductId = 'app.songsofthechurch.plus.yearly';

/// Shown only until the store hands back a real localised price. Never show
/// this to a user in a country whose currency is not USD — always prefer the
/// store's own string, which is why [PlusOffer.price] exists.
const String kPlusFallbackPrice = r'$12';

/// What the subscription is called in the interface.
const String kPlusName = 'Songs of the Church Plus';

/// RevenueCat-hosted purchase page. Opened only where [purchaseAllowedHere]
/// says it may be.
const String kPurchaseUrl = String.fromEnvironment('PURCHASE_URL');

/// Whether this build may show a purchase button, or even mention where to
/// buy.
///
/// False on iOS and Android, and that is not a limitation of the code. App
/// Store guideline 3.1.1 requires digital features sold inside an iOS app to
/// go through In-App Purchase, and Google Play's payments policy says the
/// same. Selling only on the web is allowed for a genuine multiplatform
/// service under 3.1.3(b) — but only if the mobile app neither sells nor
/// *steers*, so it must not link to the purchase page or tell anyone it
/// exists. On those platforms the paywall is a sign-in prompt and nothing
/// more.
///
/// A mobile browser is not the App Store, so the web build sells normally
/// even when it is running on an iPhone — hence the [kIsWeb] check first.
bool get purchaseAllowedHere {
  if (kPurchaseUrl.trim().isEmpty) return false;
  if (kIsWeb) return true;
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.android:
      return false;
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return true;
  }
}

const String kTermsUrl = 'https://natehale05-gif.github.io/Songs/terms.html';
const String kPrivacyUrl =
    'https://natehale05-gif.github.io/Songs/privacy.html';

/// A purchasable offer as the underlying store describes it.
///
/// The price is a *string* on purpose: stores return an already-formatted,
/// already-localised price, and reconstructing one from a number and a
/// currency code gets it wrong in enough locales to be a real problem.
class PlusOffer {
  const PlusOffer({
    required this.id,
    required this.price,
    this.period = 'year',
  });

  /// What to show before any store has answered.
  const PlusOffer.fallback()
      : id = kPlusProductId,
        price = kPlusFallbackPrice,
        period = 'year';

  final String id;
  final String price;
  final String period;

  /// "$12 per year", in whatever currency the store quoted.
  String get headline => '$price per $period';
}

/// The renewal terms Apple requires on any screen that sells an
/// auto-renewing subscription. Reviewers check for this specific substance —
/// that it renews, when it is charged, how to turn it off — and reject
/// submissions where it is missing or vague.
const String kRenewalDisclosure =
    'Payment is charged to your store account at confirmation of purchase. '
    'The subscription renews automatically unless it is cancelled at least 24 '
    'hours before the end of the current period, and your account is charged '
    'for renewal within 24 hours of the end of that period. You can manage the '
    'subscription and turn off auto-renewal in your account settings.';
