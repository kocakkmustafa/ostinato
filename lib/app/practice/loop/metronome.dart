import 'dart:math' as math;
import 'dart:typed_data';

/// F2.2 — metronome timing, pure Dart (no Flutter, no platform).
///
/// This file is the **normative reference** for the native click stream
/// (iOS `PracticeMetronomeStream`, Android `MetronomeStreamRenderer`): beat
/// `n` starts at output frame `n * framesPerBeat` of the stream, counted from
/// the stream's first frame. Both natives render the same rule, so the beat
/// grid is sample-exact by construction; only the stream's anchor (when its
/// first frame left the device) is measured on the device clock.
///
/// Click band (E50 M1, `9-ses-motoru-e45-a3.md` §5): the click sits at
/// [kMetronomeClickHz] = 6 kHz, above the onset detector's ≤4 kHz band, so the
/// learner's notes are not masked. The contract's "±15 ms onset mask around
/// clicks" was measured to delete on-time notes and is deliberately not used.
const double kMetronomeClickHz = 6000;

/// Supported tempo range for the click stream (BPM).
const int kMetronomeMinBpm = 20;
const int kMetronomeMaxBpm = 300;

/// One metronome configuration on one output stream.
final class MetronomePlan {
  MetronomePlan({
    required this.bpm,
    required this.sampleRate,
    this.beatsPerBar = 4,
    this.countInBars = 1,
  }) {
    if (sampleRate != 44100 && sampleRate != 48000) {
      throw ArgumentError.value(sampleRate, 'sampleRate');
    }
    if (!(bpm >= kMetronomeMinBpm && bpm <= kMetronomeMaxBpm)) {
      throw ArgumentError.value(bpm, 'bpm');
    }
    if (beatsPerBar < 1 || beatsPerBar > 12) {
      throw ArgumentError.value(beatsPerBar, 'beatsPerBar');
    }
    if (countInBars < 0 || countInBars > 2) {
      throw ArgumentError.value(countInBars, 'countInBars');
    }
  }

  final num bpm;
  final int sampleRate;
  final int beatsPerBar;

  /// 1–2 bars before the lesson's first beat (contract: "ön sayım 1–2 ölçü").
  final int countInBars;

  /// Whole frames per beat. Rounding keeps every beat on an exact frame; the
  /// resulting tempo error is below 0.003 % at 44.1 kHz and the timeline uses
  /// the same integer, so the grid and the stream never drift apart.
  int get framesPerBeat => (sampleRate * 60 / bpm).round();

  int get countInBeats => countInBars * beatsPerBar;

  /// Stream frame where beat [beat] (0 = first count-in click) starts.
  int clickFrame(int beat) => beat * framesPerBeat;

  bool isAccent(int beat) => beat % beatsPerBar == 0;
}

/// The two click shapes. Both are short, enveloped 6 kHz bursts (no DC step,
/// no broadband tick): the accent is louder and a little longer.
final class MetronomeClicks {
  MetronomeClicks._(this.accent, this.beat);

  factory MetronomeClicks.forSampleRate(int sampleRate) => MetronomeClicks._(
    metronomeClick(sampleRate: sampleRate, amplitude: 0.8, milliseconds: 22),
    metronomeClick(sampleRate: sampleRate, amplitude: 0.5, milliseconds: 14),
  );

  final Float64List accent;
  final Float64List beat;
}

/// A band-limited click: 1 ms raised-cosine rise, exponential decay to about
/// −60 dB at the end. Energy is concentrated around [frequencyHz].
Float64List metronomeClick({
  required int sampleRate,
  double frequencyHz = kMetronomeClickHz,
  double amplitude = 0.6,
  int milliseconds = 15,
}) {
  if (sampleRate != 44100 && sampleRate != 48000) {
    throw ArgumentError.value(sampleRate, 'sampleRate');
  }
  if (!(amplitude > 0 && amplitude <= 1)) {
    throw ArgumentError.value(amplitude, 'amplitude');
  }
  if (milliseconds < 2 || milliseconds > 100) {
    throw ArgumentError.value(milliseconds, 'milliseconds');
  }
  final frames = (sampleRate * milliseconds / 1000).round();
  final attack = math.max(1, (sampleRate * 0.001).round());
  final decay = math.log(1000) / frames;
  final out = Float64List(frames);
  for (var i = 0; i < frames; i++) {
    final rise = i < attack ? 0.5 - 0.5 * math.cos(math.pi * i / attack) : 1.0;
    out[i] =
        amplitude *
        rise *
        math.exp(-decay * i) *
        math.sin(2 * math.pi * frequencyHz * i / sampleRate);
  }
  return out;
}

/// Renders any span of the endless click stream. Natives port this function;
/// tests use it to prove the beat grid is sample-exact.
final class ClickTrackRenderer {
  ClickTrackRenderer(this.plan, this.clicks) {
    if (clicks.accent.length > plan.framesPerBeat ||
        clicks.beat.length > plan.framesPerBeat) {
      throw ArgumentError('A click must be shorter than one beat');
    }
  }

