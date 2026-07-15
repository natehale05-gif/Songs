import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/song_repository.dart';
import '../models/song.dart';

/// Owns the offline song library and notifies the UI of changes.
class LibraryController extends ChangeNotifier {
  LibraryController({SongRepository? repository})
      : _repository = repository ?? SongRepository();

  final SongRepository _repository;
  static const Uuid _uuid = Uuid();

  List<Song> _songs = <Song>[];
  bool _loading = true;

  List<Song> get songs => List<Song>.unmodifiable(_songs);
  bool get loading => _loading;

  Future<void> init() async {
    _songs = await _repository.load();
    _songs.sort((Song a, Song b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    _loading = false;
    notifyListeners();
  }

  Song? byId(String? id) {
    if (id == null) return null;
    for (final Song song in _songs) {
      if (song.id == id) return song;
    }
    return null;
  }

  Future<Song> upsert(Song song) async {
    final Song saved =
        song.id.isEmpty ? song.copyWith(id: _uuid.v4()) : song;
    final int index = _songs.indexWhere((Song s) => s.id == saved.id);
    if (index >= 0) {
      _songs[index] = saved;
    } else {
      _songs.add(saved);
    }
    _songs.sort((Song a, Song b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    await _repository.save(_songs);
    notifyListeners();
    return saved;
  }

  Future<void> delete(String id) async {
    _songs.removeWhere((Song s) => s.id == id);
    await _repository.save(_songs);
    notifyListeners();
  }
}
