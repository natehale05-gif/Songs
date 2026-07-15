import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'connection_info.dart';

/// Dependency-free LAN discovery over UDP broadcast (native only).
///
/// Makes "join by code" work offline: the leader answers broadcast probes
/// carrying a matching join code with its [ConnectionInfo], so a member that
/// only knows the code can locate the leader without typing an IP address.
class DiscoveryService {
  DiscoveryService._();

  static const int discoveryPort = 45411;
  static const String _probeTag = 'SONGSLIVE_PROBE';
  static const String _replyTag = 'SONGSLIVE_REPLY';

  static Future<DiscoveryResponder> startResponder(ConnectionInfo info) async {
    final RawDatagramSocket socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
    );
    socket.broadcastEnabled = true;

    final StreamSubscription<RawSocketEvent> sub =
        socket.listen((RawSocketEvent event) {
      if (event != RawSocketEvent.read) return;
      final Datagram? dg = socket.receive();
      if (dg == null) return;
      final Map<String, dynamic>? probe = _tryDecode(dg.data);
      if (probe == null || probe['tag'] != _probeTag) return;
      if (probe['code'] != info.code) return;
      final List<int> reply = utf8.encode(jsonEncode(<String, dynamic>{
        'tag': _replyTag,
        ...info.toJson(),
      }));
      socket.send(reply, dg.address, dg.port);
    });

    return DiscoveryResponder._(socket, sub);
  }

  static Future<ConnectionInfo?> resolve(
    String code, {
    Duration timeout = const Duration(seconds: 5),
    Duration retryEvery = const Duration(milliseconds: 700),
  }) async {
    RawDatagramSocket? socket;
    Timer? retryTimer;
    final Completer<ConnectionInfo?> completer = Completer<ConnectionInfo?>();
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      final RawDatagramSocket sock = socket;

      final List<int> probe = utf8.encode(jsonEncode(<String, dynamic>{
        'tag': _probeTag,
        'code': code,
      }));

      void sendProbe() {
        try {
          sock.send(probe, InternetAddress('255.255.255.255'), discoveryPort);
        } catch (_) {}
      }

      sock.listen((RawSocketEvent event) {
        if (event != RawSocketEvent.read) return;
        final Datagram? dg = sock.receive();
        if (dg == null) return;
        final Map<String, dynamic>? reply = _tryDecode(dg.data);
        if (reply == null || reply['tag'] != _replyTag) return;
        if (reply['code'] != code) return;
        final ConnectionInfo info = ConnectionInfo(
          host: (reply['host'] as String?) ?? dg.address.address,
          port: (reply['port'] as num?)?.toInt() ?? 0,
          code: code,
          leaderName: (reply['leader'] as String?) ?? '',
        );
        if (!completer.isCompleted) completer.complete(info);
      });

      sendProbe();
      retryTimer = Timer.periodic(retryEvery, (_) => sendProbe());
      return await completer.future.timeout(timeout, onTimeout: () => null);
    } catch (_) {
      return null;
    } finally {
      retryTimer?.cancel();
      socket?.close();
    }
  }

  static Map<String, dynamic>? _tryDecode(List<int> data) {
    try {
      final Object? decoded = jsonDecode(utf8.decode(data));
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }
}

class DiscoveryResponder {
  DiscoveryResponder._(this._socket, this._subscription);

  final RawDatagramSocket _socket;
  final StreamSubscription<RawSocketEvent> _subscription;

  Future<void> close() async {
    await _subscription.cancel();
    _socket.close();
  }
}
