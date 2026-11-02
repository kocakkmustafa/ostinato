import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app_locale.dart';
import '../../app_theme.dart';
import '../../audio/audio_input_controller.dart';
import '../../curriculum/v1_lesson.dart';
import '../../design/ostinato_theme.dart';
import '../../design/widgets.dart';
import '../../tuner/session_tuning_gate.dart';
import '../../tuner/tuner_screen.dart';
import '../../tuner/tunings.dart';
import '../../ui_copy.dart';
import '../own_recording/own_recording.dart';
import '../own_recording/own_recording_preference.dart';
import '../practice_audio_input.dart';
import '../setup/setup_profile_store.dart';
import '../setup/setup_wizard_screen.dart';
import 'metronome_beat_view.dart';
import 'practice_judge.dart';
import 'practice_marks.dart';
import 'practice_outcome.dart';
import 'practice_progress_store.dart';
import 'practice_result_screen.dart';
import 'practice_rhythm_copy.dart';
import 'practice_score.dart';
import 'practice_session_controller.dart';
import 'practice_tab_strip.dart';
import 'practice_transport.dart';
import 'practice_visual_theme.dart';
import 'v1_practice_catalog.dart';

/// What the practice screen hands back to the lesson list.
enum PracticeExit { closed, openNextLesson }

/// F2.3–F2.5 practice screen (`4-rakip-arayuzleri` §6.5): top bar, mode
/// controls, flowing TAB with a fixed NOW line, visual beat, an always
/// visible microphone strip with ✓/◆/◯ counters, start/stop.
class PracticeLoopScreen extends StatefulWidget {
  const PracticeLoopScreen({
    super.key,
    required this.lesson,
    required this.progress,
    this.hasNextLesson = false,
    this.controllerFactory,
    this.onSessionFinished,
    this.setupStore,
    this.openSetup,
    this.ownRecordingPreference,
  });

  final V1Lesson lesson;

  /// F4.2 results (latency per route); defaults to the device store.
  final SetupProfileStore? setupStore;

  /// Opens the setup wizard at a step; tests replace it.
  final Future<void> Function(BuildContext context, SetupStep start)? openSetup;

  /// "Session finished" for retention (weekly goal / streak). Fired once per
  /// run that has a summary, before the result screen opens.
  final void Function(PracticeSessionFinished event)? onSessionFinished;
  final V1PracticeProgress progress;
  final bool hasNextLesson;

  /// FK2 setting; defaults to the device file (off unless turned on).
  final OwnRecordingPreference? ownRecordingPreference;

  /// Tests inject a controller on a fake channel.
  final PracticeSessionController Function(
    PracticeScore score,
    PracticeTempo tempo,
    PassCriteria criteria,
  )?
  controllerFactory;

  @override
  State<PracticeLoopScreen> createState() => _PracticeLoopScreenState();
}

