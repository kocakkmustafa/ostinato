import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:test/test.dart';

/// Chord recognition without a learned model, because the obvious learned
/// model (Basic Pitch) carries weights trained on non-commercially-licensed
/// datasets (M-O-33). This is arithmetic we own outright — the open question
/// was never whether it is legal but whether it is *good enough*, and that is
/// what these tests pin down.
///
/// What they establish: the algorithm separates the eight open shapes on
/// synthetic material, and refuses when it should. What they do NOT establish:
/// accuracy on a real guitar. Synthetic strings have exact intonation, no fret
/// buzz, no muted-string thud and no ringing neighbour — a real recording is
/// harder in ways no synthesised fixture reproduces.
void main() {
  const sampleRate = 44100;
  final chords = SyntheticTone.openGuitarChords;

  /// The window a drill would actually score: past the strum spread, well
  /// inside the sustain.
  List<double> played(List<int> midi, {String condition = 'clean'}) {
    var s = SyntheticTone.chord(
        midiNotes: midi, sampleRate: sampleRate, seconds: 1.5);
    s = switch (condition) {
      'noisy10' => SyntheticTone.addNoise(s, snrDb: 10),
      'noisy5' => SyntheticTone.addNoise(s, snrDb: 5),
      'phone' => SyntheticTone.phoneHighpass(s, sampleRate: sampleRate),
      _ => s,
    };
    return s.sublist((0.3 * sampleRate).round(), (0.7 * sampleRate).round());
  }

  /// A drill teaches these eight shapes and no sevenths, so recognition is
  /// restricted to them. Measured effect: major-chord margins improve up to
  /// 2.2× (G), because the dominant-7th template is a *superset* of the major
  /// triad and was therefore always the nearest rival.
  final drillOnly = [
    for (final name in chords.keys)
      ChordTemplate.all().firstWhere((ChordTemplate t) => t.name == name)
  ];

  group('the eight open shapes are recognised', () {
    for (final condition in ['clean', 'noisy10', 'noisy5', 'phone']) {
      test(condition, () {
        final detector = ChordDetector(templates: drillOnly);
        for (final entry in chords.entries) {
          final reading =
              detector.detect(played(entry.value, condition: condition),
                  sampleRate: sampleRate);
          expect(reading, isNotNull,
              reason: '${entry.key} was refused under $condition');
          expect(reading!.chord.name, entry.key,
              reason: 'heard ${reading.chord.name} for ${entry.key} '
                  '(margin ${reading.runnerUpMargin})');
        }
      });
    }
  });

  test('a wrong chord is named as the chord actually played', () {
    // The product case. `chord_correctness` compares played against expected,
    // so naming the wrong chord *correctly* is the whole job — a detector that
    // charitably reports the expected chord would be useless.
    final reading = ChordDetector(templates: drillOnly)
        .detect(played(chords['Em']!), sampleRate: sampleRate);
    expect(reading?.chord.name, 'Em');
  });

  test('what is not a chord is refused, not guessed', () {
    const detector = ChordDetector();
    for (final entry in {'single note': [40], 'bare interval': [40, 47]}.entries) {
      expect(detector.detect(played(entry.value), sampleRate: sampleRate), isNull,
          reason: '${entry.key} produced a chord verdict');
    }
  });

  test('a window too short to resolve the low register is refused', () {
    // 100 ms cannot separate semitones ~5 Hz apart at the bottom of a guitar.
    // The blurred chromagram would still yield a confident-looking winner,
    // which is exactly the failure this refusal prevents.
    final short = SyntheticTone.chord(
        midiNotes: chords['E']!, sampleRate: sampleRate, seconds: 0.1);
    expect(const ChromaAnalyzer().analyze(short, sampleRate: sampleRate), isNull);
  });

  test('narrowing the template set widens the margin it is judged on', () {
    // The measured claim behind restricting the field. If this ever stops
    // holding, the restriction has stopped paying for itself.
    for (final name in ['E', 'D', 'G']) {
      final wide = const ChordDetector()
          .detect(played(chords[name]!), sampleRate: sampleRate)!;
      final narrow = ChordDetector(templates: drillOnly)
          .detect(played(chords[name]!), sampleRate: sampleRate)!;
      expect(narrow.runnerUpMargin, greaterThan(wide.runnerUpMargin * 1.3),
          reason: '$name gained only '
              '${(narrow.runnerUpMargin / wide.runnerUpMargin).toStringAsFixed(2)}×');
    }
  });

  test('the reported margin is a real comparison, never a constant', () {
    // Guarding against the failure that cost this project a night elsewhere:
    // a confidence number the code invented because it could not measure one.
    // Distinct chords must produce distinct margins.
    final margins = <double>{
      for (final name in ['E', 'A', 'D', 'G', 'C'])
        ChordDetector(templates: drillOnly)
            .detect(played(chords[name]!), sampleRate: sampleRate)!
            .runnerUpMargin
    };
    expect(margins.length, greaterThan(1),
        reason: 'every chord reported an identical margin — that is a '
            'synthesised constant, not a measurement');
  });
}
