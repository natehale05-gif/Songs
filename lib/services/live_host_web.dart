import 'dart:async';

import '../models/connection_info.dart';
import '../models/session_snapshot.dart';
import '../models/sync_message.dart';
import 'broadcast_bus.dart';
import 'live_host.dart';

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
  SessionSnapshot? _latest;
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
    _pruneTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _prune());

    // host is a synthetic value; the code is what actually locates the session.
    return ConnectionInfo(
      host: 'web',
      port: 0,
      code: code,
      leaderName: leaderName,
    );
  }

  void _onMessage(String raw) {
    final SyncMessage message = SyncMessage.decode(raw);
    switch (message.type) {
      case SyncType.join:
        if ((message.code ?? '').toUpperCase() != _code) return;
        if (message.id != null) {
          _members[message.id!] = DateTime.now();
        }
        _notifyMembers();
        // Send the current view (or a bare ack) so the new member catches up.
        if (_latest != null) {
          _sendState();
        } else {
          _bus?.send(SyncMessage.joined().encode());
        }
        break;
      case SyncType.ping:
        if (message.id != null) {
          final bool isNew = !_members.containsKey(message.id);
          _members[message.id!] = DateTime.now();
          if (isNew) _notifyMembers();
        }
        break;
      case SyncType.leave:
        if (message.id != null && _members.remove(message.id) != null) {
          _notifyMembers();
        }
        break;
      case SyncType.joined:
      case SyncType.rejected:
      case SyncType.state:
      case SyncType.unknown:
        break;
    }
  }

  void _prune() {
    final DateTime cutoff = DateTime.now().subtract(_memberTtl);
    final int before = _members.length;
    _members.removeWhere((_, DateTime seen) => seen.isBefore(cutoff));
    if (_members.length != before) {
      _notifyMembers();
    }
  }

  void _notifyMembers() {
    onMembersChanged?.call(_members.length);
    if (_latest != null) _sendState();
  }

  void _sendState() {
    if (_latest == null) return;
    _bus?.send(
      SyncMessage.state(_latest!.copyWith(memberCount: _members.length))
          .encode(),
    );
  }

  @override
  void broadcast(SessionSnapshot snapshot) {
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
