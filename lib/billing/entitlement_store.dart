import 'package:shared_preferences/shared_preferences.dart';

import 'entitlement.dart';

/// Local persistence for the paid tier.
///
/// Two jobs: cache what the server last said so the app still works offline,
/// and decide once whether this install predates the paid tier.
class EntitlementStore {
  EntitlementStore({SharedPreferences? prefs}) : _injected = prefs;

  static const String kCached = 'billing-entitlement';
  static const String kLegacyUser = 'billing-legacy-user';

  /// Keys written by earlier versions. Their presence is what tells us
  /// somebody was already using the app before any of this existed — there is
  /// no install date to read, and shipping a release purely to record one
  /// would delay the paid tier by a whole cycle.
  static const List<String> kPriorUseKeys = <String>[
    'songbook-favorites',
    'songbook-open-counts',
    'update_dismissed_version',
  ];

  final SharedPreferences? _injected;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= _injected ?? await SharedPreferences.getInstance();

  Future<Entitlement?> readCached() async {
    final String? raw = (await _p).getString(kCached);
    if (raw == null) return null;
    return Entitlement.tryParse(raw);
  }

  Future<void> writeCached(Entitlement entitlement) async {
    await (await _p).setString(kCached, entitlement.encode());
  }

  Future<void> clearCached() async {
    await (await _p).remove(kCached);
  }

  /// Whether this install was in use before the paid tier shipped.
  ///
  /// Decided once and then sticky, so that clearing favourites later does not
  /// silently revoke access somebody has been relying on.
  Future<bool> resolveLegacyUser() async {
    final SharedPreferences prefs = await _p;
    final bool? already = prefs.getBool(kLegacyUser);
    if (already != null) return already;

    final bool usedBefore =
        kPriorUseKeys.any((String key) => prefs.containsKey(key));
    await prefs.setBool(kLegacyUser, usedBefore);
    return usedBefore;
  }
}
