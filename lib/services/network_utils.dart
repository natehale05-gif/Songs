import 'dart:io';

/// Helpers for finding the device's address on the local network.
class NetworkUtils {
  NetworkUtils._();

  /// Returns the most likely LAN IPv4 address for this device, preferring
  /// private ranges (192.168.x, 10.x, 172.16-31.x) which is what a small group
  /// on the same WiFi or a phone hotspot will use.
  ///
  /// Works completely offline; it only inspects local network interfaces.
  static Future<String?> localIpv4() async {
    try {
      final List<NetworkInterface> interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
        includeLoopback: false,
      );

      String? fallback;
      for (final NetworkInterface interface in interfaces) {
        for (final InternetAddress addr in interface.addresses) {
          if (addr.isLoopback) continue;
          fallback ??= addr.address;
          if (isPrivate(addr.address)) return addr.address;
        }
      }
      return fallback;
    } catch (_) {
      return null;
    }
  }

  /// Whether [ip] is inside an RFC 1918 private IPv4 range.
  static bool isPrivate(String ip) {
    final List<String> parts = ip.split('.');
    if (parts.length != 4) return false;
    final int? a = int.tryParse(parts[0]);
    final int? b = int.tryParse(parts[1]);
    if (a == null || b == null) return false;
    if (a == 10) return true;
    if (a == 192 && b == 168) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    return false;
  }
}
