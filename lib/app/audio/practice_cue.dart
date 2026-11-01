import 'dart:math' as math;
import 'dart:typed_data';

/// F2.1 — kısa bir test kliği/tonu üretir (mono, `[-1, 1]`).
///
/// Bu bir METRONOM değildir (F2.2): zamanlama doğruluğu taşımaz, yalnız
/// çal+dinle oturumunda çıkış yolunun açık olduğunu ve ölçümün
/// `playbackActive` bayrağını taşıdığını göstermeye yarar. Zarf: 2 ms
/// yükselen kosinüs atak + üstel sönüm; tıkırtı (DC/basamak) üretmez.
Float64List practiceTestClick({
  required int sampleRate,
  double frequencyHz = 1000,
  Duration duration = const Duration(milliseconds: 30),
  double amplitude = 0.5,
}) {
  if (sampleRate != 44100 && sampleRate != 48000) {
    throw ArgumentError.value(sampleRate, 'sampleRate');
  }
  if (!(frequencyHz > 0 && frequencyHz < sampleRate / 2)) {
    throw ArgumentError.value(frequencyHz, 'frequencyHz');
  }
  if (!(amplitude > 0 && amplitude <= 1)) {
    throw ArgumentError.value(amplitude, 'amplitude');
  }
  final frames = (sampleRate * duration.inMicroseconds / 1e6).round();
  if (frames <= 0 || frames > sampleRate * 2) {
    throw ArgumentError.value(duration, 'duration');
  }
  final attack = math.max(1, (sampleRate * 0.002).round());
  // Decays to ~-60 dB at the end of the cue.
  final decayRate = math.log(1000) / frames;
  final out = Float64List(frames);
  for (var i = 0; i < frames; i++) {
    final rise = i < attack ? 0.5 - 0.5 * math.cos(math.pi * i / attack) : 1.0;
    final envelope = rise * math.exp(-decayRate * i);
    out[i] =
        amplitude *
        envelope *
        math.sin(2 * math.pi * frequencyHz * i / sampleRate);
  }
  return out;
}
