import 'dart:math' as math;
import 'dart:typed_data';

import '../dsp/fft.dart';
import '../onset/attack_locator.dart';
import 'yin.dart';

/// The three outcomes a practice note can get. "Could not hear" is a real
/// answer, not an error: a false "wrong note" is the most expensive mistake
/// the coach can make, so doubt always lands here.
enum NoteVerdict { correct, differentNote, couldNotHear }

enum NoteVerdictReason {
  matched,
  octaveResolvedToExpected,
  otherNote,
  otherOctave,
  invalidSamples,
  insufficientSamples,
  tooQuiet,
  notPeriodic,
  unstablePitch,
  ambiguous,
}

/// Fixed before evaluation (E37 PLAN). Durations in ms, levels in dB.
final class NoteVerifierConfig {
  const NoteVerifierConfig({
    this.skipAfterOnsetMs = 80,
    this.analysisMs = 320,
    this.minAnalysisMs = 200,
    this.yinWindowMs = 40,
    this.yinThreshold = 0.15,
    this.minPeriodicity = 0.6,
    this.minFrames = 3,
    this.minInlierShare = 0.6,
    this.minHz = 60,
    this.maxHz = 1400,
    this.matchToleranceCents = 50,
    this.octaveOddPowerRatio = 0.1,
    this.minExplainedShare = 0.5,
    this.maxExpectedToObservedShare = 0.5,
    this.partialToleranceCents = 30,
    this.maxPartials = 8,
    this.maxAnalysisHz = 5000,
    this.minLevelAboveFloorDb = 6,
  });

  final int skipAfterOnsetMs, analysisMs, minAnalysisMs, yinWindowMs;
  final double yinThreshold, minPeriodicity;
  final int minFrames;
  final double minInlierShare, minHz, maxHz, matchToleranceCents;
  final double octaveOddPowerRatio, minExplainedShare;
  final double maxExpectedToObservedShare, partialToleranceCents;
  final int maxPartials;
  final double maxAnalysisHz, minLevelAboveFloorDb;
}

final class NoteVerification {
  const NoteVerification({
    required this.verdict,
    required this.reason,
    this.observedHz,
    this.observedMidi,
    this.centsFromExpected,
  });
  final NoteVerdict verdict;
  final NoteVerdictReason reason;
  final double? observedHz;
  final int? observedMidi;
  final double? centsFromExpected;
}

/// Expected-note ("score-informed") verifier for one guitar note (roadmap
/// step 2). The lesson knows which note is due, so the question is binary
/// with explicit rivals — octave, neighbours — instead of open transcription.
///
/// 1. Prior-free YIN over [NoteVerifierConfig.analysisMs] after the attack;
///    the robust median of periodic frames is the observed pitch.
/// 2. Same note (± [NoteVerifierConfig.matchToleranceCents] after the
///    session's tuning offset) → correct.
/// 3. Octave relation: settled by the odd partials of the lower octave
///    (an octave-high YIN lock on the expected note leaves odd partials of the
///    expected note in place; a truly higher note has none there).
/// 4. Any other note → "different note" only when the observed note's
///    partials explain the spectrum and the expected note's do not;
///    otherwise "could not hear".
final class GuitarNoteVerifier {
  GuitarNoteVerifier({
    this.config = const NoteVerifierConfig(),
    this.referenceA4Hz = 440,
    this.attackLocator = const AttackLocator(),
  });

  final NoteVerifierConfig config;
  final double referenceA4Hz;

  /// Used when the caller does not pass `onsetIndex` (E39): the last attack
  /// that leaves the minimum analysis span.
  final AttackLocator attackLocator;

