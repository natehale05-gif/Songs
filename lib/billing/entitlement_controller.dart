import 'dart:async';

import 'package:flutter/foundation.dart';

import 'entitlement.dart';
import 'entitlement_store.dart';

/// Where the current entitlement is fetched from.
///
/// An interface rather than a concrete client so the gating can be built and
/// tested without a billing server, and so the backing can change — own
/// backend, or a billing provider — without touching any screen.
abstract class EntitlementSource {
  /// Ask the server what this user is entitled to. Should throw if it cannot
  /// reach it, rather than reporting "not entitled" — the two mean very
  /// different things to somebody who has paid.
  Future<Entitlement> fetch();
}

/// App-wide answer to "can this person use the paid features".
///
/// Reads the cache first and only then refreshes, because the app is built to
/// open instantly and work with no connection. A subscriber must never see the
/// paywall just because the network is slow.
class EntitlementController extends ChangeNotifier {
  EntitlementController({
    EntitlementStore? store,
    EntitlementSource? source,
    DateTime Function()? clock,
  })  : _store = store ?? EntitlementStore(),
        _now = clock ?? DateTime.now {
    // Assigned in the body rather than the initializer list because the field
    // is reassignable through the setter below.
    _source = source;
  }

  final EntitlementStore _store;
  final DateTime Function() _now;

  EntitlementSource? _source;
  set source(EntitlementSource? value) => _source = value;

  Entitlement _entitlement = const Entitlement.none();
  bool _loaded = false;
  bool _refreshing = false;

  /// Null until the first refresh has been attempted.
  Object? _lastRefreshError;

  Entitlement get entitlement => _entitlement;

  /// Whether the entitlement has been read from disk yet. Screens should not
  /// decide anything before this is true, or they will flash a paywall at a
  /// paying user on every cold start.
  bool get isLoaded => _loaded;

  bool get isRefreshing => _refreshing;
  Object? get lastRefreshError => _lastRefreshError;

  /// The one question the rest of the app asks.
  bool get hasPlus => _entitlement.isUsableAt(_now());

  bool get isGrandfathered => _entitlement.isGrandfathered;

  Future<void> init() async {
    final Entitlement? cached = await _store.readCached();
    if (cached != null) {
      _entitlement = cached;
    } else if (await _store.resolveLegacyUser()) {
      // Somebody who was already using the app. Record it so the decision does
      // not depend on data they might later clear.
      _entitlement = const Entitlement.grandfathered();
      await _store.writeCached(_entitlement);
    }
    _loaded = true;
    notifyListeners();

    // Deliberately not awaited: a slow or unreachable server must not hold up
    // the first frame.
    unawaited(refresh());
  }

  /// Re-check with the server. Safe to call often; failures are kept and
  /// surfaced rather than silently downgrading the user.
  Future<void> refresh() async {
    final EntitlementSource? source = _source;
    if (source == null || _refreshing) return;

    _refreshing = true;
    notifyListeners();
    try {
      final Entitlement fresh = await source.fetch();
      _entitlement = fresh.copyWith(checkedAt: _now());
      await _store.writeCached(_entitlement);
      _lastRefreshError = null;
    } catch (error) {
      // Keep whatever we had. Being unable to ask is not the same as being
      // told no, and treating it as no is how you lock out a paying user.
      _lastRefreshError = error;
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  /// Applies an entitlement learned locally — a completed purchase, or a
  /// restore — without waiting for the next server round trip.
  Future<void> apply(Entitlement entitlement) async {
    _entitlement = entitlement.copyWith(checkedAt: _now());
    await _store.writeCached(_entitlement);
    notifyListeners();
  }

  /// Signing out drops the cached entitlement, since it belonged to that
  /// account. A grandfathered install keeps its access: it was never tied to
  /// an account in the first place.
  Future<void> forget() async {
    if (_entitlement.isGrandfathered) return;
    _entitlement = const Entitlement.none();
    await _store.clearCached();
    notifyListeners();
  }
}
