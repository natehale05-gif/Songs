import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../ui_kit.dart';
import 'update_service.dart';

/// Key holding the newest version the user has already dismissed, so a
/// declined update stays declined until a later one ships.
const String _kDismissedKey = 'update_dismissed_version';

/// A slim bar offering the newest release, shown only when one exists.
///
/// Renders nothing at all in the common case, so it can sit unconditionally at
/// the top of a screen.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key, required this.palette, this.checkOverride});

  final AppPalette palette;

  /// Injection point for tests; defaults to the real GitHub lookup.
  final Future<AppUpdate?> Function()? checkOverride;

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  AppUpdate? _update;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final update = await (widget.checkOverride ?? fetchUpdate)();
    if (update == null || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_kDismissedKey) == update.version) return;
    if (!mounted) return;

    setState(() => _update = update);
  }

  Future<void> _dismiss() async {
    final version = _update?.version;
    setState(() => _update = null);
    if (version == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDismissedKey, version);
  }

  Future<void> _install() async {
    final update = _update;
    if (update == null) return;
    Haptics.light();

    // The web build updates itself through its service worker: the new assets
    // are already cached, so reloading is the whole update.
    if (kIsWeb) {
      await launchUrl(Uri.base, webOnlyWindowName: '_self');
      return;
    }
    await launchUrl(
      Uri.parse(update.downloadUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final update = _update;
    if (update == null) return const SizedBox.shrink();

    final p = widget.palette;
    final actionLabel = kIsWeb ? 'Reload' : 'Update';

    return Container(
      color: p.navy,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Icon(Icons.arrow_circle_down, size: 20, color: p.navyText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              kIsWeb
                  ? 'Version ${update.version} is ready'
                  : 'Version ${update.version} is available',
              style: TextStyle(
                color: p.navyText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Pressable(
            onTap: _install,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: p.navyText.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                actionLabel,
                style: TextStyle(
                  color: p.navyText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _dismiss,
            icon: Icon(Icons.close, size: 18, color: p.navyText),
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
