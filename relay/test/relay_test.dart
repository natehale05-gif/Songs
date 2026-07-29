import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:songs_relay/rooms.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../bin/server.dart';

/// Records what the relay pushed, without any sockets involved.
class FakePeer implements RelayPeer {
  final List<String> sent = <String>[];
  bool closed = false;

  @override
  void send(String message) => sent.add(message);

  @override
  void close() => closed = true;

  Map<String, dynamic> frameAt(int i) =>
      Map<String, dynamic>.from(jsonDecode(sent[i]) as Map);
}

String state(String text, {int revision = 1}) => jsonEncode(<String, dynamic>{
      't': 'state',
      'snap': <String, dynamic>{'partText': text, 'revision': revision},
    });

void main() {
  group('RoomRegistry', () {
    test('a member joining gets accepted and counted', () {
      final r = RoomRegistry();
      final leader = FakePeer();
      final member = FakePeer();

      expect(r.openAsLeader('ABC123', 'tok', leader).accepted, isTrue);
      expect(r.joinAsMember('ABC123', member).accepted, isTrue);

      // The member is told it is in, and the leader learns the new count.
      expect(member.frameAt(0)['t'], 'joined');
      expect(leader.sent.map((s) => jsonDecode(s)['count']), contains(1));
      expect(r.room('ABC123')!.memberCount, 1);
    });

    test('an unknown code is refused rather than opening a room', () {
      final r = RoomRegistry();
      final out = r.joinAsMember('NOPE99', FakePeer());
      expect(out.accepted, isFalse);
      expect(out.refusal, JoinRefusal.noSuchRoom);
      expect(r.roomCount, 0);
    });

    test('codes are matched case- and space-insensitively', () {
      final r = RoomRegistry();
      r.openAsLeader('ABC123', 'tok', FakePeer());
      expect(r.joinAsMember(' abc123 ', FakePeer()).accepted, isTrue);
    });

    test('a malformed code is refused', () {
      final r = RoomRegistry();
      expect(r.openAsLeader('a', 'tok', FakePeer()).refusal, JoinRefusal.badCode);
      expect(r.openAsLeader('ABC123', '', FakePeer()).refusal,
          JoinRefusal.badCode);
    });

    test('leader frames reach every member', () {
      final r = RoomRegistry();
      final leader = FakePeer();
      final a = FakePeer();
      final b = FakePeer();
      final room = r.openAsLeader('ABC123', 'tok', leader).room!;
      r.joinAsMember('ABC123', a);
      r.joinAsMember('ABC123', b);

      r.relayFromLeader(room, state('verse one'));
      expect(a.sent.last, contains('verse one'));
      expect(b.sent.last, contains('verse one'));
    });

    test('a late joiner immediately receives the current state', () {
      final r = RoomRegistry();
      final leader = FakePeer();
      final room = r.openAsLeader('ABC123', 'tok', leader).room!;
      r.relayFromLeader(room, state('verse two'));

      final late = FakePeer();
      r.joinAsMember('ABC123', late);
      // joined, then the replayed state — not a blank screen.
      expect(late.frameAt(0)['t'], 'joined');
      expect(late.sent[1], contains('verse two'));
    });

    test('rooms are isolated by code', () {
      final r = RoomRegistry();
      final roomA = r.openAsLeader('AAA111', 'tok', FakePeer()).room!;
      r.openAsLeader('BBB222', 'tok2', FakePeer());
      final outsider = FakePeer();
      r.joinAsMember('BBB222', outsider);

      r.relayFromLeader(roomA, state('only for A'));
      expect(outsider.sent.any((s) => s.contains('only for A')), isFalse);
    });

    test('a second leader with a different token is refused', () {
      final r = RoomRegistry();
      r.openAsLeader('ABC123', 'mine', FakePeer());
      final out = r.openAsLeader('ABC123', 'theirs', FakePeer());
      expect(out.accepted, isFalse);
      expect(out.refusal, JoinRefusal.roomTaken);
    });

    test('the same leader reclaims its room and keeps members', () {
      final r = RoomRegistry();
      final first = FakePeer();
      final member = FakePeer();
      r.openAsLeader('ABC123', 'mine', first);
      r.joinAsMember('ABC123', member);

      // Leader's phone slept and it reconnects with the same token.
      final second = FakePeer();
      final out = r.openAsLeader('ABC123', 'mine', second);
      expect(out.accepted, isTrue);
      expect(first.closed, isTrue, reason: 'stale socket should be dropped');
      expect(out.room!.memberCount, 1, reason: 'members must survive');
      expect(jsonDecode(second.sent.first)['count'], 1);
    });

    test('a leader leaving keeps the room alive for its members', () {
      final r = RoomRegistry();
      final leader = FakePeer();
      final member = FakePeer();
      final room = r.openAsLeader('ABC123', 'tok', leader).room!;
      r.joinAsMember('ABC123', member);

      r.remove(room, leader);
      expect(r.room('ABC123'), isNotNull);

      // Once the last member also goes, the room is collected.
      r.remove(room, member);
      expect(r.room('ABC123'), isNull);
    });

    test('the leader is told when a member leaves', () {
      final r = RoomRegistry();
      final leader = FakePeer();
      final member = FakePeer();
      final room = r.openAsLeader('ABC123', 'tok', leader).room!;
      r.joinAsMember('ABC123', member);
      r.remove(room, member);
      expect(jsonDecode(leader.sent.last)['count'], 0);
    });

    test('idle rooms are swept', () {
      final r = RoomRegistry(idleTimeout: const Duration(hours: 1));
      final leader = FakePeer();
      final room = r.openAsLeader('ABC123', 'tok', leader).room!;
      r.joinAsMember('ABC123', FakePeer());
      room.lastActivity = DateTime.now().subtract(const Duration(hours: 2));

      expect(r.sweep(), 1);
      expect(r.roomCount, 0);
    });

    test('the room ceiling is enforced', () {
      final r = RoomRegistry(maxRooms: 2);
      expect(r.openAsLeader('AAA111', 't', FakePeer()).accepted, isTrue);
      expect(r.openAsLeader('BBB222', 't', FakePeer()).accepted, isTrue);
      expect(r.openAsLeader('CCC333', 't', FakePeer()).accepted, isFalse);
    });

    test('only state frames are cached for replay', () {
      final r = RoomRegistry();
      final room = r.openAsLeader('ABC123', 'tok', FakePeer()).room!;
      r.relayFromLeader(room, jsonEncode({'t': 'ping'}));
      expect(room.lastState, isNull);
      r.relayFromLeader(room, state('kept'));
      expect(room.lastState, contains('kept'));
    });
  });

  group('over real sockets', () {
    late HttpServer server;
    late String base;

    setUp(() async {
      server = await shelf_io.serve(
          buildHandler(RoomRegistry()), InternetAddress.loopbackIPv4, 0);
      base = 'ws://${server.address.host}:${server.port}/live';
    });

    tearDown(() => server.close(force: true));

    test('a leader and two members exchange state end to end', () async {
      final leader = WebSocketChannel.connect(
          Uri.parse('$base?code=ZZZ999&role=leader&token=secret'));
      await leader.ready;
      final leaderIn = StreamQueue<dynamic>(leader.stream);

      // First thing a leader hears is the member count.
      expect(jsonDecode(await leaderIn.next as String)['t'], 'members');

      final one = WebSocketChannel.connect(
          Uri.parse('$base?code=ZZZ999&role=member'));
      await one.ready;
      final oneIn = StreamQueue<dynamic>(one.stream);
      expect(jsonDecode(await oneIn.next as String)['t'], 'joined');

      final two = WebSocketChannel.connect(
          Uri.parse('$base?code=zzz999&role=member')); // lowercase on purpose
      await two.ready;
      final twoIn = StreamQueue<dynamic>(two.stream);
      expect(jsonDecode(await twoIn.next as String)['t'], 'joined');

      leader.sink.add(state('Amazing grace, how sweet the sound'));

      for (final q in <StreamQueue<dynamic>>[oneIn, twoIn]) {
        final frame = jsonDecode(await q.next as String) as Map;
        expect(frame['t'], 'state');
        expect(frame['snap']['partText'], contains('Amazing grace'));
      }

      await leader.sink.close();
      await one.sink.close();
      await two.sink.close();
    });

    test('a wrong code is rejected with a reason', () async {
      final member = WebSocketChannel.connect(
          Uri.parse('$base?code=QQQ777&role=member'));
      await member.ready;
      final frame =
          jsonDecode(await member.stream.first as String) as Map<String, dynamic>;
      expect(frame['t'], 'rejected');
      expect(frame['reason'], contains('No online session'));
    });

    test('health endpoint answers for platform probes', () async {
      final client = HttpClient();
      final req = await client.getUrl(
          Uri.parse('http://${server.address.host}:${server.port}/health'));
      final res = await req.close();
      expect(res.statusCode, 200);
      expect(await res.transform(utf8.decoder).join(), startsWith('ok rooms='));
      client.close();
    });
  });
}
