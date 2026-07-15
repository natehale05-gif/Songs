import 'connection_info.dart';
import 'live_snapshot.dart';
import 'host_web.dart' if (dart.library.io) 'host_io.dart';

/// Hosts a live session so members can connect and mirror the leader's screen.
///
/// Selected at compile time: native builds host a real LAN WebSocket server
/// (fully offline over WiFi / hotspot); web builds use a same-browser
/// BroadcastChannel so the flow can be tried across two tabs.
abstract class LiveHost {
  factory LiveHost() => createLiveHost();

  set onMembersChanged(void Function(int count)? callback);

  bool get isRunning;
  int get memberCount;

  Future<ConnectionInfo> start({
    required String code,
    required String leaderName,
    String? preferredHost,
  });

  void broadcast(LiveSnapshot snapshot);

  Future<void> stop();
}
