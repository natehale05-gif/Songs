import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/connection_info.dart';
import '../models/session_snapshot.dart';
import '../services/discovery_service.dart';
import '../services/join_code.dart';
import '../services/live_client.dart';

/// Drives the member experience: joining a session and mirroring the leader.
class MemberController extends ChangeNotifier {
  MemberController({LiveClient? client}) : _client = client ?? LiveClient() {
    _statusSub = _client.statuses.listen(_onStatus);
    _snapshotSub = _client.snapshots.listen(_onSnapshot);
  }

  final LiveClient _client;
  StreamSubscription<LiveClientStatus>? _statusSub;
  StreamSubscription<SessionSnapshot>? _snapshotSub;

  LiveClientStatus _status = LiveClientStatus.idle;
  SessionSnapshot? _snapshot;
  String? _statusMessage;

  LiveClientStatus get status => _status;
  SessionSnapshot? get snapshot => _snapshot;
  String? get statusMessage => _statusMessage;

  bool get isConnecting => _status == LiveClientStatus.connecting;
  bool get isJoined => _status == LiveClientStatus.joined;

  Future<void> joinWithConnection(
    ConnectionInfo info, {
    required String memberName,
  }) async {
    _statusMessage = null;
    await _client.connect(info, memberName: memberName);
  }

  /// Joins using only a code by locating the leader on the LAN via UDP
  /// discovery. Works offline as long as both devices share a network.
  Future<void> joinWithCode(
    String code, {
    required String memberName,
  }) async {
    final String normalized = JoinCode.normalize(code);
    _status = LiveClientStatus.connecting;
    _statusMessage = 'Looking for a session on this network...';
    notifyListeners();

    final ConnectionInfo? info = await DiscoveryService.resolve(normalized);
    if (info == null) {
      _status = LiveClientStatus.error;
      _statusMessage =
          'No session found for code $normalized. Make sure you are on the '
          'same WiFi as the leader, or scan the QR code instead.';
      notifyListeners();
      return;
    }
    await joinWithConnection(info, memberName: memberName);
  }

  Future<void> leave() async {
    await _client.disconnect();
    _status = LiveClientStatus.idle;
    _snapshot = null;
    _statusMessage = null;
    notifyListeners();
  }

  void _onStatus(LiveClientStatus status) {
    _status = status;
    if (status == LiveClientStatus.rejected ||
        status == LiveClientStatus.error) {
      _statusMessage = _client.lastError;
    }
    notifyListeners();
  }

  void _onSnapshot(SessionSnapshot snapshot) {
    // Ignore snapshots that are older than what we already have.
    if (_snapshot != null && snapshot.revision < _snapshot!.revision) {
      return;
    }
    _snapshot = snapshot;
    notifyListeners();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _snapshotSub?.cancel();
    _client.dispose();
    super.dispose();
  }
}
