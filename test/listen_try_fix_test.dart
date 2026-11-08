// OST-P0-06 — "dinle → dene → düzelt → tekrar": saf mantık (tek ana düzeltme,
// güven kapısı, tekrar planı, sonraki egzersiz), metin taraması, bayrak.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_message_ids.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';
import 'package:ostinato/app/practice/loop/listen_try_fix.dart';
import 'package:ostinato/app/practice/loop/listen_try_fix_copy.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/practice/loop/practice_transport.dart';
import 'package:ostinato/app/practice/loop/v1_practice_catalog.dart';

V1Lesson load(String id) => V1Lesson.fromJson(
  jsonDecode(File('content/v1/gtr/$id.json').readAsStringSync())
      as Map<String, dynamic>,
);

final List<V1Lesson> pool = [
  for (final f in Directory('content/v1/gtr').listSync().whereType<File>())
    if (f.path.endsWith('.json'))
      V1Lesson.fromJson(
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
      ),
];

const c = PracticeMark.correct, d = PracticeMark.differentNote;
const u = PracticeMark.couldNotHear;

// Rhythm line: eight beats, onset timing (A3).
final rhythmScore = PracticeScore.parse('4/4: q q q q | q q q q');
const rhythmCriteria = PassCriteria(minAccuracy: .75, onTimeMs: 90);

// Pitch line: eight notes.
final pitchScore = PracticeScore.parse('E2 F2 G2 F2 | E2 F2 G2 F2');

/// [marks] per event; [timing] ms for a "different" onset; [reason] for u.
PracticeRunSummary rhythmRun(
  List<PracticeMark> marks, {
  Map<int, double> timing = const {},
  Map<int, HearingReason> reasons = const {},
  int bpm = 60,
}) => PracticeRunSummary.of(
  score: rhythmScore,
  outcomes: [
    for (var i = 0; i < marks.length; i++)
      NoteOutcome(
        eventIndex: i,
        bar: rhythmScore.events[i].bar,
        pass: 0,
        mark: marks[i],
        reason: marks[i] == u ? reasons[i] ?? HearingReason.noAttack : null,
        timingMs: timing[i],
      ),
  ],
  bpm: bpm,
  openBpm: 60,
  targetBpm: 80,
  completed: true,
  loopUsed: false,
  waitUsed: false,
  criteria: rhythmCriteria,
);

PracticeRunSummary pitchRun(List<PracticeMark> marks, {int bpm = 60}) =>
    PracticeRunSummary.of(
      score: pitchScore,
      outcomes: [
        for (var i = 0; i < marks.length; i++)
          NoteOutcome(
            eventIndex: i,
            bar: pitchScore.events[i].bar,
            pass: 0,
            mark: marks[i],
            reason: marks[i] == u ? HearingReason.unclear : null,
            expectedMidi: pitchScore.events[i].midi,
            observedMidi: marks[i] == d ? 45 : null,
          ),
      ],
      bpm: bpm,
      openBpm: 60,
      targetBpm: 80,
      completed: true,
      loopUsed: false,
      waitUsed: false,
    );

ListenTryFixResult fixOf(
  PracticeRunSummary s, {
  String lesson = 'gtr-s1-m03-04',
  bool free = false,
  int? anchor,
  List<V1Lesson>? p,
}) => ListenTryFix.of(
  s,
  lesson: load(lesson),
  freeTempo: free,
  anchorBpm: anchor,
  pool: p ?? pool,
);

FixCorrection correction(ListenTryFixResult r) {
  expect(r, isA<FixCorrection>(), reason: '$r');
  return r as FixCorrection;
}

