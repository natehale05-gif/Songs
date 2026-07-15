import 'connection_info.dart';
import 'discovery_service.dart';

Future<ConnectionInfo?> resolveSessionImpl(String code) =>
    DiscoveryService.resolve(code);
