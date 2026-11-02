import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_locale.dart';
import '../../app_theme.dart';
import '../../curriculum/v1_lesson.dart';
import '../../account_connection.dart';
import '../../course_access.dart';
import '../../design/ostinato_theme.dart';
import '../../design/widgets.dart';
import '../../ostinato_release_policy.dart';
import '../../tuner/tuner_check_memory.dart';
import '../../ui_copy.dart';
import '../setup/latency_calibration.dart';
import '../setup/setup_profile_store.dart';
import '../setup/setup_wizard_screen.dart';
import 'practice_loop_screen.dart';
import 'practice_outcome.dart';
import 'practice_progress_store.dart';
import 'v1_course_catalog.dart';
import 'v1_course_copy.dart';
import 'v1_lesson_reader_screen.dart';
import 'v1_paywall_copy.dart';

/// The full v1 guitar course (levels → modules → lessons; contract §6.4,
/// §9). Measured lessons open the practice loop; the others open the lesson
/// reader (self-check, held checkpoint, tuner, drill-soon, camera checklist).
/// A module opens when the previous module's checkpoint clears; inside an
/// open module every lesson is open. Independently of that module gate,
/// lessons outside the free scope (`ostinatoV1FreeStages`) open only through
/// the paid-access guard; titles, chips and progress stay readable.
class V1PracticeListScreen extends StatefulWidget {
  const V1PracticeListScreen({
    super.key,
    this.catalog,
    this.progressFactory,
    this.checksFactory,
    this.practiceScreenBuilder,
    this.onSessionFinished,
    this.setupStore,
    this.openSetup,
    this.tuner,
    this.startNext = false,
    this.paidFeaturesAvailable = ostinatoPaidFeaturesAvailable,
  });

  /// Whether the v1 paywall applies (release policy; tests turn it off).
  final bool paidFeaturesAvailable;

  /// Opens the first open lesson not yet done (course order) as soon as the
  /// course loads ("Start next lesson"); the course stays underneath.
  final bool startNext;

  /// F4.2 setup results; defaults to the device store.
  final SetupProfileStore? setupStore;

  /// Opens the setup wizard; tests replace it.
  final Future<void> Function(BuildContext context)? openSetup;

  /// Forwarded to every practice screen (retention wiring, PR #12).
  final void Function(PracticeSessionFinished event)? onSessionFinished;

  /// Tests pass a catalog; production loads the bundled lessons.
  final Future<V1CourseCatalog>? catalog;
  final V1PracticeProgress Function(String? accountId)? progressFactory;
  final V1LessonChecks Function(String? accountId)? checksFactory;
  final Widget Function(
    V1Lesson lesson,
    V1PracticeProgress progress,
    bool hasNext,
  )?
  practiceScreenBuilder;

  /// Forwarded to tuner lessons; defaults to the real tuner.
  final Future<TunerCheck?> Function(BuildContext context)? tuner;

  @override
  State<V1PracticeListScreen> createState() => _V1PracticeListScreenState();
}

typedef _Progress = (
  Map<String, V1PracticeRecord> records,
  Map<String, V1LessonCheck> checks,
);

class _V1PracticeListScreenState extends State<V1PracticeListScreen> {
  late Future<V1CourseCatalog> _catalog =
      widget.catalog ?? V1CourseCatalog.load();
  V1PracticeProgress? _progress;
  V1LessonChecks? _checks;
  String? _accountId;
  Future<_Progress>? _state;
  late final SetupProfileStore _setup =
      widget.setupStore ?? FileSetupProfileStore.device;
  late Future<SetupProfile> _profile = _loadProfile();

  Future<SetupProfile> _loadProfile() =>
      _setup.load().catchError((Object _) => SetupProfile.empty);

  Future<_Progress> _loadState() async {
    final records = _progress!.load();
    final checks = _checks!.load();
    return (await records, await checks);
  }

