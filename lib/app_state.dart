import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

enum AppThemeMode { light, dark }

/// Central application state: loaded song data, favorites, "popular" tracking
/// (locally derived from how often each song is opened) and the working set
/// list. Persisted via [SharedPreferences]. Light/dark appearance follows the
/// device's system setting automatically.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  static const _kFavorites = 'songbook-favorites';
  static const _kOpens = 'songbook-open-counts';

  SongBook? _book;
  SongBook get book => _book!;
  bool get isLoaded => _book != null;

  SharedPreferences? _prefs;

  final Set<int> _favorites = {};
  final Map<int, int> _openCounts = {};
  AppThemeMode _theme = _modeFor(
      WidgetsBinding.instance.platformDispatcher.platformBrightness);

  static AppThemeMode _modeFor(Brightness b) =>
      b == Brightness.dark ? AppThemeMode.dark : AppThemeMode.light;

  /// Songs queued for the current set-list build.
  final List<Song> _setList = [];

  Set<int> get favorites => _favorites;
  AppThemeMode get theme => _theme;
  List<Song> get setList => List.unmodifiable(_setList);

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    _theme = _modeFor(
        WidgetsBinding.instance.platformDispatcher.platformBrightness);
    _book = await SongBook.load();
    _prefs = await SharedPreferences.getInstance();
    _loadPrefs();
    notifyListeners();
  }

  @override
  void didChangePlatformBrightness() {
    final mode = _modeFor(
        WidgetsBinding.instance.platformDispatcher.platformBrightness);
    if (mode != _theme) {
      _theme = mode;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _loadPrefs() {
    final prefs = _prefs;
    if (prefs == null) return;

    final favRaw = prefs.getString(_kFavorites);
    if (favRaw != null) {
      try {
        _favorites
          ..clear()
          ..addAll((json.decode(favRaw) as List).map((e) => e as int));
      } catch (_) {}
    }

    final opensRaw = prefs.getString(_kOpens);
    if (opensRaw != null) {
      try {
        (json.decode(opensRaw) as Map<String, dynamic>).forEach((k, v) {
          _openCounts[int.parse(k)] = (v as num).toInt();
        });
      } catch (_) {}
    }
  }

  bool isFavorite(int id) => _favorites.contains(id);

  void toggleFavorite(int id) {
    if (!_favorites.remove(id)) _favorites.add(id);
    _prefs?.setString(_kFavorites, json.encode(_favorites.toList()));
    notifyListeners();
  }

  /// Records that a song was opened, used to compute the "Popular" list.
  void trackOpen(int id) {
    _openCounts[id] = (_openCounts[id] ?? 0) + 1;
    _prefs?.setString(
      _kOpens,
      json.encode(_openCounts.map((k, v) => MapEntry(k.toString(), v))),
    );
    notifyListeners();
  }

  /// Song ids ordered by how often they've been opened (most first).
  List<int> get popularIds {
    final entries = _openCounts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(25).map((e) => e.key).toList();
  }

  // ── Set list management ──
  bool inSetList(int id) => _setList.any((s) => s.id == id);

  int setListPosition(int id) => _setList.indexWhere((s) => s.id == id);

  void toggleSetListSong(Song song) {
    final idx = _setList.indexWhere((s) => s.id == song.id);
    if (idx >= 0) {
      _setList.removeAt(idx);
    } else {
      _setList.add(song);
    }
    notifyListeners();
  }

  void setSetList(List<Song> songs) {
    _setList
      ..clear()
      ..addAll(songs);
    notifyListeners();
  }

  void reorderSetList(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final song = _setList.removeAt(oldIndex);
    _setList.insert(newIndex, song);
    notifyListeners();
  }

  void clearSetList() {
    _setList.clear();
    notifyListeners();
  }
}
