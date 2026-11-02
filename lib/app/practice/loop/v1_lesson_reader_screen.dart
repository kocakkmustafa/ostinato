import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_locale.dart';
import '../../app_theme.dart';
import '../../design/ostinato_theme.dart';
import '../../design/widgets.dart';
import '../../tuner/tuner_check_memory.dart';
import '../../tuner/tuner_guidance.dart' show kDefaultTunerToleranceCents;
import '../../tuner/tuner_screen.dart' show openTuner;
import '../../tuner/tunings.dart';
import '../../ui_copy.dart';
import 'practice_progress_store.dart';
import 'v1_course_catalog.dart';
import 'v1_course_copy.dart';

enum V1ReaderExit { closed, openNextLesson }

/// A v1 lesson this build cannot run in the measured practice loop: goal,
/// explanation, task, an honest note on what is not measured yet, and the
/// self-check (contract §3 Ö, §4.2). Tuner lessons open the tuner instead.
/// No reference playback: the app cannot synthesize lesson references yet,
/// and the screen says so.
class V1LessonReaderScreen extends StatefulWidget {
  const V1LessonReaderScreen({
    super.key,
    required this.lesson,
    required this.checks,
    this.existing,
    this.hasNextLesson = false,
    this.tuner,
  });

  final V1CourseLesson lesson;
  final V1LessonChecks checks;
  final V1LessonCheck? existing;
  final bool hasNextLesson;

  /// Opens the tuner and returns today's check; defaults to [openTuner].
  final Future<TunerCheck?> Function(BuildContext context)? tuner;

  @override
  State<V1LessonReaderScreen> createState() => _V1LessonReaderScreenState();
}

class _V1LessonReaderScreenState extends State<V1LessonReaderScreen> {
  late V1LessonCheck? _check = widget.existing;
  late final List<bool> _ticks = List.filled(_itemCount, false);
  bool _saving = false;
  bool _saveFailed = false;
  bool _tunerMissed = false;

  V1CourseLesson get _l => widget.lesson;
  bool get _isTuner => _l.availability == V1LessonAvailability.tuner;

  int get _itemCount => _l.lesson.selfCheck.isNotEmpty
      ? _l.lesson.selfCheck.length
      : _genericItems.length;

  List<(UiCopy, Map<String, Object?>)> get _genericItems {
    if (_l.availability == V1LessonAvailability.drillSoon) {
      return const [
        (V1CourseCopy.genericTaskDone, {}),
        (V1CourseCopy.genericExplain, {}),
      ];
    }
    final target = _l.lesson.practice.tempo?.target;
    return [
      (V1CourseCopy.genericPlayedThrough, const {}),
      target == null
          ? (V1CourseCopy.genericSteady, const {})
          : (V1CourseCopy.genericTempo, {'v0': target}),
      (V1CourseCopy.genericClear, const {}),
    ];
  }

  List<String> _items(BuildContext context) => _l.lesson.selfCheck.isNotEmpty
      ? [for (final t in _l.lesson.selfCheck) t.of(context)]
      : [
          for (final (copy, values) in _genericItems)
            uiText(context, copy, values: values),
        ];

