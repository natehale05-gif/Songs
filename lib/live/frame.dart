import 'dart:convert';

import 'live_snapshot.dart';

/// Control message types exchanged over the live session transport.
enum FrameType {
  /// Member -> leader: request to join with a code and display name.
  join,

  /// Leader -> member: join accepted.
  joined,

  /// Leader -> member: join refused (wrong code / closed).
  rejected,

  /// Leader -> member: a full [LiveSnapshot] of what to show.
  state,

  /// Member -> leader: presence heartbeat.
  ping,

  /// Member -> leader: leaving.
  leave,

  unknown,
}

/// A single JSON message on the wire. Small and human-readable for easy
/// debugging across platforms and transports.
class Frame {
  const Frame({
    required this.type,
    this.snapshot,
    this.code,
    this.name,
    this.id,
    this.reason,
  });

  final FrameType type;
  final LiveSnapshot? snapshot;
  final String? code;
  final String? name;
  final String? id;
  final String? reason;

  factory Frame.join({required String code, required String name, String? id}) =>
      Frame(type: FrameType.join, code: code, name: name, id: id);

  factory Frame.joined() => const Frame(type: FrameType.joined);

  factory Frame.rejected(String reason) =>
      Frame(type: FrameType.rejected, reason: reason);

  factory Frame.state(LiveSnapshot snapshot) =>
      Frame(type: FrameType.state, snapshot: snapshot);

  factory Frame.ping({String? id}) => Frame(type: FrameType.ping, id: id);

  factory Frame.leave({String? id}) => Frame(type: FrameType.leave, id: id);

  Map<String, dynamic> toJson() => <String, dynamic>{
        't': type.name,
        if (snapshot != null) 'snap': snapshot!.toJson(),
        if (code != null) 'code': code,
        if (name != null) 'name': name,
        if (id != null) 'id': id,
        if (reason != null) 'reason': reason,
      };

  String encode() => jsonEncode(toJson());

  static Frame decode(String raw) {
    try {
      final Map<String, dynamic> json =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final FrameType type = FrameType.values.firstWhere(
        (FrameType t) => t.name == json['t'],
        orElse: () => FrameType.unknown,
      );
      final Object? snap = json['snap'];
      return Frame(
        type: type,
        snapshot: snap == null
            ? null
            : LiveSnapshot.fromJson(Map<String, dynamic>.from(snap as Map)),
        code: json['code'] as String?,
        name: json['name'] as String?,
        id: json['id'] as String?,
        reason: json['reason'] as String?,
      );
    } catch (_) {
      return const Frame(type: FrameType.unknown);
    }
  }
}
