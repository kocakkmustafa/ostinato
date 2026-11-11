import 'package:flutter/material.dart';

import '../app_locale.dart';
import '../design/ostinato_theme.dart';
import '../content.dart';
import '../design/app_scope.dart';
import '../ostinato_release_policy.dart';
import '../screens/instrument_screen.dart';
import '../screens/v1_home_copy.dart';
import '../tuner/tuner_copy.dart';
import '../ui_copy.dart';
import 'stage_copy.dart';
import 'stage_suggestion.dart';

/// OST-UX-05c: the "Another practice" layer. One suggestion line (hidden when
/// there is none), the instruments (guitar and ear training open; any other
/// instrument follows the existing "coming soon" page rule) and the tuner.
/// Scrolls inside the layer; every row is at least 48 dp.
class OtherPracticeLayer extends StatelessWidget {
  const OtherPracticeLayer({
    super.key,
    required this.suggestion,
    required this.close,
    required this.openEar,
    required this.openTuner,
  });

  final StageSuggestion? suggestion;

  /// Closes the layer (tapping guitar: the stage is already on it).
  final VoidCallback close;
  final VoidCallback openEar;
  final VoidCallback openTuner;

  static UiCopy suggestionCopy(StageSuggestionKind k) => switch (k) {
    StageSuggestionKind.pickUp => StageCopy.suggestPickUp,
    StageSuggestionKind.moveCloser => StageCopy.suggestMoveCloser,
    StageSuggestionKind.listenFirst => StageCopy.suggestListenFirst,
    StageSuggestionKind.slowDown => StageCopy.suggestSlowDown,
  };

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    final repo = context
        .getInheritedWidgetOfExactType<ContentRepositoryScope>()
        ?.repo;
    final others = repo == null
        ? const <Discipline>[]
        : repo.disciplines
              .where(
                (d) =>
                    d.status == 'live' &&
                    !ostinatoOpenInstruments.contains(d.id),
              )
              .toList();
    return SingleChildScrollView(
      key: const Key('stage-other-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            uiText(context, StageCopy.handleOther),
            style: hankenText(size: 16, weight: FontWeight.w600),
          ),
          if (s != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              uiText(context, suggestionCopy(s.kind)),
              key: const Key('stage-suggestion'),
              style: hankenText(size: 14),
            ),
          ],
          const SizedBox(height: 8),
          _row('stage-instr-guitar', uiText(context, StageCopy.guitar), close),
          if (ostinatoEarTrainingOpen)
            _row(
              'stage-instr-ear',
              uiText(context, V1HomeCopy.earCardTitle),
              openEar,
            ),
          for (final d in others)
            _row(
              'stage-instr-${d.id}',
              catalogName(context, d.id, d.displayName),
              () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => InstrumentScreenRoute(discipline: d),
                ),
              ),
            ),
          _row(
            'stage-tuner-entry',
            uiText(context, TunerCopy.title),
            openTuner,
            icon: Icons.tune,
          ),
        ],
      ),
    );
  }

  Widget _row(String key, String label, VoidCallback onTap, {IconData? icon}) =>
      Semantics(
        button: true,
        child: InkWell(
          key: Key(key),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: hankenText(size: 15, weight: FontWeight.w500),
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      );
}
