import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import 'client.dart';
import 'connection_info.dart';
import 'frame.dart';
import 'live_snapshot.dart';

LiveClient createLiveClient() => LiveClientIo();

/// Native member client that connects to the leader over a LAN WebSocket.
class LiveClientIo implements LiveClient {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;

  final StreamController<LiveSnapshot> _snapshots =
      StreamController<LiveSnapshot>.broadcast();
  final StreamController<LiveClientStatus> _statuses =
      StreamController<LiveClientStatus>.broadcast();

  @override
  Stream<LiveSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<LiveClientStatus> get statuses => _statuses.stream;

  @override
  String? lastError;

  @override
  Future<void> connect(ConnectionInfo info, {required String memberName}) async {
    await disconnect();
    _statuses.add(LiveClientStatus.connecting);
    try {
      final WebSocketChannel channel = WebSocketChannel.connect(info.socketUri);
      _channel = channel;
      await channel.ready;
      channel.sink.add(Frame.join(code: info.code, name: memberName).encode());
      _sub = channel.stream.listen(
        _onData,
        onDone: () => _statuses.add(LiveClientStatus.disconnected),
        onError: (Object error) {
          lastError = error.toString();
          _statuses.add(LiveClientStatus.error);
        },
        cancelOnError: true,
      );
    } catch (error) {
      lastError = error.toString();
      _statuses.add(LiveClientStatus.error);
    }
  }

  void _onData(dynamic raw) {
    final Frame frame = Frame.decode(raw.toString());
    switch (frame.type) {
      case FrameType.joined:
        _statuses.add(LiveClientStatus.joined);
        break;
      case FrameType.rejected:
        lastError = frame.reason ?? 'Rejected';
        _statuses.add(LiveClientStatus.rejected);
        break;
      case FrameType.state:
        if (frame.snapshot != null) {
          _statuses.add(LiveClientStatus.joined);
          _snapshots.add(frame.snapshot!);
        }
        break;
      case FrameType.ping:
      case FrameType.leave:
      case FrameType.join:
      case FrameType.unknown:
        break;
    }
  }

  @override
  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close(ws_status.normalClosure);
    } catch (_) {}
    _channel = null;
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _snapshots.close();
    await _statuses.close();
  }
}
