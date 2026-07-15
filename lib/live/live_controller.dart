import 'dart:async';

import 'package:flutter/foundation.dart';

import 'client.dart';
import 'connection_info.dart';
import 'discovery.dart';
import 'host.dart';
import 'join_code.dart';
import 'live_snapshot.dart';

enum LiveRole { none, leader, member }

/// App-wide coordinator for the live small-group feature. Holds the current
/// role (leader/member), owns the transport, tracks the shared presentation
/// state, and exposes everything the UI needs.
class LiveSessionController extends ChangeNotifier {
  LiveRole _role = LiveRole.none;
  bool _busy = false;

  LiveHost? _host;
  ConnectionInfo? _connection;
  String _leaderName = 'Leader';
  int _memberCount = 0;
  int _revision = 0;
  LiveSnapshot? _current;

  LiveClient? _client;
  StreamSubscription<LiveClientStatus>? _statusSub;
  StreamSubscription<LiveSnapshot>? _snapSub;
  LiveClientStatus _memberStatus = LiveClientStatus.idle;
  String? _memberMessage;
  LiveSnapshot? _memberSnapshot;

  // ── Shared getters ──
  LiveRole get role => _role;
  bool get isLeader => _role == LiveRole.leader;
  bool get isMember => _role == LiveRole.member;
  bool get isActive => _role != LiveRole.none;
  bool get busy => _busy;

  // ── Leader getters ──
  ConnectionInfo? get connection => _connection;
  String get leaderName => _leaderName;
  int get memberCount => _memberCount;
  LiveSnapshot? get current => _current;
  bool get isBlanked => _current?.blanked ?? false;

  // ── Member getters ──
  LiveClientStatus get memberStatus => _memberStatus;
  String? get memberMessage => _memberMessage;
  LiveSnapshot? get memberSnapshot => _memberSnapshot;

  // ─────────────────────────── Leader ───────────────────────────

  Future<void> startLeading({required String leaderName}) async {
    if (isActive || _busy) return;
    _busy = true;
    notifyListeners();

    _leaderName = leaderName.trim().isEmpty ? 'Leader' : leaderName.trim();
    final LiveHost host = LiveHost();
    host.onMembersChanged = (int count) {
      _memberCount = count;
      notifyListeners();
    };
    _host = host;
    final String code = JoinCode.generate();
    _connection = await host.start(code: code, leaderName: _leaderName);

    _role = LiveRole.leader;
    _busy = false;
    _current = LiveSnapshot(
      code: code,
      leaderName: _leaderName,
      blanked: true,
      revision: ++_revision,
    );
    host.broadcast(_current!);
    notifyListeners();
  }

  /// Publishes what the leader is currently presenting. Called by the reader and
  /// the set-list presenter as the leader navigates.
  void publish({
    int? songId,
    String songTitle = '',
    String songSubtitle = '',
    String partLabel = '',
    String partText = '',
    bool isChorus = false,
    bool isTitle = false,
    int index = 0,
    int total = 0,
  }) {
    final LiveHost? host = _host;
    final ConnectionInfo? conn = _connection;
    if (!isLeader || host == null || conn == null) return;
    _current = LiveSnapshot(
      code: conn.code,
      leaderName: _leaderName,
      songId: songId,
      songTitle: songTitle,
      songSubtitle: songSubtitle,
      partLabel: partLabel,
      partText: partText,
      isChorus: isChorus,
      isTitle: isTitle,
      index: index,
      total: total,
      blanked: false,
      memberCount: _memberCount,
      revision: ++_revision,
    );
    host.broadcast(_current!);
    notifyListeners();
  }

  void setBlank(bool on) {
    final LiveHost? host = _host;
    if (!isLeader || host == null || _current == null) return;
    _current = _current!.copyWith(blanked: on, revision: ++_revision);
    host.broadcast(_current!);
    notifyListeners();
  }

  Future<void> stopLeading() async {
    await _host?.stop();
    _host = null;
    _connection = null;
    _current = null;
    _memberCount = 0;
    _role = LiveRole.none;
    notifyListeners();
  }

  // ─────────────────────────── Member ───────────────────────────

  Future<void> joinByCode(String code, {required String memberName}) async {
    final String normalized = JoinCode.normalize(code);
    _role = LiveRole.member;
    _memberStatus = LiveClientStatus.connecting;
    _memberMessage = 'Looking for a session…';
    _memberSnapshot = null;
    notifyListeners();

    final ConnectionInfo? info = await resolveSession(normalized);
    if (info == null) {
      _memberStatus = LiveClientStatus.error;
      _memberMessage =
          'No session found for code $normalized. Make sure you are on the '
          'same WiFi as the leader (or, in the web preview, in another tab of '
          'this browser), or scan the QR code instead.';
      notifyListeners();
      return;
    }
    await _connectClient(info, memberName: memberName);
  }

  Future<void> joinByConnection(ConnectionInfo info,
      {required String memberName}) async {
    _role = LiveRole.member;
    _memberStatus = LiveClientStatus.connecting;
    _memberMessage = null;
    _memberSnapshot = null;
    notifyListeners();
    await _connectClient(info, memberName: memberName);
  }

  Future<void> _connectClient(ConnectionInfo info,
      {required String memberName}) async {
    final LiveClient client = LiveClient();
    _client = client;
    _statusSub = client.statuses.listen(_onMemberStatus);
    _snapSub = client.snapshots.listen(_onMemberSnapshot);
    await client.connect(info, memberName: memberName);
  }

  void _onMemberStatus(LiveClientStatus status) {
    _memberStatus = status;
    if (status == LiveClientStatus.rejected ||
        status == LiveClientStatus.error) {
      _memberMessage = _client?.lastError;
    }
    notifyListeners();
  }

  void _onMemberSnapshot(LiveSnapshot snapshot) {
    if (_memberSnapshot != null &&
        snapshot.revision < _memberSnapshot!.revision) {
      return;
    }
    _memberSnapshot = snapshot;
    _memberStatus = LiveClientStatus.joined;
    notifyListeners();
  }

  Future<void> leave() async {
    await _statusSub?.cancel();
    _statusSub = null;
    await _snapSub?.cancel();
    _snapSub = null;
    await _client?.dispose();
    _client = null;
    _memberStatus = LiveClientStatus.idle;
    _memberMessage = null;
    _memberSnapshot = null;
    _role = LiveRole.none;
    notifyListeners();
  }

  @override
  void dispose() {
    _host?.stop();
    _statusSub?.cancel();
    _snapSub?.cancel();
    _client?.dispose();
    super.dispose();
  }
}
