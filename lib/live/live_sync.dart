import '../models.dart';
import 'live_snapshot.dart';

/// Maps the leader's current part onto the member's own list of parts.
///
/// The two lists are usually identical, but a leader can switch verses off,
/// which shortens theirs. When that happens the leader's index means nothing to
/// the member, so fall back to matching the part's label — verse labels are
/// unique, and every "Chorus" carries the same text anyway, so picking the
/// occurrence nearest the leader's position lands in the right place.
///
/// Returns -1 when nothing matches, which callers should treat as "just show
/// the text the leader sent".
int resolveLivePartIndex({
  required List<SongPart> memberParts,
  required int leaderIndex,
  required int leaderTotal,
  required String leaderLabel,
  required bool leaderIsChorus,
}) {
  if (memberParts.isEmpty) return -1;

  // Same-shaped lists: the index is directly meaningful.
  if (leaderTotal == memberParts.length &&
      leaderIndex >= 0 &&
      leaderIndex < memberParts.length) {
    return leaderIndex;
  }

  final String wanted = leaderLabel.trim().toLowerCase();
  final List<int> matches = <int>[];
  for (int i = 0; i < memberParts.length; i++) {
    final SongPart part = memberParts[i];
    if (part.isChorus == leaderIsChorus &&
        part.label.trim().toLowerCase() == wanted) {
      matches.add(i);
    }
  }
  if (matches.isEmpty) {
    // Nothing matched by label; only trust the raw index if it is in range.
    if (leaderIndex >= 0 && leaderIndex < memberParts.length) return leaderIndex;
    return -1;
  }
  if (matches.length == 1) return matches.first;

  // Repeated label (a chorus): choose the occurrence closest to where the
  // leader is, so a member scrolling sees the same part of the page.
  int best = matches.first;
  int bestDistance = (best - leaderIndex).abs();
  for (final int i in matches.skip(1)) {
    final int d = (i - leaderIndex).abs();
    if (d < bestDistance) {
      best = i;
      bestDistance = d;
    }
  }
  return best;
}

/// Convenience wrapper taking a snapshot straight from the transport.
int resolveSnapshotPartIndex(LiveSnapshot snap, List<SongPart> memberParts) =>
    resolveLivePartIndex(
      memberParts: memberParts,
      leaderIndex: snap.index,
      leaderTotal: snap.total,
      leaderLabel: snap.partLabel,
      leaderIsChorus: snap.isChorus,
    );

/// Finds the song a snapshot refers to in the member's own library.
///
/// Members carry the whole hymnal, so they can render the song themselves in
/// whichever mode they prefer rather than being limited to the single block of
/// text the leader happens to be showing.
Song? songForSnapshot(LiveSnapshot snap, List<Song> library) {
  final int? id = snap.songId;
  if (id == null) return null;
  for (final Song song in library) {
    if (song.id == id) return song;
  }
  return null;
}
