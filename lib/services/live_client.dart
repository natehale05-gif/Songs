import '../models/connection_info.dart';
import '../models/session_snapshot.dart';
import 'live_client_web.dart'
    if (dart.library.io) 'live_client_io.dart';

enum LiveClientStatus { idle, connecting, joined, rejected, disconnected, error }

/// The member side of a live session. Connects to a leader and surfaces
/// snapshots as they arrive.
///
/// Native builds connect to the leader's LAN WebSocket server; web builds use a
/// same-browser [BroadcastChannel] so the flow can be tried across two tabs.
abstract class LiveClient {
  factory LiveClient() => createLiveClient();

  Stream<SessionSnapshot> get snapshots;
  Stream<LiveClientStatus> get statuses;
  String? get lastError;

  Future<void> connect(ConnectionInfo info, {required String memberName});
  Future<void> disconnect();
  Future<void> dispose();
}
