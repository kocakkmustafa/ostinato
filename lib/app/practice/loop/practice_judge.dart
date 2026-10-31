import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ostinato_audio/ostinato_audio.dart';

import 'metronome.dart';
import 'practice_marks.dart';
import 'practice_score.dart';

/// F2.4 — from microphone samples to one of three marks per expected note
/// (pure Dart; the controller only schedules). RAM only: nothing here writes
/// or sends audio, and [CaptureBuffer.clear] zero-fills what it held.

/// Fixed analysis constants. Windows are wide because output/input latency is
/// not calibrated yet (F4.2); timing is reported separately and shown only
/// after calibration. All values `expertPending`.
final class JudgeConfig {
  const JudgeConfig({
    this.earlyMs = 160,
    this.lateMs = 260,
    this.maxShareOfGap = .5,
    this.skipAfterOnsetMs = 80,
    this.analysisMs = 320,
    this.minAnalysisMs = 120,
    this.marginMs = 40,
    this.levelAboveFloorDb = 6,
    this.clipPeak = .98,
  });

  /// Attack search window around the expected (heard) time.
  final int earlyMs, lateMs;

  /// The window never reaches past this share of the gap to a neighbour.
  final double maxShareOfGap;
  final int skipAfterOnsetMs, analysisMs, minAnalysisMs, marginMs;
  final double levelAboveFloorDb, clipPeak;
}

/// RAM ring of recent capture, on the capture clock. Samples pass a click-band
/// reject filter on the way in, so the 6 kHz metronome (F2.2) stays out of
/// the pitch analysis as well as the onset band.
final class CaptureBuffer {
  CaptureBuffer({this.keepSeconds = 8});

  final double keepSeconds;
  final List<_Chunk> _chunks = [];
  ClickBandReject? _filter;
  int? _sampleRate;

  int? get sampleRate => _sampleRate;
  bool get isEmpty => _chunks.isEmpty;
  int? get endUs => _chunks.isEmpty ? null : _chunks.last.endUs;

  /// Returns the RMS level (dBFS) of the filtered chunk.
  double push(AudioChunk chunk) {
    if (_sampleRate != chunk.sampleRate) {
      clear();
      _sampleRate = chunk.sampleRate;
      _filter = ClickBandReject(chunk.sampleRate);
    }
    final x = Float64List.fromList(chunk.samples);
    _filter!.process(x);
    final c = _Chunk(chunk.tStartUs, x, chunk.playbackActive, chunk.sampleRate);
    _chunks.add(c);
    final keepFrom = c.endUs - (keepSeconds * 1e6).round();
    while (_chunks.length > 1 && _chunks.first.endUs < keepFrom) {
      final old = _chunks.removeAt(0).samples;
      old.fillRange(0, old.length, 0);
    }
    return rmsDb(x);
  }

  /// Samples covering `[fromUs, toUs)`; gaps are zeros. Also says whether any
  /// covered chunk carried `playbackActive` within `[flagFromUs, flagToUs)`.
  CaptureSlice slice(int fromUs, int toUs, {int? flagFromUs, int? flagToUs}) {
    final rate = _sampleRate ?? 48000;
    final n = math.max(0, ((toUs - fromUs) * rate / 1e6).round());
    final out = Float64List(n);
    var playback = false;
    final fa = flagFromUs ?? fromUs, fb = flagToUs ?? toUs;
    for (final c in _chunks) {
      if (c.playback && c.endUs > fa && c.startUs < fb) playback = true;
      if (c.endUs <= fromUs || c.startUs >= toUs) continue;
      final offset = ((c.startUs - fromUs) * rate / 1e6).round();
      for (var i = 0; i < c.samples.length; i++) {
        final j = offset + i;
        if (j >= 0 && j < n) out[j] = c.samples[i];
      }
    }
    return CaptureSlice(out, fromUs, rate, playback);
  }

  void clear() {
    for (final c in _chunks) {
      c.samples.fillRange(0, c.samples.length, 0);
    }
    _chunks.clear();
    _filter = null;
    _sampleRate = null;
  }

