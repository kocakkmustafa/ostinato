import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../account_connection.dart';
import '../app_theme.dart';
import '../course_access.dart';
import '../design/glass_layer.dart';
import '../design/ostinato_theme.dart';
import '../ostinato_release_policy.dart';
import '../practice/loop/metronome_beat_view.dart';
import '../practice/loop/practice_loop_screen.dart';
import '../practice/loop/practice_outcome.dart';
import '../practice/loop/practice_progress_store.dart';
import '../practice/loop/practice_score.dart';
import '../practice/loop/practice_transport.dart';
import '../practice/loop/practice_session_controller.dart';
import '../practice/loop/reference_listen.dart';
import '../practice/loop/v1_course_catalog.dart';
import '../practice/loop/v1_practice_list_screen.dart';
import '../retention/weekly_goal.dart';
import '../retention/weekly_goal_store.dart';
import '../tuner/tuner_screen.dart' as tuner;
import '../practice/setup/setup_profile_store.dart';
import '../ui_copy.dart';
import 'other_practice_layer.dart';
import 'stage_copy.dart';
import 'stage_layers.dart';
import 'stage_suggestion.dart';
import 'tool_shelf.dart';

/// How long the stage waits for the membership check.
const Duration stagePaidCheckTimeout = Duration(seconds: 4);

/// The three handles of the stage (04-design.md section 5.1).
enum StageHandle { another, path, setup }

/// Builds a layer's content. Layer content and the layer manager are
/// OST-UX-05c; 05b only gives the hook (default null = no layer opens).
typedef StageLayerBuilder =
    Widget Function(
      BuildContext context,
      StageHandle handle,
      VoidCallback close,
    );

/// OST-UX-05b: the stage shell (ADR-UX-001 K1), the root while
/// `ostinatoStageHomeEnabled` is on. It shows the lesson the learner
/// continues (`V1CourseState.next`; else the first measured one), embeds the
/// existing practice screen (one "Play"), three text-labelled handles, an
/// opaque tool shelf and, while playing, the pinned opaque metronome.
///
/// While a run is going the handles are gone, nothing can open (the glass
/// budget is told `playing`) and the screen never stops on an error: the
/// practice screen shows its own failure line.
class StageHomeScreen extends StatefulWidget {
  const StageHomeScreen({
    super.key,
    this.catalog,
    this.progressFactory,
    this.checksFactory,
    this.controllerFactory,
    this.setupStore,
    this.paidFeaturesAvailable = ostinatoPaidFeaturesAvailable,
    this.paidAccessCheck,
    this.paidCheckTimeout = stagePaidCheckTimeout,
    this.onHandle,
    this.layerBuilder,
    this.budget,
    this.seed,
    this.layerManager,
    this.earScreenBuilder,
    this.tunerOpener,
  });

  /// Which layer is open (null = the stage owns one). Tests drive it.
  final StageLayerManager? layerManager;

  /// The ear-training course screen (null = the course list, as on the old
  /// root).
  final WidgetBuilder? earScreenBuilder;

  /// Opens the tuner full screen (null = `openTuner`).
  final Future<void> Function(BuildContext context)? tunerOpener;

  /// Tests pass a catalog; production loads the bundled lessons.
  final V1CourseCatalog? catalog;
  final V1PracticeProgress Function(String? accountUserId)? progressFactory;
  final V1LessonChecks Function(String? accountUserId)? checksFactory;

  /// Forwarded to the practice screen (tests inject a fake channel).
  final PracticeSessionController Function(
    PracticeScore score,
    PracticeTempo tempo,
    PassCriteria criteria,
  )?
  controllerFactory;
  final SetupProfileStore? setupStore;
  final bool paidFeaturesAvailable;

  /// Side-effect free: does the signed-in account hold a membership? Null =
  /// the account's own check; none wired = treated as not a member.
  final Future<bool> Function()? paidAccessCheck;

  /// A check that hangs counts as "not a member" (fail closed): the stage
  /// falls back to the free lesson instead of waiting on the skeleton.
  final Duration paidCheckTimeout;
  final int? seed;

  /// A handle was tapped (default no-op). A host may push an exit screen
  /// here; back returns to the stage.
  final void Function(BuildContext context, StageHandle handle)? onHandle;

  /// Layer content for a handle (05c); null = the handle opens no layer.
  final StageLayerBuilder? layerBuilder;

  /// Glass budget; the stage feeds it `playing`. Null = the stage owns one.
  final GlassLayerBudget? budget;

  @override
  State<StageHomeScreen> createState() => _StageHomeScreenState();
}

