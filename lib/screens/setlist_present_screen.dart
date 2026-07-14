import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

class _Slide {
  final Song song;
  final int songIndex;
  final bool isTitle;
  final SongPart? part;
  const _Slide({
    required this.song,
    required this.songIndex,
    required this.isTitle,
    this.part,
  });
}

class SetListPresentScreen extends StatefulWidget {
  final List<Song> songs;
  const SetListPresentScreen({super.key, required this.songs});

  @override
  State<SetListPresentScreen> createState() => _SetListPresentScreenState();
}

class _SetListPresentScreenState extends State<SetListPresentScreen> {
  late final List<_Slide> _slides;
  final PageController _controller = PageController();
  int _idx = 0;
  double _fontSize = 1.7;

  @override
  void initState() {
    super.initState();
    _slides = _buildSlides();
  }

  List<_Slide> _buildSlides() {
    final result = <_Slide>[];
    for (var i = 0; i < widget.songs.length; i++) {
      final song = widget.songs[i];
      result.add(_Slide(song: song, songIndex: i, isTitle: true));
      for (final part in song.buildParts()) {
        result.add(_Slide(song: song, songIndex: i, isTitle: false, part: part));
      }
    }
    return result;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ReaderPalette get _p => context.read<AppState>().theme == AppThemeMode.dark
      ? ReaderPalette.dark
      : ReaderPalette.light;

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final slide = _slides[_idx];
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(p, slide),
            Expanded(
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _idx = i),
                    itemBuilder: (_, i) => _buildSlide(p, _slides[i]),
                  ),
                  // Tap navigation zones (do not block horizontal swipes).
                  Positioned.fill(
                    child: Row(
                      children: [
                        Expanded(child: GestureDetector(
                            behavior: HitTestBehavior.translucent, onTap: _prev)),
                        const Expanded(child: SizedBox()),
                        Expanded(child: GestureDetector(
                            behavior: HitTestBehavior.translucent, onTap: _next)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildBottomBar(p),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(ReaderPalette p, _Slide slide) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.sep, width: 0.6)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: p.accent, size: 24),
          ),
          Expanded(
            child: Text(
              slide.song.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kDisplaySerif,
                color: p.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              '${slide.songIndex + 1}/${widget.songs.length}',
              style: TextStyle(color: p.text3, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(ReaderPalette p, _Slide slide) {
    if (slide.isTitle) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12, height: 12,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: categoryColor(slide.song.category),
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                slide.song.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: kDisplaySerif,
                  color: p.text,
                  fontSize: _fontSize * 20,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              if (slide.song.key != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text('Key of ${slide.song.key}',
                      style: TextStyle(color: p.accent, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      );
    }

    final part = slide.part!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              part.isChorus ? 'CHORUS' : part.label.toUpperCase(),
              style: TextStyle(
                color: part.isChorus ? p.green : p.text3,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              part.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kDisplaySerif,
                color: p.text,
                fontSize: _fontSize * 16,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ReaderPalette p) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.sep, width: 0.6)),
      ),
      child: Row(
        children: [
          _fontButton(p, 'A−', () => setState(() => _fontSize = (_fontSize - 0.15).clamp(0.9, 4.0))),
          const SizedBox(width: 5),
          _fontButton(p, 'A+', () => setState(() => _fontSize = (_fontSize + 0.15).clamp(0.9, 4.0))),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.songs.length; i++)
                  GestureDetector(
                    onTap: () => _jumpToSong(i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _slides[_idx].songIndex == i ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _slides[_idx].songIndex == i ? p.accent : p.text3,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 84),
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

  void _next() {
    if (_idx < _slides.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    }
  }

  void _prev() {
    if (_idx > 0) {
      _controller.previousPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    }
  }

  void _jumpToSong(int songIndex) {
    final target = _slides.indexWhere((s) => s.songIndex == songIndex && s.isTitle);
    if (target >= 0) {
      _controller.jumpToPage(target);
      setState(() => _idx = target);
    }
    HapticFeedback.selectionClick();
  }
}
