import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/library_controller.dart';
import '../models/song.dart';
import '../models/song_section.dart';

class SongEditScreen extends StatefulWidget {
  const SongEditScreen({super.key, this.song});

  final Song? song;

  @override
  State<SongEditScreen> createState() => _SongEditScreenState();
}

class _SectionDraft {
  _SectionDraft({required this.label, required this.lines});
  final TextEditingController label;
  final TextEditingController lines;

  void dispose() {
    label.dispose();
    lines.dispose();
  }
}

class _SongEditScreenState extends State<SongEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _author;
  late final TextEditingController _key;
  final List<_SectionDraft> _sections = <_SectionDraft>[];

  bool get _isNew => widget.song == null;

  @override
  void initState() {
    super.initState();
    final Song? song = widget.song;
    _title = TextEditingController(text: song?.title ?? '');
    _author = TextEditingController(text: song?.author ?? '');
    _key = TextEditingController(text: song?.songKey ?? '');
    if (song != null && song.sections.isNotEmpty) {
      for (final SongSection section in song.sections) {
        _sections.add(_SectionDraft(
          label: TextEditingController(text: section.label),
          lines: TextEditingController(text: section.lines.join('\n')),
        ));
      }
    } else {
      _addSection(initialLabel: 'Verse 1');
    }
  }

  void _addSection({String initialLabel = ''}) {
    setState(() {
      _sections.add(_SectionDraft(
        label: TextEditingController(text: initialLabel),
        lines: TextEditingController(),
      ));
    });
  }

  void _removeSection(int index) {
    setState(() {
      _sections.removeAt(index).dispose();
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _key.dispose();
    for (final _SectionDraft draft in _sections) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final List<SongSection> sections = <SongSection>[];
    for (final _SectionDraft draft in _sections) {
      final List<String> lines = draft.lines.text
          .split('\n')
          .map((String l) => l.trimRight())
          .where((String l) => l.trim().isNotEmpty)
          .toList();
      final String label = draft.label.text.trim();
      if (label.isEmpty && lines.isEmpty) continue;
      sections.add(SongSection(
        label: label.isEmpty ? 'Section' : label,
        lines: lines,
      ));
    }

    final Song base = widget.song ?? const Song(id: '', title: '');
    final Song updated = base.copyWith(
      title: _title.text.trim(),
      author: _author.text.trim(),
      songKey: _key.text.trim(),
      sections: sections,
    );

    final LibraryController library =
        context.read<LibraryController>();
    await library.upsert(updated);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New song' : 'Edit song'),
        actions: <Widget>[
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (String? value) =>
                  (value == null || value.trim().isEmpty)
                      ? 'Please enter a title'
                      : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _author,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Author (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _key,
                    decoration: const InputDecoration(
                      labelText: 'Key',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Sections', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (int i = 0; i < _sections.length; i++)
              _sectionEditor(i),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _addSection(),
              icon: const Icon(Icons.add),
              label: const Text('Add section'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionEditor(int index) {
    final _SectionDraft draft = _sections[index];
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: draft.label,
                    decoration: const InputDecoration(
                      labelText: 'Label (e.g. Verse 1, Chorus)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove section',
                  onPressed: _sections.length > 1
                      ? () => _removeSection(index)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: draft.lines,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Lyrics (one line per row)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
