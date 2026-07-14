import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';
import 'seed_songs.dart';

/// Persists the song library on the device using [SharedPreferences].
///
/// Everything lives locally, so the library is fully available offline. The
/// first time the app runs the [buildSeedSongs] hymns are stored so there is
/// always something to present.
class SongRepository {
  SongRepository({SharedPreferences? preferences}) : _prefs = preferences;

  static const String _storageKey = 'songs.library.v1';
  static const String _seededKey = 'songs.seeded.v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<List<Song>> load() async {
    final SharedPreferences prefs = await _preferences;
    final bool seeded = prefs.getBool(_seededKey) ?? false;
    final String? raw = prefs.getString(_storageKey);

    if (raw == null && !seeded) {
      final List<Song> seeds = buildSeedSongs();
      await save(seeds);
      await prefs.setBool(_seededKey, true);
      return seeds;
    }

    if (raw == null) return <Song>[];
    return _decode(raw);
  }

  Future<void> save(List<Song> songs) async {
    final SharedPreferences prefs = await _preferences;
    final String raw =
        jsonEncode(songs.map((Song s) => s.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }

  List<Song> _decode(String raw) {
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((dynamic e) =>
              Song.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return <Song>[];
    }
  }
}
