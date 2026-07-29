import 'dart:convert';

/// One connected socket, as far as the relay cares.
///
/// Kept abstract so the room logic can be tested without opening real sockets.
abstract class RelayPeer {
  void send(String message);
  void close();
}

/// Why a connection attempt was refused.
enum JoinRefusal {
  /// A member used a code with no live session behind it.
  noSuchRoom,

  /// Another leader already holds this room and presented a different token.
  roomTaken,

  /// The code was not in the expected shape.
  badCode,
}

class JoinOutcome {
  const JoinOutcome.ok(this.room)
      : refusal = null,
        assert(true);
  const JoinOutcome.refused(this.refusal) : room = null;

  final Room? room;
  final JoinRefusal? refusal;

  bool get accepted => refusal == null;
}

/// A single small-group session: one leader, many members.
class Room {
  Room({required this.code, required this.leaderToken});

  final String code;

  /// Secret the leader presents so it — and only it — can reclaim the room
  /// after a dropped connection. Without this, a reconnecting leader would be
  /// locked out of its own session until the dead socket was noticed.
  String leaderToken;

  RelayPeer? leader;
  final Set<RelayPeer> members = <RelayPeer>{};

  /// Last state frame seen from the leader, replayed to anyone joining late so
  /// they see the current verse immediately rather than waiting for the leader
  /// to move.
  String? lastState;

  DateTime lastActivity = DateTime.now();

  int get memberCount => members.length;

  /// Nothing left to keep: no leader socket and nobody listening.
  bool get isDeserted => leader == null && members.isEmpty;
}

/// Frame the relay itself originates to tell a leader how many members are
/// connected. Everything else it forwards untouched.
String membersFrame(int count) =>
    jsonEncode(<String, dynamic>{'t': 'members', 'count': count});

String joinedFrame() => jsonEncode(<String, dynamic>{'t': 'joined'});

String rejectedFrame(String reason) =>
    jsonEncode(<String, dynamic>{'t': 'rejected', 'reason': reason});

/// True when [raw] is a leader state frame worth caching for late joiners.
bool isStateFrame(String raw) {
  try {
    final Object? decoded = jsonDecode(raw);
    return decoded is Map && decoded['t'] == 'state';
  } catch (_) {
    return false;
  }
}

/// Tracks live sessions by join code and fans frames out between them.
///
/// Deliberately knows nothing about song or verse structure: frames are opaque
/// strings, so the app's protocol can change without redeploying the relay.
class RoomRegistry {
  RoomRegistry({this.maxRooms = 500, this.idleTimeout = const Duration(hours: 6)});

  /// Ceiling on concurrent sessions, so a flood of codes cannot exhaust memory.
  final int maxRooms;

  /// Deserted rooms older than this are collected by [sweep].
  final Duration idleTimeout;

  final Map<String, Room> _rooms = <String, Room>{};

  int get roomCount => _rooms.length;
  Room? room(String code) => _rooms[_normalize(code)];

  static String _normalize(String code) =>
      code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  static final RegExp _codeShape = RegExp(r'^[A-Z0-9]{4,12}$');

  /// A leader opens (or reclaims) the room for [code].
  JoinOutcome openAsLeader(String code, String token, RelayPeer peer) {
    final String key = _normalize(code);
    if (!_codeShape.hasMatch(key) || token.trim().isEmpty) {
      return const JoinOutcome.refused(JoinRefusal.badCode);
    }

    final Room? existing = _rooms[key];
    if (existing != null) {
      if (existing.leader != null && existing.leaderToken != token) {
        return const JoinOutcome.refused(JoinRefusal.roomTaken);
      }
      // Same leader returning after a dropout: swap in the new socket and
      // keep the members and cached state exactly as they were.
      existing.leader?.close();
      existing.leader = peer;
      existing.leaderToken = token;
      existing.lastActivity = DateTime.now();
      peer.send(membersFrame(existing.memberCount));
      return JoinOutcome.ok(existing);
    }

    if (_rooms.length >= maxRooms) {
      sweep();
      if (_rooms.length >= maxRooms) {
        return const JoinOutcome.refused(JoinRefusal.roomTaken);
      }
    }

    final Room created = Room(code: key, leaderToken: token)..leader = peer;
    _rooms[key] = created;
    peer.send(membersFrame(0));
    return JoinOutcome.ok(created);
  }

  /// A member joins an existing room.
  JoinOutcome joinAsMember(String code, RelayPeer peer) {
    final String key = _normalize(code);
    if (!_codeShape.hasMatch(key)) {
      return const JoinOutcome.refused(JoinRefusal.badCode);
    }
    final Room? room = _rooms[key];
    if (room == null) {
      return const JoinOutcome.refused(JoinRefusal.noSuchRoom);
    }

    room.members.add(peer);
    room.lastActivity = DateTime.now();
    peer.send(joinedFrame());
    // Replay current state so a late joiner is not staring at a blank screen.
    final String? state = room.lastState;
    if (state != null) peer.send(state);
    room.leader?.send(membersFrame(room.memberCount));
    return JoinOutcome.ok(room);
  }

  /// Forwards a leader frame to every member of its room.
  void relayFromLeader(Room room, String raw) {
    room.lastActivity = DateTime.now();
    if (isStateFrame(raw)) room.lastState = raw;
    for (final RelayPeer member in room.members.toList()) {
      member.send(raw);
    }
  }

  /// Drops [peer] from [room], whichever side it was.
  void remove(Room room, RelayPeer peer) {
    if (room.leader == peer) {
      room.leader = null;
      room.lastActivity = DateTime.now();
    } else if (room.members.remove(peer)) {
      room.lastActivity = DateTime.now();
      room.leader?.send(membersFrame(room.memberCount));
    }
    // A room with no leader is kept briefly so a leader whose phone slept can
    // reclaim it with its token and its members still attached.
    if (room.isDeserted) _rooms.remove(room.code);
  }

  /// Forgets deserted rooms, and rooms idle past [idleTimeout].
  int sweep({DateTime? now}) {
    final DateTime cutoff = (now ?? DateTime.now()).subtract(idleTimeout);
    final List<String> dead = <String>[];
    _rooms.forEach((String code, Room room) {
      if (room.isDeserted || room.lastActivity.isBefore(cutoff)) {
        dead.add(code);
      }
    });
    for (final String code in dead) {
      final Room? room = _rooms.remove(code);
      room?.leader?.close();
      for (final RelayPeer m in room?.members.toList() ?? const <RelayPeer>[]) {
        m.close();
      }
    }
    return dead.length;
  }
}
