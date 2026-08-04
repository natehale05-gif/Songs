import 'dart:convert';

/// Where a subscription was bought. Kept on the entitlement because the place
/// a user has to go to cancel or fix billing differs per store, and pointing
/// them at the wrong one is a support problem.
enum PurchaseSource { appStore, playStore, stripe, grandfathered }

PurchaseSource? _sourceFromName(Object? raw) {
  for (final PurchaseSource s in PurchaseSource.values) {
    if (s.name == raw) return s;
  }
  return null;
}

/// What the app is allowed to do right now.
///
/// Deliberately a value type with no I/O: the rules about expiry and grace are
/// the part worth testing, and they should not need a network or a clock the
/// test cannot control.
class Entitlement {
  const Entitlement({
    required this.active,
    this.expiresAt,
    this.source,
    this.checkedAt,
  });

  const Entitlement.none()
      : active = false,
        expiresAt = null,
        source = null,
        checkedAt = null;

  /// Someone who was already using the app before the paid tier existed. Never
  /// expires: taking away what they already had would be a worse outcome than
  /// any revenue it might win back.
  const Entitlement.grandfathered()
      : active = true,
        expiresAt = null,
        source = PurchaseSource.grandfathered,
        checkedAt = null;

  final bool active;

  /// When the current period ends. Null means no expiry — either there is no
  /// entitlement at all, or it is one that cannot lapse.
  final DateTime? expiresAt;

  final PurchaseSource? source;

  /// When this was last confirmed with the server, for the offline grace
  /// window below.
  final DateTime? checkedAt;

  bool get isGrandfathered => source == PurchaseSource.grandfathered;

  /// How long a cached entitlement keeps working with no way to reach the
  /// server.
  ///
  /// The whole app is built to work with no connection, so a subscriber who
  /// opens it on a plane must not be told to pay again. Erring long is the
  /// right direction: the cost of being generous is a few weeks of access
  /// someone already paid for at some point, and the cost of being strict is
  /// locking out a paying user in front of a congregation.
  static const Duration offlineGrace = Duration(days: 30);

  /// Whether the paid features should be unlocked, given the time now.
  ///
  /// [now] is injected rather than read from the clock so the boundaries are
  /// actually testable.
  bool isUsableAt(DateTime now) {
    if (!active) return false;
    if (isGrandfathered) return true;

    final DateTime? expiry = expiresAt;
    if (expiry != null && now.isAfter(expiry)) {
      // Past the paid period. The store may have renewed it and we simply have
      // not been able to ask, so honour the grace window from the expiry.
      return now.isBefore(expiry.add(offlineGrace));
    }

    // Still inside the paid period.
    return true;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'active': active,
        'expiresAt': expiresAt?.toIso8601String(),
        'source': source?.name,
        'checkedAt': checkedAt?.toIso8601String(),
      };

  static Entitlement? tryParse(String raw) {
    try {
      final Object? decoded = json.decode(raw);
      if (decoded is! Map<String, Object?>) return null;
      return Entitlement(
        active: decoded['active'] == true,
        expiresAt: _date(decoded['expiresAt']),
        source: _sourceFromName(decoded['source']),
        checkedAt: _date(decoded['checkedAt']),
      );
    } catch (_) {
      // A cache that cannot be read is the same as no cache. Never let stored
      // rubbish stop the app from starting.
      return null;
    }
  }

  static DateTime? _date(Object? raw) =>
      raw is String ? DateTime.tryParse(raw) : null;

  String encode() => json.encode(toJson());

  Entitlement copyWith({
    bool? active,
    DateTime? expiresAt,
    PurchaseSource? source,
    DateTime? checkedAt,
  }) =>
      Entitlement(
        active: active ?? this.active,
        expiresAt: expiresAt ?? this.expiresAt,
        source: source ?? this.source,
        checkedAt: checkedAt ?? this.checkedAt,
      );

  @override
  String toString() => 'Entitlement(active: $active, expires: $expiresAt, '
      'source: ${source?.name})';
}
