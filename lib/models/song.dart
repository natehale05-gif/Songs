import 'song_section.dart';

/// A single song made up of ordered [SongSection]s.
///
/// This model is intentionally free of any Flutter dependency so it can be
/// serialised for offline storage and streamed over the local network to
/// members of a live small group session.
class Song {
  const Song({
    required this.id,
    required this.title,
    this.author = '',
    this.songKey = '',
    this.sections = const [],
  });

  final String id;
  final String title;
  final String author;

  /// Musical key, e.g. "G" or "Bb". Named [songKey] to avoid clashing with the
  /// reserved word behaviour of `key` in some contexts.
  final String songKey;

  final List<SongSection> sections;

  Song copyWith({
    String? id,
    String? title,
    String? author,
    String? songKey,
    List<SongSection>? sections,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      songKey: songKey ?? this.songKey,
      sections: sections ?? this.sections,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'key': songKey,
        'sections': sections.map((SongSection s) => s.toJson()).toList(),
      };

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Untitled',
      author: (json['author'] as String?) ?? '',
      songKey: (json['key'] as String?) ?? '',
      sections: (json['sections'] as List<dynamic>? ?? const [])
          .map((dynamic e) =>
              SongSection.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
