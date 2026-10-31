import 'package:ostinato_audio/ostinato_audio.dart';

import 'tunings.dart';

/// F4.1 tuner guidance: pure rules from one engine outcome to what the
/// screen may say. No I/O, no clock.
///
/// String-safety rules (RAPOR (f), 4-rakip-arayuzleri §6.4), applied in
/// this order so the safest message wins:
/// 1. Low confidence → "play again": no number, no direction.
/// 2. Octave ambiguity (the reading sits one or two octaves from a string —
///    manual: from the selected string — while more than a semitone from
///    the target) → "could not measure": never a direction.
/// 3. More than ±4 semitones from the target → the auto mode does not lock
///    a string and asks which string is being played; manual mode asks to
///    check the selected string. No direction.
/// 4. More than +1 semitone above the target → "too high, loosen". The
///    screen never says "tighten" above the target.
/// 5. Within the tolerance band → in tune; otherwise tighten/loosen.
enum TunerMode { auto, manual, chromatic }

enum TunerReadoutKind {
  /// Waiting for a pluck (no attack in the buffer yet).
  listening,

  /// The engine declined: too quiet, noisy, two strings, unstable.
  couldNotMeasure,

  /// Measured, but without a visible attack or with a wide reading spread.
  playAgain,
  octaveUnclear,
  chooseString,
  tooHigh,
  measured,
  inTune,
}

enum CouldNotMeasureReason { tooQuiet, unclear }

enum TuneDirection { tighten, loosen, none }

/// One engine outcome, reduced to what guidance needs.
final class TunerPitch {
  const TunerPitch({required this.f0Hz, required this.confident});

  final double f0Hz;

  /// Attack seen in the buffer, readings agree within the engine's strict
  /// spread, and the value is not the late-readings fallback.
  final bool confident;
}

final class TunerReadout {
  const TunerReadout._({
    required this.kind,
    this.stringIndex,
    this.targetMidi,
    this.cents,
    this.nearestMidi,
    this.direction = TuneDirection.none,
    this.reason,
  });

  const TunerReadout.listening() : this._(kind: TunerReadoutKind.listening);

  final TunerReadoutKind kind;

  /// Index into the preset strings (auto: the guessed string).
  final int? stringIndex;
  final int? targetMidi;

  /// Signed cents from the target (chromatic: from the nearest note). Only
  /// set for [TunerReadoutKind.measured] and [TunerReadoutKind.inTune].
  final double? cents;
  final int? nearestMidi;
  final TuneDirection direction;
  final CouldNotMeasureReason? reason;

  bool get showsNumber =>
      kind == TunerReadoutKind.measured || kind == TunerReadoutKind.inTune;
}

/// Engine p95 on the simulated phone channel is still above 3 cents (E45:
/// 4.9 c pooled, 6.2 c open strings), so the in-tune band is ±5 cents and is
/// printed on screen. Narrowing it is an expert setting, not a default.
const double kDefaultTunerToleranceCents = 5;

/// Rules 3 and 4 (semitones).
const double kAutoLockSemitones = 4;
const double kTooHighSemitones = 1;

/// Rule 2: how close (semitones) a reading must sit to an octave of a
/// string to count as octave-ambiguous.
const double kOctaveWindowSemitones = 0.5;

