import '../models/connection_info.dart';

/// On the web a member joins the leader's BroadcastChannel keyed by the code,
/// so there is nothing to look up on the network.
Future<ConnectionInfo?> resolveSessionImpl(String code) async {
  return ConnectionInfo(host: 'local', port: 0, code: code);
}
