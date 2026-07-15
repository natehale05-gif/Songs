/// An immutable description of exactly what a group member should see right now
/// — the part (verse/chorus/title) the leader is currently presenting.
///
/// Pure data (no Flutter imports) so it can be serialised and sent over the
/// wire. The full text of the current part travels with it, so members follow
/// along faithfully regardless of their own state.
class LiveSnapshot {
  const LiveSnapshot({
    required this.code,
    this.leaderName = '',
    this.songId,
    this.songTitle = '',
    this.songSubtitle = '',
    this.partLabel = '',
    this.partText = '',
    this.isChorus = false,
    this.isTitle = false,
    this.index = 0,
    this.total = 0,
    this.blanked = false,
    this.memberCount = 0,
    this.revision = 0,
  });

  final String code;
  final String leaderName;

  final int? songId;
  final String songTitle;
  final String songSubtitle;

  final String partLabel;
  final String partText;
  final bool isChorus;

  /// True when the leader is on a song's title card rather than a verse.
  final bool isTitle;

  final int index;
  final int total;

  /// Leader has intentionally blanked the members' screens.
  final bool blanked;

  final int memberCount;

  /// Monotonic counter so out-of-order snapshots can be discarded.
  final int revision;

  bool get hasSong => songId != null || songTitle.isNotEmpty;

  LiveSnapshot copyWith({
    String? code,
    String? leaderName,
    int? songId,
    String? songTitle,
    String? songSubtitle,
    String? partLabel,
    String? partText,
    bool? isChorus,
    bool? isTitle,
    int? index,
    int? total,
    bool? blanked,
    int? memberCount,
    int? revision,
  }) {
    return LiveSnapshot(
      code: code ?? this.code,
      leaderName: leaderName ?? this.leaderName,
      songId: songId ?? this.songId,
      songTitle: songTitle ?? this.songTitle,
      songSubtitle: songSubtitle ?? this.songSubtitle,
      partLabel: partLabel ?? this.partLabel,
      partText: partText ?? this.partText,
      isChorus: isChorus ?? this.isChorus,
      isTitle: isTitle ?? this.isTitle,
      index: index ?? this.index,
      total: total ?? this.total,
      blanked: blanked ?? this.blanked,
      memberCount: memberCount ?? this.memberCount,
      revision: revision ?? this.revision,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'leader': leaderName,
        'songId': songId,
        'title': songTitle,
        'subtitle': songSubtitle,
        'label': partLabel,
        'text': partText,
        'chorus': isChorus,
        'isTitle': isTitle,
        'i': index,
        'n': total,
        'blanked': blanked,
        'members': memberCount,
        'rev': revision,
      };

  factory LiveSnapshot.fromJson(Map<String, dynamic> json) {
    return LiveSnapshot(
      code: (json['code'] as String?) ?? '',
      leaderName: (json['leader'] as String?) ?? '',
      songId: (json['songId'] as num?)?.toInt(),
      songTitle: (json['title'] as String?) ?? '',
      songSubtitle: (json['subtitle'] as String?) ?? '',
      partLabel: (json['label'] as String?) ?? '',
      partText: (json['text'] as String?) ?? '',
      isChorus: (json['chorus'] as bool?) ?? false,
      isTitle: (json['isTitle'] as bool?) ?? false,
      index: (json['i'] as num?)?.toInt() ?? 0,
      total: (json['n'] as num?)?.toInt() ?? 0,
      blanked: (json['blanked'] as bool?) ?? false,
      memberCount: (json['members'] as num?)?.toInt() ?? 0,
      revision: (json['rev'] as num?)?.toInt() ?? 0,
    );
  }
}
