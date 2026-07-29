import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Where releases are published.
const String kRepoOwner = 'natehale05-gif';
const String kRepoName = 'Songs';

const String kReleasesApi =
    'https://api.github.com/repos/$kRepoOwner/$kRepoName/releases/latest';
const String kReleasesPage =
    'https://github.com/$kRepoOwner/$kRepoName/releases/latest';

/// Version this build was compiled as, injected by CI:
///   flutter build ... --dart-define=APP_VERSION=1.2.3
/// Empty in local development, which disables the check entirely.
const String kAppVersion = String.fromEnvironment('APP_VERSION');

/// Monotonic build id, injected the same way. Web compares this rather than
/// the version, because Pages redeploys on every push to main and so has no
/// release tag to compare against.
const String kAppBuild = String.fromEnvironment('APP_BUILD');

/// Flutter emits this next to the app on web, containing the deployed
/// version and build number.
const String kWebVersionManifest = 'version.json';

/// The platforms an installable artifact is published for. Web updates itself
/// through its service worker, so it is deliberately absent here.
enum UpdateTarget { windows, macos, linux, android }

/// Release asset that should be offered for each target. These names are fixed
/// in .github/workflows/release-desktop.yml precisely so the "latest" download
/// URLs stay stable.
const Map<UpdateTarget, String> kTargetAssets = {
  UpdateTarget.windows: 'songs-of-the-church-windows-setup.exe',
  UpdateTarget.macos: 'songs-of-the-church-macos.dmg',
  UpdateTarget.linux: 'songs-of-the-church-x86_64.AppImage',
  UpdateTarget.android: 'songs-of-the-church.apk',
};

String downloadUrlFor(UpdateTarget target) =>
    'https://github.com/$kRepoOwner/$kRepoName/releases/latest/download/'
    '${kTargetAssets[target]}';

/// Which artifact the running build should offer, or null on web.
UpdateTarget? currentTarget() {
  if (kIsWeb) return null;
  if (Platform.isWindows) return UpdateTarget.windows;
  if (Platform.isMacOS) return UpdateTarget.macos;
  if (Platform.isLinux) return UpdateTarget.linux;
  if (Platform.isAndroid) return UpdateTarget.android;
  return null; // iOS ships through the App Store, not GitHub releases.
}

/// Compares dotted numeric versions, ignoring a leading "v" and any
/// pre-release suffix. Returns <0, 0 or >0 like [Comparable.compareTo].
///
/// Missing components count as zero, so "1.2" and "1.2.0" are equal.
int compareVersions(String a, String b) {
  List<int> parts(String v) {
    final cleaned = v.trim().replaceFirst(RegExp(r'^[vV]'), '');
    // Drop any -beta / +build suffix before splitting.
    final core = cleaned.split(RegExp(r'[-+]')).first;
    return core
        .split('.')
        .map((p) => int.tryParse(p.trim()) ?? 0)
        .toList(growable: false);
  }

  final pa = parts(a);
  final pb = parts(b);
  for (var i = 0; i < (pa.length > pb.length ? pa.length : pb.length); i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

/// True when [latest] is a strictly newer release than [current].
///
/// An unparseable or empty [current] means this build was not produced by CI,
/// so no update is offered rather than nagging every developer.
bool isNewer({required String current, required String latest}) {
  if (current.trim().isEmpty || latest.trim().isEmpty) return false;
  return compareVersions(latest, current) > 0;
}

@immutable
class AppUpdate {
  /// Version of the newest release, e.g. "1.0.4".
  final String version;

  /// Direct link to the artifact for this platform, or the release page when
  /// there is no installable artifact (web).
  final String downloadUrl;

  const AppUpdate({required this.version, required this.downloadUrl});
}

/// Looks up the newest published release.
///
/// Returns null when already current, when the version is unknown, or when the
/// network is unavailable — this app is offline-first, so a failed check must
/// never surface as an error.
Future<AppUpdate?> fetchUpdate({
  http.Client? client,
  String currentVersion = kAppVersion,
  String currentBuild = kAppBuild,
  UpdateTarget? target,
  bool? isWeb,
}) async {
  final onWeb = isWeb ?? kIsWeb;
  final http.Client c = client ?? http.Client();
  try {
    return onWeb
        ? await _fetchWebUpdate(c, currentBuild)
        : await _fetchReleaseUpdate(c, currentVersion, target);
  } catch (_) {
    // Offline, rate-limited, malformed payload — all non-events.
    return null;
  } finally {
    if (client == null) c.close();
  }
}

/// Native path: ask GitHub for the newest published release.
Future<AppUpdate?> _fetchReleaseUpdate(
  http.Client c,
  String currentVersion,
  UpdateTarget? target,
) async {
  if (currentVersion.trim().isEmpty) return null;

  final res = await c
      .get(Uri.parse(kReleasesApi), headers: const {
        'Accept': 'application/vnd.github+json',
      })
      .timeout(const Duration(seconds: 8));
  if (res.statusCode != 200) return null;

  final body = jsonDecode(res.body);
  if (body is! Map) return null;
  final tag = body['tag_name'];
  if (tag is! String || tag.isEmpty) return null;

  if (!isNewer(current: currentVersion, latest: tag)) return null;

  final t = target ?? currentTarget();
  return AppUpdate(
    version: tag.replaceFirst(RegExp(r'^[vV]'), ''),
    downloadUrl: t == null ? kReleasesPage : downloadUrlFor(t),
  );
}

/// Web path: the service worker has usually already fetched the new build, so
/// a reload is the entire update. Detect that by comparing the deployed
/// version.json against what this bundle was compiled with.
///
/// The cache-busting query keeps the service worker from answering with the
/// very copy we are trying to compare against.
Future<AppUpdate?> _fetchWebUpdate(http.Client c, String currentBuild) async {
  if (currentBuild.trim().isEmpty) return null;

  // Resolve against the document base so this is correct under the
  // --base-href the Pages build uses.
  final url = Uri.base.resolve(kWebVersionManifest).replace(
      queryParameters: {'ts': '${DateTime.now().millisecondsSinceEpoch}'});
  final res = await c.get(url, headers: const {
    'Cache-Control': 'no-cache',
  }).timeout(const Duration(seconds: 8));
  if (res.statusCode != 200) return null;

  final body = jsonDecode(res.body);
  if (body is! Map) return null;

  final deployedBuild = body['build_number']?.toString() ?? '';
  if (deployedBuild.isEmpty || deployedBuild == currentBuild.trim()) return null;

  final deployedVersion = body['version']?.toString() ?? '';
  return AppUpdate(
    version: deployedVersion.isEmpty ? deployedBuild : deployedVersion,
    downloadUrl: kReleasesPage,
  );
}
