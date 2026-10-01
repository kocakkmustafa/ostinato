import 'dart:math' as math;

import '../gate/audio_confidence_gate.dart';
import 'yin.dart';

/// Offline-evaluated single-note gate. It is not a live microphone or lesson
/// score; the caller must separately establish route quality and onset timing.
enum GuitarSingleNoteVerdict { match, differentNote, noVerdict }

enum GuitarSingleNoteReason {
  observed,
  insufficientSamples,
  tooQuiet,
  notPeriodic,
  attackWindow,
  coachSpeaking,
  insufficientReliableWindows,
  unstablePitch,
  ambiguousCenter,
  invalidSamples,
  clippedSignal,
  multipleSources,
}

/// Values are supplied by a versioned app configuration and frozen before
/// evaluating a holdout. Frequencies are Hz; levels are digital dBFS.
final class GuitarSingleNoteConfig {
  const GuitarSingleNoteConfig({
    required this.windowSize,
    required this.hopSize,
    required this.minReliableWindows,
    required this.minHz,
    required this.maxHz,
    required this.yinThreshold,
    required this.minPeriodicity,
    required this.minLevelAboveFloorDb,
    required this.attackWindowUs,
    required this.maxSpreadCents,
    required this.maxCenterErrorCents,
  });

  final int windowSize;
  final int hopSize;
  final int minReliableWindows;
  final double minHz;
  final double maxHz;
  final double yinThreshold;
  final double minPeriodicity;
  final double minLevelAboveFloorDb;
  final int attackWindowUs;
  final double maxSpreadCents;
  final double maxCenterErrorCents;
}

final class GuitarSingleNoteResult {
  const GuitarSingleNoteResult({
    required this.verdict,
    required this.reason,
    required this.totalWindows,
    required this.reliableWindows,
    this.observedHz,
    this.observedMidi,
    this.signedCentsFromTarget,
  });

  final GuitarSingleNoteVerdict verdict;
  final GuitarSingleNoteReason reason;
  final int totalWindows;
  final int reliableWindows;
  final double? observedHz;
  final int? observedMidi;
  final double? signedCentsFromTarget;
}

/// A target-free measurement. It says what the estimator observed, never
/// whether a learner played correctly. Cents use the nearest note center.
final class GuitarNoteObservation {
  const GuitarNoteObservation(
      {required this.hz, required this.midi, required this.centsFromCenter});
  final double hz;
  final int midi;
  final double centsFromCenter;
}

final class GuitarNoteObservationResult {
  const GuitarNoteObservationResult(
      {required this.reason,
      required this.totalWindows,
      required this.reliableWindows,
      this.observation});
  final GuitarSingleNoteReason reason;
  final int totalWindows;
  final int reliableWindows;
  final GuitarNoteObservation? observation;
}

/// Requires repeated prior-free, same-note observations. A wrong octave can
/// only become [GuitarSingleNoteVerdict.differentNote], never a match.
final class GuitarSingleNoteEvaluator {
  GuitarSingleNoteEvaluator({required this.config}) {
    if (config.windowSize <= 0 ||
        config.hopSize <= 0 ||
        config.minReliableWindows < 2 ||
        config.minHz <= 0 ||
        config.maxHz <= config.minHz ||
        config.yinThreshold <= 0 ||
        config.yinThreshold >= 1 ||
        config.minPeriodicity < 0 ||
        config.minPeriodicity > 1 ||
        config.maxSpreadCents <= 0 ||
        config.maxCenterErrorCents <= 0) {
      throw ArgumentError.value(
          config, 'config', 'Invalid single-note gate configuration');
    }
  }

  final GuitarSingleNoteConfig config;

  /// Original offline target comparison; the observation UI never consumes
  /// this verdict and never records a match as course completion.
  GuitarSingleNoteResult evaluate(
    List<double> samples, {
    required int sampleRate,
    required int tStartUs,
    required int expectedMidi,
    required double roomFloorDb,
    int? lastOnsetTUs,
    bool coachSpeaking = false,
  }) {
    if (expectedMidi < 0 || expectedMidi > 127) {
      throw ArgumentError('Invalid expected MIDI');
    }
    final result = observe(samples,
        sampleRate: sampleRate,
        tStartUs: tStartUs,
        roomFloorDb: roomFloorDb,
        lastOnsetTUs: lastOnsetTUs,
        coachSpeaking: coachSpeaking);
    final value = result.observation;
    final targetHz = 440 * math.pow(2, (expectedMidi - 69) / 12);
    return GuitarSingleNoteResult(
      verdict: value == null
          ? GuitarSingleNoteVerdict.noVerdict
          : value.midi == expectedMidi
              ? GuitarSingleNoteVerdict.match
              : GuitarSingleNoteVerdict.differentNote,
      reason: result.reason,
      totalWindows: result.totalWindows,
      reliableWindows: result.reliableWindows,
      observedHz: value?.hz,
      observedMidi: value?.midi,
      signedCentsFromTarget:
          value == null ? null : cents(value.hz, targetHz.toDouble()),
    );
  }

