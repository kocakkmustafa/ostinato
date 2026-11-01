import 'dart:math' as math;

import 'package:ostinato_audio/ostinato_audio.dart';

import '../ui_copy.dart';
import 'tuner_copy.dart';

/// Instruments the tuner screen serves, each with its engine profile
/// (`PreciseTunerProfile`: guitar ≥ 60 Hz, bass ≥ 28 Hz, ukulele ≥ 150 Hz).
enum TunerInstrument {
  guitar(PreciseTunerProfile.guitar, TunerCopy.guitar),
  bass(PreciseTunerProfile.bass, TunerCopy.bass),
  ukulele(PreciseTunerProfile.ukulele, TunerCopy.ukulele);

  const TunerInstrument(this.profile, this.name);
  final PreciseTunerProfile profile;
  final UiCopy name;
}

/// FK7 tuning list. Strings run from the lowest-pitched string to the
/// highest (guitar: string 6 → string 1), except ukulele, which keeps its
/// re-entrant G-C-E-A order as players hold it.
final class TuningPreset {
  const TuningPreset({
    required this.id,
    required this.instrument,
    required this.name,
    required this.midis,
    this.preferFlats = false,
  });

  final String id;
  final TunerInstrument instrument;
  final UiCopy name;
  final List<int> midis;

  /// Half-step-down strings read as E♭ A♭ D♭ G♭ B♭ E♭.
  final bool preferFlats;

  int get stringCount => midis.length;

  /// Player numbering: the highest-pitched string of a guitar or bass is
  /// string 1. Ukulele strings are numbered 4-3-2-1 left to right too.
  int stringNumber(int index) => midis.length - index;

  String noteName(int index) => midiNoteName(midis[index], flats: preferFlats);
}

abstract final class TuningPresets {
  static const guitarStandard = TuningPreset(
    id: 'guitar.standard',
    instrument: TunerInstrument.guitar,
    name: TunerCopy.presetStandard,
    midis: [40, 45, 50, 55, 59, 64],
  );
  static const guitarDropD = TuningPreset(
    id: 'guitar.drop_d',
    instrument: TunerInstrument.guitar,
    name: TunerCopy.presetDropD,
    midis: [38, 45, 50, 55, 59, 64],
  );
  static const guitarHalfStepDown = TuningPreset(
    id: 'guitar.half_step_down',
    instrument: TunerInstrument.guitar,
    name: TunerCopy.presetHalfStepDown,
    midis: [39, 44, 49, 54, 58, 63],
    preferFlats: true,
  );
  static const guitarDadgad = TuningPreset(
    id: 'guitar.dadgad',
    instrument: TunerInstrument.guitar,
    name: TunerCopy.presetDadgad,
    midis: [38, 45, 50, 55, 57, 62],
  );
  static const guitarOpenG = TuningPreset(
    id: 'guitar.open_g',
    instrument: TunerInstrument.guitar,
    name: TunerCopy.presetOpenG,
    midis: [38, 43, 50, 55, 59, 62],
  );
  static const bass4 = TuningPreset(
    id: 'bass.four',
    instrument: TunerInstrument.bass,
    name: TunerCopy.presetBass4,
    midis: [28, 33, 38, 43],
  );
  static const bass5 = TuningPreset(
    id: 'bass.five',
    instrument: TunerInstrument.bass,
    name: TunerCopy.presetBass5,
    midis: [23, 28, 33, 38, 43],
  );
  static const ukuleleStandard = TuningPreset(
    id: 'ukulele.standard',
    instrument: TunerInstrument.ukulele,
    name: TunerCopy.presetUkuleleHighG,
    midis: [67, 60, 64, 69],
  );
  static const ukuleleLowG = TuningPreset(
    id: 'ukulele.low_g',
    instrument: TunerInstrument.ukulele,
    name: TunerCopy.presetUkuleleLowG,
    midis: [55, 60, 64, 69],
  );

  static const all = <TuningPreset>[
    guitarStandard,
    guitarDropD,
    guitarHalfStepDown,
    guitarDadgad,
    guitarOpenG,
    bass4,
    bass5,
    ukuleleStandard,
    ukuleleLowG,
  ];

  static List<TuningPreset> forInstrument(TunerInstrument instrument) => [
    for (final p in all)
      if (p.instrument == instrument) p,
  ];

  static TuningPreset byId(String id) => all.firstWhere((p) => p.id == id);
}

double midiToHz(num midi, {double a4Hz = 440}) =>
    a4Hz * math.pow(2, (midi - 69) / 12).toDouble();

/// Fractional MIDI note of a frequency.
double hzToMidi(double hz, {double a4Hz = 440}) =>
    69 + 12 * math.log(hz / a4Hz) / math.ln2;

const _sharps = ['C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B'];
const _flats = ['C', 'D♭', 'D', 'E♭', 'E', 'F', 'G♭', 'G', 'A♭', 'A', 'B♭', 'B'];

/// Scientific pitch name, e.g. `E2`, `D♯3`, `E♭4` (C4 = MIDI 60).
String midiNoteName(int midi, {bool flats = false}) =>
    '${(flats ? _flats : _sharps)[midi % 12]}${midi ~/ 12 - 1}';