class _StageData {
  const _StageData(
    this.catalog,
    this.lesson,
    this.hasRecords,
    this.unit,
    this.miss,
    this.nextId,
  );
  final V1CourseCatalog catalog;
  final V1CourseLesson lesson;
  final bool hasRecords;
  final V1CourseUnit? unit;

  /// What the run before mostly missed (from the stored records).
  final StageMissKind miss;
  final String? nextId;
}

class _StageHomeScreenState extends State<StageHomeScreen> {
  late final GlassLayerBudget _ownBudget = GlassLayerBudget();
  GlassLayerBudget get _budget => widget.budget ?? _ownBudget;
  final ReferenceListenController _listen = ReferenceListenController();

  Future<bool> Function()? _paidCheck;
  bool _tuningSeen = false;
  String? _accountId;
  bool _inited = false;
  V1PracticeProgress? _progress;
  Future<_StageData?>? _data;

  PracticeSessionController? _pc;
  bool _playing = false;
  bool _shelfOpen = false;
  bool _pinned = false;
  bool _notice = false;
  late final StageLayerManager _ownLayers = StageLayerManager();
  StageLayerManager get _layers => widget.layerManager ?? _ownLayers;
  final Map<StageHandle, FocusNode> _handleFocus = <StageHandle, FocusNode>{
    for (final h in StageHandle.values)
      h: FocusNode(debugLabel: 'handle-${h.name}'),
  };
  final FocusScopeNode _layerScope = FocusScopeNode(debugLabel: 'stage-layer');
  StageLayer? _lastTop;
  StageMissKind? _sessionMiss;
  bool _ranThisSession = false;
  int _epoch = 0;

  static StageHandle _handleOf(StageLayer l) => switch (l) {
    StageLayer.other => StageHandle.another,
    StageLayer.path => StageHandle.path,
    StageLayer.setup => StageHandle.setup,
  };

  @override
  void initState() {
    super.initState();
    _layers.addListener(_onLayers);
  }

  @override
  void didUpdateWidget(StageHomeScreen old) {
    super.didUpdateWidget(old);
    if (old.layerManager != widget.layerManager) {
      (old.layerManager ?? _ownLayers).removeListener(_onLayers);
      _layers.addListener(_onLayers);
    }
  }

