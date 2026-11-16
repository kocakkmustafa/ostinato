import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/practice/micro_etude/micro_etude_binder.dart';
import 'package:ostinato/app/practice/micro_etude/micro_etude_generator.dart';
import 'package:ostinato/app/practice/micro_etude/micro_etude_models.dart';
import 'package:ostinato/app/practice/micro_etude/midi_validator.dart';
import 'package:ostinato/app/practice/micro_etude/midi_writer.dart';
import 'package:ostinato/app/practice/micro_etude/musicxml_validator.dart';
import 'package:ostinato/app/practice/micro_etude/musicxml_writer.dart';

NoteOutcome _o(
  int i, {
  PracticeMark mark = PracticeMark.correct,
  int? expected,
  int? observed,
  double? timing,
  int bar = 0,
  int pass = 0,
}) => NoteOutcome(
  eventIndex: i,
  bar: bar,
  pass: pass,
  mark: mark,
  expectedMidi: expected,
  observedMidi: observed,
  timingMs: timing,
);

PracticeRunSummary _summary(
  List<NoteOutcome> outcomes, {
  String line = 'q q q q',
  bool completed = true,
  bool loopUsed = false,
  int bpm = 80,
  PassCriteria criteria = const PassCriteria(minAccuracy: .8),
}) => PracticeRunSummary.of(
  score: PracticeScore.parse('4/4: $line'),
  outcomes: outcomes,
  bpm: bpm,
  openBpm: 60,
  targetBpm: 80,
  completed: completed,
  loopUsed: loopUsed,
  waitUsed: false,
  criteria: criteria,
);

const _diff = PracticeMark.differentNote;

/// Nota satırı: 4 çeyrek, 2. nota farklı duyuldu (perde hatası).
PracticeRunSummary _pitchMiss({int bpm = 80, PassCriteria? criteria}) =>
    _summary(
      [
        _o(0, expected: 52),
        _o(1, mark: _diff, expected: 55, observed: 54),
        _o(2, expected: 52),
        _o(3, expected: 52),
      ],
      line: 'E3 G3 E3 E3',
      bpm: bpm,
      criteria: criteria ?? const PassCriteria(minAccuracy: .8),
    );

PracticeRunSummary _rhythmMiss(double t, {int bpm = 80}) => _summary(
  [
    _o(0, timing: 5),
    _o(1, timing: 10),
    _o(2, mark: _diff, timing: t),
    _o(3, timing: -3),
  ],
  bpm: bpm,
  criteria: const PassCriteria(minAccuracy: .75, onTimeMs: 90),
);