  NoteVerification verify(
    List<double> samples, {
    required int sampleRate,
    required int expectedMidi,
    int? onsetIndex,
    double? roomFloorDb,
    double tuningOffsetCents = 0,
  }) {
    final c = config;
    NoteVerification hear(NoteVerdictReason r) =>
        NoteVerification(verdict: NoteVerdict.couldNotHear, reason: r);
    if (sampleRate <= 0 || expectedMidi < 0 || expectedMidi > 127) {
      throw ArgumentError('Invalid sample rate or expected note');
    }
    for (final s in samples) {
      if (!s.isFinite || s.abs() > 1) {
        return hear(NoteVerdictReason.invalidSamples);
      }
    }
    final skip = (c.skipAfterOnsetMs * sampleRate / 1000).round();
    final onset = onsetIndex ??
        attackLocator.lastUsableAttack(samples, sampleRate,
            requiredSamples:
                skip + (c.minAnalysisMs * sampleRate / 1000).round());
    if (onset == null) return hear(NoteVerdictReason.insufficientSamples);
    final start = onset + skip;
    final end = math.min(
        samples.length, start + (c.analysisMs * sampleRate / 1000).round());
    if (end - start < (c.minAnalysisMs * sampleRate / 1000).round()) {
      return hear(NoteVerdictReason.insufficientSamples);
    }
    if (roomFloorDb != null &&
        _rmsDb(samples, start, end) < roomFloorDb + c.minLevelAboveFloorDb) {
      return hear(NoteVerdictReason.tooQuiet);
    }

    final yinSize = math.max(
        nextPowerOfTwo((c.yinWindowMs * sampleRate / 1000).round()),
        nextPowerOfTwo((2.1 * sampleRate / c.minHz).ceil()));
    final yin = YinPitchSource(
        minHz: c.minHz, maxHz: c.maxHz, threshold: c.yinThreshold);
    final frames = <double>[];
    for (var s = start; s + yinSize <= end; s += yinSize ~/ 2) {
      final r = yin.analyze(samples.sublist(s, s + yinSize),
          sampleRate: sampleRate, tStartUs: 0);
      if (r.f0Hz != null && r.periodicity >= c.minPeriodicity) {
        frames.add(r.f0Hz!);
      }
    }
    if (frames.length < c.minFrames) return hear(NoteVerdictReason.notPeriodic);
    final centre = _median(frames);
    final inliers = [
      for (final f in frames)
        if (_cents(f, centre).abs() <= 50) f
    ];
    if (inliers.length < c.minFrames ||
        inliers.length < c.minInlierShare * frames.length) {
      return hear(NoteVerdictReason.unstablePitch);
    }
    final observed = _median(inliers);

    final offset = math.pow(2, tuningOffsetCents / 1200).toDouble();
    final expectedHz =
        referenceA4Hz * math.pow(2, (expectedMidi - 69) / 12) * offset;
    final observedMidi =
        (69 + 12 * math.log(observed / offset / referenceA4Hz) / math.ln2)
            .round();
    final centsFromExpected = _cents(observed, expectedHz);
    NoteVerification result(NoteVerdict v, NoteVerdictReason r, {int? midi}) =>
        NoteVerification(
          verdict: v,
          reason: r,
          observedHz: observed,
          observedMidi: midi ?? observedMidi,
          centsFromExpected: centsFromExpected,
        );

    if (centsFromExpected.abs() <= c.matchToleranceCents) {
      return result(NoteVerdict.correct, NoteVerdictReason.matched);
    }

    final win = end - start;
    final fftSize = nextPowerOfTwo(win * 2);
    final spec = magnitudeSpectrum(
        samples.sublist(start, end), blackmanHarris(win), fftSize);
    final binHz = sampleRate / fftSize;

    final k = (centsFromExpected / 1200).round();
    final residual = centsFromExpected - 1200 * k;
    if (k != 0 && residual.abs() <= c.matchToleranceCents) {
      final lowerHz = k > 0 ? expectedHz : observed;
      final lowerHasOdd =
          _oddShare(spec, binHz, lowerHz) >= c.octaveOddPowerRatio;
      final expectedPresent = k > 0 ? lowerHasOdd : !lowerHasOdd;
      return expectedPresent
          ? result(
              NoteVerdict.correct, NoteVerdictReason.octaveResolvedToExpected,
              midi: expectedMidi)
          : result(NoteVerdict.differentNote, NoteVerdictReason.otherOctave);
    }

    final total = _bandPower(spec, binHz, c.minHz * 0.9, c.maxAnalysisHz);
    if (total <= 0) return hear(NoteVerdictReason.ambiguous);
    final explainedObserved = _harmonicPower(spec, binHz, observed) / total;
    final explainedExpected = _harmonicPower(spec, binHz, expectedHz) / total;
    if (explainedObserved >= c.minExplainedShare &&
        explainedExpected < c.maxExpectedToObservedShare * explainedObserved) {
      return result(NoteVerdict.differentNote, NoteVerdictReason.otherNote);
    }
    return NoteVerification(
      verdict: NoteVerdict.couldNotHear,
      reason: NoteVerdictReason.ambiguous,
      observedHz: observed,
      observedMidi: observedMidi,
      centsFromExpected: centsFromExpected,
    );
  }

  /// Power within ±tolerance of partials 1..maxPartials of [f0].
  double _harmonicPower(Float64List spec, double binHz, double f0) {
    var p = 0.0;
    for (var n = 1; n <= config.maxPartials; n++) {
      final hz = _partialHz(n, f0);
      if (hz > config.maxAnalysisHz) break;
      p += _partialBand(spec, binHz, hz, f0);
    }
    return p;
  }

  /// Share of odd partials (1, 3, 5, …) among partials 1..2·maxPartials.
  double _oddShare(Float64List spec, double binHz, double f0) {
    var odd = 0.0, all = 0.0;
    for (var n = 1; n <= 2 * config.maxPartials; n++) {
      final hz = _partialHz(n, f0);
      if (hz > config.maxAnalysisHz) break;
      final p = _partialBand(spec, binHz, hz, f0);
      all += p;
      if (n.isOdd) odd += p;
    }
    return all > 0 ? odd / all : 0;
  }

  static double _partialHz(int n, double f0) =>
      n * f0 * math.sqrt(1 + 1e-4 * n * n);

  double _partialBand(Float64List spec, double binHz, double hz, double f0) {
    final r = math.pow(2, config.partialToleranceCents / 1200).toDouble();
    final half = math.min(hz * (r - 1), 0.45 * f0);
    return _bandPower(spec, binHz, hz - half, hz + half);
  }

  static double _bandPower(
      Float64List spec, double binHz, double lo, double hi) {
    final a = math.max(1, (lo / binHz).ceil());
    final b = math.min(spec.length - 1, (hi / binHz).floor());
    var p = 0.0;
    for (var k = a; k <= b; k++) {
      p += spec[k] * spec[k];
    }
    return p;
  }

  static double _cents(double a, double b) => 1200 * math.log(a / b) / math.ln2;

  static double _median(List<double> v) {
    final s = List<double>.of(v)..sort();
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
  }

  static double _rmsDb(List<double> x, int start, int end) {
    var e = 0.0;
    for (var i = start; i < end; i++) {
      e += x[i] * x[i];
    }
    final rms = math.sqrt(e / math.max(1, end - start));
    return 20 * math.log(math.max(rms, 1e-9)) / math.ln10;
  }
}
