import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme.dart';
import 'billing_config.dart';
import 'entitlement.dart';
import 'entitlement_controller.dart';
import 'paywall_sheet.dart';
import 'purchase_service.dart';

/// Whether the paid features are available right now, without asking anyone.
///
/// Use this for *display* decisions — showing a small lock next to a control.
/// Use [requirePlus] for the action itself.
bool hasPlus(BuildContext context) {
  if (!billingConfigured) return true;
  return context.watch<EntitlementController>().hasPlus;
}

/// Gate in front of a paid action.
///
/// Returns true if the caller may proceed — either because the user is
/// entitled, or because they just subscribed. Returns false if they declined,
/// in which case the caller must do nothing at all.
///
/// Three ways this returns true without showing anything:
///  * billing is not configured in this build, so nothing is for sale;
///  * the user has an active subscription;
///  * the user was already using the app before the paid tier existed.
Future<bool> requirePlus(
  BuildContext context,
  AppPalette palette,
  PlusFeature feature,
) async {
  if (!billingConfigured) return true;

  final EntitlementController entitlement =
      context.read<EntitlementController>();
  if (entitlement.hasPlus) return true;

  // Not entitled yet, but the entitlement may simply not have loaded — never
  // show a paywall to somebody who has paid just because a disk read is slow.
  // Read this before any await: after one, the context may be gone.
  final PurchaseService purchases = context.read<PurchaseService>();

  if (!entitlement.isLoaded) {
    await entitlement.init();
    if (entitlement.hasPlus) return true;
  }

  final PlusOffer offer = await _offerOrFallback(purchases);
  if (!context.mounted) return false;

  return showPaywall(
    context,
    palette,
    feature: feature,
    offer: offer,
    onSubscribe: () => _complete(entitlement, purchases.subscribe()),
    onRestore: () => _complete(entitlement, purchases.restore()),
  );
}

/// A store that will not list its products should not block the paywall —
/// show the fallback price rather than nothing.
Future<PlusOffer> _offerOrFallback(PurchaseService purchases) async {
  try {
    return await purchases.loadOffer();
  } catch (_) {
    return const PlusOffer.fallback();
  }
}

/// Applies whatever the store returned, so the unlock is immediate rather
/// than waiting on the next server refresh.
Future<bool> _complete(
  EntitlementController controller,
  Future<Entitlement?> pending,
) async {
  final Entitlement? result = await pending;
  if (result == null) return false;
  await controller.apply(result);
  return controller.hasPlus;
}
