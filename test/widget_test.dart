import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:songs_of_the_church/models.dart';

void main() {
  test('buildParts interleaves chorus after every verse', () {
    final song = Song(
      id: 1,
      num: '1',
      title: 'Test Hymn',
      category: 'praise',
      author: 'Anon',
      verses: const [Verse(label: 'Verse 1', text: 'a')],
      chorus: const Verse(label: 'Chorus', text: 'c'),
      moreVerses: const [Verse(label: 'Verse 2', text: 'b')],
    );

    final parts = song.buildParts();
    expect(parts.length, 4);
    expect(parts[0].isChorus, false);
    expect(parts[1].isChorus, true);
    expect(parts[2].isChorus, false);
    expect(parts[3].isChorus, true);
  });

  test('matchesQuery searches verse text and author', () {
    const song = Song(
      id: 2,
      num: '2',
      title: 'Amazing Grace',
      category: 'praise',
      author: 'John Newton, 1779',
      verses: [Verse(label: 'Verse 1', text: 'how sweet the sound')],
      moreVerses: [],
    );

    expect(song.matchesQuery('sweet'), true);
    expect(song.matchesQuery('newton'), true);
    expect(song.matchesQuery('nonexistent'), false);
  });

  testWidgets('MaterialApp builds without data', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
