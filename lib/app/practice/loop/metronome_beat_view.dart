import 'package:flutter/material.dart';

import '../../app_locale.dart';
import '../../app_theme.dart';
import '../../design/ostinato_theme.dart';
import 'metronome.dart';

/// F2.2 visual beat: one dot per beat of the bar, the current one filled and
/// the bar's first beat larger (accent). During the count-in a big number
/// counts down. Works with the click sound off (the grid is the same).
class MetronomeBeatView extends StatelessWidget {
  const MetronomeBeatView({
    super.key,
    required this.state,
    required this.beatsPerBar,
  });

  final MetronomeBeatState state;
  final int beatsPerBar;

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final active = state.beat >= 0;
    final label = state.inCountIn && active
        ? localized(
            context,
            'Count-in: {v0}',
            'Ön sayım: {v0}',
            values: {'v0': state.countInRemaining},
          )
        : active
        ? localized(
            context,
            'Beat {v0}',
            'Vuruş {v0}',
            values: {'v0': state.beatInBar + 1},
          )
        : localized(context, 'Metronome ready', 'Metronom hazır');
    return Semantics(
      label: label,
      liveRegion: state.inCountIn,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.inCountIn && active)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  '${state.countInRemaining}',
                  key: const Key('metronome-count-in'),
                  style: hankenText(
                    size: 22,
                    weight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
              ),
            for (var b = 0; b < beatsPerBar; b++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 60),
                  key: Key('metronome-dot-$b'),
                  width: b == 0 ? 14 : 10,
                  height: b == 0 ? 14 : 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active && b == state.beatInBar
                        ? palette.ink
                        : Colors.transparent,
                    border: Border.all(color: palette.ink, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
