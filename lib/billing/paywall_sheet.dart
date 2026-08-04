import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../ui_kit.dart';
import 'billing_config.dart';

/// Which feature sent the user here, so the sheet can lead with that rather
/// than a generic pitch.
enum PlusFeature { setList, presentation, favorites, onlineGroups }

String _pitchFor(PlusFeature feature) {
  switch (feature) {
    case PlusFeature.setList:
      return 'Set lists are part of Plus.';
    case PlusFeature.presentation:
      return 'Presentation mode is part of Plus.';
    case PlusFeature.favorites:
      return 'Favorites are part of Plus.';
    case PlusFeature.onlineGroups:
      return 'Online small groups are part of Plus.';
  }
}

/// Shows the paywall. Returns true if the user came away entitled.
Future<bool> showPaywall(
  BuildContext context,
  AppPalette palette, {
  required PlusFeature feature,
  required Future<bool> Function() onSubscribe,
  required Future<bool> Function() onRestore,
  PlusOffer offer = const PlusOffer.fallback(),
}) async {
  final bool? result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: palette.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PaywallSheet(
      p: palette,
      feature: feature,
      offer: offer,
      onSubscribe: onSubscribe,
      onRestore: onRestore,
    ),
  );
  return result ?? false;
}

class _PaywallSheet extends StatefulWidget {
  const _PaywallSheet({
    required this.p,
    required this.feature,
    required this.offer,
    required this.onSubscribe,
    required this.onRestore,
  });

  final AppPalette p;
  final PlusFeature feature;
  final PlusOffer offer;
  final Future<bool> Function() onSubscribe;
  final Future<bool> Function() onRestore;

  @override
  State<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<_PaywallSheet> {
  bool _busy = false;
  String? _error;

  AppPalette get p => widget.p;

  Future<void> _run(Future<bool> Function() action, String failure) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    bool ok = false;
    try {
      ok = await action();
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
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
              _pitchFor(widget.feature),
              style: TextStyle(
                fontFamily: kDisplaySerif,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: p.label,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'All 715 songs, search and the reader stay free, always. '
              'Plus adds the tools for leading:',
              style: TextStyle(fontSize: 15, height: 1.4, color: p.label2),
            ),
            const SizedBox(height: 14),
            _perk('Set lists', 'Build an order of service, or generate one.'),
            _perk('Presentation mode',
                'Full-screen verses that flow across a whole set.'),
            _perk('Favorites', 'Keep the songs your congregation knows.'),
            _perk('Online small groups',
                'Lead over cellular, across any distance.'),
            const SizedBox(height: 18),

            // Name, period and price together — Apple requires all three
            // where the purchase happens, not just in the store listing.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: p.fill1,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kPlusName,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: p.label),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.offer.headline,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: p.label),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Renews yearly. Cancel any time.',
                    style: TextStyle(fontSize: 13, color: p.label3),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style:
                      TextStyle(fontSize: 13, height: 1.35, color: p.label2),
                ),
              ),
            ],

            const SizedBox(height: 14),
            _primary(
              _busy ? 'Working…' : 'Subscribe',
              onTap: _busy
                  ? null
                  : () => _run(widget.onSubscribe,
                      'That purchase did not go through. Nothing was charged.'),
            ),
            const SizedBox(height: 8),

            // Not optional: an app that sells a subscription and offers no way
            // to restore one is rejected, and it is the first thing a
            // reinstalling subscriber looks for.
            Center(
              child: Pressable(
                onTap: _busy
                    ? null
                    : () => _run(widget.onRestore,
                        'No previous subscription was found for this account.'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 12),
                  child: Text(
                    'Restore Purchases',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: p.navy),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),
            Text(
              kRenewalDisclosure,
              style: TextStyle(fontSize: 11.5, height: 1.4, color: p.label3),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _link('Terms of Use', kTermsUrl),
                Text(' · ', style: TextStyle(color: p.label3, fontSize: 12)),
                _link('Privacy Policy', kPrivacyUrl),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _perk(String title, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle, size: 17, color: p.navy),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, height: 1.35, color: p.label2),
                children: <InlineSpan>[
                  TextSpan(
                    text: '$title — ',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: p.label),
                  ),
                  TextSpan(text: detail),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primary(String label, {VoidCallback? onTap}) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: onTap == null ? p.navy.withValues(alpha: 0.5) : p.navy,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
                color: p.navyText, fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _link(String label, String url) {
    return Pressable(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: p.navy,
          decoration: TextDecoration.underline,
          decorationColor: p.navy,
        ),
      ),
    );
  }
}
