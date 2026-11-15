import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/practice/micro_etude/micro_etude_generator.dart';
import 'package:ostinato/app/practice/micro_etude/micro_etude_models.dart';

/// Test çatısı: farklı tempo/ölçü/sapma/geçiş girdileri (property tarzı).
List<MicroEtudeRequest> allRequests() {
  final out = <MicroEtudeRequest>[];
  const pairs = [
    (40, 41),
    (52, 55),
    (45, 57),
    (76, 40),
    (64, 67),
    (60, 72),
    (47, 52),
    (71, 59),
    (55, 54),
  ];
  for (var bpm = 50; bpm <= 120; bpm += 1) {
    for (final m in EtudeMeter.values) {
      for (var s = 0; s < m.eighthsPerBar; s++) {
        for (final d in RhythmDeviation.values) {
          out.add(
            MicroEtudeRequest(
              miss: RhythmMiss(slot: s, deviation: d),
              bpm: bpm,
              meter: m,
              seed: bpm + s,
            ),
          );
        }
      }
      for (final (a, b) in pairs) {
        out.add(
          MicroEtudeRequest(
            miss: NoteTransitionMiss(fromMidi: a, toMidi: b),
            bpm: bpm,
            meter: m,
            seed: bpm,
          ),
        );
      }
    }
  }
  return out;
}

String _sig(MicroEtude e) =>
    '${e.stages.map((s) => '${s.bpm}x${s.repeats}')}|'
    '${e.phrase.map((b) => b.events.map((v) => '${v.midi}:${v.eighths}').join(','))}|${e.rules}';

