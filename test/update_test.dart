import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:songs_of_the_church/update/update_service.dart';

void main() {
  group('compareVersions', () {
    test('orders by numeric component, not lexically', () {
      // The classic trap: "1.0.10" sorts before "1.0.9" as a string.
      expect(compareVersions('1.0.10', '1.0.9'), greaterThan(0));
      expect(compareVersions('1.2.0', '1.10.0'), lessThan(0));
      expect(compareVersions('2.0.0', '1.99.99'), greaterThan(0));
    });

    test('treats missing components as zero', () {
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1.2.0.0', '1.2'), 0);
      expect(compareVersions('1.3', '1.2.9'), greaterThan(0));
    });

    test('ignores a leading v and any suffix', () {
      expect(compareVersions('v1.0.1', '1.0.1'), 0);
      expect(compareVersions('1.0.1-beta', '1.0.1'), 0);
      expect(compareVersions('v1.0.2+7', '1.0.1'), greaterThan(0));
    });
  });

  group('isNewer', () {
    test('only a strictly greater version counts', () {
      expect(isNewer(current: '1.0.0', latest: 'v1.0.1'), isTrue);
      expect(isNewer(current: '1.0.1', latest: 'v1.0.1'), isFalse);
      expect(isNewer(current: '1.0.2', latest: 'v1.0.1'), isFalse);
    });

    test('an unknown current version never prompts', () {
      // Local builds carry no APP_VERSION; they must not nag.
      expect(isNewer(current: '', latest: 'v9.9.9'), isFalse);
      expect(isNewer(current: '   ', latest: 'v9.9.9'), isFalse);
    });
  });

  group('download targets', () {
    test('every target maps to a published asset name', () {
      for (final t in UpdateTarget.values) {
        expect(kTargetAssets[t], isNotNull, reason: '$t has no asset');
        expect(downloadUrlFor(t), contains('/releases/latest/download/'));
      }
    });
  });

  group('fetchUpdate', () {
    http.Client jsonClient(String tag, {int status = 200}) =>
        MockClient((_) async => http.Response(
            jsonEncode({'tag_name': tag}), status,
            headers: {'content-type': 'application/json'}));

    test('reports an update when the release is newer', () async {
      final u = await fetchUpdate(
        client: jsonClient('v1.0.4'),
        currentVersion: '1.0.3',
        target: UpdateTarget.android,
      );
      expect(u, isNotNull);
      expect(u!.version, '1.0.4');
      expect(u.downloadUrl, endsWith('songs-of-the-church.apk'));
    });

    test('stays quiet when already up to date', () async {
      final u = await fetchUpdate(
        client: jsonClient('v1.0.3'),
        currentVersion: '1.0.3',
        target: UpdateTarget.linux,
      );
      expect(u, isNull);
    });

    test('stays quiet when the version is unknown', () async {
      final u = await fetchUpdate(
        client: jsonClient('v9.9.9'),
        currentVersion: '',
        target: UpdateTarget.linux,
      );
      expect(u, isNull);
    });

    test('a network failure is not an error', () async {
      final u = await fetchUpdate(
        client: MockClient((_) async => throw const SocketishFailure()),
        currentVersion: '1.0.0',
        target: UpdateTarget.macos,
      );
      expect(u, isNull);
    });

    test('a non-200 response is ignored', () async {
      final u = await fetchUpdate(
        client: jsonClient('v2.0.0', status: 403),
        currentVersion: '1.0.0',
        target: UpdateTarget.windows,
      );
      expect(u, isNull);
    });

    test('a malformed payload is ignored', () async {
      final u = await fetchUpdate(
        client: MockClient((_) async => http.Response('not json', 200)),
        currentVersion: '1.0.0',
        target: UpdateTarget.windows,
      );
      expect(u, isNull);
    });
  });

  group('fetchUpdate on web', () {
    http.Client manifest(String build, {String version = '1.0.0'}) =>
        MockClient((req) async {
          // Must be cache-busted, or the service worker can answer with the
          // stale copy we are trying to compare against.
          expect(req.url.path, contains('version.json'));
          expect(req.url.queryParameters['ts'], isNotNull);
          return http.Response(
              jsonEncode({'version': version, 'build_number': build}), 200);
        });

    test('a redeployed build offers a reload', () async {
      final u = await fetchUpdate(
        client: manifest('42', version: '1.1.0'),
        currentBuild: '41',
        isWeb: true,
      );
      expect(u, isNotNull);
      expect(u!.version, '1.1.0');
    });

    test('the same build is not an update', () async {
      final u = await fetchUpdate(
        client: manifest('42'),
        currentBuild: '42',
        isWeb: true,
      );
      expect(u, isNull);
    });

    test('an unknown build never prompts', () async {
      final u = await fetchUpdate(
        client: manifest('42'),
        currentBuild: '',
        isWeb: true,
      );
      expect(u, isNull);
    });
  });
}

/// Stand-in for a connectivity failure; the real type differs per platform.
class SocketishFailure implements Exception {
  const SocketishFailure();
}
