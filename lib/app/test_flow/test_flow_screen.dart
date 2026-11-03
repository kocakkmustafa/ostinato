import 'dart:async';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../curriculum/v1_lesson.dart';
import '../design/ostinato_theme.dart';
import '../drill/drill_screen.dart';
import '../practice/loop/practice_loop_screen.dart';
import '../practice/loop/practice_outcome.dart';
import '../practice/loop/practice_progress_store.dart';
import '../ui_copy.dart';
import 'test_flow_copy.dart';
import 'test_flow_store.dart';

/// Runs a checkpoint part by part (Yönetim 2026-11-03): each part uses an
/// existing measured path (drill screen, clapping practice loop) or an
/// unmeasured self-check (singing). A failed part is repeated alone; results
/// are kept locally, so the flow resumes at the first unfinished part. When
/// every required part has passed the lesson is recorded as `test_pass`.
class TestFlowScreen extends StatefulWidget {
  const TestFlowScreen({
    super.key,
    required this.lesson,
    required this.store,
    required this.checks,
    this.runPart,
  });

  final V1Lesson lesson;
  final TestFlowProgress store;
  final V1LessonChecks checks;

  /// Runs one part and reports whether it passed (tests replace it).
  final Future<bool?> Function(BuildContext context, V1TestSection part)?
  runPart;

  @override
  State<TestFlowScreen> createState() => _TestFlowScreenState();
}

class _TestFlowScreenState extends State<TestFlowScreen> {
  Map<int, TestSectionResult>? _results;

  List<V1TestSection> get _parts => widget.lesson.practice.sections;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final r = await widget.store.load(widget.lesson.id);
    if (mounted) setState(() => _results = r);
  }

  bool _passed(int i) => _results?[i]?.passed ?? false;

  int? get _next {
    for (var i = 0; i < _parts.length; i++) {
      if (_parts[i].required && !_passed(i)) return i;
    }
    return null;
  }

  int get _requiredCount => _parts.where((p) => p.required).length;
  int get _requiredPassed => [
    for (var i = 0; i < _parts.length; i++)
      if (_parts[i].required && _passed(i)) i,
  ].length;

  Future<void> _run(int index) async {
    final part = _parts[index];
    final passed = await (widget.runPart ?? _defaultRun)(context, part);
    if (passed == null || !mounted) return;
    await widget.store.record(widget.lesson.id, index, passed: passed);
    await _load();
    if (_next == null) {
      await widget.checks.record(widget.lesson.id, V1CheckEvidence.testPass);
    }
  }

  Future<bool?> _defaultRun(BuildContext context, V1TestSection part) =>
      switch (part.kind) {
        V1SectionKind.drill => Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) =>
                DrillScreen(drill: part.drill!, title: part.title.of(context)),
          ),
        ),
        V1SectionKind.clap => _runClap(context, part),
        V1SectionKind.selfCheck => Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => _SelfCheckPart(part: part)),
        ),
      };

  Future<bool?> _runClap(BuildContext context, V1TestSection part) async {
    final capture = _CapturedRun();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PracticeLoopScreen(
          lesson: widget.lesson.forSection(part),
          progress: capture,
        ),
      ),
    );
    return capture.ran ? capture.passed : null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final results = _results;
    final next = _next;
    return Scaffold(
      backgroundColor: palette.surface,
      appBar: AppBar(title: Text(widget.lesson.title.of(context))),
      body: SafeArea(
        child: results == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Text(
                    uiText(context, TestFlowCopy.title),
                    style: hankenText(size: 20, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    uiText(context, TestFlowCopy.intro),
                    style: hankenText(size: 13.5, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    next == null
                        ? uiText(context, TestFlowCopy.resultPassed)
                        : uiText(
                            context,
                            TestFlowCopy.resultProgress,
                            values: {
                              'v0': _requiredPassed,
                              'v1': _requiredCount,
                            },
                          ),
                    key: const Key('test-flow-result'),
                    style: hankenText(
                      size: 14,
                      weight: FontWeight.w600,
                      color: next == null ? palette.success : palette.textBody,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _parts.length; i++) _partTile(context, i),
                  if (next != null) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const Key('test-flow-continue'),
                      onPressed: () => unawaited(_run(next)),
                      child: Text(
                        uiText(
                          context,
                          TestFlowCopy.continueWith,
                          values: {'v0': _parts[next].title.of(context)},
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _partTile(BuildContext context, int i) {
    final palette = OstinatoPalette.of(context);
    final part = _parts[i];
    final result = _results![i];
    final status = !part.required
        ? (result != null
              ? TestFlowCopy.partSelfDone
              : TestFlowCopy.partSelfCheck)
        : result == null
        ? TestFlowCopy.partToDo
        : result.passed
        ? TestFlowCopy.partPassed
        : TestFlowCopy.partNotYet;
    final passed = part.required && (result?.passed ?? false);
    return Card(
      child: ListTile(
        key: Key('test-flow-part-$i'),
        leading: Icon(switch (part.kind) {
          V1SectionKind.drill => Icons.quiz_outlined,
          V1SectionKind.clap => Icons.front_hand_outlined,
          V1SectionKind.selfCheck => Icons.record_voice_over_outlined,
        }),
        title: Text(part.title.of(context)),
        subtitle: Text(
          uiText(context, status),
          key: Key('test-flow-status-$i'),
          style: monoText(
            size: 10,
            color: passed ? palette.success : palette.textMono,
          ),
        ),
        trailing: passed
            ? Icon(Icons.check_circle, color: palette.success)
            : const Icon(Icons.chevron_right),
        // A passed required part is done; anything else may be (re)run.
        onTap: passed ? null : () => unawaited(_run(i)),
      ),
    );
  }
}

/// Records nothing durable: the practice loop's run result for one part.
final class _CapturedRun implements V1PracticeProgress {
  bool ran = false;
  bool passed = false;

  @override
  Future<Map<String, V1PracticeRecord>> load() async => {};

  @override
  Future<V1PracticeRecord> recordRun(
    String id,
    PracticeRunSummary s, {
    DateTime? at,
  }) async {
    final record = V1PracticeRecord(
      lessonId: id,
    ).withRun(s, at ?? DateTime.now());
    ran = true;
    passed = passed || record.passed;
    return record;
  }
}

class _SelfCheckPart extends StatefulWidget {
  const _SelfCheckPart({required this.part});
  final V1TestSection part;

  @override
  State<_SelfCheckPart> createState() => _SelfCheckPartState();
}

class _SelfCheckPartState extends State<_SelfCheckPart> {
  late final List<bool> _ticks = List.filled(widget.part.items.length, false);

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    return Scaffold(
      backgroundColor: palette.surface,
      appBar: AppBar(title: Text(widget.part.title.of(context))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            uiText(context, TestFlowCopy.partSelfCheck),
            style: monoText(size: 11, color: palette.textMono),
          ),
          for (var i = 0; i < _ticks.length; i++)
            CheckboxListTile(
              key: Key('test-flow-self-$i'),
              value: _ticks[i],
              onChanged: (v) => setState(() => _ticks[i] = v ?? false),
              title: Text(widget.part.items[i].of(context)),
            ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('test-flow-self-done'),
            onPressed: _ticks.every((t) => t)
                ? () => Navigator.of(context).pop(true)
                : null,
            child: Text(uiText(context, TestFlowCopy.selfCheckDone)),
          ),
        ],
      ),
    );
  }
}
