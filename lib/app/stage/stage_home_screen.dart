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
import '../practice/loop/v1_practice_catalog.dart';
import '../practice/loop/v1_practice_list_screen.dart';
import '../retention/weekly_goal.dart';
import '../retention/weekly_goal_store.dart';
import '../tuner/tuner_screen.dart' as tuner;
import '../practice/setup/setup_profile_store.dart';
import '../ui_copy.dart';
import '../audio/mic_permission_gate.dart';
import '../practice/setup/setup_wizard_screen.dart';
import '../screens/settings_screen.dart';
import '../tuner/session_tuning_gate.dart';
import '../tuner/tunings.dart';
import 'device_layer.dart';
import 'ghost_policy.dart';
import 'ghost_store.dart';
import 'listening_off_store.dart';
import 'other_practice_layer.dart';
import 'package:permission_handler/permission_handler.dart'
    show PermissionStatus, PermissionStatusGetters, openAppSettings;
import 'path_layer.dart';
import 'path_summary.dart';
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
    this.weeklyGoalLoader,
    this.micStatus,
    this.appSettingsOpener,
    this.listeningOffStore,
    this.setupOpener,
    this.settingsOpener,
    this.accountOpener,
    this.ghostOpen = ostinatoGhostScreenOpen,
    this.ghostStore,
    this.ghostStoreFactory,
  });

  // OST-UX-05g: the Ghost (Help) flag and its local store. Null store = the
  // account's own file; tests inject one (or a per-account factory).
  final bool ghostOpen;
  final GhostStore? ghostStore;
  final GhostStore Function(String? accountUserId)? ghostStoreFactory;

  // 05f seams (null = the real thing).
  final Future<PermissionStatus> Function()? micStatus;
  final Future<bool> Function()? appSettingsOpener;
  final ListeningOffStore? listeningOffStore;
  final Future<void> Function(BuildContext context)? setupOpener;
  final Future<void> Function(BuildContext context)? settingsOpener;
  final Future<void> Function(BuildContext context)? accountOpener;

  /// Which layer is open (null = the stage owns one). Tests drive it.
  final StageLayerManager? layerManager;

  /// The ear-training course screen (null = the course list, as on the old
  /// root).
  final WidgetBuilder? earScreenBuilder;

  /// Reads the weekly goal for the history (null = the account's own
  /// `WeeklyGoalStore`). A failure only hides that one line.
  final Future<WeeklyGoalStatus?> Function()? weeklyGoalLoader;

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