void main() {
  test('bayrak varsayılan KAPALI', () {
    expect(ostinatoMicroEtudeEnabled, isFalse);
  });

  group('null durumları', () {
    test('ölçülmemiş koşu', () {
      final s = _summary(
        [_o(0), _o(1, mark: _diff, timing: 200)],
        loopUsed: true,
        criteria: const PassCriteria(minAccuracy: .5, onTimeMs: 90),
      );
      expect(s.gate.eligible, isFalse);
      expect(
        microEtudeRequestFromSummary(s, meter: EtudeMeter.fourFour, seed: 1),
        isNull,
      );
    });

    test('yarım kalan koşu', () {
      final s = _summary([_o(0, mark: _diff, timing: 200)], completed: false);
      expect(
        microEtudeRequestFromSummary(s, meter: EtudeMeter.fourFour, seed: 1),
        isNull,
      );
    });

    test('hata yok', () {
      final s = _summary([for (var i = 0; i < 4; i++) _o(i, timing: 4)]);
      expect(
        microEtudeRequestFromSummary(s, meter: EtudeMeter.fourFour, seed: 1),
        isNull,
      );
    });

    test('yalnız duyulamayan nota karar sayılmaz', () {
      final s = _summary([
        _o(0),
        _o(1, mark: PracticeMark.couldNotHear),
        _o(2),
        _o(3),
      ]);
      expect(
        microEtudeRequestFromSummary(s, meter: EtudeMeter.fourFour, seed: 1),
        isNull,
      );
    });

    test('birden çok perde hatası desteklenmez', () {
      final s = _summary([
        _o(0, expected: 52),
        _o(1, mark: _diff, expected: 55, observed: 54),
        _o(2, mark: _diff, expected: 52, observed: 50),
        _o(3, expected: 52),
      ], line: 'E3 G3 E3 E3');
      expect(
        microEtudeRequestFromSummary(s, meter: EtudeMeter.fourFour, seed: 1),
        isNull,
      );
    });

    test('önceki nota bilinmiyorsa geçiş kurulamaz', () {
      final s = _summary([
        _o(0, mark: _diff, expected: 55, observed: 54),
        _o(1),
        _o(2),
        _o(3),
      ]);
      expect(
        microEtudeRequestFromSummary(s, meter: EtudeMeter.fourFour, seed: 1),
        isNull,
      );
    });
  });

  group('eşleme', () {
    test('ritim satırı: geç hata → RhythmMiss(late), nota ve yuva', () {
      final r = microEtudeRequestFromSummary(
        _rhythmMiss(140),
        meter: EtudeMeter.fourFour,
        seed: 9,
      )!;
      final m = r.miss as RhythmMiss;
      expect(m.deviation, RhythmDeviation.late);
      expect(m.slot, EtudeMeter.fourFour.beatSlots[2]);
      expect(r.bpm, 80);
      expect(r.meter, EtudeMeter.fourFour);
      expect(r.seed, 9);
    });

    test('ritim satırı: erken hata → early', () {
      final m =
          microEtudeRequestFromSummary(
                _rhythmMiss(-150),
                meter: EtudeMeter.sixEight,
                seed: 1,
              )!.miss
              as RhythmMiss;
      expect(m.deviation, RhythmDeviation.early);
      expect(EtudeMeter.sixEight.beatSlots, contains(m.slot));
    });

    test('nota satırı: zamanlama eşiği aşılırsa ritim, nota taşınır', () {
      final s = _summary([
        _o(0, expected: 52, timing: 5),
        _o(1, mark: _diff, expected: 55, observed: 55, timing: 180),
        _o(2, expected: 52, timing: 5),
        _o(3, expected: 52, timing: 5),
      ], line: 'E3 G3 E3 E3');
      final m =
          microEtudeRequestFromSummary(
                s,
                meter: EtudeMeter.fourFour,
                seed: 1,
              )!.miss
              as RhythmMiss;
      expect(m.deviation, RhythmDeviation.late);
      expect(m.midi, 55);
    });

    test('tek perde hatası → NoteTransitionMiss(önceki → hatalı)', () {
      final m =
          microEtudeRequestFromSummary(
                _pitchMiss(),
                meter: EtudeMeter.fourFour,
                seed: 1,
              )!.miss
              as NoteTransitionMiss;
      expect((m.fromMidi, m.toMidi), (52, 55));
    });

    test('son geçişin son turu esas alınır', () {
      final s = _summary([
        _o(0, expected: 52),
        _o(1, mark: _diff, expected: 55, observed: 54, pass: 0),
        _o(1, expected: 55, pass: 1),
        _o(2, expected: 52),
        _o(3, expected: 52),
      ], line: 'E3 G3 E3 E3');
      expect(
        microEtudeRequestFromSummary(s, meter: EtudeMeter.fourFour, seed: 1),
        isNull,
      );
    });
  });

  test('deterministik: aynı girdi → aynı istek ve aynı etüt', () {
    MicroEtudeRequest make() => microEtudeRequestFromSummary(
      _pitchMiss(),
      meter: EtudeMeter.threeFour,
      seed: 42,
    )!;
    final a = make(), b = make();
    final ma = a.miss as NoteTransitionMiss, mb = b.miss as NoteTransitionMiss;
    expect(
      (ma.fromMidi, ma.toMidi, a.bpm, a.seed),
      (mb.fromMidi, mb.toMidi, b.bpm, b.seed),
    );
    expect(
      MicroEtudeGenerator.generate(a).rules,
      MicroEtudeGenerator.generate(b).rules,
    );
  });

  test('bpm üreticinin aralığına kıstırılır', () {
    int bpmOf(int bpm) => microEtudeRequestFromSummary(
      _pitchMiss(bpm: bpm),
      meter: EtudeMeter.fourFour,
      seed: 1,
    )!.bpm;
    expect(bpmOf(10), MicroEtudeGenerator.minBpm);
    expect(bpmOf(500), MicroEtudeGenerator.maxBpm);
    expect(bpmOf(100), 100);
  });

  test('uçtan uca: istek etüt üretir, MIDI ve MusicXML doğrulanır', () {
    final requests = [
      for (final meter in EtudeMeter.values) ...[
        for (final bpm in [10, 40, 80, 160, 500]) ...[
          microEtudeRequestFromSummary(
            _pitchMiss(bpm: bpm),
            meter: meter,
            seed: bpm,
          ),
          microEtudeRequestFromSummary(
            _rhythmMiss(140, bpm: bpm),
            meter: meter,
            seed: bpm,
          ),
          microEtudeRequestFromSummary(
            _rhythmMiss(-140, bpm: bpm),
            meter: meter,
            seed: bpm,
          ),
        ],
      ],
    ];
    expect(requests, everyElement(isNotNull));
    for (final r in requests) {
      final e = MicroEtudeGenerator.generate(r!);
      expect(e.phrase, isNotEmpty);
      expect(e.durationSeconds, inInclusiveRange(15, 30.5));
      final midi = validateMidi(MidiWriter.write(e));
      final xml = validateMusicXml(MusicXmlWriter.write(e));
      expect(midi.isValid, isTrue, reason: '$midi');
      expect(xml.isValid, isTrue, reason: '$xml');
    }
  });
}
