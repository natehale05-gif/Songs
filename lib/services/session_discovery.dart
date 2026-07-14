import '../models/connection_info.dart';
import 'session_discovery_web.dart'
    if (dart.library.io) 'session_discovery_io.dart';

/// Resolves a join [code] into the connection details for the leader.
///
/// Native builds locate the leader on the LAN via UDP broadcast discovery; web
/// builds resolve locally because members join the leader's BroadcastChannel by
/// code directly.
Future<ConnectionInfo?> resolveSession(String code) =>
    resolveSessionImpl(code);