class _StageHomeScreenState extends State<StageHomeScreen>
    with WidgetsBindingObserver {
  late final GlassLayerBudget _ownBudget = GlassLayerBudget();
  GlassLayerBudget get _budget => widget.budget ?? _ownBudget;
  final ReferenceListenController _listen = ReferenceListenController();

  Future<bool> Function()? _paidCheck;
  bool _tuningSeen = false;

  // 05f: the microphone was refused on the last start -> "Listening is off".
  bool _micOff = false;
  // The failure the last notification carried (the mode is entered on the
  // TRANSITION to 'permission', so a later unrelated notification does not
  // bring it back after the learner allowed the microphone).
  String? _lastFailure;
  // null = not read yet (the link stays hidden until the store answers).
  bool? _hintMuted;
  ListeningOffStore? _ownOffStore;
  ListeningOffStore get _offStore =>
      widget.listeningOffStore ?? (_ownOffStore ??= FileListeningOffStore());
  String? _accountId;
  bool _inited = false;
  V1PracticeProgress? _progress;
  Future<_StageData?>? _data;

  PracticeSessionController? _pc;
  bool _playing = false;
  bool _shelfOpen = false;

  // OST-UX-05g: the help (Ghost) level, kept in its own store. Only exists
  // while the flag is open.
  bool _helpOpen = false;
  GhostState _ghost = const GhostState();

  /// False until the store's first read ends: until then the practice
  /// screen gets no level (as without the flag), never a guessed one.
  bool _ghostLoaded = false;
  GhostStore? _ghostStore;
  Future<void>? _ghostReady;
  V1CourseCatalog? _ghostCatalog;
  bool _pinned = false;
  bool _notice = false;
  bool _startUnverified = false;
  late final StageLayerManager _ownLayers = StageLayerManager();
  StageLayerManager get _layers => widget.layerManager ?? _ownLayers;
  final Map<StageHandle, FocusNode> _handleFocus = <StageHandle, FocusNode>{
    for (final h in StageHandle.values)
      h: FocusNode(debugLabel: 'handle-${h.name}'),
  };
  final FocusScopeNode _layerScope = FocusScopeNode(debugLabel: 'stage-layer');
  StageLayer? _lastTop;
  // What the stored records say after a run of this session (05d ek B/E):
  // the same `missFromRecord` rule as a fresh open, read from the store.
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
    WidgetsBinding.instance.addObserver(this);
    unawaited(_readMuted());
  }

  Future<void> _readMuted() async {
    var muted = false;
    try {
      muted = await _offStore.settingsHintMuted();
    } on Object {
      muted = false;
    }
    if (!mounted) return;
    setState(() => _hintMuted = muted);
  }

  /// Bumped on every account change: a read (or a counted run) that finishes
  /// after the account changed must not touch the new account's state.
  int _ghostEpoch = 0;

  Future<void> _readGhost(GhostStore store, int epoch) async {
    final g = await store.load();
    if (!mounted || epoch != _ghostEpoch) return;
    setState(() {
      _ghost = g;
      _ghostLoaded = true;
    });
  }

  bool _isRhythmOnly(String lessonId) {
    final catalog = _ghostCatalog;
    if (catalog == null) return false;
    for (final u in catalog.units) {
      for (final l in u.lessons) {
        if (l.lesson.id == lessonId) {
          return V1PracticeCatalog.scoreOf(l.lesson)?.isRhythmOnly ?? false;
        }
      }
    }
    return false;
  }

  /// A run finished on the stage: the Ghost counts it (never changes the
  /// level) and keeps it in its own store. Ear / rhythm-only runs are left
  /// out by the policy.
  Future<void> _onSessionFinished(PracticeSessionFinished e) async {
    final store = _ghostStore;
    if (!widget.ghostOpen || store == null) return;
    final epoch = _ghostEpoch;
    await _ghostReady;
    if (!mounted || epoch != _ghostEpoch) return;
    final next = GhostPolicy.afterRun(
      _ghost,
      e,
      rhythmOnly: _isRhythmOnly(e.lessonId),
    );
    if (identical(next, _ghost)) return;
    setState(() => _ghost = next);
    await store.save(next);
  }

  Future<void> _selectGhost(GhostLevel l) async {
    final store = _ghostStore;
    if (_playing || store == null) return;
    final next = GhostPolicy.select(_ghost, l);
    setState(() => _ghost = next);
    await store.save(next);
  }

  Future<void> _muteHint() async {
    setState(() => _hintMuted = true);
    try {
      await _offStore.muteSettingsHint();
    } on Object {
      // The mute is for this run of the app at least.
    }
  }

  Future<void> _goToSettings() async {
    try {
      await (widget.appSettingsOpener ?? openAppSettings)();
    } on Object {
      // Nothing to show: the link stays.
    }
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusFirst(top));
    } else if (top == null && before != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _layers.isOpen || _playing) return;
        _handleFocus[_handleOf(before)]!.requestFocus();
      });
    }
  }

  /// Focus the first real item of the open layer (else the layer itself).
  void _focusFirst(StageLayer layer) {
    if (!mounted || _layers.top != layer) return;
    final first = _layerScope.traversalDescendants
        .where((n) => n.canRequestFocus && !n.skipTraversal)
        .firstOrNull;
    (first ?? _layerScope).requestFocus();
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
      if (widget.ghostOpen) {
        // The Ghost file sits in the account's own data directory.
        final epoch = ++_ghostEpoch;
        final store =
            widget.ghostStore ??
            widget.ghostStoreFactory?.call(id) ??
            FileGhostStore(accountUserId: id);
        _ghostStore = store;
        _ghost = const GhostState();
        _ghostLoaded = false;
        _helpOpen = false;
        _ghostReady = _readGhost(store, epoch);
      }
    }
  }

  Future<_StageData?> _load(String? id) async {
    try {
      final catalog = widget.catalog ?? await V1CourseCatalog.load();
      _ghostCatalog = catalog;
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

  /// A run was written (or failed to be): read the records again and derive
  /// the suggestion and the headline from them, exactly as `_load` does.
  Future<void> _afterRun() async {
    final progress = _progress;
    if (progress == null) return;
    try {
      final records = await progress.load();
      if (!mounted || !identical(progress, _progress)) return;
      setState(() {
        _sessionMiss = missFromRecord(lastRunRecord(records.values));
        _ranThisSession = records.values.any((r) => r.runs > 0);
      });
    } on Object {
      // Keep what the stage already shows.
    }
  }

  void _retry() => setState(() => _data = _load(_accountId));

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _micOff) {
      unawaited(_recheckMic());
    }
  }

  /// Read only (never asks): the learner may have allowed the microphone in
  /// the system Settings; then the mode closes.
  Future<void> _recheckMic() async {
    PermissionStatus? status;
    try {
      status = await (widget.micStatus ?? MicPermissionGate.status)();
    } on Object {
      return;
    }
    if (!mounted || !_micOff) return;
    if (status.isGranted || status.isLimited || status.isProvisional) {
      setState(() => _micOff = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      _lastFailure = null; // a new screen's run decides on its own
      _pc = c..addListener(_onRun);
      setState(() {});
    });
  }

  void _onRun() {
    if (!mounted) return;
    final failure = _pc?.failure;
    final entered = failure == 'permission' && _lastFailure != 'permission';
    // Another failure than the refusal now stands (a retry that fails for a
    // different reason): the mode would say a reason that is no longer true.
    final other = failure != null && failure != 'permission';
    _lastFailure = failure;
    // Entered on a new refusal; left only when the microphone really runs
    // (a retry's reset must not flash the counters), or on resume (above).
    final listening = _pc?.phase == PracticePhase.running;
    if (entered && !_micOff) {
      setState(() => _micOff = true);
    } else if ((listening || other) && _micOff) {
      setState(() => _micOff = false);
    }
    final playing = _pc?.running ?? false;
    if (playing == _playing) return;
    _budget.playing = playing;
    _layers.locked = playing;
    setState(() {
      _playing = playing;
      if (playing) {
        _shelfOpen = false;
        _helpOpen = false;
        _notice = false;
      }
    });
  }

  void _tapHandle(StageHandle h) {
    if (_playing) return;
    widget.onHandle?.call(context, h);
    _layers.openLayer(switch (h) {
      StageHandle.another => StageLayer.other,
      StageHandle.path => StageLayer.path,
      StageHandle.setup => StageLayer.setup,
    });
  }

  void _closeLayer() => _layers.close();

  void _setStartUnverified(bool v) {
    if (!mounted || _startUnverified == v) return;
    setState(() => _startUnverified = v);
  }

  /// Play on a paid lesson (05d ek A). The read-only membership check is
  /// bounded by [StageHomeScreen.paidCheckTimeout]; a hang or an error means
  /// "could not verify": fail closed, say so, Play can be tried again. The
  /// membership page / sign-in that [admitV1Lesson] may open is the learner's
  /// own step and is NEVER timed out. A plain refusal (false) is silent.
  Future<bool> _admitPaid(String lessonId) async {
    _setStartUnverified(false);
    try {
      final check = _paidCheck;
      if (check != null) {
        await check().timeout(widget.paidCheckTimeout);
      }
      if (!mounted) return false;
      return await admitV1Lesson(
        context,
        lessonId,
        paidFeaturesAvailable: widget.paidFeaturesAvailable,
      );
    } on Object {
      _setStartUnverified(true);
      return false;
    }
  }

  Widget _layerContent(BuildContext context, _StageData data, StageLayer l) {
    final h = _handleOf(l);
    final custom = widget.layerBuilder;
    if (custom != null) return custom(context, h, _closeLayer);
    if (l == StageLayer.path) {
      return PathLayer(
        key: const Key('stage-path-layer'),
        load: () => _loadPath(data),
        onReady: () => _focusFirst(StageLayer.path),
      );
    }
    if (l == StageLayer.setup) return _deviceLayer(context);
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

  /// 05f: the Setup / Device layer. Exits open the existing full screens.
  Widget _deviceLayer(BuildContext context) {
    final account = AccountScope.maybeOf(context)?.connection;
    final accountOpen =
        widget.accountOpener ??
        (account == null
            ? null
            : (BuildContext c) => Navigator.of(c).push<void>(
                MaterialPageRoute<void>(builder: account.pageBuilder),
              ));
    final membership = account?.membershipPageBuilder;
    return DeviceLayer(
      key: const Key('stage-device-layer-host'),
      micStatus: widget.micStatus ?? () => MicPermissionGate.status(),
      profile: () => (widget.setupStore ?? FileSetupProfileStore.device).load(),
      openAppSettings: _goToSettings,
      openLatency: () =>
          (widget.setupOpener ??
          (c) => openSetupWizard(c, store: widget.setupStore))(context),
      openSettings: () =>
          (widget.settingsOpener ??
          (c) => Navigator.of(c).push<void>(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ))(context),
      openAccount: accountOpen == null ? null : () => accountOpen(context),
      openMembership: widget.accountOpener != null || membership == null
          ? null
          : () => Navigator.of(
              context,
            ).push<void>(MaterialPageRoute<void>(builder: membership)),
    );
  }

  /// 05f: "Listening is off". Says plainly that nothing is measured and why,
  /// keeps Go to Settings in view (until hidden) and the tuning card in
  /// reach. With the tool shelf open it shrinks to one line so the play area
  /// keeps its room; otherwise the block scrolls inside a bounded height.
  Widget _listeningOff(BuildContext context, _StageData data) {
    final p = OstinatoPalette.of(context);
    final height = MediaQuery.sizeOf(context).height;
    final compact = _shelfOpen;
    final button = TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
    final title = Text(
      uiText(context, StageCopy.listeningOff),
      style: hankenText(size: 14, weight: FontWeight.w600),
    );
    final links = <Widget>[
      if (_hintMuted == false) ...<Widget>[
        TextButton(
          key: const Key('stage-open-settings'),
          style: button,
          onPressed: _goToSettings,
          child: Text(uiText(context, StageCopy.goToSettings)),
        ),
        TextButton(
          key: const Key('stage-open-settings-mute'),
          style: button,
          onPressed: _muteHint,
          child: Text(uiText(context, StageCopy.muteHint)),
        ),
      ],
    ];
    final band = Semantics(
      container: true,
      label: uiText(context, StageCopy.listeningOff),
      child: Container(
        key: const Key('stage-listening-off'),
        padding: compact ? EdgeInsets.zero : const EdgeInsets.all(12),
        decoration: compact
            ? null
            : BoxDecoration(
                color: p.surface,
                border: Border.all(color: p.ink.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
        child: compact
            ? ExcludeSemantics(
                // Tool shelf open: the title takes the headline's one line
                // (no extra height); Go to Settings and the tuning card are
                // in the band (shelf closed) and in the Setup layer.
                child: Text(
                  uiText(context, StageCopy.listeningOff),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: hankenText(size: 14, weight: FontWeight.w600),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ExcludeSemantics(child: title),
                  // The way to Settings sits right under the title: it must
                  // never be the part that scrolls out of the bounded block.
                  if (links.isNotEmpty) Wrap(spacing: 8, children: links),
                  Text(
                    uiText(context, StageCopy.listeningOffWhy),
                    style: hankenText(size: 13),
                  ),
                ],
              ),
      ),
    );
    final card = !compact && data.lesson.lesson.course == 'gtr'
        ? Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SessionTuningGateCard(
              preset: TuningPresets.guitarStandard,
              onTune: (c) =>
                  (widget.tunerOpener ?? (c) => tuner.openTuner(c))(c),
            ),
          )
        : null;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[band, ?card],
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 10 : 6, 16, 0),
      child: compact
          ? content
          : ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: height > 700 ? 340 : height * 0.25,
              ),
              child: SingleChildScrollView(child: content),
            ),
    );
  }

  /// Read only: the stored records, the lesson checks and the weekly goal.
  /// A failure of records / checks throws (the layer shows an honest error
  /// and a retry, never the empty text); the weekly line alone may be absent.
  Future<PathLayerData> _loadPath(_StageData data) async {
    final records = await _progress!.load();
    final checks =
        await (widget.checksFactory?.call(_accountId) ??
                V1LessonCheckStore(accountUserId: _accountId))
            .load();
    WeeklyGoalStatus? weekly;
    try {
      weekly =
          await (widget.weeklyGoalLoader?.call() ??
              WeeklyGoalStore(accountUserId: _accountId).load());
    } on Object {
      weekly = null;
    }
    return PathLayerData(
      data.catalog,
      pathSummary(
        data.catalog,
        records,
        checks,
        paidFeaturesAvailable: widget.paidFeaturesAvailable,
      ),
      weekly,
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
    final headline =
        (data.hasRecords || _ranThisSession) && unit?.module != null
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
                if (!(_micOff && _shelfOpen))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Text(
                      headline,
                      key: const Key('stage-headline'),
                      style: hankenText(size: 13),
                    ),
                  ),
                if (_micOff) _listeningOff(context, data),
                if (_notice)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: Text(
                      uiText(context, StageCopy.runNotCompleted),
                      key: const Key('stage-run-not-completed'),
                      style: hankenText(size: 13),
                    ),
                  ),
                if (_startUnverified)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: Text(
                      uiText(context, StageCopy.startNotVerified),
                      key: const Key('stage-start-unverified'),
                      style: hankenText(size: 13),
                    ),
                  ),
                // Keyed: a notice above appears and goes; the practice screen
                // (and its run) must never be rebuilt because of it.
                Expanded(
                  key: const Key('stage-practice-slot'),
                  child: Semantics(
                    sortKey: const OrdinalSortKey(0),
                    child: PracticeLoopScreen(
                      key: ValueKey<int>(_epoch),
                      lesson: data.lesson.lesson,
                      progress: _progress!,
                      stageMode: true,
                      // OST-UX-05g: the older P0-07 ghost panel never shows on the stage, even
                      // when `ostinatoGhostScreenOpen` is on (the stage has its own Help).
                      ghostScreen: false,
                      // OST-UX-05g2: the chosen help level shapes the line and
                      // beat; ear/rhythm-only lessons never enter the Ghost.
                      ghostLevel:
                          widget.ghostOpen &&
                              _ghostLoaded &&
                              !_isRhythmOnly(data.lesson.id)
                          ? _ghost.level
                          : null,
                      onController: _gotController,
                      listenController: _listen,
                      controllerFactory: widget.controllerFactory,
                      setupStore: widget.setupStore,
                      seed: widget.seed,
                      listeningOff: _micOff,
                      tuningCardSeen: _tuningSeen,
                      onStarted: () => _tuningSeen = true,
                      onRunRecorded: _afterRun,
                      onSessionFinished: widget.ghostOpen
                          ? _onSessionFinished
                          : null,
                      beforeStart:
                          isFreeV1Lesson(
                            data.lesson.id,
                            paidFeaturesAvailable: widget.paidFeaturesAvailable,
                          )
                          ? null
                          : () => _admitPaid(data.lesson.id),
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
                      maxContentHeight: height * (_micOff ? 0.2 : 0.34),
                      open: _shelfOpen,
                      onToggle: () => setState(() => _shelfOpen = !_shelfOpen),
                      controller: _pc,
                      listen: _listen,
                      pinned: _pinned,
                      onPinned: (v) => setState(() => _pinned = v),
                      ghost: widget.ghostOpen ? _ghost : null,
                      onGhostSelect: _selectGhost,
                      helpOpen: _helpOpen,
                      onHelp: () => setState(() => _helpOpen = !_helpOpen),
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
