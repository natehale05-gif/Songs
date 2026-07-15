import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'connection_info.dart';
import 'discovery_service.dart';
import 'frame.dart';
import 'host.dart';
import 'live_snapshot.dart';
import 'network_utils.dart';

LiveHost createLiveHost() => LiveHostIo();

/// Native leader host: a WebSocket server on the LAN plus UDP discovery.
class LiveHostIo implements LiveHost {
  HttpServer? _server;
  DiscoveryResponder? _responder;
  final Set<WebSocketChannel> _members = <WebSocketChannel>{};
  LiveSnapshot? _latest;
  String _code = '';

  @override
  void Function(int count)? onMembersChanged;

  @override
  bool get isRunning => _server != null;

  @override
  int get memberCount => _members.length;

  @override
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
      _responder = null;
    }
    return info;
  }

  void _handleConnection(WebSocketChannel channel) {
    bool joined = false;
    channel.stream.listen(
      (dynamic raw) {
        final Frame frame = Frame.decode(raw.toString());
        if (!joined && frame.type == FrameType.join) {
          if ((frame.code ?? '').toUpperCase() == _code.toUpperCase()) {
            joined = true;
            _members.add(channel);
            channel.sink.add(Frame.joined().encode());
            if (_latest != null) {
              channel.sink.add(Frame.state(_latest!).encode());
            }
            _notifyMembers();
          } else {
            channel.sink.add(Frame.rejected('Invalid code').encode());
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
    if (_members.remove(channel)) _notifyMembers();
  }

  void _notifyMembers() {
    onMembersChanged?.call(_members.length);
    if (_latest != null) {
      broadcast(_latest!.copyWith(memberCount: _members.length));
    }
  }

  @override
  void broadcast(LiveSnapshot snapshot) {
    _latest = snapshot;
    final String encoded = Frame.state(snapshot).encode();
    for (final WebSocketChannel channel in _members.toList()) {
      try {
        channel.sink.add(encoded);
      } catch (_) {
        _members.remove(channel);
      }
    }
  }

  @override
  Future<void> stop() async {
    for (final WebSocketChannel channel in _members.toList()) {
      try {
        await channel.sink.close();
      } catch (_) {}
    }
    _members.clear();
    await _responder?.close();
    _responder = null;
    await _server?.close(force: true);
    _server = null;
    _latest = null;
  }
}
