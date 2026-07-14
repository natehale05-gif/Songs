import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/library_controller.dart';
import '../models/song.dart';
import '../models/song_section.dart';
import 'song_edit_screen.dart';

class SongDetailScreen extends StatelessWidget {
  const SongDetailScreen({super.key, required this.songId});

  final String songId;

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryController>(
      builder: (BuildContext context, LibraryController library, _) {
        final Song? song = library.byId(songId);
        if (song == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Song not found')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(song.title),
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SongEditScreen(song: song),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, library, song),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              if (song.author.isNotEmpty || song.songKey.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    <String>[
                      if (song.author.isNotEmpty) song.author,
                      if (song.songKey.isNotEmpty) 'Key ${song.songKey}',
                    ].join(' • '),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              for (final SongSection section in song.sections)
                _SectionCard(section: section),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    LibraryController library,
    Song song,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete song?'),
        content: Text('"${song.title}" will be removed from your library.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await library.delete(song.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});

  final SongSection section;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              section.label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            for (final String line in section.lines)
              Text(line, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
