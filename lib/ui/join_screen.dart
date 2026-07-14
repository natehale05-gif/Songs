import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/member_controller.dart';
import '../models/connection_info.dart';
import '../services/live_client.dart';
import 'member_view.dart';
import 'scan_screen.dart';

class JoinScreen extends StatelessWidget {
  const JoinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MemberController>(
      create: (_) => MemberController(),
      child: const _JoinBody(),
    );
  }
}

class _JoinBody extends StatelessWidget {
  const _JoinBody();

  @override
  Widget build(BuildContext context) {
    final MemberController member = context.watch<MemberController>();
    final bool joined = member.isJoined && member.snapshot != null ||
        member.status == LiveClientStatus.joined;

    return PopScope(
      canPop: member.status == LiveClientStatus.idle,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) {
          await member.leave();
          if (context.mounted) Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(joined ? 'Following' : 'Join a session'),
          actions: <Widget>[
            if (joined)
              TextButton.icon(
                onPressed: () => member.leave(),
                icon: const Icon(Icons.logout),
                label: const Text('Leave'),
              ),
          ],
        ),
        body: joined ? const MemberView() : const _JoinForm(),
      ),
    );
  }
}

class _JoinForm extends StatefulWidget {
  const _JoinForm();

  @override
  State<_JoinForm> createState() => _JoinFormState();
}

class _JoinFormState extends State<_JoinForm> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _memberName =>
      _name.text.trim().isEmpty ? 'Member' : _name.text.trim();

  Future<void> _joinByCode(MemberController member) async {
    FocusScope.of(context).unfocus();
    await member.joinWithCode(_code.text, memberName: _memberName);
  }

  Future<void> _scan(MemberController member) async {
    final ConnectionInfo? info = await Navigator.of(context).push(
      MaterialPageRoute<ConnectionInfo>(builder: (_) => const ScanScreen()),
    );
    if (info != null && mounted) {
      await member.joinWithConnection(info, memberName: _memberName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MemberController member = context.watch<MemberController>();
    final ThemeData theme = Theme.of(context);
    final bool connecting = member.isConnecting;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        const SizedBox(height: 8),
        Text(
          kIsWeb
              ? 'Join your leader\'s session to follow the lyrics live. In the '
                  'web preview, open Songs in another tab of this browser, '
                  'start leading there, then enter that join code here.'
              : 'Join your leader\'s session to follow the lyrics live. Make '
                  'sure you are on the same WiFi network (or their hotspot).',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Your name (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Join code',
            hintText: 'e.g. K7QP24',
            prefixIcon: Icon(Icons.tag),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: connecting ? null : () => _joinByCode(member),
          icon: connecting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login),
          label: Text(connecting ? 'Connecting...' : 'Join with code'),
        ),
        if (!kIsWeb) ...<Widget>[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: connecting ? null : () => _scan(member),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan QR code'),
          ),
        ],
        if (member.statusMessage != null) ...<Widget>[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: member.status == LiveClientStatus.connecting
                  ? theme.colorScheme.surfaceContainerHighest
                  : theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              member.statusMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: member.status == LiveClientStatus.connecting
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
