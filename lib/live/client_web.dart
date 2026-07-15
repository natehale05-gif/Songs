import 'dart:async';

import 'package:uuid/uuid.dart';

import 'broadcast_bus.dart';
import 'client.dart';
import 'connection_info.dart';
import 'frame.dart';
import 'live_snapshot.dart';

LiveClient createLiveClient() => LiveClientWeb();

/// Web member client built on [BroadcastChannel]: joins the leader's channel by
/// code and mirrors broadcast snapshots.
class LiveClientWeb implements LiveClient {
  static const String _channelPrefix = 'songslive-';
  static const Uuid _uuid = Uuid();

  BroadcastBus? _bus;
  StreamSubscription<String>? _sub;
  Timer? _heartbeat;
  Timer? _joinTimeout;
  String _id = '';
  bool _joined = false;

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
    _joined = false;
    _id = _uuid.v4();
    _statuses.add(LiveClientStatus.connecting);

    final String code = info.code.toUpperCase();
    final BroadcastBus bus = BroadcastBus('$_channelPrefix$code');
    _bus = bus;
    _sub = bus.messages.listen(_onMessage);

    bus.send(Frame.join(code: info.code, name: memberName, id: _id).encode());
    _heartbeat = Timer.periodic(const Duration(seconds: 3),
        (_) => _bus?.send(Frame.ping(id: _id).encode()));
    _joinTimeout = Timer(const Duration(seconds: 5), () {
      if (!_joined) {
        lastError =
            'No session found for code ${info.code}. On the web you can only '
            'join a leader running in another tab of this same browser.';
        _statuses.add(LiveClientStatus.error);
      }
    });
  }

  void _onMessage(String raw) {
    final Frame frame = Frame.decode(raw);
    switch (frame.type) {
      case FrameType.joined:
        _markJoined();
        break;
      case FrameType.state:
        if (frame.snapshot != null) {
          _markJoined();
          _snapshots.add(frame.snapshot!);
        }
        break;
      case FrameType.rejected:
        lastError = frame.reason ?? 'Rejected';
        _statuses.add(LiveClientStatus.rejected);
        break;
      case FrameType.join:
      case FrameType.ping:
      case FrameType.leave:
      case FrameType.unknown:
        break;
    }
  }

  void _markJoined() {
    _joinTimeout?.cancel();
    if (!_joined) {
      _joined = true;
      _statuses.add(LiveClientStatus.joined);
    }
  }

  @override
  Future<void> disconnect() async {
    _joinTimeout?.cancel();
    _joinTimeout = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    if (_id.isNotEmpty) _bus?.send(Frame.leave(id: _id).encode());
    await _sub?.cancel();
    _sub = null;
    _bus?.close();
    _bus = null;
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _snapshots.close();
    await _statuses.close();
  }
}
