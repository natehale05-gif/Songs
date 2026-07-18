import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../live/live_controller.dart';
import '../live/live_sheet.dart';
import '../models.dart';
import '../theme.dart';
import '../ui_kit.dart';
import 'reader_screen.dart';
import 'setlist_present_screen.dart';

class _Filter {
  final String key;
  final String label;
  final bool isLang;
  const _Filter(this.key, this.label, {this.isLang = false});
}

const List<_Filter> _langFilters = [
  _Filter('es', 'Español', isLang: true),
  _Filter('he', 'עברית', isLang: true),
  _Filter('el', 'Ἑλληνικά', isLang: true),
  _Filter('sq', 'Shqip', isLang: true),
  _Filter('zh', '中文', isLang: true),
];

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  String _filterKey = 'all';
  bool _setListMode = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  AppPalette get _palette =>
      context.read<AppState>().theme == AppThemeMode.dark ? AppPalette.dark : AppPalette.light;

  int _catCount(AppState state, _Filter filter) {
    final songs = state.book.songs;
    if (filter.isLang) return songs.where((s) => s.lang == filter.key).length;
    switch (filter.key) {
      case 'all':
        return songs.length;
      case 'favorites':
        return state.favorites.length;
      case 'popular':
        return state.popularIds.length;
      default:
        return songs.where((s) => s.category == filter.key).length;
    }
  }

  List<Song> _filtered(AppState state) {
    final book = state.book;
    List<Song> list;

    if (_filterKey == 'favorites') {
      list = book.songs.where((s) => state.isFavorite(s.id)).toList();
    } else if (_filterKey == 'popular') {
      final byId = {for (final s in book.songs) s.id: s};
      list = state.popularIds
          .map((id) => byId[id])
          .whereType<Song>()
          .toList();
    } else if (_langFilters.any((f) => f.key == _filterKey)) {
      list = book.songs.where((s) => s.lang == _filterKey).toList();
    } else if (_filterKey != 'all') {
      list = book.songs.where((s) => s.category == _filterKey).toList();
    } else {
      list = List.of(book.songs);
    }

    if (_search.trim().isNotEmpty) {
      final q = _search.trim();
      list = list.where((s) => s.matchesQuery(q)).toList();
    }
    return list;
  }

  Map<String, List<Song>> _grouped(List<Song> songs) {
    // "popular" preserves ranking, so it isn't alphabetically grouped.
    final map = <String, List<Song>>{};
    for (final s in songs) {
      map.putIfAbsent(s.sectionLetter, () => []).add(s);
    }
    return map;
  }

  void _openSong(Song song) {
    Haptics.light();
    final state = context.read<AppState>();
    state.trackOpen(song.id);
    final songs = _filtered(state);
    Navigator.of(context).push(
      appPage(
        (_) => ReaderScreen(song: song, queue: songs),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = _palette;
    final filtered = _filtered(state);
    final isPopular = _filterKey == 'popular';
    final grouped = _grouped(filtered);
    final letters = grouped.keys.toList()..sort();
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildNavBar(state, p),
              SliverPersistentHeader(
                pinned: true,
                delegate: PinnedBarDelegate(
                  extent: 102,
                  child: _searchFilterBar(state, p),
                ),
              ),
              if (_setListMode)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: PinnedBarDelegate(
                    extent: 52,
                    child: _buildSetListBar(state, p),
                  ),
                ),
              if (filtered.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _buildEmpty(p))
              else if (isPopular)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _sectionCard(state, p, filtered),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 4),
                    for (final letter in letters) ...[
                      _buildSectionHeader(p, letter),
                      _sectionCard(state, p, grouped[letter]!),
                    ],
                  ]),
                ),
              SliverToBoxAdapter(
                child: SizedBox(height: (_setListMode ? 24 : 108) + bottomInset),
              ),
            ],
          ),
          Positioned(
            left: 20,
            bottom: 24 + bottomInset,
            child: _buildLiveButton(p),
          ),
        ],
      ),
      floatingActionButton: _setListMode
          ? null
          : FloatingActionButton.extended(
              backgroundColor: p.navy,
              foregroundColor: Colors.white,
              onPressed: () {
                Haptics.light();
                setState(() => _setListMode = true);
              },
              icon: const Icon(Icons.queue_music, size: 20),
              label: const Text('Set List',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
    );
  }

  Widget _buildNavBar(AppState state, AppPalette p) {
    return CupertinoSliverNavigationBar(
      largeTitle: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              'Songs of the Church',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kDisplaySerif,
                fontWeight: FontWeight.w700,
                color: p.label,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${state.book.songs.length} songs',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: p.label3),
          ),
        ],
      ),
      automaticallyImplyLeading: false,
      backgroundColor: p.surface.withValues(alpha: 0.72),
      border: const Border(),
      padding: const EdgeInsetsDirectional.only(end: 16),
    );
  }

  Widget _searchFilterBar(AppState state, AppPalette p) {
    return FrostedBar(
      color: p.surface.withValues(alpha: 0.72),
      border: Border(bottom: BorderSide(color: p.separator, width: 0.5)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: _buildSearch(p),
          ),
          _buildFilterRow(state, p),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLiveButton(AppPalette p) {
    return Consumer<LiveSessionController>(
      builder: (context, live, _) {
        final active = live.isActive;
        return SizedBox(
          width: 58,
          height: 58,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Pressable(
                onTap: () => showLiveSheet(context),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFFF3B30) : p.navy,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (active ? const Color(0xFFFF3B30) : p.navy)
                            .withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      active ? Icons.podcasts : Icons.groups_outlined,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
              if (active && live.isLeader && live.memberCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: p.navy,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.bg, width: 2),
                    ),
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    child: Text(
                      '${live.memberCount}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearch(AppPalette p) {
    return Container(
      decoration: BoxDecoration(
        color: p.fill1,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: p.label3),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _search = v),
              style: TextStyle(color: p.label, fontSize: 16),
              cursorColor: p.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search songs, authors, verses…',
                hintStyle: TextStyle(color: p.label3, fontSize: 16),
                contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
              ),
            ),
          ),
          if (_search.isNotEmpty)
            Pressable(
              onTap: () {
                _searchController.clear();
                setState(() => _search = '');
              },
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(color: p.label3, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(AppState state, AppPalette p) {
    final filters = <_Filter>[
      for (final c in state.book.categories) _Filter(c.key, c.label),
      ..._langFilters,
    ];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = filters[i];
          final active = _filterKey == f.key;
          return Pressable(
            onTap: () {
              Haptics.selection();
              setState(() {
                _filterKey = (active && f.isLang) ? 'all' : f.key;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? (p.brightness == Brightness.dark ? Colors.white : p.navy)
                    : p.fill1,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                children: [
                  Text(
                    f.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? (p.brightness == Brightness.dark ? Colors.black : Colors.white)
                          : p.label2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_catCount(state, f)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? (p.brightness == Brightness.dark ? Colors.black54 : Colors.white70)
                          : p.label3,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSetListBar(AppState state, AppPalette p) {
    final count = state.setList.length;
    return FrostedBar(
      color: p.surface.withValues(alpha: 0.8),
      border: Border(bottom: BorderSide(color: p.separator, width: 0.5)),
      child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == 0 ? 'Tap songs to add' : '$count song${count == 1 ? '' : 's'} selected',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.label2),
            ),
          ),
          _barButton(p, 'Shuffle', secondary: true, icon: Icons.shuffle,
              onTap: () => _showRandomPicker(state, p)),
          const SizedBox(width: 8),
          _barButton(p, 'Cancel', secondary: true, onTap: () {
            setState(() => _setListMode = false);
            state.clearSetList();
          }),
          if (count > 0) ...[
            const SizedBox(width: 8),
            _barButton(p, 'Begin', secondary: false, onTap: () {
              setState(() => _setListMode = false);
              _beginSetList(state);
            }),
          ],
        ],
      ),
      ),
    );
  }

  Widget _barButton(AppPalette p, String label,
      {required bool secondary, IconData? icon, required VoidCallback onTap}) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: secondary ? p.fill2 : p.navy,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: secondary ? p.label : Colors.white),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: secondary ? p.label : Colors.white)),
          ],
        ),
      ),
    );
  }

  void _beginSetList(AppState state) {
    if (state.setList.isEmpty) return;
    Navigator.of(context).push(
      appPage(
        (_) => SetListPresentScreen(songs: state.setList),
      ),
    );
  }

  Widget _buildSectionHeader(AppPalette p, String letter) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 16, 7),
      child: Text(
        letter.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: p.label3,
        ),
      ),
    );
  }

  /// A rounded, inset "group" of song rows — the grouped-list look from iOS
  /// Settings and Contacts.
  Widget _sectionCard(AppState state, AppPalette p, List<Song> songs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < songs.length; i++)
            _buildSongItem(state, p, songs[i], isLast: i == songs.length - 1),
        ],
      ),
    );
  }

  Widget _buildEmpty(AppPalette p) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_note, size: 44, color: p.label3),
          const SizedBox(height: 12),
          Text(
            _search.isNotEmpty ? 'No songs found for "$_search"' : 'No songs here yet',
            style: TextStyle(color: p.label3, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildSongItem(AppState state, AppPalette p, Song song,
      {bool isLast = false}) {
    final inSet = state.inSetList(song.id);
    final pos = state.setListPosition(song.id);
    final isFav = state.isFavorite(song.id);

    return Material(
      color: inSet ? p.navy.withValues(alpha: 0.07) : p.surface,
      child: InkWell(
        onTap: () {
          if (_setListMode) {
            Haptics.selection();
            state.toggleSetListSong(song);
          } else {
            _openSong(song);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(
                    bottom: BorderSide(color: p.separator, width: 0.4),
                  ),
          ),
          child: Row(
            children: [
              if (_setListMode) ...[
                _buildCheck(p, inSet),
                const SizedBox(width: 12),
              ],
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: categoryColor(song.category),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: TextStyle(
                        fontFamily: kDisplaySerif,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                        color: p.label,
                      ),
                    ),
                    if (song.titleEn != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          song.titleEn!,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: p.label3,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        song.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: p.label3),
                      ),
                    ),
                  ],
                ),
              ),
              if (_setListMode)
                if (inSet)
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: p.navy, shape: BoxShape.circle),
                    child: Text('${pos + 1}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  )
                else
                  const SizedBox.shrink()
              else
                Row(
                  children: [
                    Pressable(
                      onTap: () {
                        Haptics.light();
                        state.toggleFavorite(song.id);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          size: 19,
                          color: isFav ? const Color(0xFFFF3B30) : p.label4,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: p.label4),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheck(AppPalette p, bool checked) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? p.navy : Colors.transparent,
        border: Border.all(color: checked ? p.navy : p.separator, width: 1.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: checked ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
    );
  }

  void _showRandomPicker(AppState state, AppPalette p) {
    int count = 6;
    String category = 'all';
    const counts = [4, 5, 6, 7, 8, 10, 12];
    const cats = ['all', 'praise', 'communion', 'invitation', 'prayer', 'comfort', 'christmas', 'baptism'];

    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(ctx).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: p.separator, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              Text('Random Set List',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: p.label)),
              const SizedBox(height: 18),
              _sheetLabel(p, 'NUMBER OF SONGS'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: counts
                    .map((n) => _chip(p, '$n', count == n, () => setSheet(() => count = n)))
                    .toList(),
              ),
              const SizedBox(height: 20),
              _sheetLabel(p, 'CATEGORY'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: cats
                    .map((c) => _chip(p, c == 'all' ? 'Any' : _cap(c), category == c,
                        () => setSheet(() => category = c)))
                    .toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _generateRandomSetList(state, count, category);
                  },
                  child: const Text('Generate Set List',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetLabel(AppPalette p, String text) => Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: p.label3,
        ),
      );

  Widget _chip(AppPalette p, String label, bool active, VoidCallback onTap) {
    return Pressable(
      onTap: () {
        Haptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: active ? p.navy : p.fill1,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: active ? Colors.white : p.label)),
      ),
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  void _generateRandomSetList(AppState state, int count, String category) {
    var pool = state.book.songs.where((s) => s.lang == null).toList();
    if (category != 'all') pool = pool.where((s) => s.category == category).toList();
    pool.shuffle(math.Random());
    final selected = pool.take(count).toList();
    state.setSetList(selected);
    setState(() => _setListMode = false);
    if (selected.isNotEmpty) _beginSetList(state);
  }
}
