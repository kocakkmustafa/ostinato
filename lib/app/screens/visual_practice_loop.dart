import 'package:flutter/material.dart';

import '../app_locale.dart';
import '../guitar_journey.dart' show GuitarText;

/// A symbolic instruction step, never a detected performance event.
@immutable
final class VisualPracticeStep {
  const VisualPracticeStep({required this.label, required this.instruction});
  final GuitarText label, instruction;
}

enum PracticeObservation { issue, uncertain, noIssueObserved, stopped }

enum PracticeComparison { changed, same, uncertain }

/// Manual rehearsal and learner self-observation only. No clock or persistence.
class VisualPracticeLoop extends StatefulWidget {
  VisualPracticeLoop({
    required this.taskIdentity,
    required Iterable<VisualPracticeStep> steps,
    required this.target,
    required this.observationPrompt,
    required this.recovery,
    required this.diagram,
    required this.retryChoices,
    super.key,
  }) : steps = List<VisualPracticeStep>.unmodifiable(steps) {
    if (taskIdentity.isEmpty || this.steps.isEmpty) {
      throw ArgumentError('Practice needs identity and steps');
    }
  }

  /// Stable identity covers task, source-content version and practice scope.
  /// Locale and freshly allocated copies of the same steps do not change it.
  final String taskIdentity;
  final List<VisualPracticeStep> steps;
  final GuitarText target, observationPrompt, recovery;
  final Widget Function(BuildContext, int) diagram;
  final Widget retryChoices;

  @override
  State<VisualPracticeLoop> createState() => _VisualPracticeLoopState();
}

class _VisualPracticeLoopState extends State<VisualPracticeLoop> {
  int _index = 0;
  PracticeObservation? _observation;
  PracticeComparison? _comparison;
  final _location = TextEditingController();

  @override
  void didUpdateWidget(covariant VisualPracticeLoop oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A replacement task cannot inherit an earlier attempt or answer.
    if (oldWidget.taskIdentity != widget.taskIdentity) {
      _reset();
    }
  }

  void _reset() {
    _index = 0;
    _observation = null;
    _comparison = null;
    _location.clear();
  }

  @override
  void dispose() {
    _location.dispose();
    super.dispose();
  }

