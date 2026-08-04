import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../ui_kit.dart';
import '../billing/billing_config.dart';
import '../update/update_service.dart';

const String kProjectUrl = 'https://github.com/$kRepoOwner/$kRepoName';
const String kIssuesUrl = '$kProjectUrl/issues';

/// Version this build reports, or null for a build made outside CI (which has
/// no `--dart-define=APP_VERSION` and therefore genuinely does not know).
String? _versionLine() {
  if (kAppVersion.isEmpty) return null;
  return kAppBuild.isEmpty ? kAppVersion : '$kAppVersion ($kAppBuild)';
}

/// About / privacy sheet. Apple expects the privacy policy to be reachable
/// from inside the app, not only from the store listing.
void showAboutSheet(BuildContext context, AppPalette p) {
  showModalBottomSheet(
    context: context,
    backgroundColor: p.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _AboutSheet(p: p),
  );
}

class _AboutSheet extends StatelessWidget {
  const _AboutSheet({required this.p});

  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final String? version = _versionLine();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: p.separator,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Songs of the Church',
            style: TextStyle(
              fontFamily: kDisplaySerif,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: p.label,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            version == null ? 'Development build' : 'Version $version',
            style: TextStyle(fontSize: 14, color: p.label3),
          ),
          const SizedBox(height: 16),
          Text(
            'The whole hymnal is stored in the app, so it works with no '
            'connection at all. All 715 songs are free, there is no '
            'advertising, and nothing you read is tracked.',
            style: TextStyle(fontSize: 15, height: 1.4, color: p.label2),
          ),
          const SizedBox(height: 20),
          _row(p, 'Privacy Policy', kPrivacyUrl),
          _row(p, 'Terms of Use', kTermsUrl),
          _row(p, 'Source Code', kProjectUrl),
          _row(p, 'Report a Problem', kIssuesUrl),
        ],
      ),
    );
  }

  Widget _row(AppPalette p, String label, String url) {
    return Pressable(
      onTap: () {
        Haptics.selection();
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.separator, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500, color: p.label),
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 18, color: p.label3),
          ],
        ),
      ),
    );
  }
}
