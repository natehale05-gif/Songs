import 'dart:convert';

/// Everything a member needs to connect to a leader's session. This is what is
/// encoded into the QR code.
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

  static const String scheme = 'songslive';

  Uri get socketUri => Uri(scheme: 'ws', host: host, port: port, path: '/live');

  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': 1,
        'host': host,
        'port': port,
        'code': code,
        'leader': leaderName,
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
