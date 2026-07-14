import 'dart:convert';

import 'session_snapshot.dart';

/// Message types exchanged over the live session WebSocket.
enum SyncType {
  /// Member -> leader: request to join with a code and display name.
  join,

  /// Leader -> member: the join request was accepted.
  joined,

  /// Leader -> member: the join request was rejected (wrong code / closed).
  rejected,

  /// Leader -> member: a full snapshot of what should be shown.
  state,

  /// Either direction: keep-alive.
  ping,

  unknown,
}

/// A single framed message on the wire. Kept deliberately small and JSON based
/// so it is trivial to debug and works across any platform.
class SyncMessage {
  const SyncMessage({required this.type, this.snapshot, this.name, this.code, this.reason});

  final SyncType type;
  final SessionSnapshot? snapshot;
  final String? name;
  final String? code;
  final String? reason;

  factory SyncMessage.join({required String code, required String name}) =>
      SyncMessage(type: SyncType.join, code: code, name: name);

  factory SyncMessage.joined() => const SyncMessage(type: SyncType.joined);

  factory SyncMessage.rejected(String reason) =>
      SyncMessage(type: SyncType.rejected, reason: reason);

  factory SyncMessage.state(SessionSnapshot snapshot) =>
      SyncMessage(type: SyncType.state, snapshot: snapshot);

  factory SyncMessage.ping() => const SyncMessage(type: SyncType.ping);

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (snapshot != null) 'snapshot': snapshot!.toJson(),
        if (name != null) 'name': name,
        if (code != null) 'code': code,
        if (reason != null) 'reason': reason,
      };

  String encode() => jsonEncode(toJson());

  static SyncMessage decode(String raw) {
    try {
      final Map<String, dynamic> json =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final SyncType type = SyncType.values.firstWhere(
        (SyncType t) => t.name == json['type'],
        orElse: () => SyncType.unknown,
      );
      final Object? snap = json['snapshot'];
      return SyncMessage(
        type: type,
        snapshot: snap == null
            ? null
            : SessionSnapshot.fromJson(Map<String, dynamic>.from(snap as Map)),
        name: json['name'] as String?,
        code: json['code'] as String?,
        reason: json['reason'] as String?,
      );
    } catch (_) {
      return const SyncMessage(type: SyncType.unknown);
    }
  }
}
