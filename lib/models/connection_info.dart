import 'dart:convert';

/// Everything a member needs to connect to a leader's live session over the
/// local network. This is what gets encoded into the QR code.
class ConnectionInfo {
  const ConnectionInfo({
    required this.host,
    required this.port,
    required this.code,
    this.leaderName = '',
  });

  final String host;
  final int port;
  final String code;
  final String leaderName;

  /// Prefix used to recognise our payloads when scanning arbitrary QR codes.
  static const String scheme = 'songslive';

  /// The WebSocket endpoint the member should connect to.
  Uri get socketUri =>
      Uri(scheme: 'ws', host: host, port: port, path: '/live');

  Map<String, dynamic> toJson() => {
        'v': 1,
        'host': host,
        'port': port,
        'code': code,
        'leader': leaderName,
      };

  /// A compact, single line string suitable for embedding in a QR code.
  ///
  /// Format: `songslive://<base64-url-encoded-json>`
  String toPayload() {
    final String raw = jsonEncode(toJson());
    final String encoded = base64Url.encode(utf8.encode(raw));
    return '$scheme://$encoded';
  }

  /// Parses a payload produced by [toPayload]. Returns null when the string is
  /// not a recognised Songs Live payload.
  static ConnectionInfo? tryParse(String payload) {
    try {
      final String trimmed = payload.trim();
      if (!trimmed.startsWith('$scheme://')) return null;
      final String encoded = trimmed.substring('$scheme://'.length);
      final String raw = utf8.decode(base64Url.decode(encoded));
      final Map<String, dynamic> json =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final String? host = json['host'] as String?;
      final int? port = (json['port'] as num?)?.toInt();
      final String? code = json['code'] as String?;
      if (host == null || port == null || code == null) return null;
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
