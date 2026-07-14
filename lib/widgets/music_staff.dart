import 'package:flutter/material.dart';

import '../models.dart';

/// Renders a song's opening melody on a treble staff, mirroring the original
/// SVG `MusicStaff` component. Purely decorative.
class MusicStaff extends StatelessWidget {
  final List<MelodyNote> notes;
  const MusicStaff({super.key, required this.notes});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 380 / 68,
      child: CustomPaint(painter: _StaffPainter(notes)),
    );
  }
}

class _StaffPainter extends CustomPainter {
  final List<MelodyNote> notes;
  _StaffPainter(this.notes);

  static const double _vbW = 380;
  static const double _vbH = 68;
  static const Color _gold = Color(0xD1C8A84B);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _vbW;
    final sy = size.height / _vbH;
    canvas.scale(sx, sy);

    const staffTop = 14.0;
    final lineYs = [0, 8, 16, 24, 32].map((o) => staffTop + o).toList();
    final midY = lineYs[2];
    const clefW = 30.0;

    final linePaint = Paint()
      ..color = const Color(0x4DC8A84B)
      ..strokeWidth = 0.85;
    for (final y in lineYs) {
      canvas.drawLine(Offset(clefW - 4, y), Offset(_vbW - 4, y), linePaint);
    }

    // Treble clef glyph
    _drawText(canvas, '\u{1D11E}', const Offset(1, 0), 50, const Color(0xADC8A84B),
        baselineY: lineYs[4] + 10);
    // Time signature 3/4
    _drawText(canvas, '3', Offset(clefW + 1, 0), 9, const Color(0x80C8A84B),
        baselineY: lineYs[1] + 3, bold: true);
    _drawText(canvas, '4', Offset(clefW + 1, 0), 9, const Color(0x80C8A84B),
        baselineY: lineYs[3] + 3, bold: true);

    final usable = _vbW - clefW - 12;
    final spacing = usable / notes.length;

    // Bar line after beat 4
    if (notes.length > 4) {
      final bx = clefW + 14 + 4 * spacing;
      canvas.drawLine(Offset(bx, lineYs[0]), Offset(bx, lineYs[4]),
          Paint()..color = const Color(0x66C8A84B)..strokeWidth = 1);
    }

    for (var i = 0; i < notes.length; i++) {
      final n = notes[i];
      final x = clefW + 14 + i * spacing + spacing * 0.35;
      final stemUp = n.p >= midY;
      _drawNote(canvas, x, n.p.toDouble(), n.d, stemUp, staffTop);
    }

    // Final double bar
    canvas.drawLine(Offset(_vbW - 4, lineYs[0]), Offset(_vbW - 4, lineYs[4]),
        Paint()..color = _gold..strokeWidth = 2.8);
    canvas.drawLine(Offset(_vbW - 8, lineYs[0]), Offset(_vbW - 8, lineYs[4]),
        Paint()..color = const Color(0x80C8A84B)..strokeWidth = 1);
  }

  void _drawNote(Canvas canvas, double x, double y, String dur, bool stemUp, double staffTop) {
    const rx = 5.0, ry = 3.2;
    final col = const Color(0xE0C8A84B);
    final filled = dur != 'h';
    const stemLen = 20.0;
    final stemX = stemUp ? x + rx - 0.8 : x - rx + 0.8;
    final stemY2 = stemUp ? y - stemLen : y + stemLen;
    final staffBot = staffTop + 32;

    final ledgerPaint = Paint()
      ..color = const Color(0x99C8A84B)
      ..strokeWidth = 0.9;
    if (y <= staffTop - 8) {
      for (var ly = staffTop - 8; ly >= y; ly -= 8) {
        canvas.drawLine(Offset(x - 7, ly), Offset(x + 7, ly), ledgerPaint);
      }
    }
    if (y >= staffBot + 8) {
      for (var ly = staffBot + 8; ly <= y; ly += 8) {
        canvas.drawLine(Offset(x - 7, ly), Offset(x + 7, ly), ledgerPaint);
      }
    }

    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(-12 * 3.1415926 / 180);
    final headPaint = Paint()
      ..color = col
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), headPaint);
    canvas.restore();

    canvas.drawLine(Offset(stemX, y), Offset(stemX, stemY2),
        Paint()..color = col..strokeWidth = 1.3);
  }

  void _drawText(Canvas canvas, String text, Offset topLeft, double fontSize, Color color,
      {required double baselineY, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontFamily: 'serif',
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(topLeft.dx, baselineY - tp.height));
  }

  @override
  bool shouldRepaint(covariant _StaffPainter oldDelegate) => oldDelegate.notes != notes;
}
