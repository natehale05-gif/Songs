import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../models/connection_info.dart';
import '../models/session_snapshot.dart';
import '../models/sync_message.dart';

enum LiveClientStatus { idle, connecting, joined, rejected, disconnected, error }

/// The member side of a live session. Connects to a leader over the LAN and
/// surfaces snapshots as they arrive.
class LiveClient {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;

  final StreamController<SessionSnapshot> _snapshots =
      StreamController<SessionSnapshot>.broadcast();
  final StreamController<LiveClientStatus> _statuses =
      StreamController<LiveClientStatus>.broadcast();

  Stream<SessionSnapshot> get snapshots => _snapshots.stream;
  Stream<LiveClientStatus> get statuses => _statuses.stream;

  String? lastError;

  Future<void> connect(
    ConnectionInfo info, {
    required String memberName,
  }) async {
    await disconnect();
    _statuses.add(LiveClientStatus.connecting);
    try {
      final WebSocketChannel channel =
          WebSocketChannel.connect(info.socketUri);
      _channel = channel;
      await channel.ready;

      channel.sink.add(
        SyncMessage.join(code: info.code, name: memberName).encode(),
      );

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
    final SyncMessage message = SyncMessage.decode(raw.toString());
    switch (message.type) {
      case SyncType.joined:
        _statuses.add(LiveClientStatus.joined);
        break;
      case SyncType.rejected:
        lastError = message.reason ?? 'Rejected';
        _statuses.add(LiveClientStatus.rejected);
        break;
      case SyncType.state:
        if (message.snapshot != null) {
          _statuses.add(LiveClientStatus.joined);
          _snapshots.add(message.snapshot!);
        }
        break;
      case SyncType.ping:
      case SyncType.join:
      case SyncType.unknown:
        break;
    }
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close(ws_status.normalClosure);
    } catch (_) {
      // ignore
    }
    _channel = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _snapshots.close();
    await _statuses.close();
  }
}