  final MetronomePlan plan;
  final MetronomeClicks clicks;

  /// Frames `[startFrame, startFrame + frameCount)` of the stream.
  Float64List render(int startFrame, int frameCount) {
    if (startFrame < 0 || frameCount < 0) {
      throw ArgumentError('Negative span');
    }
    final out = Float64List(frameCount);
    final fpb = plan.framesPerBeat;
    final end = startFrame + frameCount;
    // The click of the beat before startFrame may still be sounding.
    var beat = math.max(0, startFrame ~/ fpb - 1);
    for (; plan.clickFrame(beat) < end; beat++) {
      final click = plan.isAccent(beat) ? clicks.accent : clicks.beat;
      final at = plan.clickFrame(beat);
      final from = math.max(at, startFrame);
      final to = math.min(at + click.length, end);
      for (var f = from; f < to; f++) {
        out[f - startFrame] += click[f - at];
      }
    }
    return out;
  }
}

/// Where the anchor came from.
enum MetronomeAnchorSource {
  /// The native stream reported when its first frame was presented.
  native,

  /// No click stream (sound off, or native anchor missing): a silent grid
  /// anchored on the capture clock. Visual beat and judging still work.
  silent,
}

/// Ties beat numbers to the capture (measurement) clock — the same clock as
/// `AudioChunk.tStartUs`. Every expected note time is read from here.
final class MetronomeTimeline {
  const MetronomeTimeline({
    required this.anchorUs,
    required this.sampleRate,
    required this.framesPerBeat,
    required this.source,
    this.outputLatencyUs = 0,
    this.latencyCorrectionUs = 0,
  });

  /// Device-clock time (µs) of the stream's frame 0.
  final int anchorUs;
  final int sampleRate;
  final int framesPerBeat;
  final MetronomeAnchorSource source;

  /// Native estimate of output latency not already inside [anchorUs].
  final int outputLatencyUs;

  /// Measured round-trip correction from latency calibration (F4.2 / E50).
  /// Zero until calibration exists; timing is then not shown to the learner.
  final int latencyCorrectionUs;

  bool get calibrated => latencyCorrectionUs != 0;

  double get beatUs => framesPerBeat * 1e6 / sampleRate;

  int get _originUs => anchorUs + outputLatencyUs + latencyCorrectionUs;

  /// When beat [beat] is heard (fractional beats allowed).
  int beatTimeUs(num beat) =>
      _originUs + (beat * framesPerBeat * 1e6 / sampleRate).round();

  /// Fractional beat heard at [tUs] (negative before the first click).
  double beatAt(int tUs) => (tUs - _originUs) / beatUs;
}

/// Where the metronome is at one instant, for the visual beat.
final class MetronomeBeatState {
  const MetronomeBeatState({
    required this.beat,
    required this.beatInBar,
    required this.phase,
    required this.countInRemaining,
  });

  /// Absolute beat index (−1 before the first click).
  final int beat;
  final int beatInBar;

  /// 0 at the click, rising to 1 just before the next one.
  final double phase;

  /// Count-in beats left including the current one; 0 once the lesson runs.
  final int countInRemaining;

  bool get inCountIn => countInRemaining > 0;

  static MetronomeBeatState at(
    MetronomeTimeline timeline,
    int nowUs, {
    required int beatsPerBar,
    required int countInBeats,
  }) {
    final b = timeline.beatAt(nowUs);
    if (b < 0) {
      return MetronomeBeatState(
        beat: -1,
        beatInBar: -1,
        phase: 0,
        countInRemaining: countInBeats,
      );
    }
    final beat = b.floor();
    return MetronomeBeatState(
      beat: beat,
      beatInBar: beat % beatsPerBar,
      phase: b - beat,
      countInRemaining: math.max(0, countInBeats - beat),
    );
  }
}

/// Maps "now" on the local monotonic clock to the capture clock between
/// chunks. Each chunk's end is a capture-clock fact; between chunks the
/// estimate runs on the local clock and never goes backwards.
final class CaptureClockEstimator {
  int? _captureEndUs;
  int? _localAtEndUs;
  int _lastUs = -1 << 62;

  bool get ready => _captureEndUs != null;

  void observeChunk({
    required int tStartUs,
    required int sampleCount,
    required int sampleRate,
    required int localNowUs,
  }) {
    _captureEndUs = tStartUs + (sampleCount * 1e6 / sampleRate).round();
    _localAtEndUs = localNowUs;
  }

  int? nowUs(int localNowUs) {
    final end = _captureEndUs, local = _localAtEndUs;
    if (end == null || local == null) return null;
    final now = math.max(_lastUs, end + (localNowUs - local));
    _lastUs = now;
    return now;
  }

  void reset() {
    _captureEndUs = null;
    _localAtEndUs = null;
    _lastUs = -1 << 62;
  }
}
