import 'package:flutter/material.dart';

import '../audio.dart';
import '../theme.dart';

/// A chromatic pitch pipe: tap a note to hear it, shift octaves, matching the
/// original bottom-sheet pitch pipe.
class PitchPipeSheet extends StatefulWidget {
  final ReaderPalette palette;
  const PitchPipeSheet({super.key, required this.palette});

  @override
  State<PitchPipeSheet> createState() => _PitchPipeSheetState();
}

class _PitchPipeSheetState extends State<PitchPipeSheet> {
  int _octave = 0;
  int? _activeIdx;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(18, 12, 18, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(color: p.text3, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pitch Pipe',
                  style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w700)),
              Row(
                children: [
                  _octaveButton('–', () => setState(() => _octave = (_octave - 1).clamp(-2, 2))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(_octaveLabel,
                        style: TextStyle(color: p.text2, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  _octaveButton('+', () => setState(() => _octave = (_octave + 1).clamp(-2, 2))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < kPitchNotes.length; i++) _noteButton(i),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String get _octaveLabel {
    if (_octave == 0) return 'Middle';
    return _octave > 0 ? '+$_octave oct' : '$_octave oct';
  }

  Widget _octaveButton(String label, VoidCallback onTap) {
    final p = widget.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: p.btnBg, borderRadius: BorderRadius.circular(9)),
        child: Text(label, style: TextStyle(color: p.text2, fontSize: 18, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _noteButton(int i) {
    final p = widget.palette;
    final note = kPitchNotes[i];
    final active = _activeIdx == i;
    return GestureDetector(
      onTap: () {
        final freq = note.base * _octaveMultiplier;
        ToneEngine.instance.play(freq);
        setState(() => _activeIdx = i);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _activeIdx == i) setState(() => _activeIdx = null);
        });
      },
      child: Container(
        width: 58,
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? p.accent : p.btnBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: note.name,
                style: TextStyle(
                  color: active ? Colors.black : p.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (note.accidental != null)
                TextSpan(
                  text: note.accidental,
                  style: TextStyle(
                    color: active ? Colors.black54 : p.text3,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double get _octaveMultiplier {
    switch (_octave) {
      case -2:
        return 0.25;
      case -1:
        return 0.5;
      case 1:
        return 2.0;
      case 2:
        return 4.0;
      default:
        return 1.0;
    }
  }
}
