import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/library_controller.dart';
import '../models/song.dart';
import 'song_detail_screen.dart';
import 'song_edit_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Song library')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('New song'),
      ),
      body: Consumer<LibraryController>(
        builder: (BuildContext context, LibraryController library, _) {
          if (library.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<Song> songs = library.songs;
          if (songs.isEmpty) {
            return const _EmptyLibrary();
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: songs.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              final Song song = songs[index];
              return ListTile(
                leading: const Icon(Icons.music_note_outlined),
                title: Text(song.title),
                subtitle: Text(
                  <String>[
                    if (song.author.isNotEmpty) song.author,
                    if (song.songKey.isNotEmpty) 'Key ${song.songKey}',
                    '${song.sections.length} sections',
                  ].join(' • '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SongDetailScreen(songId: song.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _edit(BuildContext context, Song? song) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SongEditScreen(song: song),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.library_music_outlined,
                size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No songs yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tap "New song" to add your first one.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
