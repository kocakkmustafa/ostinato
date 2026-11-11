import 'package:flutter/material.dart';

import '../app_locale.dart';
import '../app_theme.dart';
import '../design/ostinato_theme.dart';
import '../drill/drill_copy.dart';
import '../practice/loop/v1_course_catalog.dart';
import '../practice/loop/v1_course_copy.dart';
import '../practice/loop/v1_paywall_copy.dart';
import '../retention/weekly_goal.dart';
import '../screens/v1_home_copy.dart';
import '../test_flow/test_flow_copy.dart';
import '../ui_copy.dart';
import 'path_summary.dart';
import 'stage_copy.dart';

/// What the "My path" layer shows: the summary of the stored records and the
/// weekly goal (null = no weekly row).
final class PathLayerData {
  const PathLayerData(this.catalog, this.summary, this.weekly);
  final V1CourseCatalog catalog;
  final PathSummary summary;
  final WeeklyGoalStatus? weekly;
}

/// OST-UX-05d: "My path" (design 04, section 5.2): one scrolling, linear
/// list. Path (level > module > lesson) first, then History. Nothing here is
/// tappable except the retry after a failed read, so only that is a button.
/// Locked / paid / not-measured are always words (and an icon), never only a
/// colour. History is a read of the stored bests: no points, badges or
/// streaks.
class PathLayer extends StatefulWidget {
  const PathLayer({super.key, required this.load});

  /// Reads the records (throws on a read failure: not the same as empty).
  final Future<PathLayerData> Function() load;

  @override
  State<PathLayer> createState() => _PathLayerState();
}

class _PathLayerState extends State<PathLayer> {
  late Future<PathLayerData> _future = widget.load();

