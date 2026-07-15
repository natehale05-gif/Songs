import 'connection_info.dart';
import 'discovery_web.dart' if (dart.library.io) 'discovery_io.dart';

/// Resolves a join code into connection details. Native uses UDP broadcast
/// discovery on the LAN; web resolves locally (members join by code directly).
Future<ConnectionInfo?> resolveSession(String code) => resolveSessionImpl(code);
