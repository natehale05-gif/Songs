import 'package:flutter/foundation.dart';

import '../models/connection_info.dart';
import '../models/session_snapshot.dart';
import '../models/song.dart';
import '../services/join_code.dart';
import '../services/live_host.dart';

/// Drives a live session from the leader's device: hosts the session, tracks
/// what is being presented and broadcasts every change to members.
class LeaderController extends ChangeNotifier {
  LeaderController({LiveHost? host}) : _host = host ?? LiveHost() {
    _host.onMembersChanged = _onMembersChanged;
  }

  final LiveHost _host;

  bool _live = false;
  ConnectionInfo? _connection;
  String _leaderName = 'Leader';
  String _sessionTitle = 'Live Session';
  Song? _currentSong;
  int _sectionIndex = 0;
  bool _blanked = false;
  int _memberCount = 0;
  int _revision = 0;
  bool _busy = false;

  bool get isLive => _live;
  bool get busy => _busy;
  ConnectionInfo? get connection => _connection;
  Song? get currentSong => _currentSong;
  int get sectionIndex => _sectionIndex;
  bool get blanked => _blanked;
  int get memberCount => _memberCount;
  String get leaderName => _leaderName;
  String get sessionTitle => _sessionTitle;

  int get sectionCount => _currentSong?.sections.length ?? 0;

  Future<void> startSession({
    required String leaderName,
    String sessionTitle = 'Live Session',
  }) async {
    if (_live || _busy) return;
    _busy = true;
    notifyListeners();

    _leaderName = leaderName.trim().isEmpty ? 'Leader' : leaderName.trim();
    _sessionTitle =
        sessionTitle.trim().isEmpty ? 'Live Session' : sessionTitle.trim();
    final String code = JoinCode.generate();

    _connection = await _host.start(code: code, leaderName: _leaderName);
    _live = true;
    _busy = false;
    _pushSnapshot();
    notifyListeners();
  }

  void selectSong(Song song) {
    _currentSong = song;
    _sectionIndex = 0;
    _blanked = false;
    _pushSnapshot();
    notifyListeners();
  }

  void goToSection(int index) {
    if (_currentSong == null) return;
    final int max = _currentSong!.sections.length - 1;
    if (max < 0) return;
    _sectionIndex = index.clamp(0, max);
    _pushSnapshot();
    notifyListeners();
  }

  void nextSection() => goToSection(_sectionIndex + 1);

  void previousSection() => goToSection(_sectionIndex - 1);

  bool get hasNextSection =>
      _currentSong != null && _sectionIndex < sectionCount - 1;

  bool get hasPreviousSection => _currentSong != null && _sectionIndex > 0;

  void toggleBlank() {
    _blanked = !_blanked;
    _pushSnapshot();
    notifyListeners();
  }

  void clearSong() {
    _currentSong = null;
    _sectionIndex = 0;
    _pushSnapshot();
    notifyListeners();
  }

  Future<void> endSession() async {
    await _host.stop();
    _live = false;
    _connection = null;
    _currentSong = null;
    _sectionIndex = 0;
    _blanked = false;
    _memberCount = 0;
    _revision = 0;
    notifyListeners();
  }

  /// The exact snapshot members should currently render. Exposed so the leader
  /// UI can render a faithful preview of the members' view.
  SessionSnapshot currentSnapshot() {
    return SessionSnapshot(
      code: _connection?.code ?? '',
      leaderName: _leaderName,
      sessionTitle: _sessionTitle,
      currentSong: _currentSong,
      sectionIndex: _sectionIndex,
      blanked: _blanked,
      memberCount: _memberCount,
      revision: _revision,
    );
  }

  void _pushSnapshot() {
    if (!_live) return;
    _revision++;
    _host.broadcast(currentSnapshot());
  }

  void _onMembersChanged(int count) {
    _memberCount = count;
    notifyListeners();
  }

  @override
  void dispose() {
    _host.stop();
    super.dispose();
  }
}
