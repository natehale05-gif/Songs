import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../ui_kit.dart';

class AuthorScreen extends StatelessWidget {
  final Author author;
  final SongBook book;
  final ReaderPalette palette;
  final void Function(Song song) onSelectSong;

  const AuthorScreen({
    super.key,
    required this.author,
    required this.book,
    required this.palette,
    required this.onSelectSong,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final songs = book.songsByAuthor(author);
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(22, topInset + 60, 22, 40),
            children: [
                  Text(author.name,
                      style: TextStyle(
                        fontFamily: kDisplaySerif,
                        color: p.text,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      )),
                  const SizedBox(height: 6),
                  Text(author.dates,
                      style: TextStyle(color: p.accent, fontSize: 15, fontWeight: FontWeight.w600)),
                  if (author.born != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(author.born!,
                          style: TextStyle(color: p.text3, fontSize: 13.5)),
                    ),
                  const SizedBox(height: 26),
                  if (author.quote != null) ...[
                    _sectionLabel(p, 'IN THEIR OWN WORDS'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.only(left: 14),
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: p.accent, width: 2.5)),
                      ),
                      child: Text('“${author.quote}”',
                          style: TextStyle(
                            fontFamily: kDisplaySerif,
                            color: p.text2,
                            fontSize: 18,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          )),
                    ),
                    const SizedBox(height: 26),
                  ],
                  _sectionLabel(p, 'BIOGRAPHY'),
                  const SizedBox(height: 10),
                  Text(author.bio,
                      style: TextStyle(color: p.text2, fontSize: 16, height: 1.55)),
                  if (songs.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _sectionLabel(p, 'SONGS IN THIS APP'),
                    const SizedBox(height: 10),
                    ...songs.map((s) => _songRow(context, p, s)),
                  ],
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FrostedBar(
              color: p.surface.withValues(alpha: 0.7),
              border: Border(bottom: BorderSide(color: p.sep, width: 0.5)),
              child: Padding(
                padding: EdgeInsets.only(top: topInset),
                child: SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      Pressable(
                        onTap: () => Navigator.of(context).pop(),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: Icon(Icons.chevron_left,
                                color: p.accent, size: 28),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text('Author',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: p.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(ReaderPalette p, String text) => Text(
        text,
        style: TextStyle(
          color: p.text3,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      );

  Widget _songRow(BuildContext context, ReaderPalette p, Song s) {
    return Pressable(
      onTap: () {
        Navigator.of(context).pop();
        onSelectSong(s);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.sep, width: 0.6)),
        ),
        child: Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: categoryColor(s.category), shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(s.title,
                  style: TextStyle(
                      fontFamily: kDisplaySerif,
                      color: p.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.chevron_right, size: 16, color: p.text3),
          ],
        ),
      ),
    );
  }
}
