import '../models/connection_info.dart';
import '../models/session_snapshot.dart';
import 'live_host_web.dart'
    if (dart.library.io) 'live_host_io.dart';

/// Hosts a live session so members can connect and mirror the leader's screen.
///
/// Two implementations are selected at compile time:
///  * native (mobile/desktop) hosts a real LAN WebSocket server so the session
///    works fully offline over WiFi or a hotspot;
///  * web uses a same-browser [BroadcastChannel] so the experience can be tried
///    across two browser tabs (e.g. on GitHub Pages) without a server.
abstract class LiveHost {
  factory LiveHost() => createLiveHost();

  /// Called whenever the number of connected members changes.
  set onMembersChanged(void Function(int count)? callback);

  bool get isRunning;
  int get memberCount;

  /// Starts hosting and returns the connection details members need.
  /// [preferredHost] can override auto-detection (native only).
  Future<ConnectionInfo> start({
    required String code,
    required String leaderName,
    String? preferredHost,
  });

  /// Sends [snapshot] to every connected member.
  void broadcast(SessionSnapshot snapshot);

  Future<void> stop();
}