class _PracticeLoopScreenState extends State<PracticeLoopScreen>
    with SingleTickerProviderStateMixin {
  late final PracticeScore _score = V1PracticeCatalog.scoreOf(widget.lesson)!;
  late final bool _freeTempo = widget.lesson.practice.tempo == null;
  late final PracticeTempo _initialTempo = _freeTempo
      ? PracticeTempo(openBpm: 60, targetBpm: 60)
      : PracticeTempo(
          openBpm: widget.lesson.practice.tempo!.open,
          targetBpm: widget.lesson.practice.tempo!.target,
        );
  late final PassCriteria _criteria = PassCriteria.forLesson(
    widget.lesson,
    score: _score,
  );
  late final SetupProfileStore _setup =
      widget.setupStore ?? FileSetupProfileStore.device;
  SetupProfile? _profile;
  bool _ranOnce = false;
  AudioInputController? _ownedAudio;
  OwnRecorder? _ownedRecorder;
  late final PracticeSessionController _c = _createController();
  late final Ticker _ticker = createTicker((_) => _c.tick());
  bool _resultShown = false;

  PracticeSessionController _createController() {
    final factory = widget.controllerFactory;
    if (factory != null) return factory(_score, _initialTempo, _criteria);
    final audio = _ownedAudio = createPracticeAudioInput(
      // Debug fake microphone only (`--dart-define=OSTINATO_FAKE_MIC`).
      lesson: () => (
        score: _score,
        countInBeats: _c.plan?.countInBeats ?? _score.beatsPerBar,
        loop: _c.loopRange,
        heldMidi: _c.heldEvent == null
            ? null
            : _score.events[_c.heldEvent!].midi,
      ),
    );
    return PracticeSessionController(
      score: _score,
      tempo: _initialTempo,
      audio: audio,
      freeTempo: _freeTempo,
      criteria: _criteria,
      setup: _setup,
      ownRecorder: _ownedRecorder = OwnRecorder(),
    );
  }

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
    unawaited(_loadProfile());
    unawaited(_prepareOwnRecording());
  }

  /// FK2: sweep takes a crash may have left, then follow the setting.
  Future<void> _prepareOwnRecording() async {
    final recorder = _c.ownRecorder;
    if (recorder == null) return;
    await recorder.sweep();
    final on =
        await (widget.ownRecordingPreference ??
                const FileOwnRecordingPreference())
            .read();
    if (mounted) recorder.enabled = on;
  }

  Future<void> _loadProfile() async {
    SetupProfile? p;
    try {
      p = await _setup.load();
    } on Object {
      p = null;
    }
    if (mounted) setState(() => _profile = p);
  }

  /// Timing is judged and shown: the run's own route when a run exists,
  /// otherwise the last measured route of this phone.
  bool get _timingReady {
    // Free tempo has no click, so timing is never judged: nothing to ask.
    if (_freeTempo) return true;
    if (_c.timeline != null) return _c.timingCalibrated;
    final p = _profile;
    return p != null && p.latencyFor(p.lastRoute) != null;
  }

  Future<void> _openSetup(SetupStep start) async {
    if (_c.running) return;
    final open = widget.openSetup;
    if (open != null) {
      await open(context, start);
    } else {
      await openSetupWizard(context, start: start, store: _setup);
    }
    if (mounted) await _loadProfile();
  }

  void _changed() {
    if (!mounted) return;
    final running = _c.running;
    if (running && !_ticker.isActive) _ticker.start();
    if (!running && _ticker.isActive) _ticker.stop();
    if (_c.phase == PracticePhase.finished && !_resultShown) {
      _resultShown = true;
      unawaited(_showResult());
    }
    setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    _ticker.dispose();
    unawaited(_c.stop());
    _c.dispose();
    _ownedRecorder?.dispose();
    unawaited(_ownedAudio?.dispose());
    super.dispose();
  }

  Future<void> _showResult() async {
    final summary = _c.summary;
    if (summary == null) return;
    widget.onSessionFinished?.call(
      PracticeSessionFinished(
        lessonId: widget.lesson.id,
        course: 'guitar',
        activeDuration: _c.activeDuration,
        heardEvents: summary.correct + summary.different,
        summary: summary,
      ),
    );
    V1PracticeRecord? record;
    var newlyPassed = false;
    try {
      final before = (await widget.progress.load())[widget.lesson.id];
      record = await widget.progress.recordRun(widget.lesson.id, summary);
      newlyPassed = record.passed && !(before?.passed ?? false);
    } on Object {
      record = null;
    }
    if (!mounted) return;
    final action = await Navigator.of(context).push<ResultAction>(
      MaterialPageRoute(
        builder: (_) => PracticeResultScreen(
          lesson: widget.lesson,
          score: _score,
          summary: summary,
          progressSaved: record != null,
          nextLessonOpened: newlyPassed && widget.hasNextLesson,
          hasNextLesson: widget.hasNextLesson,
          ownRecorder: _c.ownRecorder,
        ),
      ),
    );
    if (!mounted) return;
    _resultShown = false;
    switch (action) {
      case ResultActionNextLesson():
        Navigator.of(context).pop(PracticeExit.openNextLesson);
      case ResultActionLoop(:final first, :final last, :final slower):
        _c.loopBars = (first: first, last: last);
        if (slower) {
          _c.tempo = _c.tempo.withBpm(
            (_c.tempo.targetBpm * .7).round().clamp(
              PracticeTempo.minBpm(_c.tempo.targetBpm),
              _c.tempo.bpm,
            ),
          );
        }
      case ResultActionRaiseTempo():
        _c.tempo = _c.tempo.stepped(5);
      case ResultActionCheckSetup():
        await _openSetup(SetupStep.placement);
      case ResultActionPerformance():
        _c.loopBars = null;
        _c.waitMode = false;
        _c.tempo = _c.tempo.withBpm(_c.tempo.targetBpm);
      case ResultActionRetry() || null:
        break;
    }
  }

  void _start() {
    _ranOnce = true;
    unawaited(_c.start(captureAction: practiceCaptureActionFor(context)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final lesson = widget.lesson;
    return Scaffold(
      backgroundColor: palette.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _topBar(context, lesson),
                  const SizedBox(height: 10),
                  Text(
                    lesson.practice.task.of(context),
                    style: hankenText(size: 13.5, height: 1.45),
                  ),
                  const SizedBox(height: 10),
                  if (!_ranOnce && _c.phase == PracticePhase.idle)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      // Contract §5 rule 2: tuning at session start. The
                      // card never blocks ([Continue anyway]).
                      child: SessionTuningGateCard(
                        preset: TuningPresets.guitarStandard,
                        onTune: (context) => openTuner(
                          context,
                          controller: debugFakeTunerController(
                            TuningPresets.guitarStandard,
                          ),
                        ),
                      ),
                    ),
                  if (_c.canEditSettings) _settings(context),
                  if (_c.hearing.setupCardDue && _c.running)
                    _setupCard(context),
                  _stripArea(context),
                  if (_c.heldEvent != null) _waitHelp(context),
                  const SizedBox(height: 10),
                  _micStrip(context),
                  const SizedBox(height: 12),
                  _primary(context),
                  const SizedBox(height: 10),
                  Text(
                    localized(
                      context,
                      'Stop for pain, numbness or tingling. Audio stays in memory on this device; nothing is recorded or sent.',
                      'Ağrı, uyuşma ya da karıncalanmada dur. Ses yalnız bu cihazın belleğinde kalır; kaydedilmez, gönderilmez.',
                    ),
                    style: hankenText(
                      size: 11.5,
                      color: palette.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, V1Lesson lesson) {
    final t = _c.tempo;
    return Row(
      children: [
        GlassIconButton(
          icon: '‹',
          semanticLabel: localized(context, 'Back', 'Geri'),
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            lesson.title.of(context),
            style: hankenText(size: 17, weight: FontWeight.w600),
          ),
        ),
        if (!_freeTempo)
          Text(
            '♩=${t.bpm}/${t.targetBpm}',
            key: const Key('practice-tempo-label'),
            style: monoText(size: 12, letterSpacing: .4),
          ),
      ],
    );
  }

  Widget _settings(BuildContext context) {
    final t = _c.tempo;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_freeTempo) ...[
            Text(
              localized(
                context,
                'Tempo ♩={v0} · {v1} % of the target {v2}',
                'Tempo ♩={v0} · hedef {v2} temposunun %{v1}',
                values: {'v0': t.bpm, 'v1': t.percent, 'v2': t.targetBpm},
              ),
              style: hankenText(size: 13),
            ),
            Row(
              children: [
                IconButton(
                  key: const Key('practice-tempo-down'),
                  tooltip: localized(context, 'Slower', 'Daha yavaş'),
                  onPressed: () => _c.tempo = t.stepped(-5),
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Slider(
                    key: const Key('practice-tempo-slider'),
                    min: PracticeTempo.minBpm(t.targetBpm).toDouble(),
                    max: PracticeTempo.maxBpm(t.targetBpm).toDouble(),
                    value: t.bpm.toDouble(),
                    label: '♩=${t.bpm}',
                    onChanged: (v) => _c.tempo = t.withBpm(v.round()),
                  ),
                ),
                IconButton(
                  key: const Key('practice-tempo-up'),
                  tooltip: localized(context, 'Faster', 'Daha hızlı'),
                  onPressed: () => _c.tempo = t.stepped(5),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
          SwitchListTile(
            key: const Key('practice-wait-mode'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              _c.waitMode
                  ? localized(context, 'Wait for me: On', 'Beni bekle: Açık')
                  : localized(
                      context,
                      'Wait for me: Off',
                      'Beni bekle: Kapalı',
                    ),
            ),
            value: _c.waitMode,
            onChanged: _freeTempo ? null : (v) => _c.waitMode = v,
          ),
          if (!_freeTempo)
            SwitchListTile(
              key: const Key('practice-metronome-sound'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                _c.metronomeSound
                    ? localized(context, 'Click sound: On', 'Klik sesi: Açık')
                    : localized(
                        context,
                        'Click sound: Off',
                        'Klik sesi: Kapalı',
                      ),
              ),
              value: _c.metronomeSound,
              onChanged: (v) => _c.metronomeSound = v,
            ),
          if (_score.barCount > 1) _loopControl(context),
        ],
      ),
    );
  }

  Widget _loopControl(BuildContext context) {
    final loop = _c.loopBars;
    final bars = _score.barCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const Key('practice-loop'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            loop == null
                ? localized(context, 'Loop: Off', 'Döngü: Kapalı')
                : localized(
                    context,
                    'Loop: bars {v0}–{v1}',
                    'Döngü: {v0}–{v1}. ölçüler',
                    values: {'v0': loop.first + 1, 'v1': loop.last + 1},
                  ),
          ),
          value: loop != null,
          onChanged: (v) =>
              _c.loopBars = v ? (first: 0, last: bars > 1 ? 1 : 0) : null,
        ),
        if (loop != null)
          RangeSlider(
            key: const Key('practice-loop-range'),
            min: 0,
            max: (bars - 1).toDouble(),
            divisions: bars - 1,
            values: RangeValues(loop.first.toDouble(), loop.last.toDouble()),
            onChanged: (v) =>
                _c.loopBars = (first: v.start.round(), last: v.end.round()),
          ),
      ],
    );
  }

  Widget _stripArea(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_c.plan != null && _c.timeline != null)
                MetronomeBeatView(
                  state: _c.beat,
                  beatsPerBar: _score.beatsPerBar,
                )
              else
                Text(
                  localized(context, 'Metronome ready', 'Metronom hazır'),
                  style: monoText(size: 11, color: palette.textMuted),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: _timingReady
                      ? const SizedBox.shrink()
                      : Tooltip(
                          message: localized(
                            context,
                            'Timing is shown only after latency calibration.',
                            'Zamanlama yalnız gecikme kalibrasyonundan sonra gösterilir.',
                          ),
                          child: InkWell(
                            onTap: _c.running
                                ? null
                                : () =>
                                      unawaited(_openSetup(SetupStep.latency)),
                            child: Text(
                              localized(
                                context,
                                'Calibrate for timing',
                                'Zamanlama için kalibrasyon yap',
                              ),
                              key: const Key('practice-calibration-badge'),
                              textAlign: TextAlign.end,
                              style: monoText(
                                size: 10,
                                color: palette.textMuted,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 190,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: PracticeTabStrip(
                score: _score,
                displayBeat: _c.displayBeat,
                marks: _c.marks,
                heldEvent: _c.heldEvent,
                loop: _c.loopRange,
                // A rhythm-only line is one lane of strokes, not six strings.
                guitar: !_score.isRhythmOnly,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _waitHelp(BuildContext context) {
    final stage = _c.waitStage;
    if (stage == WaitStage.listening) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          localized(
            context,
            'Listening for this note…',
            'Bu notayı dinliyorum…',
          ),
          style: hankenText(size: 13),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GlassCard(
        key: const Key('practice-wait-hint'),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localized(
                context,
                "I couldn't hear this note. Play it a little stronger and on its own.",
                'Bu notayı duyamadım. Biraz daha güçlü ve tek başına çal.',
              ),
              style: hankenText(size: 13),
            ),
            if (stage == WaitStage.actions)
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    key: const Key('practice-wait-skip'),
                    onPressed: _c.skipHeld,
                    child: Text(localized(context, 'Skip', 'Atla')),
                  ),
                  TextButton(
                    key: const Key('practice-wait-listen'),
                    onPressed: () => unawaited(_c.listenHeld()),
                    child: Text(
                      localized(
                        context,
                        'Listen to this note',
                        'Bu notayı dinle',
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _setupCard(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: GlassCard(
      key: const Key('practice-setup-card'),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              localized(
                context,
                "I can't hear you clearly: move the phone about 30 cm closer · lower the app volume or use headphones.",
                'Seni net duyamıyorum: telefonu 30 cm yaklaştır · uygulama sesini kıs ya da kulaklık tak.',
              ),
              style: hankenText(size: 13, height: 1.4),
            ),
          ),
          IconButton(
            key: const Key('practice-setup-card-close'),
            tooltip: localized(context, 'Close', 'Kapat'),
            onPressed: _c.dismissSetupCard,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    ),
  );

  Widget _micStrip(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final theme = PracticeVisualThemeScope.of(context);
    final state = _c.running ? _c.micState : MicStripState.silent;
    final label = !_c.running
        ? localized(context, 'Microphone off', 'Mikrofon kapalı')
        : switch (state) {
            MicStripState.silent => localized(
              context,
              'Quiet — I listen once you play',
              'Sessiz — çalmaya başlayınca dinliyorum',
            ),
            MicStripState.hearing => localized(
              context,
              'I hear you',
              'Seni duyuyorum',
            ),
            MicStripState.unclear => localized(
              context,
              "I hear you but can't tell the note apart",
              'Duyuyorum ama ayırt edemiyorum',
            ),
          };
    Widget count(PracticeMark m, String name) {
      final style = theme.style(m);
      return Semantics(
        label: '$name ${_c.countOf(m)}',
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              '${style.symbol}${_c.countOf(m)}',
              key: Key('practice-count-${m.name}'),
              style: monoText(size: 13, color: style.color, letterSpacing: .2),
            ),
          ),
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(
            _c.running ? Icons.mic : Icons.mic_off,
            size: 18,
            color: palette.ink,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 46,
            height: 16,
            child: CustomPaint(
              painter: _LevelBars(
                _c.running ? _c.hearing.meter : 0,
                palette.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              key: const Key('practice-mic-label'),
              style: hankenText(size: 12.5),
            ),
          ),
          count(PracticeMark.correct, localized(context, 'Correct', 'Doğru')),
          count(
            PracticeMark.differentNote,
            _criteria.rhythm
                ? uiText(context, RhythmCopy.earlyOrLate)
                : localized(context, 'Different note', 'Farklı nota'),
          ),
          count(
            PracticeMark.couldNotHear,
            localized(context, "Couldn't hear", 'Duyamadım'),
          ),
        ],
      ),
    );
  }

  Widget _primary(BuildContext context) {
    final phase = _c.phase;
    if (phase == PracticePhase.starting) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            localized(context, 'Opening the microphone…', 'Mikrofon açılıyor…'),
          ),
        ],
      );
    }
    if (phase == PracticePhase.running) {
      return FilledButton.icon(
        key: const Key('practice-stop'),
        onPressed: () => unawaited(_c.stop()),
        icon: const Icon(Icons.stop),
        label: Text(
          _c.loopBars != null
              ? localized(context, 'Finish', 'Bitir')
              : localized(context, 'Stop', 'Durdur'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (phase == PracticePhase.failed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _c.failure == 'permission'
                  ? localized(
                      context,
                      'Microphone access is off. You can allow it in Settings.',
                      'Mikrofon erişimi kapalı. Ayarlar’dan izin verebilirsin.',
                    )
                  : localized(
                      context,
                      'The microphone stopped (the input changed or another app took it). Start again.',
                      'Mikrofon durdu (giriş değişti ya da başka bir uygulama aldı). Yeniden başlat.',
                    ),
              key: const Key('practice-failure'),
              style: hankenText(size: 13),
            ),
          ),
        FilledButton.icon(
          key: const Key('practice-start'),
          onPressed: _start,
          icon: const Icon(Icons.play_arrow),
          label: Text(localized(context, 'Start', 'Başlat')),
        ),
      ],
    );
  }
}

class _LevelBars extends CustomPainter {
  _LevelBars(this.level, this.color);
  final double level;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 6;
    final w = size.width / (bars * 1.6);
    for (var i = 0; i < bars; i++) {
      final on = level * bars > i;
      final h = size.height * (.35 + .65 * (i + 1) / bars);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * w * 1.6, size.height - h, w, h),
          const Radius.circular(1.5),
        ),
        Paint()..color = on ? color : color.withValues(alpha: .18),
      );
    }
  }

  @override
  bool shouldRepaint(_LevelBars old) => old.level != level;
}
