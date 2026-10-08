// SfxGen: makes the app's sound effects as small WAV files in
// assets/audio/sfx/. They are built from tones here, so there are no
// third-party sounds and no licences to track.
//
// Run from the project folder:
//   dart run tools/sfx_gen.dart
//
// Sounds (all soft and short; never a buzzer):
//   tap.wav    every button tap
//   pop.wav    a tracing stroke finished
//   chime.wav  a whole letter or number traced
//   jingle.wav the Reward screen

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const rate = 22050;

void main() {
  final dir = Directory('assets/audio/sfx')..createSync(recursive: true);
  final sounds = {
    'tap': _tap(),
    'pop': _pop(),
    'chime': _chime(),
    'jingle': _jingle(),
  };
  for (final e in sounds.entries) {
    final file = File('${dir.path}/${e.key}.wav')..writeAsBytesSync(_wav(e.value));
    stdout.writeln('  ${file.path}  ${(file.lengthSync() / 1024).toStringAsFixed(1)} KB');
  }
}

/// A short, soft wooden "tok".
List<double> _tap() => _tone(880, 0.06, decay: 60, harmonics: [1, 0.3]);

/// A bubble pop: pitch slides up quickly.
List<double> _pop() {
  const seconds = 0.12;
  final n = (seconds * rate).round();
  var phase = 0.0;
  return [
    for (var i = 0; i < n; i++)
      () {
        final t = i / rate;
        phase += 2 * math.pi * (500 + 2500 * t / seconds) / rate;
        return math.sin(phase) * math.exp(-t * 25) * _fadeIn(i);
      }(),
  ];
}

/// Two bell notes, a fifth apart.
List<double> _chime() => _mix([
      _tone(1046.5, 0.7, decay: 5, harmonics: [1, 0.4, 0.15]), // C6
      _delay(_tone(1568.0, 0.6, decay: 5, harmonics: [1, 0.4, 0.15]), 0.12), // G6
    ]);

/// A happy rising C-E-G-C, then a held chord.
List<double> _jingle() {
  const notes = [523.25, 659.25, 783.99, 1046.5];
  return _mix([
    for (var i = 0; i < notes.length; i++)
      _delay(_tone(notes[i], 1.2 - i * 0.15, decay: 3.5, harmonics: [1, 0.35, 0.1]),
          i * 0.14),
  ]);
}

List<double> _tone(double hz, double seconds,
    {required double decay, required List<double> harmonics}) {
  final n = (seconds * rate).round();
  return [
    for (var i = 0; i < n; i++)
      () {
        final t = i / rate;
        var v = 0.0;
        for (var h = 0; h < harmonics.length; h++) {
          v += harmonics[h] * math.sin(2 * math.pi * hz * (h + 1) * t);
        }
        return v * math.exp(-t * decay) * _fadeIn(i) * _fadeOut(i, n);
      }(),
  ];
}

// Tiny fades stop clicks at the start and end.
double _fadeIn(int i) => math.min(1.0, i / (0.004 * rate));
double _fadeOut(int i, int n) => math.min(1.0, (n - i) / (0.01 * rate));

List<double> _delay(List<double> s, double seconds) =>
    [...List.filled((seconds * rate).round(), 0.0), ...s];

List<double> _mix(List<List<double>> parts) {
  final n = parts.map((p) => p.length).reduce(math.max);
  return [
    for (var i = 0; i < n; i++)
      parts.fold(0.0, (sum, p) => sum + (i < p.length ? p[i] : 0.0)),
  ];
}

/// 16-bit mono WAV, normalised to a gentle 50% of full volume.
Uint8List _wav(List<double> samples) {
  final peak = samples.map((s) => s.abs()).reduce(math.max);
  final gain = peak == 0 ? 0.0 : 0.5 / peak;
  final data = ByteData(44 + samples.length * 2);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little); // chunk size
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little); // bytes per second
  data.setUint16(32, 2, Endian.little); // bytes per frame
  data.setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i] * gain * 32767).round().clamp(-32768, 32767);
    data.setInt16(44 + i * 2, v, Endian.little);
  }
  return data.buffer.asUint8List();
}
