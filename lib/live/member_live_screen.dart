import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import 'client.dart';
import 'live_controller.dart';
import 'live_snapshot.dart';

/// Full-screen view a member sees after joining: a live mirror of whatever the
/// leader is currently presenting.
class MemberLiveScreen extends StatelessWidget {
  const MemberLiveScreen({super.key});

  ReaderPalette _palette(BuildContext context) =>
      context.read<AppState>().theme == AppThemeMode.dark
          ? ReaderPalette.dark
          : ReaderPalette.light;

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveSessionController>();
    final p = _palette(context);
    final snap = live.memberSnapshot;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          await live.leave();
          if (context.mounted) Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          child: Column(
            children: [
              _header(context, p, live, snap),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.05),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey<String>(_contentKey(live, snap)),
                    child: _body(context, p, live, snap),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, ReaderPalette p,
      LiveSessionController live, LiveSnapshot? snap) {
    final leader = snap?.leaderName.isNotEmpty == true
        ? snap!.leaderName
        : (live.memberSnapshot?.leaderName ?? 'Leader');
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.sep, width: 0.6)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              await live.leave();
              if (context.mounted) Navigator.of(context).maybePop();
            },
            icon: Icon(Icons.close, color: p.accent, size: 24),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Color(0xFFFF3B30), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('LIVE',
                        style: TextStyle(
                            color: p.text3,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                  ],
                ),
                Text('Following $leader',
                    style: TextStyle(
                        color: p.text2, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Icon(Icons.people_alt_outlined, size: 16, color: p.text3),
          const SizedBox(width: 4),
          Text('${snap?.memberCount ?? 1}',
              style: TextStyle(
                  color: p.text3, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// A stable identity for the currently shown content so the AnimatedSwitcher
  /// only animates when the leader actually moves to something new.
  String _contentKey(LiveSessionController live, LiveSnapshot? snap) {
    if (snap == null) return 'status:${live.memberStatus}';
    if (snap.blanked) return 'blanked';
    if (!snap.hasSong) return 'waiting';
    return 'slide:${snap.songId}:${snap.isTitle ? 't' : snap.partLabel}';
  }

  Widget _body(BuildContext context, ReaderPalette p,
      LiveSessionController live, LiveSnapshot? snap) {
    if (live.memberStatus == LiveClientStatus.connecting &&
        snap == null) {
      return _centered(p, spinner: true, text: live.memberMessage ?? 'Connecting…');
    }
    if (live.memberStatus == LiveClientStatus.error ||
        live.memberStatus == LiveClientStatus.rejected) {
      return _centered(p,
          icon: Icons.wifi_off,
          text: live.memberMessage ?? 'Could not connect.');
    }
    if (live.memberStatus == LiveClientStatus.disconnected) {
      return _centered(p,
          icon: Icons.info_outline, text: 'The session has ended.');
    }
    if (snap == null || snap.blanked || !snap.hasSong) {
      return _centered(p,
          icon: Icons.visibility_off_outlined,
          text: 'Waiting for the leader…');
    }

    if (snap.isTitle) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(snap.songTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kDisplaySerif,
                    color: p.text,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  )),
              if (snap.songSubtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(snap.songSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.accent, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              snap.isChorus ? 'CHORUS' : snap.partLabel.toUpperCase(),
              style: TextStyle(
                color: snap.isChorus ? p.green : p.text3,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              snap.partText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kDisplaySerif,
                color: p.text,
                fontSize: 27,
                height: 1.45,
              ),
            ),
            if (snap.songTitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 26),
                child: Text(snap.songTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.text3, fontSize: 14, fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _centered(ReaderPalette p,
      {bool spinner = false, IconData? icon, required String text}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spinner)
              CircularProgressIndicator(color: p.accent)
            else if (icon != null)
              Icon(icon, size: 44, color: p.text3),
            const SizedBox(height: 16),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.text3, fontSize: 15, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
