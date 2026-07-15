import 'package:flutter_test/flutter_test.dart';
import 'package:songs_of_the_church/live/client.dart';
import 'package:songs_of_the_church/live/connection_info.dart';
import 'package:songs_of_the_church/live/frame.dart';
import 'package:songs_of_the_church/live/host.dart';
import 'package:songs_of_the_church/live/join_code.dart';
import 'package:songs_of_the_church/live/live_snapshot.dart';

void main() {
  group('JoinCode', () {
    test('generates safe codes and validates them', () {
      final code = JoinCode.generate();
      expect(code.length, 6);
      expect(JoinCode.isValid(code), isTrue);
      expect(code.contains('0'), isFalse);
      expect(code.contains('O'), isFalse);
      expect(JoinCode.normalize(' k7 qp24 '), 'K7QP24');
      expect(JoinCode.isValid('K0QP24'), isFalse);
    });
  });

  group('ConnectionInfo', () {
    test('round trips through the QR payload', () {
      const info = ConnectionInfo(
          host: '192.168.1.10', port: 8080, code: 'K7QP24', leaderName: 'Sam');
      final parsed = ConnectionInfo.tryParse(info.toPayload());
      expect(parsed, isNotNull);
      expect(parsed!.host, '192.168.1.10');
      expect(parsed.port, 8080);
      expect(parsed.code, 'K7QP24');
      expect(parsed.socketUri.toString(), 'ws://192.168.1.10:8080/live');
      expect(ConnectionInfo.tryParse('https://example.com'), isNull);
    });
  });

  group('Frame / LiveSnapshot', () {
    test('encodes and decodes a state frame', () {
      const snap = LiveSnapshot(
        code: 'K7QP24',
        leaderName: 'Sam',
        songId: 42,
        songTitle: 'Amazing Grace',
        partLabel: 'Verse 1',
        partText: 'Amazing grace...',
        index: 1,
        total: 4,
        revision: 3,
      );
      final decoded = Frame.decode(Frame.state(snap).encode());
      expect(decoded.type, FrameType.state);
      expect(decoded.snapshot!.songId, 42);
      expect(decoded.snapshot!.songTitle, 'Amazing Grace');
      expect(decoded.snapshot!.index, 1);
      expect(decoded.snapshot!.total, 4);
      expect(decoded.snapshot!.revision, 3);
    });

    test('encodes a join frame and handles junk', () {
      final decoded =
          Frame.decode(Frame.join(code: 'K7QP24', name: 'Al', id: 'x').encode());
      expect(decoded.type, FrameType.join);
      expect(decoded.code, 'K7QP24');
      expect(decoded.id, 'x');
      expect(Frame.decode('nonsense').type, FrameType.unknown);
    });
  });

  test('member mirrors the leader snapshot over a loopback socket', () async {
    final host = LiveHost();
    final info = await host.start(
      code: 'TEST24',
      leaderName: 'Leader',
      preferredHost: '127.0.0.1',
    );

    final client = LiveClient();
    addTearDown(() async {
      await client.dispose();
      await host.stop();
    });

    final firstSong =
        client.snapshots.firstWhere((s) => s.songTitle.isNotEmpty);

    await client.connect(
      ConnectionInfo(host: '127.0.0.1', port: info.port, code: 'TEST24'),
      memberName: 'Member',
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    host.broadcast(const LiveSnapshot(
      code: 'TEST24',
      songId: 1,
      songTitle: 'It Is Well',
      partLabel: 'Verse 1',
      partText: 'When peace like a river...',
      index: 0,
      total: 2,
      revision: 1,
    ));

    final received = await firstSong.timeout(const Duration(seconds: 5));
    expect(received.songTitle, 'It Is Well');
    expect(received.partText, startsWith('When peace'));
  });
}