void main() {
  group('tek ana düzeltme (hata türü önceliği)', () {
    test('erken: en az iki vuruş belirgin erken, ilk ölçü bildirilir', () {
      final r = correction(
        fixOf(rhythmRun([c, d, c, c, c, d, c, c], timing: {1: -130, 5: -120})),
      );
      expect(r.kind, FixKind.early);
      expect(r.bar, 0);
      expect(r.count, 2);
    });

    test('geç', () {
      final r = correction(
        fixOf(rhythmRun([c, c, d, c, c, c, d, c], timing: {2: 140, 6: 150})),
      );
      expect(r.kind, FixKind.late);
      expect(r.bar, 0);
    });

    test('kaçan vuruş: sinyal iyi, vuruş penceresinde atak yok', () {
      final r = correction(fixOf(rhythmRun([c, c, c, u, c, c, u, c])));
      expect(r.kind, FixKind.missed);
      expect(r.count, 2);
      expect(r.bar, 0);
    });

    test('perde sapması: perde satırında farklı duyulan notalar', () {
      final r = correction(fixOf(pitchRun([c, d, c, c, c, d, c, c])));
      expect(r.kind, FixKind.pitchOff);
      expect(r.bar, 0);
    });

    test('bir seferde yalnız BİR düzeltme: en sık tür; eşitlikte öncelik', () {
      // 3 erken + 2 geç → erken.
      final many = correction(
        fixOf(
          rhythmRun(
            [d, d, d, d, d, c, c, c],
            timing: {0: -100, 1: -100, 2: -100, 3: 100, 4: 100},
          ),
        ),
      );
      expect(many.kind, FixKind.early);
      // 2 erken + 2 geç (eşit) → öncelik sırası: erken önce.
      final tie = correction(
        fixOf(
          rhythmRun(
            [d, d, d, d, c, c, c, c],
            timing: {0: -100, 1: -100, 2: 100, 3: 100},
          ),
        ),
      );
      expect(tie.kind, FixKind.early);
    });

    test('tek örnek düzeltme sayılmaz (tek erken vuruş → net fark yok)', () {
      expect(
        fixOf(rhythmRun([c, d, c, c, c, c, c, c], timing: {1: -150})),
        isA<FixClear>(),
      );
    });

    test('hep doğru → net fark yok', () {
      expect(fixOf(rhythmRun(List.filled(8, c))), isA<FixClear>());
      expect(fixOf(pitchRun(List.filled(8, c))), isA<FixClear>());
    });

    test('belirleyici fark: aynı run aynı sonucu verir (deterministik)', () {
      final s = rhythmRun([c, d, c, c, c, d, c, c], timing: {1: -130, 5: -120});
      final a = correction(fixOf(s)), b = correction(fixOf(s));
      expect((a.kind, a.bar, a.count), (b.kind, b.bar, b.count));
      expect(a.plan.steps, b.plan.steps);
    });
  });

  group(
    'FixClear yalnız ölçülen tutarlılıkta; aksi hâlde hüküm/hızlanma yok',
    () {
      test('(a) doğruluk eşiği geçildi → tutarlı (FixClear)', () {
        final s = rhythmRun([c, c, c, c, c, c, c, c]);
        expect(s.accuracy, 1);
        expect(fixOf(s), isA<FixClear>());
        // Tek erken vuruş: doğruluk %87,5 ≥ %75 → tutarlı.
        expect(
          fixOf(rhythmRun([c, d, c, c, c, c, c, c], timing: {1: -150})),
          isA<FixClear>(),
        );
      });

      test(
        '(b) eşik geçilmedi + baskın tür yok → net fark yok, hızlanma yok',
        () {
          // 12 vuruş: 6 doğru, 2 erken, 2 geç, 2 çok sessiz. Her tür %25 altı
          // (2 < 3), duyulma 10/12; doğruluk 6/10 = %60 < %75.
          final score12 = PracticeScore.parse(
            '4/4: q q q q | q q q q | q q q q',
          );
          final marks = [c, c, c, c, c, c, d, d, d, d, u, u];
          final s = PracticeRunSummary.of(
            score: score12,
            outcomes: [
              for (var i = 0; i < 12; i++)
                NoteOutcome(
                  eventIndex: i,
                  bar: score12.events[i].bar,
                  pass: 0,
                  mark: marks[i],
                  reason: marks[i] == u ? HearingReason.tooQuiet : null,
                  timingMs: i == 6 || i == 7
                      ? -120
                      : i == 8 || i == 9
                      ? 120
                      : null,
                ),
            ],
            bpm: 60,
            openBpm: 60,
            targetBpm: 80,
            completed: true,
            loopUsed: false,
            waitUsed: false,
            criteria: rhythmCriteria,
          );
          expect(s.accuracy, closeTo(.6, 1e-9));
          final r = ListenTryFix.of(
            s,
            lesson: load('gtr-s1-m03-04'),
            freeTempo: false,
            anchorBpm: 45,
          );
          expect(r, isA<FixNoClearDifference>());
          expect(r, isNot(isA<FixClear>()));
          expect(r, isNot(isA<FixCorrection>()));
        },
      );

      test('kanıt ve sayımlar yalnız SON turdan (döngü turları karışmaz)', () {
        // Tur 0: hepsi duyulmadı; tur 1: hepsi doğru → son tur tutarlı.
        final s = PracticeRunSummary.of(
          score: rhythmScore,
          outcomes: [
            for (var p = 0; p < 2; p++)
              for (var i = 0; i < 8; i++)
                NoteOutcome(
                  eventIndex: i,
                  bar: rhythmScore.events[i].bar,
                  pass: p,
                  mark: p == 0 ? u : c,
                  reason: p == 0 ? HearingReason.noAttack : null,
                ),
          ],
          bpm: 60,
          openBpm: 60,
          targetBpm: 80,
          completed: true,
          loopUsed: true,
          waitUsed: false,
          criteria: rhythmCriteria,
        );
        expect(s.heard, .5, reason: 'özet tüm turları sayar');
        expect(fixOf(s), isA<FixClear>(), reason: 'kart yalnız son turu sayar');
      });
    },
  );

  group('güven kapısı: düşük güvende hüküm yok', () {
    test('duyulma %70 altı → ölçemedim, düzeltme yok', () {
      // 5/8 duyuldu (%62,5), duyulanların hepsi erken olsa bile.
      final s = rhythmRun(
        [d, d, d, d, d, u, u, u],
        timing: {0: -120, 1: -120, 2: -120, 3: -120, 4: -120},
      );
      final r = fixOf(s);
      expect(r, isA<FixUnmeasured>());
      expect((r as FixUnmeasured).reason, CouldNotMeasure.weakSignal);
    });

    test('sessiz oda (hiçbir atak) → ölçemedim; sessizlik hüküm değildir', () {
      final r = fixOf(rhythmRun(List.filled(8, u)));
      expect(r, isA<FixUnmeasured>());
    });

    test('zayıf/yüksek/belirsiz sinyal "kaçan vuruş" sayılmaz', () {
      final s = rhythmRun(
        [c, c, c, c, c, c, u, u],
        reasons: {6: HearingReason.tooQuiet, 7: HearingReason.unclear},
      );
      // Duyulma 6/8 = %75 ≥ %70 ama iki nota sinyal kaynaklı: düzeltme yok.
      expect(fixOf(s), isA<FixClear>());
      final playback = rhythmRun(
        [c, c, c, c, c, c, u, u],
        reasons: {6: HearingReason.appPlayback, 7: HearingReason.tooLoud},
      );
      expect(fixOf(playback), isA<FixClear>());
    });

    test('yeterli veri yok: 3 karardan az → ölçemedim', () {
      final s = PracticeRunSummary.of(
        score: rhythmScore,
        outcomes: [
          for (var i = 0; i < 2; i++)
            NoteOutcome(
              eventIndex: i,
              bar: 0,
              pass: 0,
              mark: d,
              timingMs: -150,
            ),
        ],
        bpm: 60,
        openBpm: 60,
        targetBpm: 80,
        completed: false,
        loopUsed: false,
        waitUsed: false,
        criteria: rhythmCriteria,
      );
      final r = fixOf(s);
      expect(r, isA<FixUnmeasured>());
      expect((r as FixUnmeasured).reason, CouldNotMeasure.tooFewNotes);
    });

    test('eşikler tam sınırda: %70 duyulma kabul, altı ret', () {
      // 10 vuruşluk satır: 7 duyuldu = %70 → yeterli; 6 = %60 → ölçemedim.
      final s10 = PracticeScore.parse('4/4: q q q q | q q q q | q q');
      PracticeRunSummary run(int heard) => PracticeRunSummary.of(
        score: s10,
        outcomes: [
          for (var i = 0; i < 10; i++)
            NoteOutcome(
              eventIndex: i,
              bar: s10.events[i].bar,
              pass: 0,
              mark: i < heard ? (i < 3 ? d : c) : u,
              reason: i < heard ? null : HearingReason.tooQuiet,
              timingMs: i < 3 ? -120 : null,
            ),
        ],
        bpm: 60,
        openBpm: 60,
        targetBpm: 80,
        completed: true,
        loopUsed: false,
        waitUsed: false,
        criteria: rhythmCriteria,
      );
      expect(
        ListenTryFix.of(
          run(7),
          lesson: load('gtr-s1-m03-04'),
          freeTempo: false,
        ),
        isA<FixCorrection>(),
      );
      expect(
        ListenTryFix.of(
          run(6),
          lesson: load('gtr-s1-m03-04'),
          freeTempo: false,
        ),
        isA<FixUnmeasured>(),
      );
    });
  });

  group('tekrar planı', () {
    test('kademeli tempo: %75 → mevcut → hedef; ilk adım yavaş', () {
      expect(ListenTryFix.tempoSteps(anchorBpm: 60, targetBpm: 80), [
        45,
        60,
        80,
      ]);
      final r = correction(
        fixOf(rhythmRun([c, d, c, c, c, d, c, c], timing: {1: -130, 5: -120})),
      );
      expect(r.plan.steps, [45, 60, 80]);
      expect(r.plan.nextBpm, 45);
      // Yavaş adım kısa bölümü döngüler (hata ölçüsü ile bir sonraki).
      expect(r.plan.loop, (first: 0, last: 1));
    });

    test('düzeltme sürerken çapa korunur: aynı tempo tekrar önerilir', () {
      final erken = [c, d, c, c, c, d, c, c];
      final slow = correction(
        fixOf(
          rhythmRun(erken, timing: {1: -130, 5: -120}, bpm: 45),
          anchor: 60,
        ),
      );
      expect(slow.plan.steps, [45, 60, 80]);
      expect(slow.plan.nextBpm, 45, reason: 'üst adıma geçilmez');
      expect(slow.plan.loop, (first: 0, last: 1));
      final atAnchor = correction(
        fixOf(rhythmRun(erken, timing: {1: -130, 5: -120}), anchor: 60),
      );
      expect(atAnchor.plan.nextBpm, 60);
      expect(atAnchor.plan.loop, isNull);
      final high = correction(
        fixOf(
          rhythmRun(erken, timing: {1: -130, 5: -120}, bpm: 80),
          anchor: 60,
        ),
      );
      expect(high.plan.nextBpm, 80);
    });

    test(
      'düzeltme geçince (FixClear) çapadan itibaren bir üst adıma tırman',
      () {
        final clean = List.filled(8, c);
        final r45 = fixOf(rhythmRun(clean, bpm: 45), anchor: 60);
        expect(r45, isA<FixClear>());
        expect((r45 as FixClear).nextBpm, 60);
        final r60 = fixOf(rhythmRun(clean, bpm: 60), anchor: 60);
        expect((r60 as FixClear).nextBpm, isNull, reason: 'çapaya ulaşıldı');
        expect((fixOf(rhythmRun(clean)) as FixClear).nextBpm, isNull);
        expect(
          (fixOf(rhythmRun(clean, bpm: 45), anchor: 60, free: true) as FixClear)
              .nextBpm,
          isNull,
        );
      },
    );

    test('tempo aralığı: adımlar 40%–120% içinde, tekrarsız, artan', () {
      for (final (a, t) in [(20, 20), (24, 60), (200, 60), (60, 60)]) {
        final s = ListenTryFix.tempoSteps(anchorBpm: a, targetBpm: t);
        for (var i = 0; i < s.length; i++) {
          expect(s[i], greaterThanOrEqualTo(20));
          if (i > 0) expect(s[i], greaterThan(s[i - 1]));
        }
        expect(s, isNotEmpty);
        expect(s.first, greaterThanOrEqualTo(PracticeTempo.minBpm(t)));
        expect(s.last, lessThanOrEqualTo(PracticeTempo.maxBpm(t)));
      }
      // Alt sınır: 24 BPM çapa, hedef 60 → %75 = 18 < min 24 → 24'e kenetlenir.
      expect(ListenTryFix.tempoSteps(anchorBpm: 24, targetBpm: 60).first, 24);
      expect(PracticeTempo.minBpm(60), 24);
      // Üst sınır: 200 BPM çapa, hedef 60 → en fazla %120 = 72.
      expect(ListenTryFix.tempoSteps(anchorBpm: 200, targetBpm: 60).last, 72);
      expect(PracticeTempo.maxBpm(60), 72);
    });

    test('serbest tempo (klik yok): adım yok, yalnız metin', () {
      final r = correction(
        fixOf(
          rhythmRun([c, d, c, c, c, d, c, c], timing: {1: -130, 5: -120}),
          free: true,
        ),
      );
      expect(r.plan.steps, isEmpty);
      expect(r.plan.nextBpm, isNull);
    });

    test(
      'sonraki egzersiz hatanın türünden: zamanlama → ritim, perde → perde',
      () {
        final cur = load('gtr-s1-m03-04');
        for (final k in [FixKind.early, FixKind.late, FixKind.missed]) {
          final n = ListenTryFix.nextExercise(k, lesson: cur, pool: pool)!;
          expect(
            V1PracticeCatalog.scoreOf(n)!.isRhythmOnly,
            isTrue,
            reason: '$k',
          );
          expect(n.id.compareTo(cur.id), lessThan(0));
        }
        expect(
          ListenTryFix.nextExercise(FixKind.early, lesson: cur, pool: pool)!.id,
          'gtr-s1-m03-03',
        );
        final curPitch = load('gtr-s1-m02-05');
        final p = ListenTryFix.nextExercise(
          FixKind.pitchOff,
          lesson: curPitch,
          pool: pool,
        )!;
        expect(V1PracticeCatalog.scoreOf(p)!.hasPitches, isTrue);
        expect(p.id.compareTo(curPitch.id), lessThan(0));
        expect(p.course, curPitch.course);
      },
    );

    test('havuz boşsa / önceki ders yoksa öneri yok (uydurma yok)', () {
      final cur = load('gtr-s1-m03-04');
      expect(
        ListenTryFix.nextExercise(FixKind.early, lesson: cur, pool: const []),
        isNull,
      );
      expect(
        ListenTryFix.nextExercise(
          FixKind.early,
          lesson: pool.firstWhere((l) => l.id == 'gtr-s1-m02-02'),
          pool: pool,
        ),
        isNull,
        reason: 'ilk ders; öncesinde ritim dersi yok',
      );
    });
  });

  group('metin ve bayrak', () {
    final banned = RegExp(
      r'wrong|incorrect|mistake|error|fail|yanlış|hata|başarısız',
      caseSensitive: false,
    );

    test('yeni EN/TR metinlerde yargılayıcı kelime yok', () {
      for (final (en, tr) in ListenTryFixCopy.all) {
        expect(banned.hasMatch(en), isFalse, reason: en);
        expect(banned.hasMatch(tr), isFalse, reason: tr);
      }
    });

    test('yeni metinler 14 katalogun tamamında yargılayıcı kelime içermez', () {
      final words = <String, RegExp>{
        'en': RegExp(
          r'wrong|incorrect|mistake|error|fail|\bbad\b',
          caseSensitive: false,
        ),
        'tr': RegExp(r'yanlış|hata|başarısız|kötü', caseSensitive: false),
        'ar': RegExp('خطأ|خاطئ|فشل|سيئ'),
        'de': RegExp(
          r'falsch|Fehler|fehlgeschlagen|schlecht|scheiter',
          caseSensitive: false,
        ),
        'es-419': RegExp(
          r'incorrect|error|equivoc|fall[oó]|fallo|\bmal\b|malo',
          caseSensitive: false,
        ),
        'fr': RegExp(
          r'\bfaux\b|erreur|incorrect|échec|échou|mauvais|raté',
          caseSensitive: false,
        ),
        'hi': RegExp('गलत|ग़लत|त्रुटि|असफल|विफल|बुरा'),
        'id': RegExp(r'salah|kesalahan|gagal|buruk', caseSensitive: false),
        'it': RegExp(
          r'sbagliat|errore|errat|falliment|fallit|cattiv|\bmale\b',
          caseSensitive: false,
        ),
        'ja': RegExp('間違|誤|失敗|ダメ|悪'),
        'ko': RegExp('틀렸|틀린|오류|실패|잘못|나쁜'),
        'pl': RegExp(
          r'źle|błąd|nieprawidłow|niepoprawn|porażk|zły',
          caseSensitive: false,
        ),
        'pt-BR': RegExp(
          r'errad|\berro|incorret|falh|ruim|\bmau\b',
          caseSensitive: false,
        ),
        'zh-Hans': RegExp('错|失败|不对|糟|坏'),
      };
      expect(words, hasLength(14));
      for (final entry in words.entries) {
        final raw =
            jsonDecode(File('assets/l10n/${entry.key}.json').readAsStringSync())
                as Map<String, dynamic>;
        final messages = raw['messages'] as Map<String, dynamic>;
        for (final pair in ListenTryFixCopy.all) {
          final text = messages[appMessageIds[pair]] as String?;
          expect(text, isNotNull, reason: '${entry.key} ${pair.$1}');
          expect(
            entry.value.hasMatch(text!),
            isFalse,
            reason: '${entry.key}: $text',
          );
        }
      }
    });

    test('her yeni metnin id\'si tabloda ve yer tutucuları tutarlı', () {
      for (final pair in ListenTryFixCopy.all) {
        expect(appMessageIds.containsKey(pair), isTrue, reason: pair.$1);
      }
      expect(ListenTryFixCopy.all.toSet(), hasLength(11));
    });

    test('bayrak varsayılan KAPALI', () {
      expect(ostinatoListenTryFixRepeatOpen, isFalse);
    });

    test('kaynak: kırmızı/hüküm rengi ve ağ yok', () {
      for (final f in [
        'lib/app/practice/loop/listen_try_fix.dart',
        'lib/app/practice/loop/listen_try_fix_card.dart',
        'lib/app/practice/loop/listen_try_fix_copy.dart',
      ]) {
        final src = File(f).readAsStringSync();
        expect(src, isNot(contains('dart:io')), reason: f);
        expect(src, isNot(contains('http')), reason: f);
        expect(src, isNot(contains('Colors.red')), reason: f);
        expect(src, isNot(contains('errorColor')), reason: f);
      }
    });
  });
}
