import 'package:flutter_test/flutter_test.dart';
import 'package:songs_of_the_church/live/live_snapshot.dart';
import 'package:songs_of_the_church/live/live_sync.dart';
import 'package:songs_of_the_church/models.dart';

/// Verse/chorus/verse/chorus… the way Song.buildParts interleaves them.
List<SongPart> partsWith(int verses, {bool chorus = true}) {
  final out = <SongPart>[];
  for (var v = 1; v <= verses; v++) {
    out.add(SongPart(label: 'Verse $v', text: 'verse $v text'));
    if (chorus) {
      out.add(const SongPart(
          label: 'Chorus', text: 'chorus text', isChorus: true));
    }
  }
  return out;
}

void main() {
  group('resolveLivePartIndex', () {
    test('identical lists map straight through', () {
      final parts = partsWith(3);
      for (var i = 0; i < parts.length; i++) {
        expect(
          resolveLivePartIndex(
            memberParts: parts,
            leaderIndex: i,
            leaderTotal: parts.length,
            leaderLabel: parts[i].label,
            leaderIsChorus: parts[i].isChorus,
          ),
          i,
        );
      }
    });

    test('a leader who disabled verses still lands on the right verse', () {
      // Member has all 4 verses; leader turned off verses 1 and 2, so their
      // list is shorter and their index means something different.
      final memberParts = partsWith(4, chorus: false);
      final index = resolveLivePartIndex(
        memberParts: memberParts,
        leaderIndex: 0, // first in the leader's shortened list
        leaderTotal: 2,
        leaderLabel: 'Verse 3',
        leaderIsChorus: false,
      );
      expect(memberParts[index].label, 'Verse 3');
    });

    test('the member can have fewer parts than the leader', () {
      final memberParts = partsWith(2, chorus: false);
      final index = resolveLivePartIndex(
        memberParts: memberParts,
        leaderIndex: 3,
        leaderTotal: 5,
        leaderLabel: 'Verse 2',
        leaderIsChorus: false,
      );
      expect(index, 1);
    });

    test('a repeated chorus resolves to the nearest occurrence', () {
      final memberParts = partsWith(3); // chorus at 1, 3, 5
      final index = resolveLivePartIndex(
        memberParts: memberParts,
        leaderIndex: 4,
        leaderTotal: 99, // force the label path
        leaderLabel: 'Chorus',
        leaderIsChorus: true,
      );
      expect(memberParts[index].isChorus, isTrue);
      expect(index, 3, reason: 'nearest chorus to index 4 is at 3');
    });

    test('a chorus never resolves onto a verse of the same name', () {
      final memberParts = <SongPart>[
        const SongPart(label: 'Chorus', text: 'v', isChorus: false),
        const SongPart(label: 'Chorus', text: 'c', isChorus: true),
      ];
      final index = resolveLivePartIndex(
        memberParts: memberParts,
        leaderIndex: 0,
        leaderTotal: 99,
        leaderLabel: 'Chorus',
        leaderIsChorus: true,
      );
      expect(index, 1);
    });

    test('labels match regardless of case and padding', () {
      final memberParts = partsWith(2, chorus: false);
      expect(
        resolveLivePartIndex(
          memberParts: memberParts,
          leaderIndex: 9,
          leaderTotal: 99,
          leaderLabel: '  verse 2 ',
          leaderIsChorus: false,
        ),
        1,
      );
    });

    test('an unmatchable label with an out-of-range index gives up', () {
      expect(
        resolveLivePartIndex(
          memberParts: partsWith(2, chorus: false),
          leaderIndex: 50,
          leaderTotal: 99,
          leaderLabel: 'Bridge',
          leaderIsChorus: false,
        ),
        -1,
      );
    });

    test('an empty member list gives up rather than throwing', () {
      expect(
        resolveLivePartIndex(
          memberParts: const <SongPart>[],
          leaderIndex: 0,
          leaderTotal: 0,
          leaderLabel: 'Verse 1',
          leaderIsChorus: false,
        ),
        -1,
      );
    });

    test('an unmatchable label falls back to an in-range index', () {
      expect(
        resolveLivePartIndex(
          memberParts: partsWith(3, chorus: false),
          leaderIndex: 2,
          leaderTotal: 99,
          leaderLabel: 'Bridge',
          leaderIsChorus: false,
        ),
        2,
      );
    });
  });

  group('resolveSnapshotPartIndex', () {
    test('reads the fields off a snapshot', () {
      final parts = partsWith(3, chorus: false);
      const snap = LiveSnapshot(
        code: 'ABC123',
        leaderName: 'Leader',
        songId: 7,
        partLabel: 'Verse 3',
        index: 0,
        total: 1,
        revision: 1,
      );
      expect(parts[resolveSnapshotPartIndex(snap, parts)].label, 'Verse 3');
    });
  });

  group('songForSnapshot', () {
    Song song(int id, String title) => Song(
          id: id,
          num: '$id',
          title: title,
          category: 'praise',
          author: 'Anon',
          verses: const <Verse>[],
          moreVerses: const <Verse>[],
        );
    final library = <Song>[song(1, 'One'), song(2, 'Two')];

    test('finds the leader’s song in the member’s own library', () {
      const snap = LiveSnapshot(
          code: 'A', leaderName: 'L', songId: 2, revision: 1);
      expect(songForSnapshot(snap, library)?.title, 'Two');
    });

    test('returns null when the song is unknown or absent', () {
      const missing = LiveSnapshot(
          code: 'A', leaderName: 'L', songId: 99, revision: 1);
      expect(songForSnapshot(missing, library), isNull);
      const none = LiveSnapshot(code: 'A', leaderName: 'L', revision: 1);
      expect(songForSnapshot(none, library), isNull);
    });
  });
}
