import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/connection_info.dart';
import '../models/session_snapshot.dart';
import '../models/sync_message.dart';
import 'discovery_service.dart';
import 'network_utils.dart';

/// Runs the leader's local network server so members can connect and mirror the
/// leader's screen. Everything happens over the LAN and works offline.
class LiveHost {
  HttpServer? _server;
  DiscoveryResponder? _responder;
  final Set<WebSocketChannel> _members = <WebSocketChannel>{};
  SessionSnapshot? _latest;
  String _code = '';

  /// Called whenever the number of connected members changes.
  void Function(int count)? onMembersChanged;

  bool get isRunning => _server != null;
  int get memberCount => _members.length;

  /// Binds the server (and discovery responder) and returns the connection
  /// details members need. [preferredHost] can override auto-detection.
  Future<ConnectionInfo> start({
    required String code,
    required String leaderName,
    String? preferredHost,
  }) async {
    await stop();
    _code = code;

    final Handler handler = webSocketHandler(
      (WebSocketChannel channel, String? _) => _handleConnection(channel),
    );

    // Port 0 lets the OS choose a free port.
    final HttpServer server =
        await shelf_io.serve(handler, '0.0.0.0', 0, shared: true);
    _server = server;

    final String host =
        preferredHost ?? await NetworkUtils.localIpv4() ?? '127.0.0.1';

    final ConnectionInfo info = ConnectionInfo(
      host: host,
      port: server.port,
      code: code,
      leaderName: leaderName,
    );

    try {
      _responder = await DiscoveryService.startResponder(info);
    } catch (_) {
      // Discovery is a convenience; QR based joining still works without it.
      _responder = null;
    }

    return info;
  }

  void _handleConnection(WebSocketChannel channel) {
    bool joined = false;
    channel.stream.listen(
      (dynamic raw) {
        final SyncMessage message = SyncMessage.decode(raw.toString());
        if (!joined) {
          if (message.type == SyncType.join &&
              (message.code ?? '').toUpperCase() == _code.toUpperCase()) {
            joined = true;
            _members.add(channel);
            channel.sink.add(SyncMessage.joined().encode());
            if (_latest != null) {
              channel.sink.add(SyncMessage.state(_latest!).encode());
            }
            _notifyMembers();
          } else if (message.type == SyncType.join) {
            channel.sink.add(SyncMessage.rejected('Invalid code').encode());
            channel.sink.close();
          }
        }
      },
      onDone: () => _removeMember(channel),
      onError: (Object _) => _removeMember(channel),
      cancelOnError: true,
    );
  }

  void _removeMember(WebSocketChannel channel) {
    if (_members.remove(channel)) {
      _notifyMembers();
    }
  }

  void _notifyMembers() {
    onMembersChanged?.call(_members.length);
    // Re-broadcast so members see the updated head count.
    if (_latest != null) {
      broadcast(_latest!.copyWith(memberCount: _members.length));
    }
  }

  /// Sends [snapshot] to every connected member.
  void broadcast(SessionSnapshot snapshot) {
    _latest = snapshot;
    final String encoded = SyncMessage.state(snapshot).encode();
    for (final WebSocketChannel channel in _members.toList()) {
      try {
        channel.sink.add(encoded);
      } catch (_) {
        _members.remove(channel);
      }
    }
  }

  Future<void> stop() async {
    for (final WebSocketChannel channel in _members.toList()) {
      try {
        await channel.sink.close();
      } catch (_) {
        // ignore
      }
    }
    _members.clear();
    await _responder?.close();
    _responder = null;
    await _server?.close(force: true);
    _server = null;
    _latest = null;
  }
}