  static double rmsDb(List<double> x) {
    if (x.isEmpty) return -160;
    var e = 0.0;
    for (final v in x) {
      e += v * v;
    }
    return 10 * math.log(math.max(e / x.length, 1e-16)) / math.ln10;
  }
}

final class _Chunk {
  _Chunk(this.startUs, this.samples, this.playback, int rate)
    : endUs = startUs + (samples.length * 1e6 / rate).round();
  final int startUs, endUs;
  final Float64List samples;
  final bool playback;
}

final class CaptureSlice {
  const CaptureSlice(
    this.samples,
    this.startUs,
    this.sampleRate,
    this.playback,
  );
  final Float64List samples;
  final int startUs;
  final int sampleRate;
  final bool playback;

  int indexOf(int tUs) => ((tUs - startUs) * sampleRate / 1e6).round();
  int timeOf(int index) => startUs + (index * 1e6 / sampleRate).round();
}

/// 4th-order Butterworth low-pass at 4.8 kHz plus a notch at the click
/// frequency. Stateful across chunks.
final class ClickBandReject {
  ClickBandReject(int sampleRate)
    : _stages = [
        _Biquad.lowPass(sampleRate, 4800, .5412),
        _Biquad.lowPass(sampleRate, 4800, 1.3066),
        _Biquad.notch(sampleRate, kMetronomeClickHz, 2),
      ];
  final List<_Biquad> _stages;

  void process(Float64List x) {
    for (final s in _stages) {
      s.process(x);
    }
  }
}

final class _Biquad {
  _Biquad(this.b0, this.b1, this.b2, this.a1, this.a2);

  factory _Biquad.lowPass(int rate, double hz, double q) {
    final w = 2 * math.pi * hz / rate, alpha = math.sin(w) / (2 * q);
    final c = math.cos(w), a0 = 1 + alpha;
    return _Biquad(
      (1 - c) / 2 / a0,
      (1 - c) / a0,
      (1 - c) / 2 / a0,
      -2 * c / a0,
      (1 - alpha) / a0,
    );
  }

  factory _Biquad.notch(int rate, double hz, double q) {
    final w = 2 * math.pi * hz / rate, alpha = math.sin(w) / (2 * q);
    final c = math.cos(w), a0 = 1 + alpha;
    return _Biquad(1 / a0, -2 * c / a0, 1 / a0, -2 * c / a0, (1 - alpha) / a0);
  }

  final double b0, b1, b2, a1, a2;
  double _x1 = 0, _x2 = 0, _y1 = 0, _y2 = 0;

  void process(Float64List x) {
    for (var i = 0; i < x.length; i++) {
      final v = x[i];
      final y = b0 * v + b1 * _x1 + b2 * _x2 - a1 * _y1 - a2 * _y2;
      _x2 = _x1;
      _x1 = v;
      _y2 = _y1;
      _y1 = y;
      x[i] = y;
    }
  }
}

/// One analysis job, self-contained so it can run in another isolate.
final class NoteJudgeRequest {
  const NoteJudgeRequest({
    required this.samples,
    required this.sampleRate,
    required this.kind,
    required this.expectedIndex,
    required this.searchFrom,
    required this.searchTo,
    required this.analysisMs,
    this.expectedMidi,
    this.roomFloorDb,
    this.playback = false,
    this.config = const JudgeConfig(),
  });

  final Float64List samples;
  final int sampleRate;
  final PracticeEventKind kind;
  final int? expectedMidi;

  /// Expected attack sample and the attack search range (sample indices).
  final int expectedIndex, searchFrom, searchTo;
  final int analysisMs;
  final double? roomFloorDb;

  /// App output was audible: never a verdict, always "could not hear".
  final bool playback;
  final JudgeConfig config;
}

final class NoteJudgement {
  const NoteJudgement(
    this.mark, {
    this.reason,
    this.attackIndex,
    this.observedMidi,
    this.centsFromExpected,
  });
  final PracticeMark mark;
  final HearingReason? reason;
  final int? attackIndex;
  final int? observedMidi;
  final double? centsFromExpected;
}

