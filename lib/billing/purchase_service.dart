import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'billing_config.dart';
import 'entitlement.dart';
import 'entitlement_controller.dart';

/// Reads the entitlement Supabase mirrors from RevenueCat.
///
/// The read is a single row protected by row level security, so a client can
/// only ever see its own. Nothing here can *grant* an entitlement — only the
/// webhook, running as the service role, writes that table.
class SupabaseEntitlementSource implements EntitlementSource {
  SupabaseEntitlementSource({SupabaseClient? client}) : _injected = client;

  final SupabaseClient? _injected;
  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  @override
  Future<Entitlement> fetch() async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      // Signed out is a definite answer, unlike a network failure: there is no
      // account, so there is no entitlement.
      return const Entitlement.none();
    }

    final Map<String, dynamic>? row = await _client
        .from('songs_entitlements')
        .select('active, expires_at, source')
        .eq('user_id', user.id)
        .maybeSingle();

    if (row == null) return const Entitlement.none();

    return Entitlement(
      active: row['active'] == true,
      expiresAt: DateTime.tryParse(row['expires_at']?.toString() ?? ''),
      source: _sourceFrom(row['source']?.toString()),
    );
  }

  static PurchaseSource? _sourceFrom(String? raw) {
    switch (raw) {
      case 'app_store':
        return PurchaseSource.appStore;
      case 'play_store':
        return PurchaseSource.playStore;
      case 'stripe':
        return PurchaseSource.stripe;
      default:
        return null;
    }
  }
}

/// Sends someone to the hosted purchase page, where that is permitted.
///
/// There is no in-app purchase flow at all: subscriptions are sold on the web
/// through RevenueCat, and the mobile builds deliberately cannot open this —
/// see [purchaseAllowedHere] for why that is a store rule rather than an
/// oversight.
class PurchaseLauncher {
  const PurchaseLauncher();

  bool get canPurchaseHere => purchaseAllowedHere;

  /// Opens the purchase page for [appUserId], so RevenueCat attributes the
  /// subscription to the account that will later sign in on other devices.
  ///
  /// Returns false if it could not be opened, or if selling is not permitted
  /// on this platform.
  Future<bool> open(String appUserId) async {
    if (!canPurchaseHere) return false;
    final Uri base = Uri.parse(kPurchaseUrl);
    final Uri url = base.replace(queryParameters: <String, String>{
      ...base.queryParameters,
      // RevenueCat Web Billing reads this and uses it as the App User ID.
      'app_user_id': appUserId,
    });
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
