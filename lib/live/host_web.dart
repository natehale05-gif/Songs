import 'dart:async';

import 'broadcast_bus.dart';
import 'connection_info.dart';
import 'frame.dart';
import 'host.dart';
import 'live_snapshot.dart';

LiveHost createLiveHost() => LiveHostWeb();

/// Web leader host built on [BroadcastChannel]. Members are other tabs in the
/// same browser that opened the matching channel via the join code.
class LiveHostWeb implements LiveHost {
  static const String _channelPrefix = 'songslive-';
  static const Duration _memberTtl = Duration(seconds: 9);

  BroadcastBus? _bus;
  StreamSubscription<String>? _sub;
  Timer? _pruneTimer;
  final Map<String, DateTime> _members = <String, DateTime>{};
  LiveSnapshot? _latest;
  String _code = '';

  @override
  void Function(int count)? onMembersChanged;

  @override
  bool get isRunning => _bus != null;

  @override
  int get memberCount => _members.length;

  @override
  Future<ConnectionInfo> start({
    required String code,
    required String leaderName,
    String? preferredHost,
  }) async {
    await stop();
    _code = code.toUpperCase();
    final BroadcastBus bus = BroadcastBus('$_channelPrefix$_code');
    _bus = bus;
    _sub = bus.messages.listen(_onMessage);
    _pruneTimer = Timer.periodic(const Duration(seconds: 3), (_) => _prune());
    return ConnectionInfo(host: 'web', port: 0, code: code, leaderName: leaderName);
  }

  void _onMessage(String raw) {
    final Frame frame = Frame.decode(raw);
    switch (frame.type) {
      case FrameType.join:
        if ((frame.code ?? '').toUpperCase() != _code) return;
        if (frame.id != null) _members[frame.id!] = DateTime.now();
        _notifyMembers();
        if (_latest != null) {
          _sendState();
        } else {
          _bus?.send(Frame.joined().encode());
        }
        break;
      case FrameType.ping:
        if (frame.id != null) {
          final bool isNew = !_members.containsKey(frame.id);
          _members[frame.id!] = DateTime.now();
          if (isNew) _notifyMembers();
        }
        break;
      case FrameType.leave:
        if (frame.id != null && _members.remove(frame.id) != null) {
          _notifyMembers();
        }
        break;
      case FrameType.joined:
      case FrameType.rejected:
      case FrameType.state:
      case FrameType.unknown:
        break;
    }
  }

  void _prune() {
    final DateTime cutoff = DateTime.now().subtract(_memberTtl);
    final int before = _members.length;
    _members.removeWhere((_, DateTime seen) => seen.isBefore(cutoff));
    if (_members.length != before) _notifyMembers();
  }

  void _notifyMembers() {
    onMembersChanged?.call(_members.length);
    if (_latest != null) _sendState();
  }

  void _sendState() {
    if (_latest == null) return;
    _bus?.send(
        Frame.state(_latest!.copyWith(memberCount: _members.length)).encode());
  }

  @override
  void broadcast(LiveSnapshot snapshot) {
    _latest = snapshot;
    _sendState();
  }

  @override
  Future<void> stop() async {
    _pruneTimer?.cancel();
    _pruneTimer = null;
    await _sub?.cancel();
    _sub = null;
    _bus?.close();
    _bus = null;
    _members.clear();
    _latest = null;
  }
}