  /// A layer opened: focus its first item; it closed: focus its handle.
  void _onLayers() {
    if (!mounted) return;
    final top = _layers.top;
    final before = _lastTop;
    _lastTop = top;
    setState(() {});
    if (top != null && top != before) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _layers.top != top) return;
        final first = _layerScope.traversalDescendants
            .where((n) => n.canRequestFocus && !n.skipTraversal)
            .firstOrNull;
        (first ?? _layerScope).requestFocus();
      });
    } else if (top == null && before != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _layers.isOpen || _playing) return;
        _handleFocus[_handleOf(before)]!.requestFocus();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = AccountScope.maybeOf(context)?.currentUserId;
    _paidCheck =
        widget.paidAccessCheck ??
        AccountScope.maybeOf(context)?.connection?.hasPaidAccess;
    if (!_inited || id != _accountId) {
      _inited = true;
      _accountId = id;
      _progress =
          widget.progressFactory?.call(id) ??
          V1PracticeProgressStore(accountUserId: id);
      _data = _load(id);
    }
  }

  Future<_StageData?> _load(String? id) async {
    try {
      final catalog = widget.catalog ?? await V1CourseCatalog.load();
      final records = await _progress!.load();
      final checks =
          await (widget.checksFactory?.call(id) ??
                  V1LessonCheckStore(accountUserId: id))
              .load();
      final state = V1CourseState(catalog, records, checks);
      // Same rule as `admitV1Lesson` (free lessons open; a paid one needs a
      // membership), asked WITHOUT its sign-in / membership-page side effects.
      var member = false;
      var memberAsked = false;
      Future<void> askMember() async {
        if (memberAsked) return;
        memberAsked = true;
        try {
          member = await (_paidCheck?.call() ?? Future<bool>.value(false))
              .timeout(widget.paidCheckTimeout, onTimeout: () => false);
        } on Object {
          member = false;
        }
      }

      bool measured(V1CourseLesson l) =>
          l.availability == V1LessonAvailability.measured;
      bool free(V1CourseLesson l) => isFreeV1Lesson(
        l.id,
        paidFeaturesAvailable: widget.paidFeaturesAvailable,
      );
      final next = state.next;
      if (next != null && measured(next) && !free(next)) await askMember();
      bool usable(V1CourseLesson l) => measured(l) && (free(l) || member);
      // The learner's next lesson when it is measured and admitted; else the
      // first open measured one not done; else the first measured one.
      V1CourseLesson? pick = next != null && usable(next) ? next : null;
      pick ??= catalog.lessons
          .where(
            (l) =>
                measured(l) &&
                free(l) &&
                state.isOpen(l.id) &&
                !state.isDone(l),
          )
          .firstOrNull;
      pick ??= catalog.lessons.where((l) => measured(l) && free(l)).firstOrNull;
      if (pick == null) return null;
      final unit = catalog.units.where((u) => u.id == pick!.unitId).firstOrNull;
      final hasRecords =
          records.values.any((r) => r.runs > 0) || checks.isNotEmpty;
      return _StageData(
        catalog,
        pick,
        hasRecords,
        unit,
        missFromRecord(lastRunRecord(records.values)),
        next?.id,
      );
    } on Object {
      return null;
    }
  }

  void _retry() => setState(() => _data = _load(_accountId));

  @override
  void dispose() {
    _layers.removeListener(_onLayers);
    for (final n in _handleFocus.values) {
      n.dispose();
    }
    _layerScope.dispose();
    _pc?.removeListener(_onRun);
    _listen.dispose();
    _ownBudget.dispose();
    super.dispose();
  }

  void _gotController(PracticeSessionController c) {
    // Called from the practice screen's initState (mid build): defer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pc?.removeListener(_onRun);
      _pc = c..addListener(_onRun);
      setState(() {});
    });
  }

  void _onRun() {
    if (!mounted) return;
    final playing = _pc?.running ?? false;
    if (playing == _playing) return;
    _budget.playing = playing;
    _layers.locked = playing;
    setState(() {
      _playing = playing;
      if (playing) {
        _shelfOpen = false;
        _notice = false;
      }
    });
  }

  void _tapHandle(StageHandle h) {
    if (_playing) return;
    widget.onHandle?.call(context, h);
    // 05d (path) and 05f (setup) bring their own content; until then only
    // the "another practice" handle has a built-in layer.
    if (widget.layerBuilder != null || h == StageHandle.another) {
      _layers.openLayer(switch (h) {
        StageHandle.another => StageLayer.other,
        StageHandle.path => StageLayer.path,
        StageHandle.setup => StageLayer.setup,
      });
    }
  }

  void _closeLayer() => _layers.close();

  Widget _layerContent(BuildContext context, _StageData data, StageLayer l) {
    final h = _handleOf(l);
    final custom = widget.layerBuilder;
    if (custom != null) return custom(context, h, _closeLayer);
    return OtherPracticeLayer(
      suggestion: stageSuggestion(
        hasRecords: data.hasRecords || _ranThisSession,
        nextLessonId: data.nextId,
        miss: _sessionMiss ?? data.miss,
      ),
      close: _closeLayer,
      openEar: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: widget.earScreenBuilder ?? (_) => _earScreen(),
        ),
      ),
      openTuner: () =>
          (widget.tunerOpener ?? (c) => tuner.openTuner(c))(context),
    );
  }

  Widget _earScreen() => V1PracticeListScreen(
    course: 'ear',
    onSessionFinished: (e) => WeeklyGoalStore(accountUserId: _accountId)
        .recordPracticeSession(
          MeasuredPracticeSession(
            course: PracticeCourse.ear,
            activeDuration: e.activeDuration,
            heardEvents: e.heardEvents,
            lessonId: e.lessonId,
          ),
        )
        .then<void>((_) {}, onError: (_) {}),
  );

  /// Back: a layer closes first; during a run the run ends and is NOT
  /// recorded (the practice screen is rebuilt, its listener is removed
  /// before it stops the session, so no result and no store write follow).
  void _onBack() {
    if (_layers.isOpen) {
      _closeLayer();
      return;
    }
    if (_playing) {
      _pc?.removeListener(_onRun);
      _pc = null;
      _budget.playing = false;
      // The listener is gone, so `_onRun` never reports the end: unlock here.
      _layers.locked = false;
      setState(() {
        _playing = false;
        _notice = true;
        _epoch++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    return PopScope(
      canPop: !_layers.isOpen && !_playing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        key: const Key('stage-home'),
        backgroundColor: palette.surface,
        body: SafeArea(
          child: FutureBuilder<_StageData?>(
            future: _data,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return _skeleton(context, failed: false);
              }
              final data = snap.data;
              if (data == null) return _skeleton(context, failed: true);
              return _stage(context, data);
            },
          ),
        ),
      ),
    );
  }

  Widget _skeleton(BuildContext context, {required bool failed}) => Column(
    children: <Widget>[
      const Spacer(),
      if (failed)
        TextButton(
          key: const Key('stage-retry'),
          onPressed: _retry,
          child: Text(uiText(context, StageCopy.tryAgain)),
        ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          key: const Key('stage-play-pending'),
          onPressed: null,
          child: Text(uiText(context, StageCopy.play)),
        ),
      ),
      _handles(context),
    ],
  );

  Widget _stage(BuildContext context, _StageData data) {
    final unit = data.unit;
    final headline = data.hasRecords && unit?.module != null
        ? uiText(
            context,
            StageCopy.continueLine,
            values: {'v0': unit!.level, 'v1': unit.module},
          )
        : uiText(context, StageCopy.justStarting);
    final open = _layers.open;
    final height = MediaQuery.sizeOf(context).height;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: ExcludeSemantics(
            excluding: open.isNotEmpty,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Text(
                    headline,
                    key: const Key('stage-headline'),
                    style: hankenText(size: 13),
                  ),
                ),
                if (_notice)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: Text(
                      uiText(context, StageCopy.runNotCompleted),
                      key: const Key('stage-run-not-completed'),
                      style: hankenText(size: 13),
                    ),
                  ),
                Expanded(
                  child: Semantics(
                    sortKey: const OrdinalSortKey(0),
                    child: PracticeLoopScreen(
                      key: ValueKey<int>(_epoch),
                      lesson: data.lesson.lesson,
                      progress: _progress!,
                      stageMode: true,
                      onController: _gotController,
                      listenController: _listen,
                      controllerFactory: widget.controllerFactory,
                      setupStore: widget.setupStore,
                      seed: widget.seed,
                      tuningCardSeen: _tuningSeen,
                      onStarted: () => _tuningSeen = true,
                      onSessionFinished: (e) {
                        _sessionMiss = missFromSummary(e.summary);
                        _ranThisSession = true;
                      },
                      beforeStart:
                          isFreeV1Lesson(
                            data.lesson.id,
                            paidFeaturesAvailable: widget.paidFeaturesAvailable,
                          )
                          ? null
                          : () => admitV1Lesson(
                              context,
                              data.lesson.id,
                              paidFeaturesAvailable:
                                  widget.paidFeaturesAvailable,
                            ),
                    ),
                  ),
                ),
                if (_playing && _pinned && _pc != null) _pinnedMetronome(),
                if (!_playing) ...<Widget>[
                  Semantics(
                    sortKey: const OrdinalSortKey(1),
                    child: _handles(context),
                  ),
                  Semantics(
                    sortKey: const OrdinalSortKey(2),
                    child: ToolShelf(
                      maxContentHeight: height * 0.34,
                      open: _shelfOpen,
                      onToggle: () => setState(() => _shelfOpen = !_shelfOpen),
                      controller: _pc,
                      listen: _listen,
                      pinned: _pinned,
                      onPinned: (v) => setState(() => _pinned = v),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (open.isNotEmpty)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, box) => Stack(
                children: <Widget>[
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: box.maxHeight * 0.4,
                    child: GestureDetector(
                      key: const Key('stage-layer-scrim'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _closeLayer,
                    ),
                  ),
                  for (final l in open)
                    GlassLayer(
                      key: ValueKey<StageLayer>(l),
                      budget: _budget,
                      child: FocusScope(
                        node: _layerScope,
                        child: _layerContent(context, data, l),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Opaque, tiny, outside the glass budget (design section 6).
  Widget _pinnedMetronome() {
    final palette = OstinatoPalette.of(context);
    final c = _pc!;
    return Material(
      key: const Key('stage-pinned-metronome'),
      color: palette.surface,
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) =>
            MetronomeBeatView(state: c.beat, beatsPerBar: c.score.beatsPerBar),
      ),
    );
  }

  Widget _handles(BuildContext context) {
    Widget handle(String key, UiCopy label, StageHandle h) => Expanded(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: OutlinedButton(
          key: Key(key),
          focusNode: _handleFocus[h],
          onPressed: _playing ? null : () => _tapHandle(h),
          child: Text(
            uiText(context, label),
            textAlign: TextAlign.center,
            style: hankenText(size: 14, weight: FontWeight.w500),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        key: const Key('stage-handles'),
        children: <Widget>[
          handle(
            'stage-handle-other',
            StageCopy.handleOther,
            StageHandle.another,
          ),
          const SizedBox(width: 8),
          handle('stage-handle-path', StageCopy.handlePath, StageHandle.path),
          const SizedBox(width: 8),
          handle(
            'stage-handle-setup',
            StageCopy.handleSetup,
            StageHandle.setup,
          ),
        ],
      ),
    );
  }
}