  GuitarNoteObservationResult observe(
    List<double> samples, {
    required int sampleRate,
    required int tStartUs,
    required double roomFloorDb,
    int? lastOnsetTUs,
    bool coachSpeaking = false,
  }) {
    if (sampleRate <= 0 || !roomFloorDb.isFinite) {
      throw ArgumentError('Invalid sample rate or room floor');
    }
    final minimum =
        config.windowSize + config.hopSize * (config.minReliableWindows - 1);
    if (samples.length < minimum) {
      return const GuitarNoteObservationResult(
        reason: GuitarSingleNoteReason.insufficientSamples,
        totalWindows: 0,
        reliableWindows: 0,
      );
    }

    // Deliberately no expectedHzPrior: that YIN option folds an octave-high
    // tone down to the prompted note for the older cello drill.
    final source = YinPitchSource(
      minHz: config.minHz,
      maxHz: config.maxHz,
      threshold: config.yinThreshold,
    );
    final gate = AudioConfidenceGate(
      config: AudioGateConfig(
        minPeriodicity: config.minPeriodicity,
        attackWindowUs: config.attackWindowUs,
        minLevelAboveFloorDb: config.minLevelAboveFloorDb,
      ),
    );

    final frequencies = <double>[];
    var total = 0;
    GuitarSingleNoteReason? firstRefusal;
    for (var start = 0;
        start + config.windowSize <= samples.length;
        start += config.hopSize) {
      total++;
      final reading = source.analyze(
        samples.sublist(start, start + config.windowSize),
        sampleRate: sampleRate,
        tStartUs: tStartUs + (start * 1000000 / sampleRate).round(),
      );
      final decision = gate.evaluate(
        reading,
        roomFloorDb: roomFloorDb,
        lastOnsetTUs: lastOnsetTUs,
        coachSpeaking: coachSpeaking,
      );
      if (decision.mayJudge) {
        frequencies.add(reading.f0Hz!);
      } else {
        firstRefusal ??= switch (decision.reason) {
          AudioGateReason.tooQuiet => GuitarSingleNoteReason.tooQuiet,
          AudioGateReason.notPeriodic => GuitarSingleNoteReason.notPeriodic,
          AudioGateReason.attackWindow => GuitarSingleNoteReason.attackWindow,
          AudioGateReason.coachSpeaking => GuitarSingleNoteReason.coachSpeaking,
          _ => GuitarSingleNoteReason.insufficientReliableWindows,
        };
      }
    }

    GuitarNoteObservationResult refuse(GuitarSingleNoteReason reason) =>
        GuitarNoteObservationResult(
          reason: reason,
          totalWindows: total,
          reliableWindows: frequencies.length,
        );

    if (frequencies.length < config.minReliableWindows) {
      return refuse(
          firstRefusal ?? GuitarSingleNoteReason.insufficientReliableWindows);
    }
    frequencies.sort();
    if (absCents(frequencies.last, frequencies.first) > config.maxSpreadCents) {
      return refuse(GuitarSingleNoteReason.unstablePitch);
    }
    final observedHz = frequencies[frequencies.length ~/ 2];
    final observedMidi =
        (69 + 12 * math.log(observedHz / 440) / math.ln2).round();
    final observedCenterHz = 440 * math.pow(2, (observedMidi - 69) / 12);
    if (absCents(observedHz, observedCenterHz.toDouble()) >
        config.maxCenterErrorCents) {
      return refuse(GuitarSingleNoteReason.ambiguousCenter);
    }
    return GuitarNoteObservationResult(
      reason: GuitarSingleNoteReason.observed,
      totalWindows: total,
      reliableWindows: frequencies.length,
      observation: GuitarNoteObservation(
        hz: observedHz,
        midi: observedMidi,
        centsFromCenter: cents(observedHz, observedCenterHz.toDouble()),
      ),
    );
  }
}