  String _observationLabel(BuildContext context, PracticeObservation value) =>
      switch (value) {
        PracticeObservation.issue => localized(
          context,
          'I noticed one issue',
          'Bir sorun fark ettim',
        ),
        PracticeObservation.uncertain => localized(
          context,
          'I am uncertain',
          'Emin değilim',
        ),
        PracticeObservation.noIssueObserved => localized(
          context,
          'I noticed no issue',
          'Sorun fark etmedim',
        ),
        PracticeObservation.stopped => localized(
          context,
          'I stopped or rested',
          'Durdum veya dinlendim',
        ),
      };

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.target.of(context)),
        const SizedBox(height: 12),
        Text(
          localized(
            context,
            'Before trying, choose one bar/count to compare. Keep it in mind or write it outside the app; changing hands, restarting or leaving clears this temporary note.',
            'Denemeden önce karşılaştıracağın tek ölçü/sayımı seç. Aklında tut veya uygulama dışında yaz; el değiştirme, yeniden başlama veya çıkış bu geçici notu siler.',
          ),
        ),
        TextField(
          key: const Key('visual-observation-location'),
          controller: _location,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: localized(
              context,
              'Optional: chosen bar/count',
              'İsteğe bağlı: seçilen ölçü/sayım',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          localized(
            context,
            'First read the steps using the buttons. Then play using your own count, without pressing Next while playing. This symbolic guide has no tempo clock; it does not hear, watch or assess your attempt.',
            'Önce düğmelerle adımları oku. Sonra çalarken Sonraki’ye basmadan kendi sayımınla çal. Bu sembolik rehberin tempo saati yok; denemeni duymaz, izlemez veya değerlendirmez.',
          ),
        ),
        const SizedBox(height: 16),
        widget.diagram(context, _index),
        const SizedBox(height: 12),
        Semantics(
          key: const Key('visual-active-heading'),
          header: true,
          liveRegion: true,
          child: Text(
            step.label.of(context),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Text(
          step.instruction.of(context),
          key: const Key('visual-active-instruction'),
        ),
        Wrap(
          spacing: 8,
          children: [
            if (_index > 0)
              TextButton(
                key: const Key('visual-previous-step'),
                onPressed: () => setState(() => _index--),
                child: Text(
                  localized(context, 'Previous instruction', 'Önceki yönerge'),
                ),
              ),
            if (_index + 1 < widget.steps.length)
              TextButton(
                key: const Key('visual-next-step'),
                onPressed: () => setState(() => _index++),
                child: Text(
                  localized(context, 'Next instruction', 'Sonraki yönerge'),
                ),
              ),
            TextButton(
              key: const Key('visual-restart'),
              onPressed: () => setState(_reset),
              child: Text(
                localized(context, 'Restart this task', 'Bu görevi baştan al'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          localized(
            context,
            'Try on your instrument only when comfortable, at your own slow tempo. First use one silent four-count bar. Stop or rest whenever needed. Clicking through is reading, not proof of playing.',
            'Yalnız rahatsan çalgında kendi yavaş temponla dene. Önce sessiz bir dört sayımlık ölçü kullan. Gerektiğinde dur veya dinlen. Düğmeleri gezmek okumadır, çalım kanıtı değildir.',
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(
            localized(context, 'Your own observation', 'Kendi gözlemin'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Text(widget.observationPrompt.of(context)),
        Wrap(
          spacing: 8,
          children: [
            for (final value in PracticeObservation.values)
              ChoiceChip(
                key: Key('visual-observation-${value.name}'),
                label: Text(_observationLabel(context, value)),
                selected: _observation == value,
                onSelected: (_) => setState(() => _observation = value),
              ),
          ],
        ),
        if (_observation != null) ...[
          Text(
            localized(
              context,
              'This is your report, not a measured result. No score or completion is recorded; this note disappears when you leave or restart.',
              'Bu senin beyanın, ölçülen sonuç değil. Puan veya tamamlama kaydı yok; bu not çıkınca veya yeniden başlayınca silinir.',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            localized(
              context,
              'For an issue or uncertainty, choose one hand and the same bar to inspect a smaller task. If no issue was observed, that is not verified correctness; revisit the same task another day. If you stopped, rest before deciding whether to retry.',
              'Sorun veya belirsizlikte küçük görevi incelemek için aynı ölçüde tek el seç. Sorun fark etmemek doğrulanmış doğruluk değildir; aynı göreve başka gün dön. Durduysan tekrar denemeye karar vermeden dinlen.',
            ),
          ),
          Text(widget.recovery.of(context), key: const Key('visual-recovery')),
          widget.retryChoices,
          Text(
            localized(
              context,
              'After the retry, compare that same chosen count at the same chosen tempo. Your observation: changed, same, or uncertain. A smaller-hand attempt is preparation; compare the two-hand task only after returning to both hands.',
              'Tekrar denemeden sonra aynı seçilen sayımı aynı seçilen tempoda karşılaştır. Kendi gözlemin: değişti, aynı veya belirsiz. Tek el denemesi hazırlıktır; iki el görevini ancak iki ele döndükten sonra karşılaştır.',
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final result in PracticeComparison.values)
                ChoiceChip(
                  key: Key('visual-comparison-${result.name}'),
                  selected: _comparison == result,
                  label: Text(
                    localized(
                      context,
                      switch (result) {
                        PracticeComparison.changed => 'Changed',
                        PracticeComparison.same => 'Same',
                        PracticeComparison.uncertain => 'Uncertain',
                      },
                      switch (result) {
                        PracticeComparison.changed => 'Değişti',
                        PracticeComparison.same => 'Aynı',
                        PracticeComparison.uncertain => 'Belirsiz',
                      },
                    ),
                  ),
                  onSelected: (_) => setState(() => _comparison = result),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
