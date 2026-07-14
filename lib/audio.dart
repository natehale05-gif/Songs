import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Equal-tempered note frequencies (A4 = 440), keyed by musical key name.
const Map<String, double> kKeyFreqs = {
  'C': 261.63, 'C#': 277.18, 'Db': 277.18,
  'D': 293.66, 'D#': 311.13, 'Eb': 311.13,
  'E': 329.63, 'F': 349.23, 'F#': 369.99, 'Gb': 369.99,
  'G': 392.00, 'G#': 415.30, 'Ab': 415.30,
  'A': 440.00, 'A#': 466.16, 'Bb': 466.16, 'B': 493.88,
};

/// The 12 chromatic notes used by the pitch pipe.
class PitchNote {
  final String name;
  final String? accidental;
  final double base;
  const PitchNote(this.name, this.accidental, this.base);
}

const List<PitchNote> kPitchNotes = [
  PitchNote('C', null, 261.63),
  PitchNote('C', '#', 277.18),
  PitchNote('D', null, 293.66),
  PitchNote('D', '#', 311.13),
  PitchNote('E', null, 329.63),
  PitchNote('F', null, 349.23),
  PitchNote('F', '#', 369.99),
  PitchNote('G', null, 392.00),
  PitchNote('G', '#', 415.30),
  PitchNote('A', null, 440.00),
  PitchNote('A', '#', 466.16),
  PitchNote('B', null, 493.88),
];

/// Generates simple sine tones (with a soft organ-like blend) and plays them
/// through a single reusable [AudioPlayer]. Works across mobile, desktop & web.
class ToneEngine {
  ToneEngine._();
  static final ToneEngine instance = ToneEngine._();

  final AudioPlayer _player = AudioPlayer();
  static const int _sampleRate = 44100;

  /// Plays a sustained tone at [freq] Hz for [seconds]. Any currently playing
  /// tone is stopped first.
  Future<void> play(double freq, {double seconds = 1.6}) async {
    try {
      final bytes = _buildWav(freq, seconds);
      await _player.stop();
      await _player.play(BytesSource(bytes), volume: 0.9);
    } catch (_) {
      // Audio is best-effort; ignore failures on unsupported platforms.
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  Uint8List _buildWav(double freq, double seconds) {
    final totalSamples = (_sampleRate * seconds).round();
    final data = ByteData(44 + totalSamples * 2);

    // RIFF header
    _writeString(data, 0, 'RIFF');
    data.setUint32(4, 36 + totalSamples * 2, Endian.little);
    _writeString(data, 8, 'WAVE');
    _writeString(data, 12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, _sampleRate, Endian.little);
    data.setUint32(28, _sampleRate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    _writeString(data, 36, 'data');
    data.setUint32(40, totalSamples * 2, Endian.little);

    const attack = 0.02;
    const release = 0.12;
    final attackSamples = (_sampleRate * attack).round();
    final releaseSamples = (_sampleRate * release).round();

    for (var i = 0; i < totalSamples; i++) {
      final t = i / _sampleRate;
      // Fundamental plus a soft octave overtone for a warmer, organ-like tone.
      var sample = math.sin(2 * math.pi * freq * t) * 0.7 +
          math.sin(2 * math.pi * freq * 2 * t) * 0.18 +
          math.sin(2 * math.pi * freq * 3 * t) * 0.06;

      // Amplitude envelope to avoid clicks.
      double env = 1.0;
      if (i < attackSamples) {
        env = i / attackSamples;
      } else if (i > totalSamples - releaseSamples) {
        env = (totalSamples - i) / releaseSamples;
      }
      sample *= env * 0.6;

      final value = (sample.clamp(-1.0, 1.0) * 32767).round();
      data.setInt16(44 + i * 2, value, Endian.little);
    }

    return data.buffer.asUint8List();
  }

  void _writeString(ByteData data, int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }
}
