import 'package:flutter_test/flutter_test.dart';
import 'package:songs/models/connection_info.dart';
import 'package:songs/models/session_snapshot.dart';
import 'package:songs/models/song.dart';
import 'package:songs/models/song_section.dart';
import 'package:songs/services/live_client.dart';
import 'package:songs/services/live_host.dart';

void main() {
  test('member receives the leader snapshot over the local socket', () async {
    final LiveHost host = LiveHost();
    final ConnectionInfo info = await host.start(
      code: 'TEST24',
      leaderName: 'Leader',
      preferredHost: '127.0.0.1',
    );

    const Song song = Song(
      id: 's1',
      title: 'Amazing Grace',
      sections: <SongSection>[
        SongSection(label: 'Verse 1', lines: <String>['line one']),
      ],
    );

    // Point the client explicitly at loopback and the negotiated port.
    final ConnectionInfo clientInfo = ConnectionInfo(
      host: '127.0.0.1',
      port: info.port,
      code: info.code,
      leaderName: info.leaderName,
    );

    final LiveClient client = LiveClient();
    addTearDown(() async {
      await client.dispose();
      await host.stop();
    });

    final Future<SessionSnapshot> firstSongSnapshot = client.snapshots
        .firstWhere((SessionSnapshot s) => s.currentSong != null);

    await client.connect(clientInfo, memberName: 'Member');

    // Give the join handshake a moment, then broadcast a song.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    host.broadcast(
      const SessionSnapshot(
        code: 'TEST24',
        currentSong: song,
        sectionIndex: 0,
        revision: 1,
      ),
    );

    final SessionSnapshot received =
        await firstSongSnapshot.timeout(const Duration(seconds: 5));

    expect(received.currentSong!.title, 'Amazing Grace');
    expect(received.code, 'TEST24');
  });

  test('member count is reported to the host', () async {
    final LiveHost host = LiveHost();
    int reported = -1;
    host.onMembersChanged = (int count) => reported = count;

    final ConnectionInfo info = await host.start(
      code: 'CNT24A',
      leaderName: 'Leader',
      preferredHost: '127.0.0.1',
    );

    final LiveClient client = LiveClient();
    addTearDown(() async {
      await client.dispose();
      await host.stop();
    });

    await client.connect(
      ConnectionInfo(host: '127.0.0.1', port: info.port, code: 'CNT24A'),
      memberName: 'Member',
    );

    // Wait until the host registers the member.
    final DateTime deadline =
        DateTime.now().add(const Duration(seconds: 5));
    while (host.memberCount < 1 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    expect(host.memberCount, 1);
    expect(reported, 1);
  });
}
