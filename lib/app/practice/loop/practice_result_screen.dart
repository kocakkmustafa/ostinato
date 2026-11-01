import 'package:flutter/material.dart';

import '../../app_locale.dart';
import '../../app_theme.dart';
import '../../curriculum/v1_lesson.dart';
import '../../design/ostinato_theme.dart';
import '../../design/widgets.dart';
import 'practice_marks.dart';
import 'practice_outcome.dart';
import 'practice_score.dart';
import 'practice_visual_theme.dart';

/// What the learner chose on the result screen.
sealed class ResultAction {
  const ResultAction();
}

final class ResultActionNextLesson extends ResultAction {
  const ResultActionNextLesson();
}

final class ResultActionRetry extends ResultAction {
  const ResultActionRetry();
}

/// Open the setup wizard (heard rate too low: the microphone, not the player).
final class ResultActionCheckSetup extends ResultAction {
  const ResultActionCheckSetup();
}

final class ResultActionRaiseTempo extends ResultAction {
  const ResultActionRaiseTempo();
}

final class ResultActionPerformance extends ResultAction {
  const ResultActionPerformance();
}

final class ResultActionLoop extends ResultAction {
  const ResultActionLoop(this.first, this.last, {this.slower = false});
  final int first, last;
  final bool slower;
}

/// F2.5 result (`4-rakip-arayuzleri` §6.6 "Sonuç ekranı"): three big
/// counters, accuracy and heard rates, the measured gate with its thresholds
/// written out, an error map whose bars can be looped, and one suggested next
/// step. Never the word "wrong"; a low heard rate is the microphone's problem.
class PracticeResultScreen extends StatelessWidget {
  const PracticeResultScreen({
    super.key,
    required this.lesson,
    required this.score,
    required this.summary,
    this.progressSaved = true,
    this.nextLessonOpened = false,
    this.hasNextLesson = false,
  });

  final V1Lesson lesson;
  final PracticeScore score;
  final PracticeRunSummary summary;
  final bool progressSaved;
  final bool nextLessonOpened;
  final bool hasNextLesson;

