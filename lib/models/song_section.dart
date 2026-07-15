/// A labelled block of lyrics within a [Song], e.g. "Verse 1" or "Chorus".
class SongSection {
  const SongSection({required this.label, required this.lines});

  /// A short human readable label such as "Verse 1", "Chorus" or "Bridge".
  final String label;

  /// The individual lyric lines that make up this section.
  final List<String> lines;

  SongSection copyWith({String? label, List<String>? lines}) {
    return SongSection(
      label: label ?? this.label,
      lines: lines ?? this.lines,
    );
  }

  Map<String, dynamic> toJson() => {'label': label, 'lines': lines};

  factory SongSection.fromJson(Map<String, dynamic> json) {
    return SongSection(
      label: (json['label'] as String?) ?? '',
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .map((dynamic e) => e.toString())
          .toList(),
    );
  }
}
