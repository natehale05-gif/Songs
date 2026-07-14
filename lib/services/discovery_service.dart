import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/connection_info.dart';

/// Lightweight, dependency free LAN discovery built on UDP broadcast.
///
/// This is what makes "join by code" work fully offline: the leader listens for
/// broadcast probes carrying a join code, and answers matching probes with its
/// [ConnectionInfo]. A member that only knows the code can therefore locate the
/// leader on the same network without typing an IP address.
class DiscoveryService {
  DiscoveryService._();

  /// Well known UDP port the leader listens on for discovery probes.
  static const int discoveryPort = 45411;

  static const String _probeTag = 'SONGSLIVE_PROBE';
  static const String _replyTag = 'SONGSLIVE_REPLY';

  /// Starts a responder that answers discovery probes for [info.code] with the
  /// full [info]. Returns a [DiscoveryResponder] that must be closed when the
  /// session ends.
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
      final String? wanted = probe['code'] as String?;
      if (wanted == null || wanted != info.code) return;

      final List<int> reply = utf8.encode(jsonEncode(<String, dynamic>{
        'tag': _replyTag,
        ...info.toJson(),
      }));
      socket.send(reply, dg.address, dg.port);
    });

    return DiscoveryResponder._(socket, sub);
  }

  /// Broadcasts a probe for [code] and waits up to [timeout] for a matching
  /// leader to answer. Returns the resolved [ConnectionInfo] or null on
  /// timeout.
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
          sock.send(
            probe,
            InternetAddress('255.255.255.255'),
            discoveryPort,
          );
        } catch (_) {
          // Ignore transient send failures; we retry on a timer.
        }
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

/// Handle to a running discovery responder. Call [close] to stop answering.
class DiscoveryResponder {
  DiscoveryResponder._(this._socket, this._subscription);

  final RawDatagramSocket _socket;
  final StreamSubscription<RawSocketEvent> _subscription;

  Future<void> close() async {
    await _subscription.cancel();
    _socket.close();
  }
}
