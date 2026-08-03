/// Base URL of the relay that carries online sessions, e.g.
/// `wss://songs-relay.fly.dev`. Injected at build time:
///
///   flutter build ... --dart-define=RELAY_URL=wss://your-relay.example
///
/// Empty by default: there is no relay anyone can reach until you deploy one
/// (see relay/README.md), and silently pointing church sessions at a server
/// nobody here controls would be worse than saying so.
const String kRelayUrl = String.fromEnvironment('RELAY_URL');

/// Whether online sessions can be offered at all.
bool get relayConfigured => kRelayUrl.trim().isNotEmpty;

/// Socket URL for one end of a session.
///
/// [token] is the leader's secret for reclaiming its own room after a dropped
/// connection; members do not send one.
Uri relaySocketUri({
  required String code,
  required bool asLeader,
  String? token,
  String base = kRelayUrl,
}) {
  String trimmed = base.trim().replaceAll(RegExp(r'/+$'), '');

  // Tolerate a base that already names the endpoint, so that pasting the URL
  // the app connects to does not produce /live/live.
  trimmed = trimmed.replaceFirst(RegExp(r'/live$'), '');

  // Accept http(s) for convenience and map it to the websocket scheme.
  String normalized = trimmed
      .replaceFirst(RegExp(r'^https://'), 'wss://')
      .replaceFirst(RegExp(r'^http://'), 'ws://');

  // `fly status` and the Render dashboard both print a bare hostname, which is
  // what anyone would paste into RELAY_URL. Without a scheme this parses as a
  // *relative* URI and the socket fails at connect time with something that
  // says nothing about the cause, so assume the secure scheme.
  if (!normalized.contains('://')) normalized = 'wss://$normalized';

  return Uri.parse('$normalized/live').replace(queryParameters: <String, String>{
    'code': code,
    'role': asLeader ? 'leader' : 'member',
    if (asLeader && token != null && token.isNotEmpty) 'token': token,
  });
}
