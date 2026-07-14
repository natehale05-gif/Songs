import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// A single verse or chorus block of text.
class SongPart {
  final String label;
  final String text;
  final bool isChorus;

  const SongPart({
    required this.label,
    required this.text,
    this.isChorus = false,
  });
}

class Verse {
  final String label;
  final String text;

  const Verse({required this.label, required this.text});

  factory Verse.fromJson(Map<String, dynamic> json) =>
      Verse(label: json['label'] as String? ?? '', text: json['text'] as String? ?? '');
}

class Song {
  final int id;
  final String num;
  final String title;
  final String? titleEn;
  final String category;
  final String? lang;
  final String author;
  final String? tune;
  final String? key;
  final String? scripture;
  final List<Verse> verses;
  final Verse? chorus;
  final List<Verse> moreVerses;

  const Song({
    required this.id,
    required this.num,
    required this.title,
    this.titleEn,
    required this.category,
    this.lang,
    required this.author,
    this.tune,
    this.key,
    this.scripture,
    required this.verses,
    this.chorus,
    required this.moreVerses,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    List<Verse> parseVerses(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map(Verse.fromJson)
            .toList(growable: false);
      }
      return const [];
    }

    return Song(
      id: json['id'] as int,
      num: json['num']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      titleEn: json['titleEn'] as String?,
      category: json['category'] as String? ?? 'praise',
      lang: json['lang'] as String?,
      author: json['author'] as String? ?? '',
      tune: json['tune'] as String?,
      key: json['key'] as String?,
      scripture: json['scripture'] as String?,
      verses: parseVerses(json['verses']),
      chorus: json['chorus'] is Map<String, dynamic>
          ? Verse.fromJson(json['chorus'] as Map<String, dynamic>)
          : null,
      moreVerses: parseVerses(json['moreVerses']),
    );
  }

  /// The section letter used for alphabetical grouping.
  String get sectionLetter => title.isEmpty ? '#' : title[0].toUpperCase();

  /// Verse-only parts (no chorus) — used by the verse picker.
  List<SongPart> get verseOnlyParts {
    final parts = <SongPart>[];
    for (final v in verses) {
      parts.add(SongPart(label: v.label, text: v.text));
    }
    for (final v in moreVerses) {
      parts.add(SongPart(label: v.label, text: v.text));
    }
    return parts;
  }

  /// Interleaves verses with the chorus, matching the original `buildParts`.
  List<SongPart> buildParts() {
    final parts = <SongPart>[];
    void addWithChorus(List<Verse> vs) {
      for (final v in vs) {
        parts.add(SongPart(label: v.label, text: v.text));
        if (chorus != null) {
          parts.add(SongPart(label: 'Chorus', text: chorus!.text, isChorus: true));
        }
      }
    }

    addWithChorus(verses);
    addWithChorus(moreVerses);

    // Collapse consecutive choruses (can't happen between verses, but guards edges).
    final result = <SongPart>[];
    for (var i = 0; i < parts.length; i++) {
      final p = parts[i];
      if (p.isChorus && i > 0 && parts[i - 1].isChorus) continue;
      result.add(p);
    }
    return result;
  }

  bool matchesQuery(String q) {
    final lower = q.toLowerCase();
    if (title.toLowerCase().contains(lower)) return true;
    if (titleEn != null && titleEn!.toLowerCase().contains(lower)) return true;
    if (author.toLowerCase().contains(lower)) return true;
    if (scripture != null && scripture!.toLowerCase().contains(lower)) return true;
    if (num.toLowerCase().contains(lower)) return true;
    for (final v in verses) {
      if (v.text.toLowerCase().contains(lower)) return true;
    }
    if (chorus != null && chorus!.text.toLowerCase().contains(lower)) return true;
    for (final v in moreVerses) {
      if (v.text.toLowerCase().contains(lower)) return true;
    }
    return false;
  }
}

class Author {
  final String name;
  final String dates;
  final String? born;
  final String bio;
  final String? quote;
  final List<String> hymns;

  const Author({
    required this.name,
    required this.dates,
    this.born,
    required this.bio,
    this.quote,
    required this.hymns,
  });

  factory Author.fromJson(String name, Map<String, dynamic> json) => Author(
        name: name,
        dates: json['dates'] as String? ?? '',
        born: json['born'] as String?,
        bio: json['bio'] as String? ?? '',
        quote: json['quote'] as String?,
        hymns: (json['hymns'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}

class Category {
  final String key;
  final String label;

  const Category({required this.key, required this.label});

  factory Category.fromJson(Map<String, dynamic> json) =>
      Category(key: json['key'] as String, label: json['label'] as String);
}

/// A single note in an opening-melody staff line.
class MelodyNote {
  /// y-position on the staff (see original comment table).
  final int p;

  /// duration: "q" quarter, "h" half, "e" eighth.
  final String d;

  const MelodyNote({required this.p, required this.d});

  factory MelodyNote.fromJson(Map<String, dynamic> json) =>
      MelodyNote(p: (json['p'] as num).toInt(), d: json['d'] as String? ?? 'q');
}

/// Holds all parsed song-book data loaded from the bundled asset.
class SongBook {
  final List<Song> songs;
  final Map<String, Author> authors;
  final List<Category> categories;
  final Map<int, List<MelodyNote>> melody;

  const SongBook({
    required this.songs,
    required this.authors,
    required this.categories,
    required this.melody,
  });

  static Future<SongBook> load() async {
    final raw = await rootBundle.loadString('assets/data/songs.json');
    final data = json.decode(raw) as Map<String, dynamic>;

    final songs = (data['songs'] as List)
        .map((e) => Song.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

    final authors = <String, Author>{};
    (data['authors'] as Map<String, dynamic>).forEach((name, value) {
      authors[name] = Author.fromJson(name, value as Map<String, dynamic>);
    });

    final categories = (data['categories'] as List)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

    final melody = <int, List<MelodyNote>>{};
    (data['melody'] as Map<String, dynamic>).forEach((id, value) {
      melody[int.parse(id)] = (value as List)
          .map((e) => MelodyNote.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    });

    return SongBook(
      songs: songs,
      authors: authors,
      categories: categories,
      melody: melody,
    );
  }

  /// Finds the author whose key is a prefix of the song's author string,
  /// mirroring the original lookup logic.
  Author? authorForSong(Song song) {
    for (final entry in authors.entries) {
      if (song.author.startsWith(entry.key)) return entry.value;
    }
    return null;
  }

  /// Songs attributed to a given author (loose title match, like the original).
  List<Song> songsByAuthor(Author author) {
    return songs.where((s) {
      return author.hymns.any((h) {
        final needle = h
            .toLowerCase()
            .split(' ')
            .take(3)
            .join(' ');
        return s.title.toLowerCase().contains(needle);
      });
    }).toList();
  }
}