void main() {
  final requests = allRequests();

  test('girdi kümesi büyük (property taraması)', () {
    expect(requests.length, greaterThan(3000));
  });

  test('süre her girdide 15–30 sn', () {
    for (final r in requests) {
      final e = MicroEtudeGenerator.generate(r);
      expect(
        e.durationSeconds,
        inInclusiveRange(15.0, 30.0),
        reason: '${r.meter} ${r.bpm} ${r.miss.runtimeType}',
      );
    }
  });

  test('cümle 2–4 ölçü; her ölçü tam uzunlukta; uzunluklar yazılabilir', () {
    for (final r in requests) {
      final e = MicroEtudeGenerator.generate(r);
      expect(e.phrase.length, inInclusiveRange(2, 4));
      expect(e.rules.length, e.phrase.length);
      for (final bar in e.phrase) {
        expect(
          bar.events.fold(0, (a, ev) => a + ev.eighths),
          r.meter.eighthsPerBar,
        );
        for (final ev in bar.events) {
          expect([1, 2, 3, 4, 6, 8], contains(ev.eighths));
        }
      }
      final bpms = e.stages.map((s) => s.bpm).toList();
      expect(bpms, orderedEquals([...bpms]..sort()));
      expect(e.stages.last.bpm, r.bpm);
    }
  });

  test('menzil E2–E5 ve ardışık sıçrama ≤ 12', () {
    for (final r in requests) {
      final e = MicroEtudeGenerator.generate(r);
      int? prev;
      for (final (:bpm, :bar) in e.timeline) {
        expect(bpm, greaterThan(0));
        for (final ev in bar.events) {
          final m = ev.midi;
          if (m == null) continue;
          expect(m, inInclusiveRange(40, 76));
          if (prev != null) {
            expect((m - prev).abs(), lessThanOrEqualTo(12));
          }
          prev = m;
        }
      }
    }
  });

  test('hedef kalıp cümlede var: geçişte A→B bitişik, ritimde hedef slot', () {
    for (final r in requests) {
      final e = MicroEtudeGenerator.generate(r);
      final miss = r.miss;
      if (miss is NoteTransitionMiss) {
        final notes = [
          for (final bar in e.phrase)
            for (final ev in bar.events)
              if (ev.midi != null) ev.midi!,
        ];
        var found = false;
        for (var i = 0; i + 1 < notes.length; i++) {
          if (notes[i] % 12 == miss.fromMidi % 12 &&
              notes[i + 1] % 12 == miss.toMidi % 12) {
            found = true;
          }
        }
        expect(found, isTrue);
      } else if (miss is RhythmMiss) {
        var pos = 0;
        var hit = false;
        for (final ev in e.phrase.first.events) {
          if (pos == miss.slot && !ev.isRest) hit = true;
          pos += ev.eighths;
        }
        expect(hit, isTrue, reason: 'R1 hedef slotta nota içermeli');
      }
    }
  });

  test('tempo kademesi yavaştan hedefe; geçiş kural sırası', () {
    final e = MicroEtudeGenerator.generate(
      const MicroEtudeRequest(
        miss: NoteTransitionMiss(fromMidi: 52, toMidi: 55),
        bpm: 80,
        meter: EtudeMeter.fourFour,
      ),
    );
    expect(e.stages.first.bpm, lessThan(e.stages.last.bpm));
    expect(e.stages.last.bpm, 80);
    expect(e.rules.first, 'T1');
    expect(e.rules.last, 'T4');
  });

  test('determinizm: aynı girdi aynı etüt; tohum değişince değişebilir', () {
    for (final r in requests.take(500)) {
      expect(
        _sig(MicroEtudeGenerator.generate(r)),
        _sig(MicroEtudeGenerator.generate(r)),
      );
    }
    final sigs = {
      for (var seed = 0; seed < 20; seed++)
        _sig(
          MicroEtudeGenerator.generate(
            MicroEtudeRequest(
              miss: const RhythmMiss(slot: 3, deviation: RhythmDeviation.late),
              bpm: 90,
              meter: EtudeMeter.fourFour,
              seed: seed,
            ),
          ),
        ),
    };
    expect(sigs.length, greaterThan(1));
  });

  test('R3: erken → bekle, geç → ön vuruş', () {
    MicroEtude gen(RhythmDeviation d) => MicroEtudeGenerator.generate(
      MicroEtudeRequest(
        miss: RhythmMiss(slot: 3, deviation: d),
        bpm: 60,
        meter: EtudeMeter.fourFour,
      ),
    );
    expect(gen(RhythmDeviation.early).rules, contains('R3-wait'));
    expect(gen(RhythmDeviation.late).rules, contains('R3-leadin'));
  });

  test('geçersiz girdi reddedilir', () {
    expect(
      () => MicroEtudeGenerator.generate(
        const MicroEtudeRequest(
          miss: RhythmMiss(slot: 8, deviation: RhythmDeviation.late),
          bpm: 60,
          meter: EtudeMeter.fourFour,
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => MicroEtudeGenerator.generate(
        const MicroEtudeRequest(
          miss: NoteTransitionMiss(fromMidi: 50, toMidi: 50),
          bpm: 60,
          meter: EtudeMeter.fourFour,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('aralık dışı bpm ve nota sıkıştırılır/katlanır', () {
    final e = MicroEtudeGenerator.generate(
      const MicroEtudeRequest(
        miss: NoteTransitionMiss(fromMidi: 20, toMidi: 100),
        bpm: 400,
        meter: EtudeMeter.threeFour,
      ),
    );
    expect(e.targetBpm, 160);
    expect(e.durationSeconds, inInclusiveRange(15.0, 30.0));
    for (final bar in e.phrase) {
      for (final ev in bar.events) {
        expect(ev.midi == null || (ev.midi! >= 40 && ev.midi! <= 76), isTrue);
      }
    }
  });

  test('katlamadan sonra aynı perdeye inen geçiş reddedilir', () {
    for (final (a, b) in const [(28, 40), (88, 76), (40, 28), (76, 88)]) {
      expect(
        () => MicroEtudeGenerator.generate(
          MicroEtudeRequest(
            miss: NoteTransitionMiss(fromMidi: a, toMidi: b),
            bpm: 80,
            meter: EtudeMeter.fourFour,
          ),
        ),
        throwsArgumentError,
        reason: '$a→$b',
      );
    }
  });
}