/// The judgement itself. Rules:
/// - no attack in the window → could not hear (silence is never "correct");
/// - app playback audible → could not hear (low confidence, no verdict);
/// - pitch notes go to [GuitarNoteVerifier]; doubt lands on "could not hear";
/// - onset notes (rhythm lines) are "correct" when an attack is in the window;
/// - degree notes (voice, relative pitch) have no engine here → could not hear.
NoteJudgement judgeNote(NoteJudgeRequest r) {
  final c = r.config;
  if (r.playback) {
    return const NoteJudgement(
      PracticeMark.couldNotHear,
      reason: HearingReason.appPlayback,
    );
  }
  final rate = r.sampleRate;
  final skip = (c.skipAfterOnsetMs * rate / 1000).round();
  final minAnalysis = (math.min(c.minAnalysisMs, r.analysisMs) * rate / 1000)
      .round();
  final attacks = const AttackLocator().attacks(r.samples, rate);
  int? best;
  for (final a in attacks) {
    if (a < r.searchFrom || a > r.searchTo) continue;
    if (r.samples.length - a < skip + minAnalysis) continue;
    if (best == null ||
        (a - r.expectedIndex).abs() < (best - r.expectedIndex).abs()) {
      best = a;
    }
  }
  if (best == null) {
    return const NoteJudgement(
      PracticeMark.couldNotHear,
      reason: HearingReason.noAttack,
    );
  }
  final attack = best;
  if (r.kind == PracticeEventKind.onset) {
    return NoteJudgement(PracticeMark.correct, attackIndex: attack);
  }
  final midi = r.expectedMidi;
  if (r.kind == PracticeEventKind.degree || midi == null) {
    return NoteJudgement(
      PracticeMark.couldNotHear,
      reason: HearingReason.unclear,
      attackIndex: attack,
    );
  }
  final verifier = GuitarNoteVerifier(
    config: NoteVerifierConfig(
      analysisMs: r.analysisMs,
      minAnalysisMs: math.min(c.minAnalysisMs, r.analysisMs),
    ),
  );
  final v = verifier.verify(
    r.samples,
    sampleRate: rate,
    expectedMidi: midi,
    onsetIndex: attack,
    roomFloorDb: r.roomFloorDb,
  );
  switch (v.verdict) {
    case NoteVerdict.correct:
      return NoteJudgement(
        PracticeMark.correct,
        attackIndex: attack,
        observedMidi: v.observedMidi,
        centsFromExpected: v.centsFromExpected,
      );
    case NoteVerdict.differentNote:
      return NoteJudgement(
        PracticeMark.differentNote,
        attackIndex: attack,
        observedMidi: v.observedMidi,
        centsFromExpected: v.centsFromExpected,
      );
    case NoteVerdict.couldNotHear:
      final end = math.min(
        r.samples.length,
        attack + skip + (r.analysisMs * rate / 1000).round(),
      );
      var peak = 0.0;
      for (var i = attack; i < end; i++) {
        peak = math.max(peak, r.samples[i].abs());
      }
      return NoteJudgement(
        PracticeMark.couldNotHear,
        reason: peak >= c.clipPeak
            ? HearingReason.tooLoud
            : v.reason == NoteVerdictReason.tooQuiet
            ? HearingReason.tooQuiet
            : HearingReason.unclear,
        attackIndex: attack,
        observedMidi: v.observedMidi,
      );
  }
}

/// The capture-clock windows of one expected note in flow mode.
final class NoteWindow {
  const NoteWindow({
    required this.expectedUs,
    required this.searchFromUs,
    required this.searchToUs,
    required this.analysisMs,
    required this.readyAtUs,
  });

  final int expectedUs, searchFromUs, searchToUs, analysisMs, readyAtUs;

