import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';
import 'package:ostinato/app/practice/display/before_after.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';

const _diff = PracticeMark.differentNote;
const _unh = PracticeMark.couldNotHear;

NoteOutcome _o(
  int i, {
  PracticeMark mark = PracticeMark.correct,
  double? timing,
  int bar = 0,
}) =>
    NoteOutcome(eventIndex: i, bar: bar, pass: 0, mark: mark, timingMs: timing);

PracticeRunSummary _s(
  List<NoteOutcome> outcomes, {
  int bpm = 80,
  bool calibrated = true,
  bool loopUsed = false,
}) => PracticeRunSummary.of(
  score: PracticeScore.parse('4/4: q q q q'),
  outcomes: outcomes,
  bpm: bpm,
  openBpm: 60,
  targetBpm: 80,
  completed: true,
  loopUsed: loopUsed,
  waitUsed: false,
  timingCalibrated: calibrated,
);

List<NoteOutcome> _four({
  PracticeMark m1 = PracticeMark.correct,
  PracticeMark m2 = PracticeMark.correct,
  double? t,
  int bar = 0,
}) => [
  _o(0, timing: t),
  _o(1, mark: m1, bar: bar),
  _o(2, mark: m2, bar: bar + 1),
  _o(3),
];

void main() {
  test('bayrak varsayılan KAPALI', () {
    expect(ostinatoBeforeAfterEnabled, isFalse);
  });

  group('null durumları', () {
    test('önce ölçülmemiş', () {
      final b = _s(_four(), loopUsed: true);
      expect(b.gate.eligible, isFalse);
      expect(beforeAfterOf(b, _s(_four())), isNull);
    });
    test('sonra ölçülmemiş', () {
      expect(beforeAfterOf(_s(_four()), _s(_four(), loopUsed: true)), isNull);
    });
    test('ikisi de ölçülmemiş', () {
      final x = _s(_four(), loopUsed: true);
      expect(beforeAfterOf(x, x), isNull);
    });
  });

  group('yönler', () {
    test('iyileşme', () {
      final r = beforeAfterOf(_s(_four(m1: _diff, m2: _unh)), _s(_four()))!;
      expect(r.correct.delta, 2);
      expect(r.correct.direction, BeforeAfterDirection.improved);
      expect(r.different.delta, -1);
      expect(r.different.direction, BeforeAfterDirection.improved);
      expect(r.unheard.direction, BeforeAfterDirection.improved);
      expect(r.errorBars.before, 2);
      expect(r.errorBars.after, 0);
      expect(r.errorBars.direction, BeforeAfterDirection.improved);
    });

    test('aynı', () {
      final r = beforeAfterOf(_s(_four(m1: _diff)), _s(_four(m1: _diff)))!;
      for (final m in [
        r.correct,
        r.different,
        r.unheard,
        r.errorBars,
        r.tempoBpm,
      ]) {
        expect(m.delta, 0);
        expect(m.direction, BeforeAfterDirection.same);
      }
    });

    test('farklı (iyileşme olmayan değişim)', () {
      final r = beforeAfterOf(_s(_four()), _s(_four(m1: _diff, m2: _unh)))!;
      expect(r.correct.direction, BeforeAfterDirection.different);
      expect(r.different.direction, BeforeAfterDirection.different);
      expect(r.unheard.direction, BeforeAfterDirection.different);
      expect(r.errorBars.direction, BeforeAfterDirection.different);
    });

    test('tempo değişimi yönsüz', () {
      final up = beforeAfterOf(_s(_four(), bpm: 70), _s(_four(), bpm: 80))!;
      final down = beforeAfterOf(_s(_four(), bpm: 80), _s(_four(), bpm: 70))!;
      expect(up.tempoBpm.delta, 10);
      expect(up.tempoBpm.direction, BeforeAfterDirection.different);
      expect(down.tempoBpm.delta, -10);
      expect(down.tempoBpm.direction, BeforeAfterDirection.different);
    });
  });

  group('medianTimingMs', () {
    test('iki taraf ölçülmüş ve kalibre', () {
      final r = beforeAfterOf(_s(_four(t: 80)), _s(_four(t: 30)))!;
      expect(r.medianTimingMs!.delta, -50);
      expect(r.medianTimingMs!.direction, BeforeAfterDirection.improved);
      final w = beforeAfterOf(_s(_four(t: 30)), _s(_four(t: 80)))!;
      expect(w.medianTimingMs!.direction, BeforeAfterDirection.different);
      final s = beforeAfterOf(_s(_four(t: 30)), _s(_four(t: 30)))!;
      expect(s.medianTimingMs!.direction, BeforeAfterDirection.same);
    });
    test('negatif ham timingMs: özet |·| alır', () {
      PracticeRunSummary run(double t) => _s(_four(t: t));
      final a = beforeAfterOf(run(-80), run(-20))!.medianTimingMs!;
      expect(a.before, 80);
      expect(a.after, 20);
      expect(a.direction, BeforeAfterDirection.improved);
      final b = beforeAfterOf(run(-20), run(60))!.medianTimingMs!;
      expect(b.direction, BeforeAfterDirection.different);
      final c = beforeAfterOf(run(-50), run(50))!.medianTimingMs!;
      expect(c.delta, 0);
      expect(c.direction, BeforeAfterDirection.same);
    });
    test('çift sayıda örnekli medyan (üst orta değer)', () {
      PracticeRunSummary run(List<double> ts) =>
          _s([for (var i = 0; i < ts.length; i++) _o(i, timing: ts[i])]);
      final r = beforeAfterOf(
        run([-80, 20, -40, 60]),
        run([10, -10, 30, -30]),
      )!.medianTimingMs!;
      expect(r.before, 60);
      expect(r.after, 30);
      expect(r.direction, BeforeAfterDirection.improved);
    });
    test('önce null', () {
      expect(
        beforeAfterOf(_s(_four()), _s(_four(t: 30)))!.medianTimingMs,
        isNull,
      );
    });
    test('sonra null', () {
      expect(
        beforeAfterOf(_s(_four(t: 30)), _s(_four()))!.medianTimingMs,
        isNull,
      );
    });
    test('ikisi null', () {
      expect(beforeAfterOf(_s(_four()), _s(_four()))!.medianTimingMs, isNull);
    });
    test('timingCalibrated=false (önce)', () {
      final r = beforeAfterOf(
        _s(_four(t: 30), calibrated: false),
        _s(_four(t: 30)),
      )!;
      expect(r.medianTimingMs, isNull);
    });
    test('timingCalibrated=false (sonra)', () {
      final r = beforeAfterOf(
        _s(_four(t: 30)),
        _s(_four(t: 30), calibrated: false),
      )!;
      expect(r.medianTimingMs, isNull);
    });
  });

  test('determinizm', () {
    final b = _s(_four(m1: _diff, t: 60));
    final a = _s(_four(t: 20));
    final x = beforeAfterOf(b, a)!, y = beforeAfterOf(b, a)!;
    expect(x.correct.delta, y.correct.delta);
    expect(x.errorBars.direction, y.errorBars.direction);
    expect(x.medianTimingMs!.delta, y.medianTimingMs!.delta);
  });
}
