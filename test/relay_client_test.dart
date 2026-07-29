import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:songs_of_the_church/live/client.dart';
import 'package:songs_of_the_church/live/connection_info.dart';
import 'package:songs_of_the_church/live/live_snapshot.dart';
import 'package:songs_of_the_church/live/relay_config.dart';
import 'package:songs_of_the_church/live/relay_transport.dart';

void main() {
  group('relaySocketUri', () {
    test('builds a leader URL carrying the reclaim token', () {
      final u = relaySocketUri(
          code: 'ABC123',
          asLeader: true,
          token: 'deadbeef',
          base: 'wss://relay.example');
      expect(u.scheme, 'wss');
      expect(u.path, '/live');
      expect(u.queryParameters['code'], 'ABC123');
      expect(u.queryParameters['role'], 'leader');
      expect(u.queryParameters['token'], 'deadbeef');
    });

    test('members never send a token', () {
      final u = relaySocketUri(
          code: 'ABC123', asLeader: false, base: 'wss://relay.example');
      expect(u.queryParameters['role'], 'member');
      expect(u.queryParameters.containsKey('token'), isFalse);
    });

    test('http(s) bases are mapped to the websocket scheme', () {
      expect(
          relaySocketUri(code: 'A1B2C3', asLeader: false, base: 'https://r.test')
              .scheme,
          'wss');
      expect(
          relaySocketUri(code: 'A1B2C3', asLeader: false, base: 'http://r.test')
              .scheme,
          'ws');
    });

    test('a trailing slash does not double up the path', () {
      final u = relaySocketUri(
          code: 'A1B2C3', asLeader: false, base: 'wss://r.test/');
      expect(u.path, '/live');
    });
  });

  group('leader tokens', () {
    test('are long and not repeated', () {
      final a = newLeaderToken();
      final b = newLeaderToken();
      expect(a.length, 32);
      expect(a, isNot(b));
    });
  });

  group('ConnectionInfo online mode', () {
    test('survives a QR round trip', () {
      const info = ConnectionInfo.online(code: 'K7QP24', leaderName: 'Nate');
      final parsed = ConnectionInfo.tryParse(info.toPayload());
      expect(parsed, isNotNull);
      expect(parsed!.isOnline, isTrue);
      expect(parsed.code, 'K7QP24');
      expect(parsed.leaderName, 'Nate');
    });

    test('a payload without a mode is still read as LAN', () {
      // Guards compatibility with QR codes produced before online existed.
      const lan = ConnectionInfo(host: '192.168.1.5', port: 4040, code: 'AAA111');
      final parsed = ConnectionInfo.tryParse(lan.toPayload());
      expect(parsed!.mode, LiveMode.lan);
      expect(parsed.host, '192.168.1.5');
      expect(parsed.port, 4040);
    });

    test('the right transport is chosen per mode', () {
      expect(LiveClient.forMode(LiveMode.online), isA<RelayClient>());
      expect(LiveClient.forMode(LiveMode.lan), isNot(isA<RelayClient>()));
    });
  });

  group('against a real relay', () {
    late Process relay;
    late String base;

    setUpAll(() async {
      // Run the actual relay so this exercises the wire protocol, not a mock.
      relay = await Process.start(
        'dart',
        ['run', 'bin/server.dart'],
        workingDirectory: 'relay',
        environment: {'PORT': '8791'},
      );
      // Wait for the listening line before connecting.
      await relay.stdout
          .transform(const SystemEncoding().decoder)
          .firstWhere((line) => line.contains('listening'))
          .timeout(const Duration(seconds: 40));
      base = 'ws://127.0.0.1:8791';
    });

    tearDownAll(() => relay.kill());

    test('a member on a different connection receives the leader state',
        timeout: const Timeout(Duration(seconds: 90)), () async {
      final host = RelayHost(relayBase: base);
      final info = await host.start(code: 'LMN456', leaderName: 'Leader');
      expect(info.isOnline, isTrue);

      final member = RelayClient(relayBase: base);
      final seen = <LiveSnapshot>[];
      member.snapshots.listen(seen.add);
      await member.connect(info, memberName: 'Phone');

      // Let the join settle, then publish.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      host.broadcast(const LiveSnapshot(
        code: 'LMN456',
        leaderName: 'Leader',
        songTitle: 'Amazing Grace',
        partText: 'how sweet the sound',
        revision: 2,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(seen, isNotEmpty);
      expect(seen.last.songTitle, 'Amazing Grace');
      expect(seen.last.partText, contains('sweet the sound'));

      // And the leader learned that somebody is connected.
      expect(host.memberCount, 1);

      await member.dispose();
      await host.stop();
    });

    test('a late member is caught up to the current verse',
        timeout: const Timeout(Duration(seconds: 90)), () async {
      final host = RelayHost(relayBase: base);
      final info = await host.start(code: 'LATE77', leaderName: 'Leader');
      host.broadcast(const LiveSnapshot(
        code: 'LATE77',
        leaderName: 'Leader',
        partText: 'verse already showing',
        revision: 5,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final member = RelayClient(relayBase: base);
      final seen = <LiveSnapshot>[];
      member.snapshots.listen(seen.add);
      await member.connect(info, memberName: 'Latecomer');
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(seen, isNotEmpty,
          reason: 'a late joiner must be caught up, not left blank');
      expect(seen.first.partText, 'verse already showing');

      await member.dispose();
      await host.stop();
    });

    test('an unknown code is rejected with a readable reason',
        timeout: const Timeout(Duration(seconds: 90)), () async {
      final member = RelayClient(relayBase: base);
      final statuses = <LiveClientStatus>[];
      member.statuses.listen(statuses.add);
      await member.connect(
          const ConnectionInfo.online(code: 'GHOST1'), memberName: 'Nobody');
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(statuses, contains(LiveClientStatus.rejected));
      expect(member.lastError, contains('No online session'));
      await member.dispose();
    });
  });
}
