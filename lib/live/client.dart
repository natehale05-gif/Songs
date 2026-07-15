import 'connection_info.dart';
import 'live_snapshot.dart';
import 'client_web.dart' if (dart.library.io) 'client_io.dart';

enum LiveClientStatus { idle, connecting, joined, rejected, disconnected, error }

/// The member side of a live session. Native connects to the leader's LAN
/// WebSocket; web uses a same-browser BroadcastChannel.
abstract class LiveClient {
  factory LiveClient() => createLiveClient();

  Stream<LiveSnapshot> get snapshots;
  Stream<LiveClientStatus> get statuses;
  String? get lastError;

  Future<void> connect(ConnectionInfo info, {required String memberName});
  Future<void> disconnect();
  Future<void> dispose();
}
