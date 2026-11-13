import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../design/ostinato_theme.dart';
import '../practice/loop/metronome_beat_view.dart';
import '../practice/loop/practice_session_controller.dart';
import '../practice/loop/reference_listen.dart';
import '../practice/loop/reference_listen_bar.dart';
import '../ui_copy.dart';
import 'ghost_level_copy.dart';
import 'ghost_policy.dart';
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
    this.ghost,
    this.onGhostSelect,
    this.helpOpen = false,
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

  /// OST-UX-05g: the Ghost state; null = the flag is closed and the help row
  /// does not exist at all.
  final GhostState? ghost;
  final ValueChanged<GhostLevel>? onGhostSelect;
  final bool helpOpen;

  /// The help row's action (opens / closes the level surface).
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
              // Same condition as the practice screen's own bar (the stage
              // never hides guides, so `Guide.referenceAudio` always holds).
              if (c.score.hasPitches || c.score.isRhythmOnly)
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
                    final bars = c.score.barCount;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SwitchListTile(
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
                              ? (first: 0, last: bars > 1 ? 1 : 0)
                              : null,
                        ),
                        if (loop != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: RangeSlider(
                              key: const Key('stage-loop-range'),
                              min: 0,
                              max: (bars - 1).toDouble(),
                              divisions: bars - 1,
                              semanticFormatterCallback: (v) =>
                                  '${v.round() + 1}',
                              values: RangeValues(
                                loop.first.toDouble(),
                                loop.last.toDouble(),
                              ),
                              onChanged: (v) => c.loopBars = (
                                first: v.start.round(),
                                last: v.end.round(),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              if (ghost != null) ...<Widget>[
                Semantics(
                  key: const Key('stage-help-row'),
                  container: true,
                  button: true,
                  expanded: helpOpen,
                  label: uiText(context, StageCopy.help),
                  onTap: onHelp,
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: onHelp,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            uiText(context, StageCopy.help),
                            style: hankenText(
                              size: 14,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (helpOpen)
                  _EnsureVisible(child: _ghostSurface(context, ghost!)),
              ],
            ]),
        ],
      ),
    );
  }

  static UiCopy _levelCopy(GhostLevel l) => switch (l) {
    GhostLevel.learn => GhostLevelCopy.learn,
    GhostLevel.reinforce => GhostLevelCopy.reinforce,
    GhostLevel.recall => GhostLevelCopy.recall,
    GhostLevel.independent => GhostLevelCopy.independent,
  };

  static UiCopy _itemCopy(GhostItem i) => switch (i) {
    GhostItem.notation => GhostLevelCopy.notation,
    GhostItem.tab => GhostLevelCopy.tab,
    GhostItem.beat => GhostLevelCopy.beat,
    GhostItem.label => GhostLevelCopy.label,
    GhostItem.preStartPreview => GhostLevelCopy.preStartPreview,
  };

  /// The four manual levels, what each shows, and (only after enough valid
  /// runs) one thin suggestion line. Opaque; part of the shelf's own scroll.
  Widget _ghostSurface(BuildContext context, GhostState g) {
    final palette = OstinatoPalette.of(context);
    final next = GhostPolicy.suggestion(g);
    return Padding(
      key: const Key('ghost-help-surface'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            uiText(context, GhostLevelCopy.title),
            style: hankenText(size: 13, weight: FontWeight.w600),
          ),
          for (final l in GhostLevel.values)
            Semantics(
              key: Key('ghost-level-${l.name}'),
              container: true,
              button: true,
              selected: l == g.level,
              label: uiText(context, _levelCopy(l)),
              onTap: () => onGhostSelect?.call(l),
              excludeSemantics: true,
              child: InkWell(
                onTap: () => onGhostSelect?.call(l),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          uiText(context, _levelCopy(l)),
                          style: hankenText(
                            size: 14,
                            weight: l == g.level
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (l == g.level) const Icon(Icons.check, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            uiText(context, GhostLevelCopy.shown),
            style: hankenText(size: 12, color: palette.textMuted),
          ),
          for (final i in GhostItem.values)
            if (GhostPolicy.itemsFor(g.level).contains(i))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  uiText(context, _itemCopy(i)),
                  key: Key('ghost-item-${i.name}'),
                  style: hankenText(size: 13),
                ),
              ),
          if (GhostPolicy.itemsFor(g.level).isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                uiText(context, GhostLevelCopy.noExtraHelp),
                key: const Key('ghost-item-none'),
                style: hankenText(size: 13),
              ),
            ),
          if (g.lastRun == GhostLastRun.notMeasured)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                uiText(context, GhostLevelCopy.notMeasured),
                key: const Key('ghost-last-run'),
                style: hankenText(size: 12.5),
              ),
            ),
          if (next != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${uiText(context, GhostLevelCopy.suggestion)}: '
                '${uiText(context, _levelCopy(next))}',
                key: const Key('ghost-suggestion'),
                style: hankenText(size: 12.5, weight: FontWeight.w600),
              ),
            ),
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

/// OST-UX-05g: when the help surface opens inside the shelf's own scroll, it
/// is scrolled to the top of the viewport once (no animation), so it is never
/// left below the fold on a small phone.
class _EnsureVisible extends StatefulWidget {
  const _EnsureVisible({required this.child});
  final Widget child;

  @override
  State<_EnsureVisible> createState() => _EnsureVisibleState();
}

class _EnsureVisibleState extends State<_EnsureVisible> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(context, alignment: 0);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
