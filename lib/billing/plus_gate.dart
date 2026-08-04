import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme.dart';
import 'auth_controller.dart';
import 'entitlement_controller.dart';
import 'paywall_sheet.dart';
import 'purchase_service.dart';
import 'sign_in_sheet.dart';
import 'supabase_config.dart';

/// Whether the paid features are available right now, without asking anyone.
///
/// For *display* decisions — a lock icon beside a control. Use [requirePlus]
/// for the action itself.
bool hasPlus(BuildContext context) {
  if (!billingConfigured) return true;
  return context.watch<EntitlementController>().hasPlus;
}

/// Gate in front of a paid action.
///
/// Returns true if the caller may proceed. False means the user declined, and
/// the caller must do nothing at all.
///
/// Returns true without showing anything when billing is not configured in
/// this build, when the subscription is active, or when the install predates
/// the paid tier.
Future<bool> requirePlus(
  BuildContext context,
  AppPalette palette,
  PlusFeature feature,
) async {
  if (!billingConfigured) return true;

  final EntitlementController entitlement =
      context.read<EntitlementController>();
  final AuthController auth = context.read<AuthController>();
  const PurchaseLauncher purchases = PurchaseLauncher();

  if (entitlement.hasPlus) return true;

  // Never paywall somebody who has paid just because a disk read is slow.
  if (!entitlement.isLoaded) {
    await entitlement.init();
    if (entitlement.hasPlus) return true;
  }

  // Signed in already? Ask the server once before concluding anything — they
  // may have subscribed in a browser a moment ago.
  if (auth.isSignedIn) {
    await entitlement.refresh();
    if (entitlement.hasPlus) return true;
  }

  if (!context.mounted) return false;

  return showPaywall(
    context,
    palette,
    feature: feature,
    stage: _stageFor(auth, purchases),
    onSignIn: () => _signInThenCheck(context, palette, auth, entitlement),
    onPurchase: () => _purchase(auth, purchases),
    onRecheck: () => _recheck(entitlement),
  );
}

PaywallStage _stageFor(AuthController auth, PurchaseLauncher purchases) {
  if (!auth.isSignedIn) return PaywallStage.signedOut;
  return purchases.canPurchaseHere
      ? PaywallStage.canBuy
      : PaywallStage.cannotBuyHere;
}

/// Signing in is not itself an unlock — it only tells us whose entitlement to
/// look up. Check immediately afterwards so somebody who already subscribed on
/// another device is let straight through.
Future<bool> _signInThenCheck(
  BuildContext context,
  AppPalette palette,
  AuthController auth,
  EntitlementController entitlement,
) async {
  final bool signedIn = await showSignInSheet(context, palette, auth);
  if (!signedIn) return false;
  await entitlement.refresh();
  return entitlement.hasPlus;
}

/// Opens the hosted purchase page, reporting only whether it *opened*.
///
/// The purchase itself finishes in a browser, so there is nothing here to
/// await — the sheet stays open and the user comes back to "Check again".
Future<bool> _purchase(AuthController auth, PurchaseLauncher purchases) async {
  final String? appUserId = auth.appUserId;
  if (appUserId == null) return false;
  return purchases.open(appUserId);
}

Future<bool> _recheck(EntitlementController entitlement) async {
  await entitlement.refresh();
  return entitlement.hasPlus;
}
