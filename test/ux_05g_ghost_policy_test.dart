// OST-UX-05g (U) — Hayalet Ekran sahne politikasi, oneri tablosu, yerel store,
// kulak/ritim ayrimi, metin taramasi. Beklenen degerler LITERAL.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_message_ids.dart';
import 'package:ostinato/app/practice/loop/listen_try_fix.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/stage/ghost_level_copy.dart';
import 'package:ostinato/app/stage/ghost_policy.dart';
import 'package:ostinato/app/stage/ghost_store.dart';
import 'package:ostinato/app/stage/stage_copy.dart';

final _score = PracticeScore.parse('E2 F2 G2 F2 | E2 F2 G2 F2');
const _c = PracticeMark.correct, _u = PracticeMark.couldNotHear;

PracticeRunSummary _summary(
  List<PracticeMark> marks, {
  bool completed = true,
  bool loop = false,
  bool wait = false,
  int bpm = 60,
}) => PracticeRunSummary.of(
  score: _score,
  outcomes: [
    for (var i = 0; i < marks.length; i++)
      NoteOutcome(
        eventIndex: i,
        bar: _score.events[i].bar,
        pass: 0,
        mark: marks[i],
        reason: marks[i] == _u ? HearingReason.noAttack : null,
        expectedMidi: _score.events[i].midi,
      ),
  ],
  bpm: bpm,
  openBpm: 50,
  targetBpm: 60,
  completed: completed,
  loopUsed: loop,
  waitUsed: wait,
  criteria: const PassCriteria(minAccuracy: .8),
);

PracticeSessionFinished _event(
  PracticeRunSummary s, {
  String id = 'gtr-s1-m02-02',
  String course = 'guitar',
}) => PracticeSessionFinished(
  lessonId: id,
  course: course,
  activeDuration: const Duration(seconds: 12),
  heardEvents: s.correct + s.different,
  summary: s,
);

final _valid = _event(_summary(List.filled(8, _c)));

// Guvenilmez / sayilmayan dort tur (biri duyulan < %80).
final Map<String, PracticeSessionFinished> _bad = {
  'stoppedEarly': _event(_summary(List.filled(4, _c), completed: false)),
  'loopUsed': _event(_summary(List.filled(8, _c), loop: true)),
  'waitUsed': _event(_summary(List.filled(8, _c), wait: true)),
  'heard<80': _event(_summary([_c, _c, _c, _c, _c, _u, _u, _u])),
};

GhostState _reach(GhostLevel level, int valid) {
  var s = GhostPolicy.select(const GhostState(), level);
  for (var i = 0; i < valid; i++) {
    s = GhostPolicy.afterRun(s, _valid, rhythmOnly: false);
  }
  return s;
}

