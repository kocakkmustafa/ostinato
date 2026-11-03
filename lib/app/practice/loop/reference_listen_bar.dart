import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../design/ostinato_theme.dart';
import '../../ui_copy.dart';
import 'practice_score.dart';
import 'reference_copy.dart';
import 'reference_listen.dart';

/// FK1 "Listen first" controls: one button per tempo, Stop while sounding,
/// and an honest status line (preparing, playing, cut, unavailable).
class ReferenceListenBar extends StatelessWidget {
  const ReferenceListenBar({
    super.key,
    required this.controller,
    required this.score,
    required this.tempos,
    this.enabled = true,
    this.port,
  });

  final ReferenceListenController controller;
  final PracticeScore score;

  /// Tempos to offer, fastest first (`[target, open]` or the current one).
  final List<int> tempos;
  final bool enabled;

  /// Defaults to the audio root above this widget's route.
  final ReferencePlaybackPort? Function(BuildContext context)? port;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final palette = OstinatoPalette.of(context);
      final c = controller;
      final muted = hankenText(
        size: 12.5,
        color: palette.textMuted,
        height: 1.4,
      );
      final passage = c.passage;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (c.busy)
            OutlinedButton.icon(
              key: const Key('reference-stop'),
              onPressed: () => unawaited(c.stop()),
              icon: const Icon(Icons.stop),
              label: Text(uiText(context, ReferenceCopy.stop)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final bpm in {...tempos})
                  OutlinedButton.icon(
                    key: Key('reference-listen-$bpm'),
                    onPressed: enabled
                        ? () => unawaited(
                            c.play(
                              (port ?? ReferenceRoutePort.of)(context),
                              score,
                              bpm,
                            ),
                          )
                        : null,
                    icon: const Icon(Icons.headphones),
                    label: Text(
                      uiText(
                        context,
                        ReferenceCopy.listenAt,
                        values: {'v0': bpm},
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 6),
          Text(
            switch (c.state) {
              ReferenceListenState.preparing => uiText(
                context,
                ReferenceCopy.preparing,
              ),
              ReferenceListenState.playing => uiText(
                context,
                ReferenceCopy.playing,
                values: {'v0': c.bpm},
              ),
              ReferenceListenState.unavailable => uiText(
                context,
                ReferenceCopy.unavailable,
              ),
              ReferenceListenState.idle => uiText(
                context,
                ReferenceCopy.synthesized,
              ),
            },
            key: const Key('reference-status'),
            style: muted,
          ),
          if (c.state == ReferenceListenState.playing &&
              passage != null &&
              passage.truncated)
            Text(
              uiText(
                context,
                ReferenceCopy.truncated,
                values: {'v0': passage.barsPlayed, 'v1': passage.barCount},
              ),
              key: const Key('reference-truncated'),
              style: muted,
            ),
        ],
      );
    },
  );
}
