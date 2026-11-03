import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ostinato_audio/ostinato_audio.dart';

import '../practice/loop/metronome.dart';

/// F2.6 — what a drill question sounds like, as data (pure Dart). The
/// generator describes notes; [renderDrillSound] turns them into PCM for the
/// FK1 reference output. Nothing is recorded; every sound is synthesized.
enum DrillTimbre {
  /// Simple piano-like tone: decaying harmonics, soft attack.
  piano,

  /// The stiff-string model of the practice screen (guitar).
  string,

  /// A metronome click (accent when [DrillNote.gain] ≥ 0.75).
  click,
}

final class DrillNote {
  const DrillNote({
    required this.at,
    required this.midi,
    required this.seconds,
    this.gain = 1,
    this.timbre = DrillTimbre.piano,
  });

  /// Start, in seconds from the clip start.
  final double at;

  /// Fractional MIDI pitch (cents are hundredths): 60.5 is C4 + 50 c.
  final double midi;
  final double seconds;
  final double gain;
  final DrillTimbre timbre;

  double get end => at + seconds;
}

final class DrillSound {
  const DrillSound(this.notes);
  final List<DrillNote> notes;

  /// Clip length including a short release tail.
  double get seconds =>
      notes.fold<double>(0, (m, n) => math.max(m, n.end)) + 0.4;
}

/// Mono float PCM, peak ≤ 0.8. Deterministic for the same sound and rate.
Float32List renderDrillSound(DrillSound sound, {required int sampleRate}) {
  if (sampleRate != 44100 && sampleRate != 48000) {
    throw ArgumentError.value(sampleRate, 'sampleRate');
  }
  if (sound.notes.isEmpty) throw ArgumentError('A sound needs notes');
  final total = (sound.seconds * sampleRate).ceil();
  final mix = Float64List(total);
  final clicks = MetronomeClicks.forSampleRate(sampleRate);
  for (final n in sound.notes) {
    final tone = switch (n.timbre) {
      DrillTimbre.piano => _piano(n.midi, n.seconds, sampleRate),
      DrillTimbre.string => _string(n.midi, n.seconds, sampleRate),
      DrillTimbre.click => n.gain >= 0.75 ? clicks.accent : clicks.beat,
    };
    final start = (n.at * sampleRate).round();
    final gain = n.timbre == DrillTimbre.click ? 1.0 : n.gain;
    for (var i = 0; i < tone.length && start + i < total; i++) {
      mix[start + i] += tone[i] * gain;
    }
  }
  var peak = 0.0;
  for (final v in mix) {
    peak = math.max(peak, v.abs());
  }
  final scale = peak > 0.8 ? 0.8 / peak : 1.0;
  return Float32List.fromList([for (final v in mix) v * scale]);
}

double _hz(double midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();

Float64List _piano(double midi, double seconds, int rate) {
  final f0 = _hz(midi);
  final n = (seconds * rate).round();
  final out = Float64List(n);
  final attack = (0.006 * rate).round();
  final release = math.min(n, (0.08 * rate).round());
  for (var k = 1; k <= 10; k++) {
    final f = k * f0 * math.sqrt(1 + 3e-4 * k * k);
    if (f > rate * 0.45) break;
    final amp = 0.35 / math.pow(k, 1.3);
    final decay = 1.4 / math.sqrt(k);
    final w = 2 * math.pi * f / rate;
    for (var i = 0; i < n; i++) {
      out[i] += amp * math.exp(-i / rate / decay) * math.sin(w * i);
    }
  }
  for (var i = 0; i < attack && i < n; i++) {
    out[i] *= i / attack;
  }
  for (var i = 0; i < release; i++) {
    out[n - 1 - i] *= i / release;
  }
  return out;
}

Float64List _string(double midi, double seconds, int rate) {
  final tone = SyntheticString.pluck(
    f0Hz: _hz(midi),
    sampleRate: rate,
    seconds: seconds,
    pickNoiseLevel: 0,
    peak: .5,
  );
  final release = math.min(tone.length, (0.05 * rate).round());
  for (var i = 0; i < release; i++) {
    tone[tone.length - 1 - i] *= i / release;
  }
  return tone;
}
