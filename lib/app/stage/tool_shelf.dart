import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../design/ostinato_theme.dart';
import '../practice/loop/metronome_beat_view.dart';
import '../practice/loop/practice_session_controller.dart';
import '../practice/loop/reference_listen.dart';
import '../practice/loop/reference_listen_bar.dart';
import '../ui_copy.dart';
import 'stage_copy.dart';

/// OST-UX-05b: the stage's tool shelf. FULLY OPAQUE (no blur, no glass, not
/// counted by `GlassLayerBudget`). Closed it is one row; open it lists the
/// metronome, the reference bar and the loop switch, reusing the existing
/// widgets, plus the place of the help row. The caller never builds it while
/// a run is going (the shelf cannot open then).
class ToolShelf extends StatelessWidget {
  const ToolShelf({
    super.key,
    required this.open,
    required this.onToggle,
    required this.controller,
    required this.listen,
    required this.pinned,
    required this.onPinned,
    this.onHelp,
    this.maxContentHeight,
  });

  final bool open;
  final VoidCallback onToggle;

  /// Null until the practice screen has handed its session controller over.
  final PracticeSessionController? controller;
  final ReferenceListenController listen;
  final bool pinned;
  final ValueChanged<bool> onPinned;

  /// The help row's action; null = the row only holds its place.
  final VoidCallback? onHelp;

  /// OST-UX-05b2: the open list scrolls inside this height so the Play area
  /// above keeps its room (null = unbounded, as before).
  final double? maxContentHeight;

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final c = controller;
    return Material(
      key: const Key('stage-shelf'),
      color: palette.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            button: true,
            expanded: open,
            child: InkWell(
              key: const Key('stage-shelf-toggle'),
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          uiText(context, StageCopy.tools),
                          style: hankenText(size: 14, weight: FontWeight.w500),
                        ),
                      ),
                      Icon(open ? Icons.expand_more : Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (open && c != null)
            _scrolled(<Widget>[
              _row(
                context,
                StageCopy.metronome,
                ListenableBuilder(
                  listenable: c,
                  builder: (context, _) => MetronomeBeatView(
                    state: c.beat,
                    beatsPerBar: c.score.beatsPerBar,
                  ),
                ),
              ),
              SwitchListTile(
                key: const Key('stage-pin-metronome'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                dense: true,
                title: Text(uiText(context, StageCopy.pinMetronome)),
                value: pinned,
                onChanged: onPinned,
              ),
              _row(
                context,
                StageCopy.reference,
                ReferenceListenBar(
                  controller: listen,
                  score: c.score,
                  tempos: <int>[c.tempo.bpm],
                ),
              ),
              if (c.score.barCount > 1)
                ListenableBuilder(
                  listenable: c,
                  builder: (context, _) {
                    final loop = c.loopBars;
                    return SwitchListTile(
                      key: const Key('stage-loop'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      dense: true,
                      title: Text(uiText(context, StageCopy.loop)),
                      subtitle: loop == null
                          ? null
                          : Text('${loop.first + 1}–${loop.last + 1}'),
                      value: loop != null,
                      onChanged: (v) => c.loopBars = v
                          ? (first: 0, last: c.score.barCount > 1 ? 1 : 0)
                          : null,
                    );
                  },
                ),
              InkWell(
                key: const Key('stage-help-row'),
                onTap: onHelp,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        uiText(context, StageCopy.help),
                        style: hankenText(size: 14, weight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _scrolled(List<Widget> children) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    final max = maxContentHeight;
    if (max == null) return column;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: max),
      child: SingleChildScrollView(
        key: const Key('stage-shelf-scroll'),
        child: column,
      ),
    );
  }

  Widget _row(BuildContext context, UiCopy label, Widget child) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(uiText(context, label), style: hankenText(size: 13)),
        const SizedBox(height: 4),
        child,
      ],
    ),
  );
}