  String _pct(double v) => '${(v * 100).round()}';

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final s = summary;
    final gate = s.gate;
    return Scaffold(
      backgroundColor: palette.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GlassIconButton(
                    icon: '‹',
                    semanticLabel: localized(context, 'Back', 'Geri'),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lesson.title.of(context),
                      style: hankenText(size: 17, weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _counters(context),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line(
                      context,
                      localized(context, 'Accuracy', 'Doğruluk'),
                      s.accuracy == null ? '—' : '%${_pct(s.accuracy!)}',
                      key: const Key('result-accuracy'),
                    ),
                    _line(
                      context,
                      localized(context, 'Heard', 'Duyulma'),
                      '%${_pct(s.heard)}',
                      key: const Key('result-heard'),
                    ),
                    _line(
                      context,
                      localized(context, 'Tempo', 'Tempo'),
                      '♩=${s.bpm} / ${s.targetBpm}',
                    ),
                    _line(
                      context,
                      localized(context, 'Timing', 'Zamanlama'),
                      s.medianTimingMs == null
                          ? localized(
                              context,
                              'calibrate first',
                              'önce kalibrasyon',
                            )
                          : '${s.medianTimingMs!.round()} ms',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localized(
                        context,
                        "Accuracy counts only the notes I could decide; \"couldn't hear\" is reported apart.",
                        'Doğruluk yalnız karar verebildiğim notaları sayar; "duyamadım" ayrı raporlanır.',
                      ),
                      style: hankenText(size: 11.5, color: palette.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _gate(context, gate),
              const SizedBox(height: 12),
              _errorMap(context),
              const SizedBox(height: 16),
              _nextStep(context),
              const SizedBox(height: 8),
              if (gate.passed && !gate.completed)
                OutlinedButton(
                  key: const Key('result-target-run'),
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(const ResultActionPerformance()),
                  child: Text(
                    localized(
                      context,
                      'Play it at the target tempo',
                      'Hedef tempoda çal',
                    ),
                  ),
                )
              else
                OutlinedButton(
                  key: const Key('result-retry'),
                  onPressed: () =>
                      Navigator.of(context).pop(const ResultActionRetry()),
                  child: Text(localized(context, 'Try again', 'Tekrar dene')),
                ),
              if (!progressSaved)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    localized(
                      context,
                      'This result could not be saved on the device.',
                      'Bu sonuç cihaza kaydedilemedi.',
                    ),
                    style: hankenText(size: 12, color: palette.warnInk),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _counters(BuildContext context) {
    final theme = PracticeVisualThemeScope.of(context);
    Widget cell(PracticeMark m, int n, String name) {
      final st = theme.style(m);
      return Expanded(
        child: Semantics(
          label: '$name $n',
          child: ExcludeSemantics(
            child: Column(
              children: [
                Text(
                  '${st.symbol} $n',
                  key: Key('result-count-${m.name}'),
                  style: hankenText(
                    size: 26,
                    weight: FontWeight.w600,
                    color: st.color,
                  ),
                ),
                Text(name, style: hankenText(size: 12)),
              ],
            ),
          ),
        ),
      );
    }

    return GlassCard(
      child: Row(
        children: [
          cell(
            PracticeMark.correct,
            summary.correct,
            localized(context, 'Correct', 'Doğru'),
          ),
          cell(
            PracticeMark.differentNote,
            summary.different,
            localized(context, 'Different note', 'Farklı nota'),
          ),
          cell(
            PracticeMark.couldNotHear,
            summary.unheard,
            localized(context, "Couldn't hear", 'Duyulamadı'),
          ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String name, String value, {Key? key}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(name, style: hankenText(size: 14))),
            Text(value, key: key, style: monoText(size: 13, letterSpacing: .3)),
          ],
        ),
      );

  Widget _gate(BuildContext context, PassGate gate) {
    final palette = OstinatoPalette.of(context);
    String check(GateCheck c) => switch (c.kind) {
      GateCheckKind.accuracy => localized(
        context,
        'Accuracy ≥ %{v0}',
        'Doğruluk ≥ %{v0}',
        values: {'v0': _pct(c.threshold)},
      ),
      GateCheckKind.heard => localized(
        context,
        'Heard ≥ %{v0}',
        'Duyulma ≥ %{v0}',
        values: {'v0': _pct(c.threshold)},
      ),
      GateCheckKind.tempo
          when gate.criteria.tempoGate == TempoGate.targetOnly =>
        localized(
          context,
          'Target tempo ♩={v0} (module transition)',
          'Hedef tempo ♩={v0} (modül geçişi)',
          values: {'v0': c.threshold.round()},
        ),
      GateCheckKind.tempo => localized(
        context,
        'Opening tempo ♩={v0} or faster',
        'Açılış temposu ♩={v0} ya da üstü',
        values: {'v0': c.threshold.round()},
      ),
      GateCheckKind.minCorrect => localized(
        context,
        'At least {v0} correct',
        'En az {v0} doğru',
        values: {'v0': c.threshold.round()},
      ),
    };
    final title = gate.completed
        ? localized(
            context,
            'Completed at the target tempo',
            'Hedef tempoda tamamlandı',
          )
        : gate.passed
        ? localized(
            context,
            'Passed at the opening tempo',
            'Açılış temposunda geçtin',
          )
        : !gate.eligible
        ? localized(
            context,
            'Practice round — the gate is measured on a full run',
            'Pratik turu — geçiş tam bir turda ölçülür',
          )
        : gate.heardTooLow
        ? localized(
            context,
            "Not your score — the microphone got stuck. Let's check the setup and try again.",
            'Puanın değil, mikrofonun takıldı. Kurulumu kontrol edip tekrar deneyelim.',
          )
        : localized(context, 'Not yet', 'Henüz değil');
    return GlassCard(
      key: const Key('result-gate'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            key: const Key('result-gate-title'),
            style: hankenText(size: 15, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          for (final c in gate.checks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    c.ok ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 16,
                    color: palette.ink,
                    semanticLabel: c.ok
                        ? localized(context, 'met', 'sağlandı')
                        : localized(context, 'not met', 'sağlanmadı'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(check(c), style: hankenText(size: 13))),
                ],
              ),
            ),
          if (gate.criteria.tempoGate == TempoGate.openingOpensNext &&
              summary.openBpm < summary.targetBpm)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    gate.completed
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: palette.ink,
                    semanticLabel: gate.completed
                        ? localized(context, 'met', 'sağlandı')
                        : localized(context, 'not met', 'sağlanmadı'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      localized(
                        context,
                        'Target tempo ♩={v0} marks the lesson completed',
                        'Hedef tempo ♩={v0} dersi "tamamlandı" yapar',
                        values: {'v0': summary.targetBpm},
                      ),
                      key: const Key('result-completion-rule'),
                      style: hankenText(size: 13),
                    ),
                  ),
                ],
              ),
            ),
          if (gate.passed && !gate.completed)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                localized(
                  context,
                  'The opening tempo opens the next lesson. Pass at the target tempo ♩={v0} to mark this one completed.',
                  'Açılış temposu sıradaki dersi açar. Bu dersi "tamamlandı" yapmak için hedef tempoda (♩={v0}) geç.',
                  values: {'v0': summary.targetBpm},
                ),
                key: const Key('result-opening-pass'),
                style: hankenText(size: 12.5),
              ),
            ),
          for (final reason in gate.ineligible)
            Text(switch (reason) {
              GateIneligible.stoppedEarly => localized(
                context,
                'The run was stopped before the end.',
                'Tur sonuna kadar çalınmadı.',
              ),
              GateIneligible.loopUsed => localized(
                context,
                'Loop was on.',
                'Döngü açıktı.',
              ),
              GateIneligible.waitUsed => localized(
                context,
                '"Wait for me" was on.',
                '"Beni bekle" açıktı.',
              ),
            }, style: hankenText(size: 12.5, color: palette.textMuted)),
          if (gate.criteria.customText != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                localized(
                  context,
                  gate.criteria.customText!.en,
                  gate.criteria.customText!.tr,
                ),
                style: hankenText(size: 12.5),
              ),
            ),
          if (gate.criteria.expertPending)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                localized(
                  context,
                  'Thresholds are defaults awaiting a music teacher’s review.',
                  'Eşikler varsayılandır; müzik öğretmeni incelemesi bekliyor.',
                ),
                style: hankenText(size: 11.5, color: palette.textMuted),
              ),
            ),
          if (nextLessonOpened)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                localized(
                  context,
                  'The next lesson is open.',
                  'Sıradaki ders açıldı.',
                ),
                key: const Key('result-next-opened'),
                style: hankenText(size: 14, weight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _errorMap(BuildContext context) {
    final theme = PracticeVisualThemeScope.of(context);
    final palette = OstinatoPalette.of(context);
    // Notes never reached (a stopped run) show as a plain dot.
    MarkStyle styleOf(PracticeEvent e) {
      final st = theme.style(
        summary.lastMarks[e.index]?.mark ?? PracticeMark.pending,
      );
      return st.symbol.isEmpty ? MarkStyle(st.shape, st.color, '·') : st;
    }

    final byBar = <int, List<PracticeEvent>>{};
    for (final e in score.events) {
      (byBar[e.bar] ??= []).add(e);
    }
    return GlassCard(
      key: const Key('result-error-map'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localized(context, 'Where it happened', 'Nerede oldu'),
            style: hankenText(size: 15, weight: FontWeight.w600),
          ),
          Text(
            localized(
              context,
              'Tap a bar to loop it.',
              'Döngülemek için bir ölçüye dokun.',
            ),
            style: hankenText(size: 12, color: palette.textMuted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final bar in byBar.keys)
                InkWell(
                  key: Key('result-bar-$bar'),
                  onTap: () =>
                      Navigator.of(context).pop(ResultActionLoop(bar, bar)),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: palette.outline),
                    ),
                    child: Semantics(
                      label: localized(
                        context,
                        'Bar {v0}',
                        '{v0}. ölçü',
                        values: {'v0': bar + 1},
                      ),
                      button: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${bar + 1} ',
                            style: monoText(size: 11, letterSpacing: .2),
                          ),
                          for (final e in byBar[bar]!)
                            Text(
                              styleOf(e).symbol,
                              style: TextStyle(
                                fontSize: 15,
                                color: styleOf(e).color,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (final o in summary.lastMarks.values)
            if (o.mark == PracticeMark.differentNote &&
                o.observedMidi != null &&
                o.expectedMidi != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  localized(
                    context,
                    'Bar {v0}: heard {v1} · {v2} was expected {v3}',
                    '{v0}. ölçü: {v1} duydum · {v2} bekleniyordu {v3}',
                    values: {
                      'v0': o.bar + 1,
                      'v1': musicPitch(context, midiName(o.observedMidi!)),
                      'v2': musicPitch(context, midiName(o.expectedMidi!)),
                      'v3': o.observedMidi! < o.expectedMidi! ? '↑' : '↓',
                    },
                  ),
                  style: hankenText(size: 12.5),
                ),
              ),
        ],
      ),
    );
  }

  Widget _nextStep(BuildContext context) {
    final s = summary;
    final loop = s.loopSuggestion;
    final (String label, ResultAction action) = switch (s.nextStep) {
      NextStep.nextLesson when hasNextLesson => (
        localized(context, 'Go to the next lesson', 'Sonraki derse geç'),
        const ResultActionNextLesson(),
      ),
      NextStep.nextLesson => (
        localized(context, 'Play it again', 'Bir kez daha çal'),
        const ResultActionRetry(),
      ),
      NextStep.checkSetup => (
        localized(context, 'Check the setup', 'Kurulumu kontrol et'),
        const ResultActionCheckSetup(),
      ),
      NextStep.loopSlower when loop != null => (
        localized(
          context,
          'Loop these bars at 70 % tempo',
          'Bu ölçüleri %70 tempoda döngüle',
        ),
        ResultActionLoop(loop.first, loop.last, slower: true),
      ),
      NextStep.loopSlower => (
        localized(context, 'Try again', 'Tekrar dene'),
        const ResultActionRetry(),
      ),
      NextStep.raiseTempo => (
        localized(context, 'Raise the tempo by 5', 'Tempoyu 5 artır'),
        const ResultActionRaiseTempo(),
      ),
      NextStep.performanceRun => (
        localized(
          context,
          'Play the full line at the target tempo',
          'Tüm diziyi hedef tempoda çal',
        ),
        const ResultActionPerformance(),
      ),
      NextStep.tryAgain => (
        localized(context, 'Try again', 'Tekrar dene'),
        const ResultActionRetry(),
      ),
    };
    return FilledButton(
      key: const Key('result-next-step'),
      onPressed: () => Navigator.of(context).pop(action),
      child: Text(label),
    );
  }
}