  Future<void> _record(V1CheckEvidence evidence) async {
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      final saved = await widget.checks.record(_l.id, evidence);
      if (!mounted) return;
      setState(() {
        _check = saved;
        _saving = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
    }
  }

  Future<void> _tune() async {
    final check = await (widget.tuner ?? (c) => openTuner(c))(context);
    if (!mounted) return;
    final tuned =
        check != null &&
        check.allInTune &&
        check.presetId == TuningPresets.guitarStandard.id;
    setState(() {
      _tunerMissed = !tuned;
    });
    if (tuned) await _record(V1CheckEvidence.tunerCheck);
  }

  UiCopy get _banner => switch (_l.availability) {
    V1LessonAvailability.selfCheck => V1CourseCopy.bannerSelfCheck,
    V1LessonAvailability.selfCheckLesson => V1CourseCopy.bannerSelfCheckLesson,
    V1LessonAvailability.camera => V1CourseCopy.bannerCamera,
    V1LessonAvailability.drillSoon => V1CourseCopy.bannerDrill,
    V1LessonAvailability.held => V1CourseCopy.bannerHeld,
    V1LessonAvailability.tuner ||
    V1LessonAvailability.measured => V1CourseCopy.bannerTuner,
  };

  UiCopy? get _reason => switch (_l.reason) {
    V1PendingReason.chords => V1CourseCopy.reasonChords,
    V1PendingReason.pitchTrack => V1CourseCopy.reasonPitchTrack,
    V1PendingReason.piano => V1CourseCopy.reasonPiano,
    V1PendingReason.technique => V1CourseCopy.reasonTechnique,
    V1PendingReason.notation => V1CourseCopy.reasonNotation,
    // The camera and drill banners already say what is missing.
    V1PendingReason.camera ||
    V1PendingReason.drill ||
    V1PendingReason.none => null,
  };

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final lesson = _l.lesson;
    final tempo = lesson.practice.tempo;
    final done = _check != null;
    final heading = hankenText(size: 15, weight: FontWeight.w600);
    final body = hankenText(size: 13.5, height: 1.45);
    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: heading),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
    final items = _items(context);
    return Scaffold(
      backgroundColor: palette.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: [
            Row(
              children: [
                GlassIconButton(
                  icon: '‹',
                  semanticLabel: localized(context, 'Back', 'Geri'),
                  onTap: () => Navigator.of(context).pop(V1ReaderExit.closed),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lesson.title.of(context),
                    style: hankenText(size: 20, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GlassCard(
              key: const Key('v1-reader-banner'),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    uiText(
                      context,
                      _banner,
                      values: {'v0': kDefaultTunerToleranceCents.round()},
                    ),
                    style: body,
                  ),
                  if (_reason != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      uiText(context, _reason!),
                      key: const Key('v1-reader-reason'),
                      style: hankenText(
                        size: 12.5,
                        color: palette.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            section(uiText(context, V1CourseCopy.readerGoal), [
              Text(lesson.goal.of(context), style: body),
            ]),
            section(uiText(context, V1CourseCopy.readerExplanation), [
              for (final point in lesson.explanation)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${point.of(context)}', style: body),
                ),
            ]),
            section(uiText(context, V1CourseCopy.readerTask), [
              Text(lesson.practice.task.of(context), style: body),
              if (tempo != null) ...[
                const SizedBox(height: 4),
                Text(
                  uiText(
                    context,
                    V1CourseCopy.readerTempo,
                    values: {'v0': tempo.open, 'v1': tempo.target},
                  ),
                  style: monoText(size: 11, color: palette.textMono),
                ),
              ],
            ]),
            if (lesson.referenceAudio.kinds.isNotEmpty && !_isTuner)
              section(uiText(context, V1CourseCopy.readerReference), [
                Text(
                  uiText(context, V1CourseCopy.readerReferenceSoon),
                  key: const Key('v1-reader-reference'),
                  style: hankenText(
                    size: 12.5,
                    color: palette.textMuted,
                    height: 1.4,
                  ),
                ),
              ]),
            if (_isTuner)
              ..._tunerPart(context, body)
            else
              ..._selfCheckPart(context, items, done, body),
            if (_saveFailed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  uiText(context, V1CourseCopy.readerSaveFailed),
                  style: hankenText(size: 12.5, color: palette.warnInk),
                ),
              ),
            if (done && widget.hasNextLesson)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton(
                  key: const Key('v1-reader-next'),
                  onPressed: () =>
                      Navigator.of(context).pop(V1ReaderExit.openNextLesson),
                  child: Text(uiText(context, V1CourseCopy.readerNext)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _tunerPart(BuildContext context, TextStyle body) {
    final palette = OstinatoPalette.of(context);
    final tuned = _check?.evidence == V1CheckEvidence.tunerCheck;
    return [
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const Key('v1-reader-tuner'),
        onPressed: _saving ? null : () => unawaited(_tune()),
        icon: const Icon(Icons.tune),
        label: Text(uiText(context, V1CourseCopy.readerOpenTuner)),
      ),
      if (tuned)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            uiText(context, V1CourseCopy.readerTuned),
            key: const Key('v1-reader-status'),
            style: hankenText(size: 13, color: palette.success),
          ),
        )
      else if (_tunerMissed)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            uiText(context, V1CourseCopy.readerNotTuned),
            key: const Key('v1-reader-status'),
            style: body,
          ),
        ),
    ];
  }

  List<Widget> _selfCheckPart(
    BuildContext context,
    List<String> items,
    bool done,
    TextStyle body,
  ) {
    final palette = OstinatoPalette.of(context);
    final allTicked = _ticks.every((t) => t);
    final held = _l.availability == V1LessonAvailability.held;
    return [
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          uiText(context, V1CourseCopy.chipSelfCheckLesson),
          style: hankenText(size: 15, weight: FontWeight.w600),
        ),
      ),
      for (var i = 0; i < items.length; i++)
        CheckboxListTile(
          key: Key('v1-reader-check-$i'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: done || _ticks[i],
          onChanged: done
              ? null
              : (v) => setState(() {
                  _ticks[i] = v ?? false;
                }),
          title: Text(items[i], style: body),
        ),
      if (done)
        Text(
          uiText(
            context,
            held ? V1CourseCopy.readerHeldDone : V1CourseCopy.readerDoneSelf,
          ),
          key: const Key('v1-reader-status'),
          style: hankenText(size: 13, color: palette.textMuted, height: 1.4),
        )
      else ...[
        if (!allTicked)
          Text(
            uiText(context, V1CourseCopy.readerTickAll),
            style: hankenText(size: 12.5, color: palette.textMuted),
          ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('v1-reader-mark-done'),
          onPressed: allTicked && !_saving
              ? () => unawaited(_record(V1CheckEvidence.selfReport))
              : null,
          child: Text(uiText(context, V1CourseCopy.readerMarkDone)),
        ),
      ],
    ];
  }
}
