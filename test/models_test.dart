import 'package:flutter_test/flutter_test.dart';
import 'package:songs/models/connection_info.dart';
import 'package:songs/models/session_snapshot.dart';
import 'package:songs/models/song.dart';
import 'package:songs/models/song_section.dart';
import 'package:songs/models/sync_message.dart';
import 'package:songs/services/join_code.dart';

void main() {
  group('Song serialization', () {
    test('round trips through JSON', () {
      const Song song = Song(
        id: 'abc',
        title: 'Amazing Grace',
        author: 'John Newton',
        songKey: 'G',
        sections: <SongSection>[
          SongSection(label: 'Verse 1', lines: <String>['a', 'b']),
        ],
      );
      final Song decoded = Song.fromJson(song.toJson());
      expect(decoded.id, song.id);
      expect(decoded.title, song.title);
      expect(decoded.author, song.author);
      expect(decoded.songKey, song.songKey);
      expect(decoded.sections.length, 1);
      expect(decoded.sections.first.label, 'Verse 1');
      expect(decoded.sections.first.lines, <String>['a', 'b']);
    });
  });

  group('JoinCode', () {
    test('generates codes of the requested length using safe alphabet', () {
      final String code = JoinCode.generate(length: 6);
      expect(code.length, 6);
      expect(RegExp(r'^[A-HJ-NP-Z2-9]+$').hasMatch(code), isTrue);
      expect(code.contains('0'), isFalse);
      expect(code.contains('O'), isFalse);
      expect(code.contains('1'), isFalse);
    });

    test('normalizes user input', () {
      expect(JoinCode.normalize(' k7q p24 '), 'K7QP24');
    });

    test('validates length and alphabet', () {
      expect(JoinCode.isValid('K7QP24'), isTrue);
      expect(JoinCode.isValid('k7qp24'), isTrue);
      expect(JoinCode.isValid('SHORT'), isFalse);
      expect(JoinCode.isValid('K0QP24'), isFalse); // contains 0
    });
  });

  group('ConnectionInfo payload', () {
    test('round trips through QR payload', () {
      const ConnectionInfo info = ConnectionInfo(
        host: '192.168.1.42',
        port: 8123,
        code: 'K7QP24',
        leaderName: 'Sam',
      );
      final String payload = info.toPayload();
      expect(payload.startsWith('songslive://'), isTrue);

      final ConnectionInfo? parsed = ConnectionInfo.tryParse(payload);
      expect(parsed, isNotNull);
      expect(parsed!.host, info.host);
      expect(parsed.port, info.port);
      expect(parsed.code, info.code);
      expect(parsed.leaderName, info.leaderName);
      expect(parsed.socketUri.toString(), 'ws://192.168.1.42:8123/live');
    });

    test('rejects non Songs Live payloads', () {
      expect(ConnectionInfo.tryParse('https://example.com'), isNull);
      expect(ConnectionInfo.tryParse('songslive://not-base64!!'), isNull);
    });
  });

  group('SyncMessage', () {
    test('encodes and decodes a state snapshot', () {
      const SessionSnapshot snapshot = SessionSnapshot(
        code: 'K7QP24',
        leaderName: 'Sam',
        currentSong: Song(id: 's1', title: 'Test'),
        sectionIndex: 2,
        blanked: true,
        memberCount: 3,
        revision: 7,
      );
      final String raw = SyncMessage.state(snapshot).encode();
      final SyncMessage decoded = SyncMessage.decode(raw);

      expect(decoded.type, SyncType.state);
      expect(decoded.snapshot, isNotNull);
      expect(decoded.snapshot!.code, 'K7QP24');
      expect(decoded.snapshot!.sectionIndex, 2);
      expect(decoded.snapshot!.blanked, isTrue);
      expect(decoded.snapshot!.memberCount, 3);
      expect(decoded.snapshot!.revision, 7);
      expect(decoded.snapshot!.currentSong!.title, 'Test');
    });

    test('encodes and decodes a join request', () {
      final String raw =
          SyncMessage.join(code: 'K7QP24', name: 'Alex').encode();
      final SyncMessage decoded = SyncMessage.decode(raw);
      expect(decoded.type, SyncType.join);
      expect(decoded.code, 'K7QP24');
      expect(decoded.name, 'Alex');
    });

    test('gracefully handles malformed input', () {
      expect(SyncMessage.decode('not json').type, SyncType.unknown);
    });
  });
}
