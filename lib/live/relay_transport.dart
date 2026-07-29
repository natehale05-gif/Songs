import 'dart:async';
import 'dart:math';

import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'client.dart';
import 'connection_info.dart';
import 'frame.dart';
import 'host.dart';
import 'live_snapshot.dart';
import 'relay_config.dart';

/// Secret a leader keeps so it can reclaim its own room after a dropout.
String newLeaderToken([Random? random]) {
  final Random rng = random ?? Random.secure();
  return List<int>.generate(16, (_) => rng.nextInt(256))
      .map((int b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}

/// Leader side of an online session.
///
/// Unlike the LAN host this opens no server — it dials *out* to the relay,
/// which is what lets it work behind carrier NAT where nothing can accept an
/// incoming connection.
class RelayHost implements LiveHost {
  RelayHost({this.relayBase = kRelayUrl});

  final String relayBase;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  LiveSnapshot? _latest;
  String _code = '';
  String _token = '';
  int _members = 0;
  bool _running = false;

  @override
  void Function(int count)? onMembersChanged;

  @override
  bool get isRunning => _running;

  @override
  int get memberCount => _members;

  @override
  Future<ConnectionInfo> start({
    required String code,
    required String leaderName,
    String? preferredHost,
  }) async {
    await stop();
    _code = code;
    _token = newLeaderToken();

    final WebSocketChannel channel = WebSocketChannel.connect(
      relaySocketUri(
          code: code, asLeader: true, token: _token, base: relayBase),
    );
    _channel = channel;
    await channel.ready;
    _running = true;

    _sub = channel.stream.listen(
      _onData,
      onDone: () => _running = false,
      onError: (Object _) => _running = false,
      cancelOnError: true,
    );

    return ConnectionInfo.online(code: code, leaderName: leaderName);
  }

  void _onData(dynamic raw) {
    final Frame frame = Frame.decode(raw.toString());
    if (frame.type != FrameType.members) return;
    _members = frame.count ?? 0;
    onMembersChanged?.call(_members);
    // Mirror the LAN host: republish so members see the updated count.
    final LiveSnapshot? latest = _latest;
    if (latest != null) broadcast(latest.copyWith(memberCount: _members));
  }

  @override
  void broadcast(LiveSnapshot snapshot) {
    _latest = snapshot;
    try {
      _channel?.sink.add(Frame.state(snapshot).encode());
    } catch (_) {
      // Dropped connection; the stream's onDone clears _running.
    }
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close(ws_status.normalClosure);
    } catch (_) {}
    _channel = null;
    _latest = null;
    _members = 0;
    _running = false;
    _code = '';
    _token = '';
  }

  /// The join code this host is serving, for tests and diagnostics.
  String get code => _code;
}

/// Member side of an online session.
class RelayClient implements LiveClient {
  RelayClient({this.relayBase = kRelayUrl});

  final String relayBase;

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
  Future<void> connect(ConnectionInfo info,
      {required String memberName}) async {
    await disconnect();
    _statuses.add(LiveClientStatus.connecting);
    try {
      final WebSocketChannel channel = WebSocketChannel.connect(
        relaySocketUri(code: info.code, asLeader: false, base: relayBase),
      );
      _channel = channel;
      await channel.ready;
      // The relay routes by query parameter, but sending the join frame keeps
      // the wire protocol identical to a LAN session.
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
      lastError = 'Could not reach the online session. Check your internet '
          'connection and the code.';
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
        final LiveSnapshot? snap = frame.snapshot;
        if (snap != null) {
          _statuses.add(LiveClientStatus.joined);
          _snapshots.add(snap);
        }
        break;
      case FrameType.members:
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