  void _retry() {
    final next = widget.load();
    setState(() {
      _future = next;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PathLayerData>(
    future: _future,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const SizedBox(
          key: Key('stage-path-loading'),
          height: 96,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snap.hasError || snap.data == null) return _failed(context);
      return _content(context, snap.data!);
    },
  );

  Widget _failed(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          uiText(context, StageCopy.pathReadFailed),
          key: const Key('stage-path-failed'),
          style: hankenText(size: 14),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: TextButton(
            key: const Key('stage-path-retry'),
            onPressed: _retry,
            child: Text(uiText(context, StageCopy.tryAgain)),
          ),
        ),
      ],
    ),
  );

  Widget _content(BuildContext context, PathLayerData d) {
    final s = d.summary;
    final palette = OstinatoPalette.of(context);
    final next = s.next;
    final nextLesson = next == null ? null : d.catalog.lesson(next.lessonId);
    final why = next?.why;
    return SingleChildScrollView(
      key: const Key('stage-path-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              uiText(context, StageCopy.handlePath),
              style: hankenText(size: 16, weight: FontWeight.w600),
            ),
          ),
          if (nextLesson != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '${uiText(context, V1CourseCopy.nextChip)}: '
              '${nextLesson.lesson.title.of(context)}',
              key: const Key('stage-path-next'),
              style: hankenText(size: 14, weight: FontWeight.w500),
            ),
            if (why != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  uiText(context, whyCopy(why)),
                  key: const Key('stage-path-why'),
                  style: hankenText(size: 13, color: palette.textMuted),
                ),
              ),
          ],
          for (final level in s.levels) ..._level(context, d, level, next),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              uiText(context, StageCopy.historyTitle),
              key: const Key('stage-history-title'),
              style: hankenText(size: 16, weight: FontWeight.w600),
            ),
          ),
          ..._history(context, d),
        ],
      ),
    );
  }

  static UiCopy whyCopy(PathWhy w) => switch (w) {
    PathWhy.firstModule => StageCopy.whyFirstModule,
    PathWhy.gateMeasured => StageCopy.whyGateMeasured,
    PathWhy.gateNotMeasured => StageCopy.whyGateNotMeasured,
    PathWhy.earlierProgress => StageCopy.whyEarlierProgress,
  };

  List<Widget> _level(
    BuildContext context,
    PathLayerData d,
    PathLevel level,
    PathNext? next,
  ) => <Widget>[
    Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Semantics(
        header: true,
        child: Text(
          '${uiText(context, V1CourseCopy.levelTitle, values: {'v0': level.level})}'
          ' · ${uiText(context, V1CourseCopy.levelProgress, values: {'v0': level.done, 'v1': level.total})}',
          key: Key('stage-path-level-${level.level}'),
          style: hankenText(size: 15, weight: FontWeight.w600),
        ),
      ),
    ),
    for (final u in level.units) _unit(context, d, u, next),
  ];

  String _unitTitle(BuildContext context, PathUnit u) {
    final module = u.module;
    if (module == null) {
      return uiText(
        context,
        switch (u.track) {
          'a' => V1CourseCopy.levelTestAcoustic,
          'b' => V1CourseCopy.levelTestElectric,
          _ => V1CourseCopy.levelTest,
        },
        values: {'v0': u.level},
      );
    }
    return uiText(
      context,
      switch (u.track) {
        'a' => V1CourseCopy.trackAcoustic,
        'b' => V1CourseCopy.trackElectric,
        _ => V1CourseCopy.moduleTitle,
      },
      values: {'v0': '$module${u.track?.toUpperCase() ?? ''}'},
    );
  }

  Widget _unit(
    BuildContext context,
    PathLayerData d,
    PathUnit u,
    PathNext? next,
  ) {
    final values = {'v0': u.done, 'v1': u.total};
    final line = switch (u.open) {
      V1UnitOpen.locked => uiText(context, V1CourseCopy.unitLocked),
      V1UnitOpen.openNotMeasured => uiText(
        context,
        V1CourseCopy.unitNotMeasured,
        values: values,
      ),
      V1UnitOpen.open || V1UnitOpen.openEarlierProgress => uiText(
        context,
        V1CourseCopy.unitOpen,
        values: values,
      ),
    };
    final title = _unitTitle(context, u);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey<String>('stage-path-unit-${u.id}'),
        initiallyExpanded: next?.unitId == u.id,
        tilePadding: EdgeInsets.zero,
        minTileHeight: 48,
        leading: Icon(
          u.open == V1UnitOpen.locked
              ? Icons.lock_outline
              : u.done == u.total
              ? Icons.check_circle
              : Icons.menu_book_outlined,
        ),
        title: Text(
          title,
          key: Key('stage-path-unit-title-${u.id}'),
          style: hankenText(size: 14, weight: FontWeight.w500),
        ),
        subtitle: Text(
          line,
          key: Key('stage-path-unit-status-${u.id}'),
          style: monoText(),
        ),
        children: <Widget>[
          for (final l in u.lessons) _lessonRow(context, d, l),
        ],
      ),
    );
  }

  String _status(BuildContext context, PathLesson l) {
    return switch (l.status) {
      V1LessonStatus.completed => localized(
        context,
        'COMPLETED · ♩={v0}',
        'TAMAMLANDI · ♩={v0}',
        values: {'v0': l.bpm ?? 0},
      ),
      V1LessonStatus.passed => localized(
        context,
        'PASSED · ♩={v0}',
        'GEÇİLDİ · ♩={v0}',
        values: {'v0': l.bpm ?? 0},
      ),
      V1LessonStatus.played => localized(
        context,
        'PLAYED ×{v0}',
        'ÇALINDI ×{v0}',
        values: {'v0': l.runs},
      ),
      V1LessonStatus.open => localized(context, 'OPEN', 'AÇIK'),
      V1LessonStatus.locked => uiText(context, V1CourseCopy.statusLocked),
      V1LessonStatus.tuned => uiText(context, V1CourseCopy.statusTuned),
      V1LessonStatus.selfReported => uiText(
        context,
        V1CourseCopy.statusSelfReported,
      ),
      V1LessonStatus.drillPassed => uiText(context, DrillCopy.statusPassed),
      V1LessonStatus.testPassed => uiText(context, TestFlowCopy.statusPassed),
      V1LessonStatus.repeatWithMeasurement => uiText(
        context,
        V1CourseCopy.statusRepeat,
      ),
      V1LessonStatus.held => uiText(context, V1CourseCopy.statusHeld),
      V1LessonStatus.heldSelfReported => uiText(
        context,
        V1CourseCopy.statusHeldSelfReported,
      ),
    };
  }

  Widget _lessonRow(BuildContext context, PathLayerData d, PathLesson l) {
    final palette = OstinatoPalette.of(context);
    final lesson = d.catalog.lesson(l.id)!;
    final title = lesson.lesson.title.of(context);
    final status = _status(context, l);
    final paid = l.paid ? uiText(context, V1PaywallCopy.membershipMark) : null;
    final next = l.isNext ? uiText(context, V1CourseCopy.nextChip) : null;
    return MergeSemantics(
      child: ConstrainedBox(
        key: Key('stage-path-lesson-${l.id}'),
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                l.locked ? Icons.lock_outline : Icons.circle_outlined,
                size: 16,
                color: palette.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      next == null ? title : '$next: $title',
                      style: hankenText(size: 14),
                    ),
                    Text(
                      status,
                      key: Key('stage-path-status-${l.id}'),
                      style: monoText(size: 10.5),
                    ),
                  ],
                ),
              ),
              if (paid != null) ...<Widget>[
                const SizedBox(width: 8),
                Icon(Icons.lock_outline, size: 14, color: palette.textMuted),
                const SizedBox(width: 2),
                Text(
                  paid,
                  key: Key('stage-path-paid-${l.id}'),
                  style: monoText(size: 10, color: palette.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _pct(double? v) => v == null ? '–' : '${(v * 100).round()}%';

  List<Widget> _history(BuildContext context, PathLayerData d) {
    final s = d.summary;
    final palette = OstinatoPalette.of(context);
    final weekly = d.weekly;
    final out = <Widget>[];
    if (s.history.isEmpty && s.ear.lessonsPlayed == 0) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            uiText(context, StageCopy.historyEmpty),
            key: const Key('stage-history-empty'),
            style: hankenText(size: 14),
          ),
        ),
      );
    }
    if (s.history.isNotEmpty) {
      final heard = uiText(context, StageCopy.heardLabel);
      final accuracy = uiText(context, StageCopy.accuracyLabel);
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            key: const Key('stage-history-head'),
            children: <Widget>[
              const Expanded(child: SizedBox.shrink()),
              SizedBox(
                width: 76,
                child: Text(
                  heard,
                  textAlign: TextAlign.end,
                  style: monoText(size: 10.5, color: palette.textMuted),
                ),
              ),
              SizedBox(
                width: 84,
                child: Text(
                  accuracy,
                  textAlign: TextAlign.end,
                  style: monoText(size: 10.5, color: palette.textMuted),
                ),
              ),
            ],
          ),
        ),
      );
      for (final r in s.history) {
        final title = d.catalog.lesson(r.lessonId)?.lesson.title.of(context);
        final extra = <String>[
          localized(
            context,
            'PLAYED ×{v0}',
            'ÇALINDI ×{v0}',
            values: {'v0': r.runs},
          ),
          if (r.bestBpm != null)
            uiText(context, StageCopy.bestTempo, values: {'v0': r.bestBpm}),
        ].join(' · ');
        out.add(
          MergeSemantics(
            child: ConstrainedBox(
              key: Key('stage-history-row-${r.lessonId}'),
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title ?? r.lessonId,
                            style: hankenText(size: 14),
                          ),
                          Text(extra, style: monoText(size: 10.5)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 76,
                      child: Text(
                        _pct(r.bestHeard),
                        key: Key('stage-history-heard-${r.lessonId}'),
                        textAlign: TextAlign.end,
                        style: hankenText(size: 14),
                      ),
                    ),
                    SizedBox(
                      width: 84,
                      child: Text(
                        _pct(r.bestAccuracy),
                        key: Key('stage-history-accuracy-${r.lessonId}'),
                        textAlign: TextAlign.end,
                        style: hankenText(size: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }
    if (weekly != null) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            uiText(
              context,
              StageCopy.weeklyLine,
              values: {'v0': weekly.credit, 'v1': weekly.goal},
            ),
            key: const Key('stage-history-weekly'),
            style: hankenText(size: 14),
          ),
        ),
      );
    }
    if (s.ear.lessonsPlayed > 0) {
      out
        ..add(const SizedBox(height: 16))
        ..add(
          Semantics(
            header: true,
            child: Text(
              uiText(context, V1HomeCopy.earCardTitle),
              key: const Key('stage-history-ear-title'),
              style: hankenText(size: 15, weight: FontWeight.w600),
            ),
          ),
        )
        ..add(
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              uiText(
                context,
                StageCopy.earLine,
                values: {'v0': s.ear.lessonsPlayed, 'v1': s.ear.runs},
              ),
              key: const Key('stage-history-ear'),
              style: hankenText(size: 14),
            ),
          ),
        );
    }
    return out;
  }
}
