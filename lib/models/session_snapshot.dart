import 'song.dart';

/// An immutable description of exactly what a member should currently see.
///
/// The leader broadcasts a fresh snapshot every time anything changes. It
/// carries the full [currentSong] so members can follow along even if the song
/// is not in their own local library.
class SessionSnapshot {
  const SessionSnapshot({
    required this.code,
    this.leaderName = '',
    this.sessionTitle = 'Live Session',
    this.currentSong,
    this.sectionIndex = 0,
    this.blanked = false,
    this.memberCount = 0,
    this.revision = 0,
  });

  final String code;
  final String leaderName;
  final String sessionTitle;

  /// The song the leader is presenting right now, or null when nothing is
  /// selected yet.
  final Song? currentSong;

  /// Index into [currentSong]'s sections that the leader is highlighting.
  final int sectionIndex;

  /// When true the leader has intentionally blanked the members' screens.
  final bool blanked;

  final int memberCount;

  /// Monotonically increasing counter so stale snapshots can be discarded.
  final int revision;

  SessionSnapshot copyWith({
    String? code,
    String? leaderName,
    String? sessionTitle,
    Song? currentSong,
    bool clearSong = false,
    int? sectionIndex,
    bool? blanked,
    int? memberCount,
    int? revision,
  }) {
    return SessionSnapshot(
      code: code ?? this.code,
      leaderName: leaderName ?? this.leaderName,
      sessionTitle: sessionTitle ?? this.sessionTitle,
      currentSong: clearSong ? null : (currentSong ?? this.currentSong),
      sectionIndex: sectionIndex ?? this.sectionIndex,
      blanked: blanked ?? this.blanked,
      memberCount: memberCount ?? this.memberCount,
      revision: revision ?? this.revision,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'leader': leaderName,
        'title': sessionTitle,
        'song': currentSong?.toJson(),
        'section': sectionIndex,
        'blanked': blanked,
        'members': memberCount,
        'rev': revision,
      };

  factory SessionSnapshot.fromJson(Map<String, dynamic> json) {
    final Object? song = json['song'];
    return SessionSnapshot(
      code: (json['code'] as String?) ?? '',
      leaderName: (json['leader'] as String?) ?? '',
      sessionTitle: (json['title'] as String?) ?? 'Live Session',
      currentSong: song == null
          ? null
          : Song.fromJson(Map<String, dynamic>.from(song as Map)),
      sectionIndex: (json['section'] as num?)?.toInt() ?? 0,
      blanked: (json['blanked'] as bool?) ?? false,
      memberCount: (json['members'] as num?)?.toInt() ?? 0,
      revision: (json['rev'] as num?)?.toInt() ?? 0,
    );
  }
}
