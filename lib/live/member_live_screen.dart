import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../ui_kit.dart';
import 'client.dart';
import 'live_controller.dart';
import 'live_snapshot.dart';
import 'live_sync.dart';

/// Full-screen view a member sees after joining.
///
/// The member holds the whole hymnal, so rather than being limited to the one
/// block of text the leader happens to be showing, they can read in whichever
/// mode they prefer. Either way the leader's position drives what is
/// highlighted, so a scrolling member and a tapping leader stay together.
class MemberLiveScreen extends StatefulWidget {
  const MemberLiveScreen({super.key});

  @override
  State<MemberLiveScreen> createState() => _MemberLiveScreenState();
}

class _MemberLiveScreenState extends State<MemberLiveScreen> {
  /// The member's own reading mode, independent of the leader's.
  String _mode = 'tap';

  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _partKeys = <GlobalKey>[];
  int _lastScrolledTo = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  ReaderPalette get _p => context.read<AppState>().theme == AppThemeMode.dark
      ? ReaderPalette.dark
      : ReaderPalette.light;

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveSessionController>();
    final p = _p;
    final snap = live.memberSnapshot;

    // The song as the member has it, which is what lets them read freely.
    final Song? song = snap == null
        ? null
        : songForSnapshot(snap, context.read<AppState>().book.songs);
    final List<SongPart> parts = song?.buildParts() ?? const <SongPart>[];
    final int liveIndex =
        (snap == null || parts.isEmpty) ? -1 : resolveSnapshotPartIndex(snap, parts);

    if (_mode == 'scroll' && liveIndex >= 0) {
      _scheduleScrollTo(liveIndex, parts.length);
    }

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
              _header(context, p, live, snap, canRead: parts.isNotEmpty),
              Expanded(child: _content(context, p, live, snap, parts, liveIndex)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Following the leader while scrolling ──

  void _scheduleScrollTo(int index, int total) {
    if (index == _lastScrolledTo) return;
    _lastScrolledTo = index;
    while (_partKeys.length < total) {
      _partKeys.add(GlobalKey());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index >= _partKeys.length) return;
      final BuildContext? ctx = _partKeys[index].currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.15,
      );
    });
  }

  // ── Chrome ──

  Widget _header(BuildContext context, ReaderPalette p,
      LiveSessionController live, LiveSnapshot? snap,
      {required bool canRead}) {
    final leader =
        snap?.leaderName.isNotEmpty == true ? snap!.leaderName : 'Leader';
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
                        color: p.text2,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          // Offered only when the member actually has the song to read.
          if (canRead)
            Pressable(
              onTap: () {
                Haptics.light();
                setState(() {
                  _mode = _mode == 'scroll' ? 'tap' : 'scroll';
                  _lastScrolledTo = -1;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: p.btnBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_mode == 'scroll' ? Icons.view_agenda_outlined : Icons.notes,
                        size: 14, color: p.text2),
                    const SizedBox(width: 5),
                    Text(_mode == 'scroll' ? 'Tap' : 'Scroll',
                        style: TextStyle(
                            color: p.text2,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 8),
          Icon(Icons.people_alt_outlined, size: 16, color: p.text3),
          const SizedBox(width: 4),
          Text('${snap?.memberCount ?? 1}',
              style: TextStyle(
                  color: p.text3, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Content ──

  Widget _content(BuildContext context, ReaderPalette p,
      LiveSessionController live, LiveSnapshot? snap, List<SongPart> parts,
      int liveIndex) {
    if (live.memberStatus == LiveClientStatus.connecting && snap == null) {
      return _centered(p,
          spinner: true, text: live.memberMessage ?? 'Connecting…');
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

    if (_mode == 'scroll' && parts.isNotEmpty) {
      return _scrollBody(p, snap, parts, liveIndex);
    }
    return _tapBody(p, snap, parts, liveIndex);
  }

  /// One part at a time, following whatever the leader is on.
  Widget _tapBody(
      ReaderPalette p, LiveSnapshot snap, List<SongPart> parts, int liveIndex) {
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
                      style: TextStyle(
                          color: p.accent,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      );
    }

    // Prefer the member's own copy so the text matches what they'd read
    // themselves; fall back to whatever the leader sent.
    final SongPart? part =
        (liveIndex >= 0 && liveIndex < parts.length) ? parts[liveIndex] : null;
    final String label = part?.label ?? snap.partLabel;
    final String text = part?.text ?? snap.partText;
    final bool isChorus = part?.isChorus ?? snap.isChorus;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(0, 0.05), end: Offset.zero)
              .animate(animation),
          child: child,
        ),
      ),
      child: Center(
        // Animate when the leader moves to a different part, not on every
        // publish — member-count updates re-send the same slide.
        key: ValueKey<String>(
            '${snap.songId}:${snap.isTitle ? 'title' : label}'),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isChorus ? 'CHORUS' : label.toUpperCase(),
                style: TextStyle(
                  color: isChorus ? p.green : p.text3,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                text,
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
                      style: TextStyle(
                          color: p.text3,
                          fontSize: 14,
                          fontStyle: FontStyle.italic)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The whole song, with the leader's current part highlighted and kept in
  /// view. Members can still scroll freely; the next move by the leader pulls
  /// them back.
  Widget _scrollBody(
      ReaderPalette p, LiveSnapshot snap, List<SongPart> parts, int liveIndex) {
    while (_partKeys.length < parts.length) {
      _partKeys.add(GlobalKey());
    }
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 48),
      children: [
        if (snap.songTitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              children: [
                Text(snap.songTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kDisplaySerif,
                      color: p.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    )),
                if (snap.songSubtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(snap.songSubtitle,
                        style: TextStyle(color: p.text3, fontSize: 13)),
                  ),
              ],
            ),
          ),
        for (int i = 0; i < parts.length; i++)
          KeyedSubtree(
            key: _partKeys[i],
            child: _scrollPart(p, parts[i], isLive: i == liveIndex),
          ),
      ],
    );
  }

  Widget _scrollPart(ReaderPalette p, SongPart part, {required bool isLive}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: isLive
            ? p.accent.withValues(alpha: 0.10)
            : (part.isChorus ? p.chorusBg : Colors.transparent),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLive
              ? p.accent.withValues(alpha: 0.55)
              : (part.isChorus ? p.chorusBorder : Colors.transparent),
          width: isLive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                part.isChorus ? 'CHORUS' : part.label.toUpperCase(),
                style: TextStyle(
                  color: isLive
                      ? p.accent
                      : (part.isChorus ? p.green : p.text3),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),
              if (isLive) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: p.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('NOW',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            part.text,
            style: TextStyle(
              fontFamily: kDisplaySerif,
              color: p.text,
              fontSize: 19,
              height: 1.5,
            ),
          ),
        ],
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