  Future<void> _openSetup() async {
    final open = widget.openSetup;
    if (open != null) {
      await open(context);
    } else {
      await openSetupWizard(context, store: _setup);
    }
    if (!mounted) return;
    final next = _loadProfile();
    setState(() {
      _profile = next;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = AccountScope.maybeOf(context)?.currentUserId;
    if (_progress == null || id != _accountId) {
      _accountId = id;
      _progress =
          widget.progressFactory?.call(id) ??
          V1PracticeProgressStore(accountUserId: id);
      _checks =
          widget.checksFactory?.call(id) ??
          V1LessonCheckStore(accountUserId: id);
      _state = _loadState();
      if (widget.startNext && !_startedNext) {
        _startedNext = true;
        unawaited(_openNext());
      }
    }
  }

  bool _startedNext = false;

  /// Units the learner opened or that held the next lesson; kept across
  /// reloads.
  final Set<String> _expanded = {};

  Future<V1CourseState?> _courseState() async {
    try {
      final catalog = await _catalog;
      final (records, checks) = await _state!;
      return V1CourseState(catalog, records, checks);
    } on Object {
      return null; // The course shows the error and a retry.
    }
  }

  Future<void> _openNext() async {
    final state = await _courseState();
    if (!mounted || state == null) return;
    final next = state.next;
    if (next != null) await _open(state.catalog, next);
  }

  void _reload() {
    final next = _loadState();
    setState(() {
      _state = next;
    });
  }

  Future<void> _open(V1CourseCatalog catalog, V1CourseLesson lesson) async {
    // Paywall gate (independent of the module gate the caller checked).
    if (!await admitV1Lesson(
          context,
          lesson.id,
          paidFeaturesAvailable: widget.paidFeaturesAvailable,
        ) ||
        !mounted) {
      return;
    }
    final next = catalog.nextAfter(lesson.id);
    final bool openNext;
    if (lesson.availability == V1LessonAvailability.measured) {
      openNext = await _openPractice(lesson.lesson, next != null);
    } else {
      final (_, checks) = await _state!.catchError(
        (Object _) => (<String, V1PracticeRecord>{}, <String, V1LessonCheck>{}),
      );
      if (!mounted) return;
      final exit = await Navigator.of(context).push<V1ReaderExit>(
        MaterialPageRoute(
          builder: (_) => V1LessonReaderScreen(
            lesson: lesson,
            checks: _checks!,
            existing: checks[lesson.id],
            hasNextLesson: next != null,
            tuner: widget.tuner,
          ),
        ),
      );
      openNext = exit == V1ReaderExit.openNextLesson;
    }
    if (!mounted) return;
    _reload();
    if (openNext && next != null) {
      final state = await _courseState();
      if (!mounted || state == null) return;
      if (state.isOpen(next.id)) unawaited(_open(catalog, next));
    }
  }

  /// Returns whether the learner asked for the next lesson.
  Future<bool> _openPractice(V1Lesson lesson, bool hasNext) async {
    // "Choose a lesson → setup → play": the wizard comes first until it has
    // been gone through once (every step done or skipped).
    final visited = (await _profile).visited;
    if (!mounted) return false;
    if (!visited) {
      await _openSetup();
      if (!mounted) return false;
    }
    final progress = _progress!;
    final exit = await Navigator.of(context).push<PracticeExit>(
      MaterialPageRoute(
        builder: (_) =>
            widget.practiceScreenBuilder?.call(lesson, progress, hasNext) ??
            PracticeLoopScreen(
              lesson: lesson,
              progress: progress,
              hasNextLesson: hasNext,
              onSessionFinished: widget.onSessionFinished,
              setupStore: _setup,
            ),
      ),
    );
    if (!mounted) return false;
    final profile = _loadProfile();
    setState(() {
      _profile = profile;
    });
    return exit == PracticeExit.openNextLesson;
  }

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    return Scaffold(
      backgroundColor: palette.surface,
      body: SafeArea(
        child: FutureBuilder<V1CourseCatalog>(
          future: _catalog,
          builder: (context, catalogSnap) {
            if (catalogSnap.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      localized(
                        context,
                        'Lessons could not be loaded.',
                        'Dersler yüklenemedi.',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        final next = V1CourseCatalog.load();
                        setState(() {
                          _catalog = next;
                        });
                      },
                      child: Text(localized(context, 'Retry', 'Yeniden dene')),
                    ),
                  ],
                ),
              );
            }
            if (!catalogSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final catalog = catalogSnap.data!;
            return FutureBuilder<_Progress>(
              future: _state,
              builder: (context, snap) {
                // A reload keeps the previous data on screen (no flash).
                if (snap.connectionState != ConnectionState.done &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final (records, checks) =
                    snap.data ??
                    (
                      const <String, V1PracticeRecord>{},
                      const <String, V1LessonCheck>{},
                    );
                final state = V1CourseState(catalog, records, checks);
                final next = state.next;
                final nextUnit = next?.unitId;
                if (nextUnit != null) _expanded.add(nextUnit);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  children: [
                    Row(
                      children: [
                        GlassIconButton(
                          icon: '‹',
                          semanticLabel: localized(context, 'Back', 'Geri'),
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            uiText(context, V1CourseCopy.title),
                            style: hankenText(
                              size: 20,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      uiText(
                        context,
                        V1CourseCopy.intro,
                        values: {'v0': catalog.lessons.length},
                      ),
                      style: hankenText(size: 13, height: 1.45),
                    ),
                    if (snap.hasError)
                      Text(
                        localized(
                          context,
                          'Progress unknown',
                          'İlerleme bilinmiyor',
                        ),
                        style: monoText(color: palette.warnInk),
                      ),
                    if (widget.paidFeaturesAvailable &&
                        v1FreeLevel('gtr') != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        uiText(
                          context,
                          V1PaywallCopy.freeScope,
                          values: {'v0': v1FreeLevel('gtr')},
                        ),
                        key: const Key('v1-course-free-scope'),
                        style: monoText(size: 10.5),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _setupCard(context),
                    const SizedBox(height: 8),
                    if (catalog.lessons.isEmpty)
                      Text(
                        localized(
                          context,
                          'No measured lessons in this build.',
                          'Bu sürümde ölçülü ders yok.',
                        ),
                      ),
                    for (final level in catalog.levels) ...[
                      _levelHeader(context, state, level),
                      for (final unit in level.units)
                        _unit(
                          context,
                          state,
                          unit,
                          unit.id == nextUnit,
                          next?.id,
                        ),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _levelHeader(
    BuildContext context,
    V1CourseState state,
    V1CourseLevel level,
  ) {
    var done = 0, total = 0;
    for (final u in level.units) {
      final (d, t) = state.unitProgress(u);
      done += d;
      total += t;
    }
    return Padding(
      key: Key('v1-course-level-${level.level}'),
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              uiText(
                context,
                V1CourseCopy.levelTitle,
                values: {'v0': level.level},
              ),
              style: hankenText(size: 17, weight: FontWeight.w600),
            ),
          ),
          Text(
            uiText(
              context,
              V1CourseCopy.levelProgress,
              values: {'v0': done, 'v1': total},
            ),
            style: monoText(size: 10.5),
          ),
        ],
      ),
    );
  }

  String _unitTitle(BuildContext context, V1CourseUnit u) {
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
    V1CourseState state,
    V1CourseUnit unit,
    bool expanded,
    String? nextId,
  ) {
    final palette = OstinatoPalette.of(context);
    final open = state.units[unit.id] ?? V1UnitOpen.locked;
    final (done, total) = state.unitProgress(unit);
    final values = {'v0': done, 'v1': total};
    final line = switch (open) {
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: PageStorageKey('v1-course-unit-${unit.id}'),
            initiallyExpanded: expanded || _expanded.contains(unit.id),
            onExpansionChanged: (open) =>
                open ? _expanded.add(unit.id) : _expanded.remove(unit.id),
            leading: Icon(
              open == V1UnitOpen.locked
                  ? Icons.lock_outline
                  : done == total
                  ? Icons.check_circle
                  : Icons.menu_book_outlined,
            ),
            title: Text(
              _unitTitle(context, unit),
              key: Key('v1-course-unit-${unit.id}'),
            ),
            subtitle: Text(
              line,
              key: Key('v1-course-unit-status-${unit.id}'),
              style: monoText(
                color: open == V1UnitOpen.openNotMeasured
                    ? palette.warnInk
                    : null,
              ),
            ),
            children: [
              if (open == V1UnitOpen.openNotMeasured)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    uiText(context, V1CourseCopy.notMeasuredNote),
                    style: hankenText(
                      size: 12.5,
                      color: palette.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
              for (final lesson in unit.lessons)
                _tile(context, state, lesson, isNext: lesson.id == nextId),
            ],
          ),
        ),
      ),
    );
  }

  UiCopy _chip(V1LessonAvailability a) => switch (a) {
    V1LessonAvailability.measured => V1CourseCopy.chipMeasured,
    V1LessonAvailability.tuner => V1CourseCopy.chipTuner,
    V1LessonAvailability.selfCheck => V1CourseCopy.chipSelfCheck,
    V1LessonAvailability.selfCheckLesson => V1CourseCopy.chipSelfCheckLesson,
    V1LessonAvailability.camera => V1CourseCopy.chipCamera,
    V1LessonAvailability.drillSoon => V1CourseCopy.chipDrill,
    V1LessonAvailability.held => V1CourseCopy.chipHeld,
  };

  String _status(
    BuildContext context,
    V1CourseLesson lesson,
    V1LessonStatus status,
    V1PracticeRecord? record,
  ) {
    final target = lesson.lesson.practice.tempo?.target;
    return switch (status) {
      V1LessonStatus.completed => localized(
        context,
        'COMPLETED · ♩={v0}',
        'TAMAMLANDI · ♩={v0}',
        values: {'v0': record?.completedBpm ?? 0},
      ),
      V1LessonStatus.passed =>
        target == null
            ? localized(
                context,
                'PASSED · ♩={v0}',
                'GEÇİLDİ · ♩={v0}',
                values: {'v0': record?.passedBpm ?? 0},
              )
            : localized(
                context,
                'PASSED · ♩={v0} · completes at ♩={v1}',
                'GEÇİLDİ · ♩={v0} · ♩={v1} ile tamamlanır',
                values: {'v0': record?.passedBpm ?? 0, 'v1': target},
              ),
      V1LessonStatus.played => localized(
        context,
        'PLAYED ×{v0}',
        'ÇALINDI ×{v0}',
        values: {'v0': record?.runs ?? 0},
      ),
      V1LessonStatus.open => localized(context, 'OPEN', 'AÇIK'),
      V1LessonStatus.locked => uiText(context, V1CourseCopy.statusLocked),
      V1LessonStatus.tuned => uiText(context, V1CourseCopy.statusTuned),
      V1LessonStatus.selfReported => uiText(
        context,
        V1CourseCopy.statusSelfReported,
      ),
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

  Widget _tile(
    BuildContext context,
    V1CourseState state,
    V1CourseLesson lesson, {
    bool isNext = false,
  }) {
    final palette = OstinatoPalette.of(context);
    final record = state.records[lesson.id];
    final status = state.status(lesson);
    final open = state.isOpen(lesson.id);
    final paid = !isFreeV1Lesson(
      lesson.id,
      paidFeaturesAvailable: widget.paidFeaturesAvailable,
    );
    // A paid lesson in a module that is not open yet still opens the
    // membership page, so the paid scope is reachable before the checkpoints
    // (App Review); after that the module gate applies as usual.
    final previewPaid = !open && paid;
    return ListTile(
      key: Key('v1-practice-${lesson.id}'),
      enabled: open || previewPaid,
      leading: Icon(switch (status) {
        V1LessonStatus.completed || V1LessonStatus.tuned => Icons.check_circle,
        V1LessonStatus.passed => Icons.check_circle_outline,
        V1LessonStatus.selfReported ||
        V1LessonStatus.heldSelfReported => Icons.task_alt,
        V1LessonStatus.locked => Icons.lock_outline,
        V1LessonStatus.held => Icons.pause_circle_outline,
        _ =>
          lesson.availability == V1LessonAvailability.measured
              ? Icons.play_circle_outline
              : Icons.menu_book_outlined,
      }),
      title: Text(lesson.lesson.title.of(context)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            uiText(context, _chip(lesson.availability)),
            key: Key('v1-course-chip-${lesson.id}'),
            style: hankenText(
              size: 11.5,
              color: lesson.availability == V1LessonAvailability.measured
                  ? palette.success
                  : palette.textMuted,
            ),
          ),
          Text(
            _status(context, lesson, status, record),
            key: Key('v1-course-status-${lesson.id}'),
            style: monoText(),
          ),
        ],
      ),
      // The suggested next lesson ("Start next lesson" rule); the others in
      // an open module stay tappable. A paid lesson also carries its
      // membership mark.
      trailing: switch ((isNext, paid)) {
        (true, true) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _nextChip(context, lesson),
            const SizedBox(height: 4),
            _membershipMark(context, lesson.id),
          ],
        ),
        (true, false) => _nextChip(context, lesson),
        (false, true) => _membershipMark(context, lesson.id),
        (false, false) => null,
      },
      onTap: open
          ? () => unawaited(_open(state.catalog, lesson))
          : previewPaid
          ? () => unawaited(_previewPaid(lesson))
          : null,
    );
  }

  /// Closed paid lesson: the paid-access guard first (sign-in, membership
  /// page); a member then hears why the lesson is still closed.
  Future<void> _previewPaid(V1CourseLesson lesson) async {
    final admitted = await admitV1Lesson(
      context,
      lesson.id,
      paidFeaturesAvailable: widget.paidFeaturesAvailable,
    );
    if (!admitted || !mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(uiText(context, V1CourseCopy.unitLocked))),
    );
  }

  /// Small mark on a lesson that needs a membership to open.
  Widget _membershipMark(BuildContext context, String id) {
    final palette = OstinatoPalette.of(context);
    return Row(
      key: Key('v1-course-paid-$id'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline, size: 15, color: palette.textMuted),
        const SizedBox(width: 3),
        Text(
          uiText(context, V1PaywallCopy.membershipMark),
          style: monoText(size: 10, color: palette.textMuted),
        ),
      ],
    );
  }

  Widget _nextChip(BuildContext context, V1CourseLesson lesson) {
    final palette = OstinatoPalette.of(context);
    return Semantics(
      label: uiText(context, V1CourseCopy.nextChipSemantics),
      child: ExcludeSemantics(
        child: Container(
          key: Key('v1-course-next-${lesson.id}'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            // The hue's chip/ink pair (contrast-checked in both themes).
            color: palette.guitar.chip,
            border: Border.all(color: palette.guitar.ink),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            uiText(context, V1CourseCopy.nextChip),
            style: hankenText(
              size: 12,
              weight: FontWeight.w600,
              color: palette.guitar.ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _setupCard(BuildContext context) => FutureBuilder<SetupProfile>(
    future: _profile,
    builder: (context, snap) {
      final p = snap.data;
      final latency = p?.latencyFor(p.lastRoute);
      final line = p == null || !p.visited
          ? localized(
              context,
              'Placement, room, latency and tuning — about two minutes.',
              'Yerleşim, oda, gecikme ve akort — yaklaşık iki dakika.',
            )
          : latency == null
          ? localized(
              context,
              'Latency not measured on this output: timing stays hidden.',
              'Bu çıkışta gecikme ölçülmedi: zamanlama gizli kalır.',
            )
          : localized(
              context,
              'Latency {v0} ms ({v1}); timing is shown.',
              'Gecikme {v0} ms ({v1}); zamanlama gösterilir.',
              values: {
                'v0': (latency.roundTripUs / 1000).round(),
                'v1': switch (p.lastRoute!) {
                  CalibrationRoute.speaker => localized(
                    context,
                    'speaker',
                    'hoparlör',
                  ),
                  CalibrationRoute.wiredHeadset => localized(
                    context,
                    'wired headphones',
                    'kablolu kulaklık',
                  ),
                  CalibrationRoute.bluetooth => localized(
                    context,
                    'Bluetooth',
                    'Bluetooth',
                  ),
                },
              },
            );
      return GlassCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          key: const Key('v1-practice-setup'),
          leading: const Icon(Icons.tune),
          title: Text(localized(context, 'Setup', 'Kurulum')),
          subtitle: Text(line, key: const Key('v1-practice-setup-status')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => unawaited(_openSetup()),
        ),
      );
    },
  );
}
