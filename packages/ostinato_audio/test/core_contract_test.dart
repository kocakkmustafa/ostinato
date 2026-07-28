import 'package:motion_core/motion_core.dart';
import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:test/test.dart';

/// Proof that the audio path and the family core agree about time.
///
/// The contract is documented in three places (family catalogue §4, our PRD §5,
/// ADR-001) — but a documented contract that nothing executes is a wish. These
/// tests are the executable half: they pin the core by tag, drive the audio
/// engine from `MotionClock`, and fail loudly if the two ever disagree about
/// what "now" means.
void main() {
  const sampleRate = 44100;

  group('Single clock contract (MotionClock ↔ audio timestamps)', () {
    test('audio windows are stamped from the core clock, not an invented zero', () {
      final clock = ManualMotionClock();
      final source = YinPitchSource();
      final signal = SyntheticTone.harmonic(
          f0Hz: ReferencePitches.a4, sampleRate: sampleRate, seconds: 1.0);

      // A session starts 3.2 s after the clock's zero point — the realistic
      // case, since the clock starts with the session and audio capture warms
      // up afterwards.
      clock.advanceUs(3200000);
      final captureStart = clock.nowUs();

      final reading = source.analyze(
        signal.sublist(20000, 20000 + 4096),
        sampleRate: sampleRate,
        tStartUs: captureStart,
      );

      expect(reading.tStartUs, captureStart);
      // The window's own length is derived from the sample count, so an engine
      // that fused this with a pose frame would be intersecting real intervals.
      expect(reading.windowLength.inMicroseconds,
          closeTo(4096 * 1000000 / sampleRate, 2));
      expect(reading.tEndUs, greaterThan(reading.tStartUs));
    });

    test('onsets land on the same timeline as the clock that scheduled them', () {
      final clock = ManualMotionClock();
      clock.advanceUs(5000000); // session has been running 5 s
      final captureStart = clock.nowUs();

      const playedSeconds = [0.20, 0.70, 1.20];
      final signal = SyntheticTone.notesAt(
        onsetSeconds: playedSeconds,
        f0Hz: ReferencePitches.d3,
        sampleRate: sampleRate,
        totalSeconds: 1.6,
      );

      final onsets =
          OnsetDetector().detect(signal, sampleRate: sampleRate, tStartUs: captureStart);

      expect(onsets.length, playedSeconds.length);
      for (var i = 0; i < onsets.length; i++) {
        final expectedUs = captureStart + (playedSeconds[i] * 1000000).round();
        expect((onsets[i].tUs - expectedUs).abs(), lessThan(30000),
            reason: 'onset ${i + 1} drifted off the shared timeline');
      }
    });

    test('a metronome judged against HEARD time forgives a Bluetooth listener', () {
      // The failure this prevents: the engine schedules a beat at t, the user
      // hears it 180 ms later over Bluetooth, plays exactly on what they heard,
      // and a naive engine reports them 180 ms late on every single beat. No
      // tolerance window fixes a constant bias — the grid has to be corrected.
      const outputLatencyUs = 180000;
      final scheduledBeats = [1000000, 1500000, 2000000, 2500000];
      final heardBeats = [for (final b in scheduledBeats) b + outputLatencyUs];

      // The student plays perfectly against what they heard.
      final onsets = [
        for (final b in heardBeats) Onset(tUs: b + 4000, strength: 1),
      ];

      const aligner = MetronomeAligner();
      final naive = aligner.align(onsets: onsets, beatTimesUs: scheduledBeats);
      final corrected = aligner.align(onsets: onsets, beatTimesUs: heardBeats);

      expect(corrected.bias, TimingBias.centred);
      expect(corrected.medianMs, lessThan(10));
      // And the naive version really would have punished them: either it calls
      // them late, or the notes fall outside the match window and it reports
      // that they played nothing at all. Both are wrong; both are prevented by
      // using the core's latency profile.
      final naiveIsWrong =
          naive.bias == TimingBias.dragging || naive.matchedBeats < scheduledBeats.length;
      expect(naiveIsWrong, isTrue,
          reason: 'uncorrected grid must visibly misjudge a latent audio route');
    });
  });

  group('Core ownership boundary', () {
    test('beat grids come from the core, not from us', () {
      // We consume BeatGrid; we do not define tempo. This test exists so that
      // an accidental local "BeatGrid" in the audio package would collide and
      // be caught rather than quietly forking the family contract.
      const grid = ConstantTempoBeatGrid(bpm: 120, firstBeatUs: 0);
      final beats = [for (var i = 0; i < 4; i++) grid.timeOfBeatUs(i)];

      expect(beats, [0, 500000, 1000000, 1500000]);

      final onsets = [for (final b in beats) Onset(tUs: b + 3000, strength: 1)];
      final report = const MetronomeAligner().align(onsets: onsets, beatTimesUs: beats);
      expect(report.coverage, 1.0);
      expect(report.bias, TimingBias.centred);
    });
  });
}