  /// [prevGapUs]/[nextGapUs]: distance to the neighbouring notes (null = none).
  factory NoteWindow.forNote({
    required int expectedUs,
    required int durationUs,
    int? prevGapUs,
    int? nextGapUs,
    JudgeConfig config = const JudgeConfig(),
  }) {
    int capped(int ms, int? gapUs) {
      final us = ms * 1000;
      if (gapUs == null) return us;
      return math.min(us, (gapUs * config.maxShareOfGap).round());
    }

    final early = capped(config.earlyMs, prevGapUs);
    final late = capped(config.lateMs, nextGapUs);
    // Analysis must stay inside the note: duration minus the attack skip.
    final analysisMs = math.max(
      config.minAnalysisMs,
      math.min(config.analysisMs, durationUs ~/ 1000 - config.skipAfterOnsetMs),
    );
    final readyAt =
        expectedUs +
        late +
        (config.skipAfterOnsetMs + analysisMs + config.marginMs) * 1000;
    return NoteWindow(
      expectedUs: expectedUs,
      searchFromUs: expectedUs - early,
      searchToUs: expectedUs + late,
      analysisMs: analysisMs,
      readyAtUs: readyAt,
    );
  }
}

/// Live hearing state for the always-visible microphone strip and the setup
/// card (`4-rakip-arayuzleri` §6.6 "Duyamadım" rules 1–3).
enum MicStripState { silent, hearing, unclear }

final class HearingMonitor {
  HearingMonitor({
    this.unclearHoldUs = 1500000,
    this.setupCardSnoozeUs = 5 * 60 * 1000000,
  });

  final int unclearHoldUs, setupCardSnoozeUs;
  double? roomFloorDb;
  double levelDb = -160;
  int? _unclearAtUs;
  int _consecutiveUnheard = 0;
  int _judged = 0, _unheard = 0;
  int? _snoozedUntilUs;
  bool _cardDue = false;

  bool get setupCardDue => _cardDue;
  int get consecutiveUnheard => _consecutiveUnheard;

  /// Level of the filtered input in dBFS.
  void observeLevel(double db) => levelDb = db;

  /// Floor from the count-in (median chunk level).
  static double floorOf(List<double> levels) {
    if (levels.isEmpty) return -70;
    final s = List<double>.of(levels)..sort();
    return s[s.length ~/ 2];
  }

  MicStripState state(int nowUs) {
    final floor = roomFloorDb ?? -60;
    if (levelDb < floor + 6) return MicStripState.silent;
    final u = _unclearAtUs;
    if (u != null && nowUs - u <= unclearHoldUs) return MicStripState.unclear;
    return MicStripState.hearing;
  }

  /// 0..1 bar height for the strip (−80 dBFS … −20 dBFS).
  double get meter => ((levelDb + 80) / 60).clamp(0.0, 1.0);

  void observe(NoteJudgement j, int nowUs) {
    if (j.mark == PracticeMark.pending) return;
    if (j.mark == PracticeMark.couldNotHear) {
      if (j.reason == HearingReason.unclear ||
          j.reason == HearingReason.tooLoud) {
        _unclearAtUs = nowUs;
      }
      if (j.reason == HearingReason.skipped) return;
      _consecutiveUnheard++;
      _unheard++;
    } else {
      _consecutiveUnheard = 0;
    }
    _judged++;
    final snoozed = _snoozedUntilUs != null && nowUs < _snoozedUntilUs!;
    if (!snoozed &&
        (_consecutiveUnheard >= 3 ||
            (_judged >= 8 && _unheard / _judged > .25))) {
      _cardDue = true;
    }
  }

  void dismissSetupCard(int nowUs) {
    _cardDue = false;
    _consecutiveUnheard = 0;
    _snoozedUntilUs = nowUs + setupCardSnoozeUs;
  }
}

/// "Wait for me" timers (§6.6 rule 2): hint after 4 s, Skip/Listen after 8 s.
enum WaitStage { listening, hint, actions }

WaitStage waitStageOf(int waitedUs) => waitedUs >= 8000000
    ? WaitStage.actions
    : waitedUs >= 4000000
    ? WaitStage.hint
    : WaitStage.listening;
