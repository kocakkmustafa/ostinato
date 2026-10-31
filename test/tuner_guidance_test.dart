import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/tuner/tuner_analysis.dart';
import 'package:ostinato/app/tuner/tuner_guidance.dart';
import 'package:ostinato/app/tuner/tunings.dart';
import 'package:ostinato_audio/ostinato_audio.dart';

double hz(num midi) => midiToHz(midi);
double cents(num midi, double c) => hz(midi) * math.pow(2, c / 1200);

TunerReadout guide(
  double f0, {
  TunerMode mode = TunerMode.auto,
  TuningPreset preset = TuningPresets.guitarStandard,
  int? selected,
  bool confident = true,
}) => guideTuner(
  mode: mode,
  preset: preset,
  reading: TunerPitch(f0Hz: f0, confident: confident),
  selectedString: selected,
);

void main() {
  group('FK7 tuning list', () {
    test('every preset has its expected notes', () {
      String names(TuningPreset p) =>
          [for (var i = 0; i < p.stringCount; i++) p.noteName(i)].join(' ');
      expect(names(TuningPresets.guitarStandard), 'E2 A2 D3 G3 B3 E4');
      expect(names(TuningPresets.guitarDropD), 'D2 A2 D3 G3 B3 E4');
      expect(names(TuningPresets.guitarHalfStepDown), 'E♭2 A♭2 D♭3 G♭3 B♭3 E♭4');
      expect(names(TuningPresets.guitarDadgad), 'D2 A2 D3 G3 A3 D4');
      expect(names(TuningPresets.guitarOpenG), 'D2 G2 D3 G3 B3 D4');
      expect(names(TuningPresets.bass4), 'E1 A1 D2 G2');
      expect(names(TuningPresets.bass5), 'B0 E1 A1 D2 G2');
      expect(names(TuningPresets.ukuleleStandard), 'G4 C4 E4 A4');
      expect(names(TuningPresets.ukuleleLowG), 'G3 C4 E4 A4');
      expect(TuningPresets.all.map((p) => p.id).toSet(), hasLength(9));
    });

    test('every string lies inside its engine profile range', () {
      for (final preset in TuningPresets.all) {
        final profile = preset.instrument.profile;
        for (final midi in preset.midis) {
          expect(hz(midi), greaterThanOrEqualTo(profile.minHz),
              reason: '${preset.id} $midi');
          expect(hz(midi), lessThanOrEqualTo(profile.maxHz));
        }
      }
      expect(hz(23), closeTo(30.87, 0.01)); // B0 above the 28 Hz bass floor
    });

    test('string numbers count from the highest-pitched guitar string', () {
      expect(TuningPresets.guitarStandard.stringNumber(0), 6);
      expect(TuningPresets.guitarStandard.stringNumber(5), 1);
    });
  });

  group('guidance', () {
    test('auto guesses the nearest string and gives a direction', () {
      final flat = guide(cents(45, -20));
      expect(flat.kind, TunerReadoutKind.measured);
      expect(flat.stringIndex, 1);
      expect(flat.cents, closeTo(-20, 0.01));
      expect(flat.direction, TuneDirection.tighten);

      final sharp = guide(cents(45, 30));
      expect(sharp.direction, TuneDirection.loosen);
    });

    test('inside ±5 cents is in tune with no direction', () {
      final r = guide(cents(64, 4.5));
      expect(r.kind, TunerReadoutKind.inTune);
      expect(r.direction, TuneDirection.none);
      expect(guide(cents(64, 5.5)).kind, TunerReadoutKind.measured);
    });

    test('rule 1: low confidence shows no number and no direction', () {
      final r = guide(cents(40, -12), confident: false);
      expect(r.kind, TunerReadoutKind.playAgain);
      expect(r.cents, isNull);
      expect(r.showsNumber, isFalse);
      expect(r.direction, TuneDirection.none);
    });

    test('rule 4: above +1 semitone says loosen, never tighten', () {
      // Manual, low E selected, string tuned up to G2 (+3 semitones).
      final r = guide(hz(43), mode: TunerMode.manual, selected: 0);
      expect(r.kind, TunerReadoutKind.tooHigh);
      expect(r.direction, TuneDirection.loosen);
      expect(r.showsNumber, isFalse);
      // Auto: D3 string pulled 1.3 semitones sharp (not near E2's octave).
      final auto = guide(cents(50, 130));
      expect(auto.stringIndex, 2);
      expect(auto.kind, TunerReadoutKind.tooHigh);
      // Exactly +1 semitone is still a measured "loosen".
      expect(guide(cents(50, 99)).kind, TunerReadoutKind.measured);
    });

    test('flat by up to 4 semitones still tightens (new string)', () {
      final r = guide(hz(36), mode: TunerMode.manual, selected: 0);
      expect(r.kind, TunerReadoutKind.measured);
      expect(r.direction, TuneDirection.tighten);
      expect(r.cents, closeTo(-400, 0.01));
    });

    test('rule 3: beyond ±4 semitones the auto mode asks which string', () {
      // Bass preset, a sound at B2 (59): 16 semitones above G2 and not an
      // octave of any bass string.
      final r = guide(hz(59) * 1.01, preset: TuningPresets.bass4);
      expect(r.kind, TunerReadoutKind.chooseString);
      expect(r.stringIndex, isNull);
      expect(r.direction, TuneDirection.none);
      // Manual: far from the selected string.
      final manual = guide(hz(48), mode: TunerMode.manual, selected: 0);
      expect(manual.kind, TunerReadoutKind.chooseString);
      expect(manual.direction, TuneDirection.none);
    });

    test('rule 2: octave ambiguity never gives a direction', () {
      // Auto: G2 could be the A string tuned down or the G string read an
      // octave low; "tighten" would be unsafe for the G string.
      expect(guide(hz(43)).kind, TunerReadoutKind.octaveUnclear);
      // Bass: A2 is two octaves above the A1 string.
      expect(
        guide(hz(57), preset: TuningPresets.bass4).kind,
        TunerReadoutKind.octaveUnclear,
      );
      // Low E2 read an octave high as E3: nearest string D3 would say
      // "+200 c, loosen" — the octave of E2 makes it ambiguous instead.
      final r = guide(hz(52));
      expect(r.kind, TunerReadoutKind.octaveUnclear);
      expect(r.direction, TuneDirection.none);
      expect(r.showsNumber, isFalse);
      // Manual: low E selected but the reading is E3.
      final manual = guide(cents(52, 10), mode: TunerMode.manual, selected: 0);
      expect(manual.kind, TunerReadoutKind.octaveUnclear);
    });

    test('manual without a selected string asks for one', () {
      final r = guide(hz(40), mode: TunerMode.manual);
      expect(r.kind, TunerReadoutKind.chooseString);
    });

    test('chromatic shows the nearest note with no string', () {
      final r = guide(cents(61, -12), mode: TunerMode.chromatic);
      expect(r.kind, TunerReadoutKind.measured);
      expect(r.nearestMidi, 61);
      expect(r.cents, closeTo(-12, 0.01));
      expect(r.stringIndex, isNull);
    });

    test('engine refusals map to listening or could-not-measure', () {
      TunerReadout refused(TunerRefusal r) => guideTuner(
        mode: TunerMode.auto,
        preset: TuningPresets.guitarStandard,
        refusal: r,
      );
      expect(refused(TunerRefusal.insufficientSamples).kind,
          TunerReadoutKind.listening);
      final quiet = refused(TunerRefusal.tooQuiet);
      expect(quiet.kind, TunerReadoutKind.couldNotMeasure);
      expect(quiet.reason, CouldNotMeasureReason.tooQuiet);
      expect(refused(TunerRefusal.unstable).reason,
          CouldNotMeasureReason.unclear);
    });

    test('a different A4 reference shifts the target', () {
      final r = guideTuner(
        mode: TunerMode.auto,
        preset: TuningPresets.guitarStandard,
        reading: TunerPitch(f0Hz: midiToHz(45, a4Hz: 442), confident: true),
        a4Hz: 442,
      );
      expect(r.kind, TunerReadoutKind.inTune);
    });
  });

  group('session state', () {
    test('a string is ticked only after two in-tune readouts in a row', () {
      final s = TunerSessionState(TuningPresets.guitarStandard);
      final inTune = guide(hz(40));
      expect(s.apply(inTune), isFalse);
      expect(s.states[0], StringTuneState.pending);
      expect(s.apply(inTune), isTrue);
      expect(s.states[0], StringTuneState.inTune);
      expect(s.focus, 1, reason: 'highlight moves on; no navigation');
      expect(s.inTuneCount, 1);
      expect(s.notInTuneCount, 5);
    });

    test('an interrupted streak does not tick', () {
      final s = TunerSessionState(TuningPresets.guitarStandard);
      s.apply(guide(hz(40)));
      s.apply(guide(hz(40), confident: false));
      expect(s.apply(guide(hz(40))), isFalse);
      expect(s.states[0], StringTuneState.pending);
    });

    test('direction states follow measured readouts', () {
      final s = TunerSessionState(TuningPresets.guitarStandard);
      s.apply(guide(cents(45, -30)));
      expect(s.states[1], StringTuneState.low);
      s.apply(guide(hz(48), mode: TunerMode.manual, selected: 1));
      expect(s.states[1], StringTuneState.high);
    });
  });

  group('analysis on synthetic plucks', () {
    const sr = 44100;
    List<double> pluck(double f0, {double pre = 0.25, double seconds = 1.4}) =>
        SyntheticString.pluck(
          f0Hz: f0,
          sampleRate: sr,
          seconds: seconds,
          preRollSeconds: pre,
          inharmonicityB: 1e-4,
          seed: 7,
        );

    test('a clean pluck with its attack in view is confident', () {
      final a = analyzeTunerBuffer(
        pluck(cents(45, -14)),
        sampleRate: sr,
        profile: PreciseTunerProfile.guitar,
      );
      expect(a.reading, isNotNull);
      expect(a.reading!.confident, isTrue);
      final r = guideTuner(
        mode: TunerMode.auto,
        preset: TuningPresets.guitarStandard,
        reading: a.reading,
      );
      expect(r.stringIndex, 1);
      expect(r.cents!, closeTo(-14, 3));
    });

    test('a tail without its attack is never shown as a number', () {
      final full = pluck(hz(45), pre: 0, seconds: 3);
      final tail = full.sublist((0.8 * sr).round());
      final a = analyzeTunerBuffer(
        tail,
        sampleRate: sr,
        profile: PreciseTunerProfile.guitar,
      );
      if (a.reading != null) expect(a.reading!.confident, isFalse);
    });

    test('silence waits or declines, without a reading', () {
      final a = analyzeTunerBuffer(
        List<double>.filled(sr * 2, 0),
        sampleRate: sr,
        profile: PreciseTunerProfile.guitar,
        roomFloorDb: -90,
      );
      expect(a.reading, isNull);
    });

    test('a low B0 is read with the bass profile', () {
      final a = analyzeTunerBuffer(
        SyntheticString.pluck(
          f0Hz: hz(23),
          sampleRate: sr,
          seconds: 2.0,
          preRollSeconds: 0.25,
          inharmonicityB: 2e-4,
          seed: 5,
        ),
        sampleRate: sr,
        profile: PreciseTunerProfile.bass,
      );
      expect(a.reading, isNotNull);
      final r = guideTuner(
        mode: TunerMode.auto,
        preset: TuningPresets.bass5,
        reading: a.reading,
      );
      expect(r.stringIndex, 0);
    });
  });
}
