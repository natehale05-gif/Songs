import 'dart:convert';

/// How a session's traffic is carried.
enum LiveMode {
  /// Leader hosts directly on the local network. Works with no internet at
  /// all, but every device must be on the same WiFi.
  lan,

  /// Both ends connect out to a relay, so they can be on different networks —
  /// cellular, different buildings, different cities.
  online,
}

/// Everything a member needs to connect to a leader's session. This is what is
/// encoded into the QR code.
class ConnectionInfo {
  const ConnectionInfo({
    required this.host,
    required this.port,
    required this.code,
    this.leaderName = '',
    this.mode = LiveMode.lan,
  });

  /// An online session is reached purely by code; the relay URL comes from the
  /// build, so there is no host or port to carry.
  const ConnectionInfo.online({
    required this.code,
    this.leaderName = '',
  })  : host = '',
        port = 0,
        mode = LiveMode.online;

  final String host;
  final int port;
  final String code;
  final String leaderName;
  final LiveMode mode;

  bool get isOnline => mode == LiveMode.online;

  static const String scheme = 'songslive';

  Uri get socketUri => Uri(scheme: 'ws', host: host, port: port, path: '/live');

  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': 1,
        'host': host,
        'port': port,
        'code': code,
        'leader': leaderName,
        // Older builds ignore this and read the payload as a LAN session,
        // which is the right fallback for them.
        if (mode == LiveMode.online) 'mode': 'online',
      };

  /// Compact single-line string for embedding in a QR code.
  String toPayload() {
    final String raw = jsonEncode(toJson());
    return '$scheme://${base64Url.encode(utf8.encode(raw))}';
  }

  static ConnectionInfo? tryParse(String payload) {
    try {
      final String trimmed = payload.trim();
      if (!trimmed.startsWith('$scheme://')) return null;
      final String encoded = trimmed.substring('$scheme://'.length);
      final Map<String, dynamic> json = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(base64Url.decode(encoded))) as Map);
      final String? code = json['code'] as String?;
      if (code == null) return null;

      if (json['mode'] == 'online') {
        return ConnectionInfo.online(
          code: code,
          leaderName: (json['leader'] as String?) ?? '',
        );
      }

      final String? host = json['host'] as String?;
      final int? port = (json['port'] as num?)?.toInt();
      if (host == null || port == null) return null;
      return ConnectionInfo(
        host: host,
        port: port,
        code: code,
        leaderName: (json['leader'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
