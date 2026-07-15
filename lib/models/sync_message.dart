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

  /// Either direction: keep-alive / presence heartbeat.
  ping,

  /// Member -> leader: leaving the session.
  leave,

  unknown,
}

/// A single framed message on the wire. Kept deliberately small and JSON based
/// so it is trivial to debug and works across any platform.
class SyncMessage {
  const SyncMessage({
    required this.type,
    this.snapshot,
    this.name,
    this.code,
    this.reason,
    this.id,
  });

  final SyncType type;
  final SessionSnapshot? snapshot;
  final String? name;
  final String? code;
  final String? reason;

  /// Opaque member identifier, used for presence tracking on transports that
  /// share a single message bus (e.g. the web BroadcastChannel transport).
  final String? id;

  factory SyncMessage.join({
    required String code,
    required String name,
    String? id,
  }) =>
      SyncMessage(type: SyncType.join, code: code, name: name, id: id);

  factory SyncMessage.joined() => const SyncMessage(type: SyncType.joined);

  factory SyncMessage.rejected(String reason) =>
      SyncMessage(type: SyncType.rejected, reason: reason);

  factory SyncMessage.state(SessionSnapshot snapshot) =>
      SyncMessage(type: SyncType.state, snapshot: snapshot);

  factory SyncMessage.ping({String? id}) =>
      SyncMessage(type: SyncType.ping, id: id);

  factory SyncMessage.leave({String? id}) =>
      SyncMessage(type: SyncType.leave, id: id);

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (snapshot != null) 'snapshot': snapshot!.toJson(),
        if (name != null) 'name': name,
        if (code != null) 'code': code,
        if (reason != null) 'reason': reason,
        if (id != null) 'id': id,
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
        id: json['id'] as String?,
      );
    } catch (_) {
      return const SyncMessage(type: SyncType.unknown);
    }
  }
}
