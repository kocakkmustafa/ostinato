import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../design/ostinato_theme.dart';
import '../../design/widgets.dart';
import '../../ui_copy.dart';
import 'listen_try_fix.dart';
import 'listen_try_fix_copy.dart';
import 'practice_result_screen.dart';

/// OST-P0-06: the one measured difference, the one correction and the
/// stepped repeat, on the result screen. Plain colors, no verdict word.
class ListenTryFixCard extends StatelessWidget {
  const ListenTryFixCard({super.key, required this.result});

  final ListenTryFixResult result;

  /// The tempo the card's one button repeats at; null = no button.
  static int? repeatBpm(ListenTryFixResult result) => switch (result) {
    FixCorrection(:final plan) => plan.nextBpm,
    FixClear(:final nextBpm) => nextBpm,
    _ => null,
  };

  /// A correction with no repeat action (free tempo) says "a bit slower"
  /// without a way to do it, so it is not shown. The other kinds are plain
  /// information and stay.
  static bool shown(ListenTryFixResult result) =>
      result is! FixCorrection || repeatBpm(result) != null;

  @override
  Widget build(BuildContext context) {
    if (!shown(result)) return const SizedBox.shrink();
    final palette = OstinatoPalette.of(context);
    final body = switch (result) {
      FixUnmeasured() => uiText(context, ListenTryFixCopy.couldNotMeasure),
      FixClear() => uiText(context, ListenTryFixCopy.clear),
      FixNoClearDifference() => uiText(
        context,
        ListenTryFixCopy.noClearDifference,
      ),
      FixCorrection(:final kind, :final bar) => uiText(
        context,
        switch (kind) {
          FixKind.early => ListenTryFixCopy.early,
          FixKind.late => ListenTryFixCopy.late,
          FixKind.missed => ListenTryFixCopy.missed,
          FixKind.pitchOff => ListenTryFixCopy.pitch,
        },
        values: {'v0': bar + 1},
      ),
    };
    final title = uiText(context, ListenTryFixCopy.title);
    final correction = result is FixCorrection ? result as FixCorrection : null;
    final plan = correction?.plan;
    final next = repeatBpm(result);
    return GlassCard(
      key: const Key('listen-try-fix-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            header: true,
            child: Text(
              title,
              style: hankenText(size: 15, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 4),
          Semantics(
            container: true,
            liveRegion: true,
            child: Text(
              body,
              key: const Key('listen-try-fix-body'),
              style: hankenText(size: 14, height: 1.45),
            ),
          ),
          if (plan != null && plan.steps.length > 1) ...[
            const SizedBox(height: 8),
            Text(
              '${uiText(context, ListenTryFixCopy.stepsLabel)}: '
              '${plan.steps.map((b) => '♩=$b').join(' → ')}',
              key: const Key('listen-try-fix-steps'),
              textDirection: TextDirection.ltr,
              style: hankenText(size: 12.5, color: palette.textMuted),
            ),
          ],
          if (plan?.nextExercise case final lesson?) ...[
            const SizedBox(height: 6),
            Text(
              uiText(
                context,
                ListenTryFixCopy.nextExercise,
                values: {'v0': lesson.title.of(context)},
              ),
              key: const Key('listen-try-fix-next-exercise'),
              style: hankenText(size: 12.5, color: palette.textMuted),
            ),
          ],
          if (next != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              key: const Key('listen-try-fix-repeat'),
              onPressed: () => Navigator.of(context).pop(
                ResultActionRepeat(
                  next,
                  first: plan?.loop?.first,
                  last: plan?.loop?.last,
                ),
              ),
              child: Text(
                uiText(context, ListenTryFixCopy.tryAt, values: {'v0': next}),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
