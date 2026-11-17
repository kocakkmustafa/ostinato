import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';
import 'package:ostinato/app/practice/adaptive/adaptive_tempo.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/practice/loop/practice_tempo_ladder.dart';

NoteOutcome _o(int i, PracticeMark mark) =>
    NoteOutcome(eventIndex: i, bar: 0, pass: 0, mark: mark);

/// Steady run: all four notes right. Unsteady: half different.
PracticeRunSummary _run(
  int bpm, {
  bool steady = true,
  bool measured = true,
  int open = 60,
  int target = 80,
}) => PracticeRunSummary.of(
  score: PracticeScore.parse('4/4: q q q q'),
  outcomes: [
    for (var i = 0; i < 4; i++)
      _o(
        i,
        steady || i < 2 ? PracticeMark.correct : PracticeMark.differentNote,
      ),
  ],
  bpm: bpm,
  openBpm: open,
  targetBpm: target,
  completed: true,
  loopUsed: !measured,
  waitUsed: false,
  criteria: const PassCriteria(minAccuracy: .8),
);

void main() {
  test('bayrak varsayılan KAPALI', () {
    expect(ostinatoAdaptiveTempoEnabled, isFalse);
  });

  test('fixture: kararlı/kararsız/ölçülmemiş beklendiği gibi', () {
    expect(_run(70).gate.eligible, isTrue);
    expect(TempoLadder.cleared(_run(70)), isTrue);
    expect(_run(70, steady: false).gate.eligible, isTrue);
    expect(TempoLadder.cleared(_run(70, steady: false)), isFalse);
    expect(_run(70, measured: false).gate.eligible, isFalse);
    expect(TempoLadder.cleared(_run(70, measured: false)), isFalse);
  });

  test('ölçülmemiş koşu: tempo değişmez', () {
    final d = adaptTempo(
      _run(70, measured: false),
      history: [_run(70), _run(70)],
    );
    expect(d.nextBpm, 70);
    expect(d.reason, AdaptiveTempoReason.notMeasured);
  });

  test('geçmiş yok: tek kararlı koşu yükseltmez', () {
    final d = adaptTempo(_run(65));
    expect(d.nextBpm, 65);
    expect(d.reason, AdaptiveTempoReason.keep);
  });

  test('ardışık iki kararlı koşu: bir adım yükselt', () {
    final d = adaptTempo(_run(65), history: [_run(65)]);
    expect(d.nextBpm, 70);
    expect(d.reason, AdaptiveTempoReason.raise);
  });

  test('önceki kararlı koşu başka tempoda ise yükseltme yok', () {
    final d = adaptTempo(_run(70), history: [_run(65)]);
    expect(d.reason, AdaptiveTempoReason.keep);
    expect(d.nextBpm, 70);
  });

  test('ölçülmemiş koşular atlanır, seri bozulmaz', () {
    final d = adaptTempo(
      _run(65),
      history: [_run(65), _run(65, measured: false)],
    );
    expect(d.reason, AdaptiveTempoReason.raise);
  });

  test('kararsız sonra kararlı: yükseltme yok', () {
    final d = adaptTempo(_run(65), history: [_run(65, steady: false)]);
    expect(d.reason, AdaptiveTempoReason.keep);
    expect(d.nextBpm, 65);
  });

  test('hedefi aşmaz: son adım hedefte biter', () {
    final d = adaptTempo(_run(78), history: [_run(78)]);
    expect(d.nextBpm, 80);
    expect(d.reason, AdaptiveTempoReason.raise);
  });

  test('hedefteyken yükseltmez', () {
    final d = adaptTempo(_run(80), history: [_run(80)]);
    expect(d.nextBpm, 80);
    expect(d.reason, AdaptiveTempoReason.keep);
  });

  test('hedefin üstündeki koşu hedefe kenetlenir', () {
    final d = adaptTempo(_run(90, target: 80), history: [_run(90)]);
    expect(d.nextBpm, 80);
    expect(d.reason, AdaptiveTempoReason.keep);
  });

  test('tek kötü koşu düşürmez', () {
    final d = adaptTempo(_run(70, steady: false), history: [_run(70)]);
    expect(d.nextBpm, 70);
    expect(d.reason, AdaptiveTempoReason.keep);
  });

  test('geçmişsiz tek kötü koşu düşürmez', () {
    final d = adaptTempo(_run(70, steady: false));
    expect(d.reason, AdaptiveTempoReason.keep);
  });

  test('ardışık iki kararsız koşu: bir adım yavaşla', () {
    final d = adaptTempo(
      _run(70, steady: false),
      history: [_run(70, steady: false)],
    );
    expect(d.nextBpm, 65);
    expect(d.reason, AdaptiveTempoReason.slowDown);
  });

  test('açılış temposunun altına inmez', () {
    final d = adaptTempo(
      _run(62, steady: false),
      history: [_run(62, steady: false)],
    );
    expect(d.nextBpm, 60);
    expect(d.reason, AdaptiveTempoReason.slowDown);
  });

  test('açılış temposunda yavaşlamaz', () {
    final d = adaptTempo(
      _run(60, steady: false),
      history: [_run(60, steady: false)],
    );
    expect(d.nextBpm, 60);
    expect(d.reason, AdaptiveTempoReason.keep);
  });

  test('özel adım: tek adımda en çok step kadar', () {
    final up = adaptTempo(_run(65), history: [_run(65)], step: 3);
    expect(up.nextBpm, 68);
    final down = adaptTempo(
      _run(70, steady: false),
      history: [_run(70, steady: false)],
      step: 3,
    );
    expect(down.nextBpm, 67);
  });

  test('deterministik: aynı girdi aynı karar', () {
    final a = adaptTempo(_run(65), history: [_run(65)]);
    final b = adaptTempo(_run(65), history: [_run(65)]);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('ölçülmemiş koşu hedef üstündeyse de tempo değişmez', () {
    final d = adaptTempo(_run(90, measured: false, target: 80));
    expect(d.nextBpm, 90);
    expect(d.reason, AdaptiveTempoReason.notMeasured);
  });

  test('geçmiş SIRASI önemli: [kararsız,kararlı] ve [kararlı,kararsız]', () {
    final raise = adaptTempo(
      _run(65),
      history: [_run(65, steady: false), _run(65)],
    );
    expect(raise.reason, AdaptiveTempoReason.raise);
    final keep = adaptTempo(
      _run(65),
      history: [_run(65), _run(65, steady: false)],
    );
    expect(keep.reason, AdaptiveTempoReason.keep);
    expect(keep.nextBpm, 65);
  });

  test('[kararlı@65, kararlı@70] + son@65: yükseltme yok', () {
    final d = adaptTempo(_run(65), history: [_run(65), _run(70)]);
    expect(d.reason, AdaptiveTempoReason.keep);
    expect(d.nextBpm, 65);
  });

  test('adım aralıktan büyükse sınırda kesilir', () {
    final up = adaptTempo(_run(65), history: [_run(65)], step: 50);
    expect(up.nextBpm, 80);
    final down = adaptTempo(
      _run(70, steady: false),
      history: [_run(70, steady: false)],
      step: 50,
    );
    expect(down.nextBpm, 60);
  });

  test('açılış > hedef: atmaz, keep', () {
    final d = adaptTempo(
      _run(70, open: 90, target: 80),
      history: [_run(70, open: 90, target: 80)],
    );
    expect(d.nextBpm, 70);
    expect(d.reason, AdaptiveTempoReason.keep);
  });

  test('step <= 0: ArgumentError', () {
    expect(() => adaptTempo(_run(65), step: 0), throwsArgumentError);
    expect(() => adaptTempo(_run(65), step: -5), throwsArgumentError);
  });

  test('slowDown yönü: biri kararlı biri kararsız → keep', () {
    final a = adaptTempo(_run(70, steady: false), history: [_run(70)]);
    expect(a.reason, AdaptiveTempoReason.keep);
    final b = adaptTempo(_run(70), history: [_run(70, steady: false)]);
    expect(b.reason, AdaptiveTempoReason.keep);
  });
}