TunerReadout guideTuner({
  required TunerMode mode,
  required TuningPreset preset,
  TunerPitch? reading,
  TunerRefusal? refusal,
  int? selectedString,
  double a4Hz = 440,
  double toleranceCents = kDefaultTunerToleranceCents,
}) {
  if (reading == null) {
    return switch (refusal) {
      null || TunerRefusal.insufficientSamples => const TunerReadout.listening(),
      TunerRefusal.tooQuiet => const TunerReadout._(
        kind: TunerReadoutKind.couldNotMeasure,
        reason: CouldNotMeasureReason.tooQuiet,
      ),
      _ => const TunerReadout._(
        kind: TunerReadoutKind.couldNotMeasure,
        reason: CouldNotMeasureReason.unclear,
      ),
    };
  }
  if (!reading.confident || !reading.f0Hz.isFinite || reading.f0Hz <= 0) {
    return const TunerReadout._(kind: TunerReadoutKind.playAgain);
  }
  final exact = hzToMidi(reading.f0Hz, a4Hz: a4Hz);
  final nearest = exact.round();

  if (mode == TunerMode.chromatic) {
    final cents = (exact - nearest) * 100;
    return TunerReadout._(
      kind: cents.abs() <= toleranceCents
          ? TunerReadoutKind.inTune
          : TunerReadoutKind.measured,
      cents: cents,
      nearestMidi: nearest,
      targetMidi: nearest,
      direction: cents.abs() <= toleranceCents
          ? TuneDirection.none
          : cents > 0
          ? TuneDirection.loosen
          : TuneDirection.tighten,
    );
  }

  final int? index;
  if (mode == TunerMode.manual) {
    index = selectedString;
    if (index == null || index < 0 || index >= preset.stringCount) {
      return TunerReadout._(
        kind: TunerReadoutKind.chooseString,
        nearestMidi: nearest,
      );
    }
  } else {
    var best = 0;
    for (var i = 1; i < preset.stringCount; i++) {
      if ((exact - preset.midis[i]).abs() < (exact - preset.midis[best]).abs()) {
        best = i;
      }
    }
    index = best;
  }
  final target = preset.midis[index];
  final semitones = exact - target;

  // Manual: the player named the string, so only its own octaves are in
  // doubt. Auto: any string's octave could be the real source, and a
  // "tighten" on the wrong octave is how strings break.
  if (semitones.abs() > kTooHighSemitones &&
      _nearOctave(
        exact,
        mode == TunerMode.manual ? [target] : preset.midis,
      )) {
    return TunerReadout._(
      kind: TunerReadoutKind.octaveUnclear,
      stringIndex: mode == TunerMode.manual ? index : null,
      nearestMidi: nearest,
    );
  }
  if (semitones.abs() > kAutoLockSemitones) {
    return TunerReadout._(
      kind: TunerReadoutKind.chooseString,
      stringIndex: mode == TunerMode.manual ? index : null,
      nearestMidi: nearest,
    );
  }
  if (semitones > kTooHighSemitones) {
    return TunerReadout._(
      kind: TunerReadoutKind.tooHigh,
      stringIndex: index,
      targetMidi: target,
      nearestMidi: nearest,
      direction: TuneDirection.loosen,
    );
  }
  final cents = semitones * 100;
  final inTune = cents.abs() <= toleranceCents;
  return TunerReadout._(
    kind: inTune ? TunerReadoutKind.inTune : TunerReadoutKind.measured,
    stringIndex: index,
    targetMidi: target,
    cents: cents,
    nearestMidi: nearest,
    direction: inTune
        ? TuneDirection.none
        : cents > 0
        ? TuneDirection.loosen
        : TuneDirection.tighten,
  );
}

bool _nearOctave(double exact, List<int> midis) {
  for (final midi in midis) {
    for (final k in const [-24, -12, 12, 24]) {
      if ((exact - (midi + k)).abs() <= kOctaveWindowSemitones) return true;
    }
  }
  return false;
}

enum StringTuneState { pending, low, high, inTune }

/// Per-string progress across readouts. A string is marked in tune only
/// after [confirmations] consecutive in-tune readouts on that same string,
/// so one lucky reading cannot tick it. The screen never navigates away
/// when a string is done; it only moves the highlight ([focus]).
final class TunerSessionState {
  TunerSessionState(this.preset, {this.confirmations = 2})
    : _states = List.filled(preset.stringCount, StringTuneState.pending);

  final TuningPreset preset;
  final int confirmations;
  final List<StringTuneState> _states;
  int? _streakString;
  int _streak = 0;
  int focus = 0;

  List<StringTuneState> get states => List.unmodifiable(_states);

  int get inTuneCount =>
      _states.where((s) => s == StringTuneState.inTune).length;

  int get notInTuneCount => preset.stringCount - inTuneCount;

  bool get allInTune => inTuneCount == preset.stringCount;

  /// Returns true when this readout newly confirmed a string.
  bool apply(TunerReadout readout) {
    final i = readout.stringIndex;
    if (i == null || i < 0 || i >= _states.length) {
      if (readout.kind != TunerReadoutKind.listening) _resetStreak();
      return false;
    }
    switch (readout.kind) {
      case TunerReadoutKind.inTune:
        if (_streakString == i) {
          _streak++;
        } else {
          _streakString = i;
          _streak = 1;
        }
        if (_streak >= confirmations &&
            _states[i] != StringTuneState.inTune) {
          _states[i] = StringTuneState.inTune;
          _moveFocusFrom(i);
          return true;
        }
        return false;
      case TunerReadoutKind.measured || TunerReadoutKind.tooHigh:
        _resetStreak();
        _states[i] = readout.direction == TuneDirection.loosen
            ? StringTuneState.high
            : StringTuneState.low;
        focus = i;
        return false;
      default:
        _resetStreak();
        return false;
    }
  }

  void select(int index) {
    if (index >= 0 && index < _states.length) focus = index;
  }

  void _resetStreak() {
    _streakString = null;
    _streak = 0;
  }

  void _moveFocusFrom(int i) {
    for (var step = 1; step < _states.length; step++) {
      final next = (i + step) % _states.length;
      if (_states[next] != StringTuneState.inTune) {
        focus = next;
        return;
      }
    }
  }
}