void main() {
  group('05g-2 matris (04-design Ek B, 5.6)', () {
    test('05g-2: dort basamak x oge tablosu (literal)', () {
      expect(GhostItem.values, hasLength(7));
      expect(GhostPolicy.itemsFor(GhostLevel.learn), {
        GhostItem.notation,
        GhostItem.tab,
        GhostItem.beat,
        GhostItem.label,
      });
      expect(GhostPolicy.itemsFor(GhostLevel.reinforce), {
        GhostItem.notation,
        GhostItem.tab,
        GhostItem.beat,
      });
      expect(GhostPolicy.itemsFor(GhostLevel.recall), {
        GhostItem.preStartPreview,
        GhostItem.beat,
      });
      expect(GhostPolicy.itemsFor(GhostLevel.independent), {
        GhostItem.metronome,
        GhostItem.hint,
      });
    });
  });

  group('05g-3 yalniz elle', () {
    test('05g-3: yuksek basarili koslar basamagi DEGISTIRMEZ', () {
      for (final level in GhostLevel.values) {
        final s = _reach(level, 10);
        expect(s.level, level, reason: '$level');
        expect(s.validRuns, 10, reason: 'kontrol: sayac artar ($level)');
      }
    });

    test('05g-3: select yalniz elle; basamak degisince sayac 0', () {
      var s = _reach(GhostLevel.learn, 3);
      s = GhostPolicy.select(s, GhostLevel.recall);
      expect(s.level, GhostLevel.recall);
      expect(s.validRuns, 0);
    });
  });

  group('05g-4 oneri tablosu', () {
    // gecis: (basamak, esik, hedef)
    const trans = <(GhostLevel, int, GhostLevel)>[
      (GhostLevel.learn, 1, GhostLevel.reinforce),
      (GhostLevel.reinforce, 2, GhostLevel.recall),
      (GhostLevel.recall, 3, GhostLevel.independent),
    ];
    for (final (from, th, to) in trans) {
      test('05g-4: $from esik-1 = ${th - 1} gecerli kosu -> oneri yok', () {
        expect(GhostPolicy.suggestion(_reach(from, th)), to, reason: 'kontrol');
        expect(GhostPolicy.suggestion(_reach(from, th - 1)), isNull);
      });
      test('05g-4: $from esik = $th -> $to onerilir', () {
        expect(GhostPolicy.suggestion(_reach(from, th)), to);
      });
      test('05g-4: $from esik+1 = ${th + 1} -> $to onerilir', () {
        expect(GhostPolicy.suggestion(_reach(from, th + 1)), to);
      });
      for (final e in _bad.entries) {
        test('05g-4: $from esik-1 gecerli + ${e.key} -> oneri YOK', () {
          // kontrol: ayni noktada gecerli bir kosu onerir
          expect(GhostPolicy.suggestion(_reach(from, th)), to);
          var s = _reach(from, th - 1);
          s = GhostPolicy.afterRun(s, e.value, rhythmOnly: false);
          expect(GhostPolicy.suggestion(s), isNull, reason: e.key);
          expect(s.level, from);
        });
      }
    }

    test('05g-4: bagimsiz basamakta oneri yok (kontrol: recall onerir)', () {
      expect(GhostPolicy.suggestion(_reach(GhostLevel.recall, 3)), isNotNull);
      expect(GhostPolicy.suggestion(_reach(GhostLevel.independent, 9)), isNull);
    });

    test('05g-4: gecerli kosu olcutu: tam, duyulan>=80, gecit gecti', () {
      expect(GhostPolicy.isValidRun(_valid, rhythmOnly: false), isTrue);
      for (final e in _bad.entries) {
        expect(
          GhostPolicy.isValidRun(e.value, rhythmOnly: false),
          isFalse,
          reason: e.key,
        );
      }
      // 8 nottan 2 duyulmadi = %75 -> sayilmaz
      final seventyFive = _event(_summary([_c, _c, _c, _c, _c, _c, _u, _u]));
      expect(GhostPolicy.isValidRun(seventyFive, rhythmOnly: false), isFalse);
      // 1/8 duyulmadi = %87,5 -> sayilir
      final ok = _event(_summary([_c, _c, _c, _c, _c, _c, _c, _u]));
      expect(GhostPolicy.isValidRun(ok, rhythmOnly: false), isTrue);
    });

    test('05g-4: sayilmayan kosu sayaci SIFIRLAMAZ, ARTIRMAZ da (toplam)', () {
      var s = _reach(GhostLevel.reinforce, 1);
      for (final e in _bad.values) {
        s = GhostPolicy.afterRun(s, e, rhythmOnly: false);
      }
      expect(s.validRuns, 1);
      s = GhostPolicy.afterRun(s, _valid, rhythmOnly: false);
      expect(s.validRuns, 2);
      expect(GhostPolicy.suggestion(s), GhostLevel.recall);
    });
  });

  group('05g-5 durum + metin', () {
    test('05g-5: yarim/dongulu kosu notMeasured; gecmeyen notCounted', () {
      GhostLastRun last(PracticeSessionFinished e) => GhostPolicy.afterRun(
        const GhostState(),
        e,
        rhythmOnly: false,
      ).lastRun;
      expect(last(_bad['stoppedEarly']!), GhostLastRun.notMeasured);
      expect(last(_bad['loopUsed']!), GhostLastRun.notMeasured);
      expect(last(_bad['waitUsed']!), GhostLastRun.notMeasured);
      expect(last(_bad['heard<80']!), GhostLastRun.notCounted);
      expect(last(_valid), GhostLastRun.counted);
    });

    final stems = RegExp(
      r'yetkinlik|kazanıl|ustalaş|mastered|competen|proficien|skill gained|'
      r'yanlış|wrong',
      caseSensitive: false,
    );
    final promise = RegExp(
      r'\b(yet|soon|coming)\b|henüz|yakında',
      caseSensitive: false,
    );

    test(
      '05g-5: Hayalet metinleri (>=14 cift), 14 dil katalogu, yasak yok',
      () {
        expect(GhostLevelCopy.all.length, greaterThanOrEqualTo(14));
        final files = Directory('assets/l10n')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList();
        expect(files, hasLength(14));
        for (final c in <(String, String)>[
          ...GhostLevelCopy.all,
          ...StageCopy.all,
        ]) {
          expect(stems.hasMatch('${c.$1} ${c.$2}'), isFalse, reason: c.$1);
          expect(promise.hasMatch('${c.$1} ${c.$2}'), isFalse, reason: c.$1);
        }
        for (final c in GhostLevelCopy.all) {
          final id = appMessageIds[c];
          expect(id, isNotNull, reason: c.$1);
          for (final f in files) {
            final m =
                (jsonDecode(f.readAsStringSync())
                        as Map<String, dynamic>)['messages']
                    as Map<String, dynamic>;
            final t = m[id] as String?;
            expect(t, isNotNull, reason: '${f.path} ${c.$1}');
            expect(stems.hasMatch(t!), isFalse, reason: '${f.path} $t');
          }
        }
      },
    );

    test('05g-5: literal TR metinler', () {
      final tr = GhostLevelCopy.all.map((c) => c.$2).toSet();
      expect(
        tr,
        containsAll(<String>[
          'Yardım düzeyi',
          'Öğrenme',
          'Pekiştirme',
          'Hatırlama',
          'Bağımsız',
          'Bir basamak yukarı denenebilir',
          'Son koşu ölçülmedi; basamağa sayılmadı',
        ]),
      );
    });
  });

  group('05g-6 ayri yerel anahtar', () {
    test(
      '05g-6: dosya adi, JSON, gidis-donus, bozuk dosya = Ogrenme',
      () async {
        final dir = Directory.systemTemp.createTempSync('ghost05g');
        addTearDown(() => dir.deleteSync(recursive: true));
        final store = FileGhostStore(directoryProvider: () async => dir);
        expect(FileGhostStore.fileName, 'ghost-screen.v1.json');
        await store.save(
          const GhostState(
            level: GhostLevel.recall,
            validRuns: 2,
            lastRun: GhostLastRun.counted,
          ),
        );
        final file = File('${dir.path}/ghost-screen.v1.json');
        expect(file.existsSync(), isTrue);
        final j = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        expect(j['schemaVersion'], 1);
        final back = await store.load();
        expect((back.level, back.validRuns), (GhostLevel.recall, 2));
        // yalniz bu dosya yazildi (V1PracticeRecord deposuna dokunmaz)
        expect(dir.listSync().map((e) => e.uri.pathSegments.last), [
          'ghost-screen.v1.json',
        ]);
        file.writeAsStringSync('{bozuk');
        final bad = await store.load();
        expect((bad.level, bad.validRuns), (GhostLevel.learn, 0));
        expect(GhostPolicy.suggestion(bad), isNull);
        file.writeAsStringSync('{"schemaVersion":99,"level":2}');
        expect((await store.load()).level, GhostLevel.learn);
      },
    );

    test('05g-6: Hayalet kapiyi ve V1PracticeRecord/esikleri DEGISTIRMEZ', () {
      // Esikler sabit (yalniz okunur).
      expect(const PassCriteria(minAccuracy: .8).minHeard, .8);
      expect(FixThresholds.minHeard, .7);
      final s = _bad['heard<80']!.summary;
      final before = V1PracticeRecord(
        lessonId: 'gtr-s1-m02-02',
      ).withRun(_valid.summary, DateTime.utc(2026, 11, 1));
      final gateBefore = s.gate.passed;
      var g = _reach(GhostLevel.recall, 5);
      g = GhostPolicy.afterRun(g, _valid, rhythmOnly: false);
      expect(g.validRuns, 6, reason: 'kontrol: Hayalet sayar');
      expect(before.runs, 1);
      expect(before.passed, isTrue);
      expect(s.gate.passed, gateBefore);
      expect(s.gate.passed, isFalse);
    });
  });

  group('05g-7 kulak/ritim ayrimi (Motion orchestration karari)', () {
    test('05g-7: kulak kosusu (course ear / ear-s id) Hayaleti etkilemez', () {
      final base = _reach(GhostLevel.learn, 0);
      expect(
        GhostPolicy.afterRun(base, _valid, rhythmOnly: false).validRuns,
        1,
        reason: 'kontrol: gitar kosusu sayilir',
      );
      final ear = _event(
        _summary(List.filled(8, _c)),
        id: 'ear-s1-m01-01',
        course: 'ear',
      );
      expect(GhostPolicy.isValidRun(ear, rhythmOnly: false), isFalse);
      final after = GhostPolicy.afterRun(base, ear, rhythmOnly: false);
      expect(
        (after.level, after.validRuns, after.lastRun),
        (GhostLevel.learn, 0, GhostLastRun.none),
      );
      // yalniz id (course gitar gorunse bile ear-s deseni)
      final earId = _event(_summary(List.filled(8, _c)), id: 'ear-s2-m03-01');
      expect(GhostPolicy.isValidRun(earId, rhythmOnly: false), isFalse);
    });

    test('05g-7: ritim-only (isRhythmOnly) kosu Hayaleti etkilemez', () {
      final base = _reach(GhostLevel.reinforce, 1);
      expect(
        GhostPolicy.afterRun(base, _valid, rhythmOnly: false).validRuns,
        2,
        reason: 'kontrol',
      );
      final after = GhostPolicy.afterRun(base, _valid, rhythmOnly: true);
      expect(after.validRuns, 1);
      expect(GhostPolicy.isValidRun(_valid, rhythmOnly: true), isFalse);
    });

    test('05g-7: tersi: Hayalet secimi enstruman kaydini etkilemez', () {
      final rec = V1PracticeRecord(
        lessonId: 'gtr-s1-m02-02',
      ).withRun(_valid.summary, DateTime.utc(2026, 11, 1));
      var g = _reach(GhostLevel.learn, 1);
      g = GhostPolicy.select(g, GhostLevel.independent);
      expect(g.level, GhostLevel.independent, reason: 'kontrol: secim calisir');
      expect(rec.passed, isTrue);
      expect(rec.runs, 1);
    });
  });
}
