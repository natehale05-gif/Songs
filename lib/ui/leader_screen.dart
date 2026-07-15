import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/leader_controller.dart';
import '../controllers/library_controller.dart';
import '../models/song.dart';
import 'widgets/lyrics_view.dart';
import 'widgets/qr_panel.dart';

class LeaderScreen extends StatelessWidget {
  const LeaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LeaderController>(
      create: (_) => LeaderController(),
      child: const _LeaderBody(),
    );
  }
}

class _LeaderBody extends StatelessWidget {
  const _LeaderBody();

  @override
  Widget build(BuildContext context) {
    final LeaderController leader = context.watch<LeaderController>();
    return PopScope(
      canPop: !leader.isLive,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop && leader.isLive) {
          await leader.endSession();
          if (context.mounted) Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(leader.isLive ? 'Leading' : 'Lead a session'),
          actions: <Widget>[
            if (leader.isLive)
              TextButton.icon(
                onPressed: () => leader.endSession(),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('End'),
              ),
          ],
        ),
        body: leader.isLive
            ? const _LiveLeader()
            : const _StartSessionForm(),
      ),
    );
  }
}

class _StartSessionForm extends StatefulWidget {
  const _StartSessionForm();

  @override
  State<_StartSessionForm> createState() => _StartSessionFormState();
}

class _StartSessionFormState extends State<_StartSessionForm> {
  final TextEditingController _name =
      TextEditingController(text: 'Leader');
  final TextEditingController _title =
      TextEditingController(text: 'Live Session');

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LeaderController leader = context.watch<LeaderController>();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        const SizedBox(height: 8),
        Text(
          kIsWeb
              ? 'Start a live session, then open Songs in another browser tab '
                  'and join with the code to see members follow along. (On '
                  'phones this works offline over WiFi between real devices.)'
              : 'Start a live session and your group can follow along on their '
                  'own devices — no internet required, just the same WiFi or a '
                  'hotspot.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _title,
          decoration: const InputDecoration(
            labelText: 'Session name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Your name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: leader.busy
              ? null
              : () => leader.startSession(
                    leaderName: _name.text,
                    sessionTitle: _title.text,
                  ),
          icon: leader.busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow),
          label: Text(leader.busy ? 'Starting...' : 'Start session'),
        ),
      ],
    );
  }
}

class _LiveLeader extends StatelessWidget {
  const _LiveLeader();

  @override
  Widget build(BuildContext context) {
    final LeaderController leader = context.watch<LeaderController>();
    final ThemeData theme = Theme.of(context);

    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          color: theme.colorScheme.primaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              Icon(Icons.qr_code_2,
                  color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Join code',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      )),
                  Text(
                    leader.connection?.code ?? '------',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Chip(
                avatar: const Icon(Icons.people_alt_outlined, size: 18),
                label: Text('${leader.memberCount}'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () => _showQr(context),
                icon: const Icon(Icons.qr_code),
                label: const Text('Show QR'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            color: theme.colorScheme.surface,
            child: LyricsView(
              song: leader.currentSong,
              sectionIndex: leader.sectionIndex,
              blanked: leader.blanked,
            ),
          ),
        ),
        _sectionChips(context, leader),
        _controlBar(context, leader),
      ],
    );
  }

  Widget _sectionChips(BuildContext context, LeaderController leader) {
    final Song? song = leader.currentSong;
    if (song == null || song.sections.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: song.sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final bool selected = index == leader.sectionIndex;
          return ChoiceChip(
            label: Text(song.sections[index].label),
            selected: selected,
            onSelected: (_) => leader.goToSection(index),
          );
        },
      ),
    );
  }

  Widget _controlBar(BuildContext context, LeaderController leader) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickSong(context, leader),
                icon: const Icon(Icons.queue_music),
                label: const Text('Songs'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed:
                  leader.hasPreviousSection ? leader.previousSection : null,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: leader.currentSong == null
                  ? null
                  : leader.toggleBlank,
              isSelected: leader.blanked,
              icon: Icon(leader.blanked
                  ? Icons.visibility_off
                  : Icons.visibility_outlined),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: leader.hasNextSection ? leader.nextSection : null,
              icon: const Icon(Icons.arrow_forward),
            ),
          ],
        ),
      ),
    );
  }

  void _showQr(BuildContext context) {
    final LeaderController leader = context.read<LeaderController>();
    final connection = leader.connection;
    if (connection == null) return;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: QrPanel(connection: connection),
        ),
      ),
    );
  }

  void _pickSong(BuildContext context, LeaderController leader) {
    final LibraryController library = context.read<LibraryController>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        final List<Song> songs = library.songs;
        if (songs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Text('Your library is empty. Add songs first.'),
          );
        }
        return ListView.builder(
          itemCount: songs.length,
          itemBuilder: (BuildContext context, int index) {
            final Song song = songs[index];
            final bool selected = song.id == leader.currentSong?.id;
            return ListTile(
              leading: Icon(selected
                  ? Icons.play_circle
                  : Icons.music_note_outlined),
              title: Text(song.title),
              subtitle: song.author.isEmpty ? null : Text(song.author),
              selected: selected,
              onTap: () {
                leader.selectSong(song);
                Navigator.of(sheetContext).pop();
              },
            );
          },
        );
      },
    );
  }
}
