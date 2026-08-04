import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_state.dart';
import '../billing/paywall_sheet.dart';
import '../billing/plus_gate.dart';
import '../theme.dart';
import '../ui_kit.dart';
import 'connection_info.dart';
import 'live_controller.dart';
import 'member_live_screen.dart';
import 'scan_screen.dart';

/// Presents the Apple-style small-group sheet that slides up from the bottom.
Future<void> showLiveSheet(BuildContext context) {
  final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
  final p = context.read<AppState>().theme == AppThemeMode.dark
      ? AppPalette.dark
      : AppPalette.light;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LiveSheet(palette: p, pageNavigator: navigator),
  );
}

class _LiveSheet extends StatefulWidget {
  const _LiveSheet({required this.palette, required this.pageNavigator});

  final AppPalette palette;
  final NavigatorState pageNavigator;

  @override
  State<_LiveSheet> createState() => _LiveSheetState();
}

enum _Mode { home, join }

class _LiveSheetState extends State<_LiveSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _code = TextEditingController();
  _Mode _mode = _Mode.home;

  /// Chosen transport. Online is the better default when it is available: it
  /// covers the same-WiFi case too, and adds cellular and long distance.
  LiveMode? _transport;

  LiveMode _transportFor(LiveSessionController live) =>
      _transport ??= (live.onlineAvailable && hasPlus(context))
          ? LiveMode.online
          : LiveMode.lan;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  AppPalette get p => widget.palette;

  String get _memberName =>
      _name.text.trim().isEmpty ? 'Member' : _name.text.trim();

  void _openMemberView() {
    Navigator.of(context).pop();
    widget.pageNavigator.push(
      appPage<void>((_) => const MemberLiveScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 10, 20, 20 + MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                    color: p.separator, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 16),
            Consumer<LiveSessionController>(
              builder: (context, live, _) {
                if (live.isLeader) return _leaderPanel(live);
                if (live.isMember) return _memberPanel(live);
                return _mode == _Mode.home ? _homePanel(live) : _joinPanel(live);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Home ──
  Widget _homePanel(LiveSessionController live) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('Small Group'),
        const SizedBox(height: 6),
        Text(
          _blurb(live),
          style: TextStyle(color: p.label3, fontSize: 13.5, height: 1.35),
        ),
        const SizedBox(height: 16),
        _transportPicker(live),
        const SizedBox(height: 14),
        _field(_name, 'Your name', TextCapitalization.words),
        const SizedBox(height: 14),
        _primaryButton(
          live.busy ? 'Starting…' : 'Lead a group',
          icon: Icons.cast_connected,
          onTap: live.busy
              ? null
              : () => live.startLeading(
                    leaderName: _name.text,
                    mode: _transportFor(live),
                  ),
        ),
        const SizedBox(height: 10),
        _secondaryButton('Join a group',
            icon: Icons.group_add_outlined,
            onTap: () => setState(() => _mode = _Mode.join)),
        if (live.startError != null) ...[
          const SizedBox(height: 12),
          _errorNote(live.startError!),
        ],
      ],
    );
  }

  /// Leading can fail before there is any session screen to report it on —
  /// the relay may be unreachable, or not configured at all. Without this the
  /// button simply appeared to do nothing.
  Widget _errorNote(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 17, color: Color(0xFFFF3B30)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: p.label2, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  // ── Join ──
  Widget _joinPanel(LiveSessionController live) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Pressable(
              onTap: () => setState(() => _mode = _Mode.home),
              child: Icon(Icons.chevron_left, color: p.accent, size: 26),
            ),
            const SizedBox(width: 4),
            _title('Join a group'),
          ],
        ),
        const SizedBox(height: 14),
        _transportPicker(live),
        const SizedBox(height: 14),
        _field(_name, 'Your name (optional)', TextCapitalization.words),
        const SizedBox(height: 12),
        _field(_code, 'Join code (e.g. K7QP24)', TextCapitalization.characters),
        const SizedBox(height: 16),
        _primaryButton('Join with code',
            icon: Icons.login,
            onTap: () {
              live.joinByCode(
                _code.text,
                memberName: _memberName,
                mode: _transportFor(live),
              );
              _openMemberView();
            }),
        if (!kIsWeb) ...[
          const SizedBox(height: 10),
          _secondaryButton('Scan QR code',
              icon: Icons.qr_code_scanner, onTap: () => _scan(live)),
        ],
      ],
    );
  }

  Future<void> _scan(LiveSessionController live) async {
    final ConnectionInfo? info = await widget.pageNavigator.push<ConnectionInfo>(
      appPage<ConnectionInfo>((_) => const ScanScreen()),
    );
    if (info != null) {
      live.joinByConnection(info, memberName: _memberName);
      _openMemberView();
    }
  }

  // ── Leader ──
  Widget _leaderPanel(LiveSessionController live) {
    final conn = live.connection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _title("You're leading")),
        const SizedBox(height: 8),
        // Which transport is live decides what the leader should tell people,
        // so it is worth stating rather than leaving them to guess.
        Center(child: _modeBadge(live.isOnlineSession)),
        const SizedBox(height: 14),
        if (conn != null)
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: QrImageView(
                data: conn.toPayload(),
                version: QrVersions.auto,
                size: 180,
              ),
            ),
          ),
        const SizedBox(height: 16),
        Center(child: Text('JOIN CODE', style: _labelStyle())),
        const SizedBox(height: 4),
        Center(
          // SelectableText keeps the code copyable, but it publishes no label
          // to the accessibility tree — so the one string a leader has to read
          // out was the one string a screen reader could not see. Spell it out
          // character by character; read as a word it comes out as noise.
          child: Semantics(
            container: true,
            label: conn == null
                ? 'Join code not ready yet'
                : 'Join code ${conn.code.split('').join(' ')}',
            excludeSemantics: true,
            child: SelectableText(
              conn?.code ?? '------',
              style: TextStyle(
                color: p.label,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
              color: p.fill1, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(Icons.people_alt_outlined, size: 18, color: p.label2),
              const SizedBox(width: 8),
              Text(
                  '${live.memberCount} ${live.memberCount == 1 ? 'member' : 'members'} connected',
                  style: TextStyle(
                      color: p.label2, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Open any song or start a set list — the verse you\'re on shows on '
          'everyone\'s screen. Close this sheet to keep leading.',
          style: TextStyle(color: p.label3, fontSize: 13, height: 1.35),
        ),
        const SizedBox(height: 16),
        _secondaryButton(
          live.isBlanked ? 'Show screens' : 'Hide screens (blank)',
          icon: live.isBlanked ? Icons.visibility : Icons.visibility_off,
          onTap: () => live.setBlank(!live.isBlanked),
        ),
        const SizedBox(height: 10),
        _dangerButton('End session', onTap: () => live.stopLeading()),
      ],
    );
  }

  // ── Member ──
  Widget _memberPanel(LiveSessionController live) {
    final leader = live.memberSnapshot?.leaderName ?? 'the leader';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _title('In a group')),
        const SizedBox(height: 12),
        Text('You\'re following $leader. Your screen mirrors the current verse.',
            style: TextStyle(color: p.label3, fontSize: 13.5, height: 1.35)),
        const SizedBox(height: 16),
        _primaryButton('Open live view',
            icon: Icons.visibility, onTap: _openMemberView),
        const SizedBox(height: 10),
        _dangerButton('Leave group', onTap: () => live.leave()),
      ],
    );
  }

  /// Small pill naming the transport carrying this session.
  Widget _modeBadge(bool online) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: p.fill1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(online ? Icons.public : Icons.wifi, size: 14, color: p.label2),
          const SizedBox(width: 6),
          Text(
            online ? 'Online — anyone with internet' : 'Same WiFi only',
            style: TextStyle(
                color: p.label2, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── Building blocks ──
  /// Explains what the currently selected transport actually does, since the
  /// difference (same WiFi vs anywhere) is the whole point of the choice.
  String _blurb(LiveSessionController live) {
    if (_transportFor(live) == LiveMode.online) {
      return 'Everyone follows the current verse live. Online works over '
          'cellular and across any distance — you just all need internet.';
    }
    if (kIsWeb) {
      return 'Everyone follows the current verse live. Without a relay, the '
          'web build can only sync between tabs of this browser.';
    }
    return 'Everyone follows the current verse live. Same WiFi needs no '
        'internet at all — just one network or a hotspot.';
  }

  /// Two-way choice between the LAN transport and the relay.
  Widget _transportPicker(LiveSessionController live) {
    final LiveMode selected = _transportFor(live);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: p.fill1,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _transportOption(
                label: 'Same WiFi',
                icon: Icons.wifi,
                selected: selected == LiveMode.lan,
                onTap: () => setState(() => _transport = LiveMode.lan),
              ),
              _transportOption(
                label: 'Online',
                icon: Icons.public,
                selected: selected == LiveMode.online,
                enabled: live.onlineAvailable,
                // Online is the one live transport with a running cost — it
                // needs the relay — so it sits behind Plus alongside the other
                // leader tools. Same WiFi stays free and always will.
                onTap: live.onlineAvailable
                    ? () async {
                        if (!await requirePlus(
                            context, p, PlusFeature.onlineGroups)) {
                          return;
                        }
                        if (!mounted) return;
                        setState(() => _transport = LiveMode.online);
                      }
                    : null,
              ),
            ],
          ),
        ),
        if (!live.onlineAvailable) ...[
          const SizedBox(height: 8),
          Text(
            'Online needs a relay. This build has none configured — '
            'see relay/README.md.',
            style: TextStyle(color: p.label3, fontSize: 12, height: 1.3),
          ),
        ],
      ],
    );
  }

  Widget _transportOption({
    required String label,
    required IconData icon,
    required bool selected,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    final Color fg = !enabled
        ? p.label4
        : selected
            ? p.navyText
            : p.label2;
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? p.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                    color: fg, fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _title(String text) => Text(text,
      style: TextStyle(
          color: p.label,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: kDisplaySerif));

  TextStyle _labelStyle() => TextStyle(
      color: p.label3,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8);

  Widget _field(TextEditingController c, String label, TextCapitalization cap) {
    return TextField(
      controller: c,
      textCapitalization: cap,
      autocorrect: false,
      style: TextStyle(color: p.label, fontSize: 16),
      cursorColor: p.accent,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: p.label3),
        filled: true,
        fillColor: p.fill1,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _primaryButton(String label, {IconData? icon, VoidCallback? onTap}) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap == null
            ? null
            : () {
                Haptics.light();
                onTap();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: p.navy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: p.navy.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white70,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: Icon(icon, size: 20),
        label: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _secondaryButton(String label,
      {IconData? icon, VoidCallback? onTap}) {
    return SizedBox(
      height: 52,
      child: TextButton.icon(
        onPressed: onTap == null
            ? null
            : () {
                Haptics.light();
                onTap();
              },
        style: TextButton.styleFrom(
          backgroundColor: p.fill1,
          foregroundColor: p.label,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: Icon(icon, size: 20),
        label: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _dangerButton(String label, {VoidCallback? onTap}) {
    return SizedBox(
      height: 50,
      child: TextButton(
        onPressed: onTap == null
            ? null
            : () {
                Haptics.medium();
                onTap();
              },
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFFF3B30),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
