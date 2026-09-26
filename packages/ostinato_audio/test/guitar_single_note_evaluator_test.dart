import 'dart:math' as math;

import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:test/test.dart';

const sampleRate = 44100;
const config = GuitarSingleNoteConfig(
  windowSize: 4096,
  hopSize: 2048,
  minReliableWindows: 2,
  minHz: 70,
  maxHz: 1200,
  yinThreshold: 0.15,
  minPeriodicity: 0.55,
  minLevelAboveFloorDb: 6,
  attackWindowUs: 100000,
  maxSpreadCents: 35,
  maxCenterErrorCents: 35,
);

List<double> tone(double hz, {double amplitude = 0.3}) => List<double>.generate(
    8192, (i) => amplitude * math.sin(2 * math.pi * hz * i / sampleRate));

GuitarSingleNoteResult evaluate(
  List<double> samples, {
  int expectedMidi = 57, // A3
  double roomFloorDb = -60,
  int? lastOnsetTUs,
  bool coachSpeaking = false,
}) =>
    GuitarSingleNoteEvaluator(config: config).evaluate(
      samples,
      sampleRate: sampleRate,
      tStartUs: 200000,
      expectedMidi: expectedMidi,
      roomFloorDb: roomFloorDb,
      lastOnsetTUs: lastOnsetTUs,
      coachSpeaking: coachSpeaking,
    );

void main() {
  test('stable A3 yields a measured match with repeated windows', () {
    final result = evaluate(tone(220));
    expect(result.verdict, GuitarSingleNoteVerdict.match);
    expect(result.observedMidi, 57);
    expect(result.reliableWindows, greaterThanOrEqualTo(2));
    expect(result.signedCentsFromTarget!.abs(), lessThan(5));
  });

  test('stable neighboring note is explicitly different', () {
    final result = evaluate(tone(233.08188076));
    expect(result.verdict, GuitarSingleNoteVerdict.differentNote);
    expect(result.observedMidi, 58);
  });

  test('an octave-high tone never becomes the expected lower note', () {
    final result = evaluate(tone(440));
    expect(result.verdict, GuitarSingleNoteVerdict.differentNote);
    expect(result.observedMidi, 69);
    expect(result.observedMidi, isNot(57));
  });

  test('weak signal declines to judge', () {
    final result = evaluate(tone(220, amplitude: 0.00001));
    expect(result.verdict, GuitarSingleNoteVerdict.noVerdict);
    expect(result.reason, GuitarSingleNoteReason.tooQuiet);
    expect(result.signedCentsFromTarget, isNull);
  });

  test('noise declines to judge', () {
    final noise =
        SyntheticTone.roomNoise(sampleRate: sampleRate, seconds: 0.19);
    final result = evaluate(noise);
    expect(result.verdict, GuitarSingleNoteVerdict.noVerdict);
    expect(result.signedCentsFromTarget, isNull);
  });

  test('attack and coach voice decline to judge', () {
    final attack = evaluate(tone(220), lastOnsetTUs: 150000);
    expect(attack.verdict, GuitarSingleNoteVerdict.noVerdict);
    expect(attack.reason, GuitarSingleNoteReason.attackWindow);
    final coach = evaluate(tone(220), coachSpeaking: true);
    expect(coach.verdict, GuitarSingleNoteVerdict.noVerdict);
    expect(coach.reason, GuitarSingleNoteReason.coachSpeaking);
  });

  test('a transition between two notes declines to judge', () {
    final samples = [
      ...tone(220).sublist(0, 4096),
      ...tone(440).sublist(0, 4096)
    ];
    final result = evaluate(samples);
    expect(result.verdict, GuitarSingleNoteVerdict.noVerdict);
    expect(result.signedCentsFromTarget, isNull);
  });
}
