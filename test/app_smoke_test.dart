import 'package:flutter_test/flutter_test.dart';

import 'package:songs_of_the_church/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled songs.json parses into the full song book', () async {
    final book = await SongBook.load();

    expect(book.songs.length, greaterThan(700));
    expect(book.authors.isNotEmpty, true);
    expect(book.categories.any((c) => c.key == 'all'), true);
    expect(book.melody.isNotEmpty, true);

    // Every song has a title, category and at least one verse.
    for (final s in book.songs) {
      expect(s.title.isNotEmpty, true);
      expect(s.category.isNotEmpty, true);
      expect(s.verses.isNotEmpty, true);
    }

    // A well-known hymn is present and resolves to its author bio.
    final amazingGrace = book.songs.firstWhere((s) => s.title == 'Amazing Grace');
    expect(book.authorForSong(amazingGrace), isNotNull);
  });
}
