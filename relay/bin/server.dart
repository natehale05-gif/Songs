import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:songs_relay/rooms.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Messages larger than this are dropped. A state frame is well under a
/// kilobyte, so anything near this is not our protocol.
const int kMaxFrameBytes = 64 * 1024;

class SocketPeer implements RelayPeer {
  SocketPeer(this.channel);

  final WebSocketChannel channel;

  @override
  void send(String message) {
    try {
      channel.sink.add(message);
    } catch (_) {
      // Already gone; its onDone handles removal.
    }
  }

  @override
  void close() {
    try {
      channel.sink.close();
    } catch (_) {}
  }
}

String refusalMessage(JoinRefusal refusal) {
  switch (refusal) {
    case JoinRefusal.noSuchRoom:
      return 'No online session with that code. Check the code, or ask the '
          'leader to start the session first.';
    case JoinRefusal.roomTaken:
      return 'Another leader is already hosting that code.';
    case JoinRefusal.badCode:
      return 'That code is not valid.';
  }
}

/// Builds the request handler. Exposed so tests can serve it on a loopback port.
Handler buildHandler(RoomRegistry registry) {
  return (Request request) {
    if (request.url.path == 'health') {
      return Response.ok('ok rooms=${registry.roomCount}');
    }
    if (request.url.path != 'live') {
      return Response.notFound('Songs of the Church relay');
    }

    final String code = request.url.queryParameters['code'] ?? '';
    final String role = request.url.queryParameters['role'] ?? 'member';
    final String token = request.url.queryParameters['token'] ?? '';

    final Handler upgrade =
        webSocketHandler((WebSocketChannel channel, String? _) {
      final SocketPeer peer = SocketPeer(channel);
      final JoinOutcome outcome = role == 'leader'
          ? registry.openAsLeader(code, token, peer)
          : registry.joinAsMember(code, peer);

      if (!outcome.accepted) {
        peer.send(rejectedFrame(refusalMessage(outcome.refusal!)));
        peer.close();
        return;
      }
      final Room room = outcome.room!;
      // Operational visibility: without this there is no way to see whether a
      // session ever reached the relay.
      stdout.writeln('$role joined ${room.code} '
          '(members=${room.memberCount}, rooms=${registry.roomCount})');

      channel.stream.listen(
        (dynamic raw) {
          final String message = raw.toString();
          if (message.length > kMaxFrameBytes) return;
          // Only the leader drives the session; member frames are presence
          // chatter with nowhere to go.
          if (room.leader == peer) registry.relayFromLeader(room, message);
        },
        onDone: () => registry.remove(room, peer),
        onError: (Object _) => registry.remove(room, peer),
        cancelOnError: true,
      );
    });

    return upgrade(request);
  };
}

Future<void> main(List<String> args) async {
  final int port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final RoomRegistry registry = RoomRegistry();

  // Reclaim rooms nobody came back to.
  Timer.periodic(const Duration(minutes: 15), (_) {
    final int dropped = registry.sweep();
    if (dropped > 0) {
      stdout.writeln('swept $dropped idle room(s); ${registry.roomCount} live');
    }
  });

  final HttpServer server = await shelf_io.serve(
    buildHandler(registry),
    InternetAddress.anyIPv4,
    port,
  );
  server.autoCompress = true;
  stdout.writeln('relay listening on :${server.port}');
}
