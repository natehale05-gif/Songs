import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../audio.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/music_staff.dart';
import '../widgets/pitch_pipe.dart';
import 'author_screen.dart';

class ReaderScreen extends StatefulWidget {
  final Song song;
  final List<Song> queue;

  const ReaderScreen({super.key, required this.song, this.queue = const []});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late Song _song;
  late List<SongPart> _allParts;
  late List<SongPart> _verseOnly;
  late Set<int> _enabledVerses;
  final ScrollController _scrollController = ScrollController();

  String _mode = 'scroll';
  int _tapIdx = 0;
  double _fontSize = 1.35;
  bool _keyPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadSong(widget.song);
  }

  void _loadSong(Song song) {
    _song = song;
    _allParts = song.buildParts();
    _verseOnly = song.verseOnlyParts;
    _enabledVerses = {for (var i = 0; i < _verseOnly.length; i++) i};
    _tapIdx = 0;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    ToneEngine.instance.stop();
    super.dispose();
  }

  ReaderPalette get _p => context.read<AppState>().theme == AppThemeMode.dark
      ? ReaderPalette.dark
      : ReaderPalette.light;

  List<SongPart> get _activeParts {
    var vc = 0;
    final result = <SongPart>[];
    for (final part in _allParts) {
      if (part.isChorus) {
        result.add(part);
      } else {
        if (_enabledVerses.contains(vc)) result.add(part);
        vc++;
      }
    }
    return result;
  }

  double get _fontPx => _fontSize * 16;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = _p;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(state, p),
            Expanded(
              child: _mode == 'scroll' ? _buildScrollMode(p) : _buildTapMode(p),
            ),
            _buildBottomControls(p),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppState state, ReaderPalette p) {
    final author = state.book.authorForSong(_song);
    final isFav = state.isFavorite(_song.id);
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.sep, width: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.chevron_left, color: p.accent, size: 28),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_song.title,
                    style: TextStyle(
                      fontFamily: kDisplaySerif,
                      color: p.text,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    )),
                if (_song.titleEn != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(_song.titleEn!,
                        style: TextStyle(
                            color: p.text3, fontSize: 13, fontStyle: FontStyle.italic)),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: author != null
                      ? GestureDetector(
                          onTap: () => _openAuthor(state, author),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(_song.author,
                                    style: TextStyle(
                                        color: p.accent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ),
                              Icon(Icons.chevron_right, size: 14, color: p.accent),
                            ],
                          ),
                        )
                      : Text(_song.author,
                          style: TextStyle(color: p.text3, fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => state.toggleFavorite(_song.id),
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                size: 20, color: isFav ? const Color(0xFFFF3B30) : p.text3),
          ),
          if (_song.key != null) _buildKeyButton(p),
        ],
      ),
    );
  }

  Widget _buildKeyButton(ReaderPalette p) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 4),
      child: GestureDetector(
        onTapDown: (_) {
          final freq = kKeyFreqs[_song.key];
          if (freq != null) {
            ToneEngine.instance.play(freq, seconds: 2.2);
            setState(() => _keyPlaying = true);
          }
        },
        onTapUp: (_) => _stopKey(),
        onTapCancel: _stopKey,
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _keyPlaying ? p.accent : p.btnBg,
            shape: BoxShape.circle,
          ),
          child: Text(_song.key!,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: _keyPlaying ? Colors.black : p.text,
              )),
        ),
      ),
    );
  }

  void _stopKey() {
    ToneEngine.instance.stop();
    if (mounted) setState(() => _keyPlaying = false);
  }

  void _openAuthor(AppState state, Author author) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AuthorScreen(
          author: author,
          book: state.book,
          palette: _p,
          onSelectSong: (s) {
            state.trackOpen(s.id);
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => ReaderScreen(song: s, queue: widget.queue)),
            );
          },
        ),
      ),
    );
  }

  Widget _buildScrollMode(ReaderPalette p) {
    final parts = _activeParts;
    final melody = context.read<AppState>().book.melody[_song.id];
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      children: [
        if (melody != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: MusicStaff(notes: melody),
          ),
        ],
        for (final part in parts) _buildScrollPart(p, part),
        if (_song.scripture != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Text(
                _song.scripture!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.accent,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildScrollPart(ReaderPalette p, SongPart part) {
    final isChorus = part.isChorus;
    return Container(
      margin: const EdgeInsets.only(bottom: 26),
      padding: isChorus ? const EdgeInsets.fromLTRB(16, 14, 16, 16) : EdgeInsets.zero,
      decoration: isChorus
          ? BoxDecoration(
              color: p.chorusBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.chorusBorder),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              part.label.toUpperCase(),
              style: TextStyle(
                color: isChorus ? p.green : p.text3,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Text(
            part.text,
            style: TextStyle(
              fontFamily: kDisplaySerif,
              color: p.text,
              fontSize: _fontPx,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTapMode(ReaderPalette p) {
    final parts = _activeParts;
    if (parts.isEmpty) {
      return Center(
        child: Text('No verses selected', style: TextStyle(color: p.text3)),
      );
    }
    final idx = _tapIdx.clamp(0, parts.length - 1);
    final cur = parts[idx];
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cur.isChorus ? 'CHORUS' : cur.label.toUpperCase(),
                        style: TextStyle(
                          color: cur.isChorus ? p.green : p.text3,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        cur.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: kDisplaySerif,
                          color: p.text,
                          fontSize: _fontPx,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Tap zones
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _goPrev,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _goNext,
                    ),
                  ),
                ],
              ),
              if (idx > 0)
                Positioned(
                  left: 8, top: 0, bottom: 0,
                  child: Center(child: Icon(Icons.chevron_left, color: p.text3, size: 28)),
                ),
              if (idx < parts.length - 1)
                Positioned(
                  right: 8, top: 0, bottom: 0,
                  child: Center(child: Icon(Icons.chevron_right, color: p.text3, size: 28)),
                ),
            ],
          ),
        ),
        _buildTapDots(p, parts, idx),
      ],
    );
  }

  Widget _buildTapDots(ReaderPalette p, List<SongPart> parts, int idx) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < parts.length; i++)
            GestureDetector(
              onTap: () => setState(() => _tapIdx = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == idx ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == idx
                      ? (parts[i].isChorus ? p.green : p.accent)
                      : p.text3,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _goNext() {
    final parts = _activeParts;
    if (_tapIdx < parts.length - 1) setState(() => _tapIdx++);
  }

  void _goPrev() {
    if (_tapIdx > 0) setState(() => _tapIdx--);
  }

  Widget _buildBottomControls(ReaderPalette p) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.sep, width: 0.6)),
      ),
      child: Row(
        children: [
          _fontButton(p, 'A−', () => setState(() => _fontSize = (_fontSize - 0.15).clamp(0.85, 4.0))),
          const SizedBox(width: 5),
          _fontButton(p, 'A+', () => setState(() => _fontSize = (_fontSize + 0.15).clamp(0.85, 4.0))),
          const Spacer(),
          _pillButton(p, 'Verses · ${_enabledVerses.length}/${_verseOnly.length}', _showVersePicker),
          const SizedBox(width: 8),
          _pillButton(p, _mode == 'scroll' ? 'Tap' : 'Scroll', () {
            setState(() {
              _mode = _mode == 'scroll' ? 'tap' : 'scroll';
              _tapIdx = 0;
            });
          }),
          const SizedBox(width: 8),
          _pillButton(p, 'Pitch', _showPitchPipe),
        ],
      ),
    );
  }

  Widget _fontButton(ReaderPalette p, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: p.btnBg, borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: TextStyle(color: p.text2, fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _pillButton(ReaderPalette p, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: p.btnBg, borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: TextStyle(color: p.text2, fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _showPitchPipe() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PitchPipeSheet(palette: _p),
    );
  }

  void _showVersePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _p.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final p = _p;
            void toggle(int i) {
              setState(() {
                if (!_enabledVerses.remove(i)) _enabledVerses.add(i);
                _tapIdx = 0;
              });
              setSheet(() {});
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(18, 12, 18, 20 + MediaQuery.of(ctx).padding.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(color: p.text3, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Choose Verses',
                          style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w700)),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text('Done',
                            style: TextStyle(color: p.accent, fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ],
                  ),
                  Text('Tap to toggle. Chorus is always shown.',
                      style: TextStyle(color: p.text3, fontSize: 13)),
                  const SizedBox(height: 14),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (var i = 0; i < _verseOnly.length; i++)
                            _versePickRow(p, i, toggle),
                          if (_song.chorus != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: p.chorusBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: p.chorusBorder),
                              ),
                              child: Row(
                                children: [
                                  Text('Chorus',
                                      style: TextStyle(
                                          color: p.green, fontWeight: FontWeight.w700, fontSize: 14)),
                                  const SizedBox(width: 10),
                                  Text('Always included',
                                      style: TextStyle(color: p.text3, fontSize: 13)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _pickerAction(p, 'Select All', () {
                          setState(() => _enabledVerses = {for (var i = 0; i < _verseOnly.length; i++) i});
                          setSheet(() {});
                        }),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _pickerAction(p, 'Clear All', () {
                          setState(() => _enabledVerses = {});
                          setSheet(() {});
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _versePickRow(ReaderPalette p, int i, void Function(int) toggle) {
    final on = _enabledVerses.contains(i);
    final part = _verseOnly[i];
    final preview = part.text.split('\n').first;
    return GestureDetector(
      onTap: () => toggle(i),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: on ? p.btnActive : p.btnBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? p.accent : Colors.transparent, width: 1),
        ),
        child: Row(
          children: [
            Icon(on ? Icons.check_circle : Icons.circle_outlined,
                size: 20, color: on ? p.accent : p.text3),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(part.label,
                      style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(
                    preview.length > 40 ? '${preview.substring(0, 40)}…' : preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.text3, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickerAction(ReaderPalette p, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: p.btnBg, borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: TextStyle(color: p.text2, fontWeight: FontWeight.w600, fontSize: 14)),
      ),
    );
  }
}
