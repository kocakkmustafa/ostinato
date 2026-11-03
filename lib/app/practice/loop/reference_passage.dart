import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ostinato_audio/ostinato_audio.dart';

import 'metronome.dart';
import 'practice_score.dart';

/// FK1 — "Listen first": a lesson line rendered as audio on the device
/// (`docs/design/fk1-referans-ses.md`). Pure Dart and deterministic: the same
/// line, tempo and rate always give the same samples. Never a recording.
///
/// Pitch events are plucked with the stiff-string model the practice screen
/// already uses for "Listen to this note"; a rhythm-only line (`q q ee q`)
/// is tapped on a muted string. Clicks are the metronome's own shapes, one
/// count-in bar first, so the learner hears the tempo before the line.

/// Longest reference the player accepts. A line that does not fit is cut at
/// a bar line and [ReferencePassage.truncated] says so.
const int kMaxReferenceSeconds = 40;

/// Silence after the last note so its release is heard.
const double _tailSeconds = 1.2;

/// A plucked note never rings longer than this, whatever its written length.
const double _maxRingSeconds = 2.5;

/// Pitch of the muted tap in a rhythm-only line (A2, guitar range).
const int _tapMidi = 45;

final class ReferencePassage {
  const ReferencePassage._({
    required this.samples,
    required this.sampleRate,
    required this.bpm,
    required this.barsPlayed,
    required this.barCount,
  });

  final Float32List samples;
  final int sampleRate;
  final int bpm;

  /// Bars of the line in [samples] (count-in not included).
  final int barsPlayed;
  final int barCount;

  bool get truncated => barsPlayed < barCount;
  Duration get duration =>
      Duration(microseconds: samples.length * 1000000 ~/ sampleRate);
}

/// Renders [score] at [bpm]. [click] adds the metronome under the line as
/// well; the count-in bar is always clicked. Throws [ArgumentError] for a
/// rate the players do not take, a tempo outside the metronome's range or a
/// line with nothing to sound.
ReferencePassage renderReferencePassage(
  PracticeScore score, {
  required int bpm,
  required int sampleRate,
  bool click = true,
  int maxSeconds = kMaxReferenceSeconds,
}) {
  if (sampleRate != 44100 && sampleRate != 48000) {
    throw ArgumentError.value(sampleRate, 'sampleRate');
  }
  if (bpm < kMetronomeMinBpm || bpm > kMetronomeMaxBpm) {
    throw ArgumentError.value(bpm, 'bpm');
  }
  final sounding = [
    for (final e in score.events)
      if (_midiOf(e) != null) e,
  ];
  if (sounding.isEmpty) throw ArgumentError('Nothing to sound');

  final perBar = score.beatsPerBar;
  final secondsPerBeat = 60 / bpm;
  final countInBeats = perBar;
  // Whole bars that fit with the count-in and the tail; at least one.
  final budgetBeats = (maxSeconds - _tailSeconds) / secondsPerBeat;
  final fitBars = ((budgetBeats - countInBeats) / perBar).floor();
  final barsPlayed = math.max(1, math.min(score.barCount, fitBars));
  final lineBeats = math.min(
    score.totalBeats,
    (barsPlayed * perBar).toDouble(),
  );

  final framesPerBeat = sampleRate * 60 / bpm;
  final total =
      ((countInBeats + lineBeats) * framesPerBeat + _tailSeconds * sampleRate)
          .ceil();
  final mix = Float64List(total);

  void add(Float64List src, int at, {double gain = 1}) {
    for (var i = 0; i < src.length && at + i < total; i++) {
      mix[at + i] += src[i] * gain;
    }
  }

  final clicks = MetronomeClicks.forSampleRate(sampleRate);
  final clickedBeats = click ? countInBeats + lineBeats.ceil() : countInBeats;
  for (var b = 0; b < clickedBeats; b++) {
    final shape = b % perBar == 0 ? clicks.accent : clicks.beat;
    add(shape, (b * framesPerBeat).round(), gain: b < countInBeats ? 0.6 : 0.3);
  }

  final cache = <(int, int), Float64List>{};
  for (final e in sounding) {
    if (e.startBeat >= lineBeats) break;
    final midi = _midiOf(e)!;
    final tap = e.kind == PracticeEventKind.onset;
    // Ring for the written length (plus a short release), in whole 50 ms
    // steps so repeated notes share one rendering.
    final ring = tap
        ? 0.12
        : math.min(_maxRingSeconds, e.durationBeats * secondsPerBeat + 0.15);
    final steps = math.max(1, (ring * 20).round());
    final tone = cache.putIfAbsent((
      midi,
      steps,
    ), () => _pluck(midi, steps / 20, sampleRate, tap: tap));
    add(tone, ((countInBeats + e.startBeat) * framesPerBeat).round());
  }

  var peak = 0.0;
  for (final v in mix) {
    peak = math.max(peak, v.abs());
  }
  final scale = peak > 0.8 ? 0.8 / peak : 1.0;
  final out = Float32List(total);
  for (var i = 0; i < total; i++) {
    out[i] = mix[i] * scale;
  }
  return ReferencePassage._(
    samples: out,
    sampleRate: sampleRate,
    bpm: bpm,
    barsPlayed: barsPlayed,
    barCount: score.barCount,
  );
}

int? _midiOf(PracticeEvent e) => switch (e.kind) {
  PracticeEventKind.pitch => e.midi,
  PracticeEventKind.onset => _tapMidi,
  PracticeEventKind.degree => null,
};

Float64List _pluck(
  int midi,
  double seconds,
  int sampleRate, {
  bool tap = false,
}) {
  final tone = SyntheticString.pluck(
    f0Hz: 440 * math.pow(2, (midi - 69) / 12).toDouble(),
    sampleRate: sampleRate,
    seconds: seconds,
    pickNoiseLevel: tap ? 0.3 : 0,
    // A muted tap dies almost at once.
    fundamentalDecaySeconds: tap ? 0.05 : 2.0,
    peak: tap ? 0.35 : 0.5,
  );
  // Fade the last 40 ms (damping), so a cut note ends without a step.
  final fade = math.min(tone.length, (sampleRate * 0.04).round());
  for (var i = 0; i < fade; i++) {
    tone[tone.length - 1 - i] *= i / fade;
  }
  return tone;
}
