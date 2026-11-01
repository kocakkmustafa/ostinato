import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:ostinato_audio/ostinato_audio.dart';

import '../../audio/audio_capture_channel.dart';
import '../../audio/audio_input_controller.dart';
import '../../audio/practice_audio_root.dart';
import 'metronome.dart';
import 'practice_judge.dart';
import 'practice_marks.dart';
import 'practice_outcome.dart';
import 'practice_score.dart';
import 'practice_tab_strip.dart';
import 'practice_transport.dart';

/// Runs one analysis job; production runs it off the UI isolate.
typedef NoteAnalyzer = Future<NoteJudgement> Function(NoteJudgeRequest);

Future<NoteJudgement> analyzeOffMain(NoteJudgeRequest r) =>
    Isolate.run(() => judgeNote(r));

enum PracticePhase { idle, starting, running, finished, failed }

/// F2.2–F2.4 wiring: play+record capture, click stream, timeline, transport,
/// judge. The logic lives in the pure files; this class only schedules.
/// Audio stays in RAM ([CaptureBuffer]); nothing is written or sent.
final class PracticeSessionController extends ChangeNotifier {
  PracticeSessionController({
    required this.score,
    required PracticeTempo tempo,
    required this.audio,
    this.freeTempo = false,
    this.guitar = true,
    NoteAnalyzer? analyzer,
    int Function()? localClockUs,
    this.config = const JudgeConfig(),
    this.anchorTimeout = const Duration(milliseconds: 1200),
    this.requestedSampleRate = 48000,
    this.criteria = const PassCriteria(minAccuracy: .8),
  }) : _tempo = tempo,
       _waitMode = freeTempo,
       _metronomeSound = !freeTempo,
       _analyze = analyzer ?? analyzeOffMain,
       _localUs = localClockUs ?? _stopwatchUs;

  static final Stopwatch _watch = Stopwatch()..start();
  static int _stopwatchUs() => _watch.elapsedMicroseconds;

  final PracticeScore score;
  final AudioInputController audio;

  /// Lesson has no tempo ("serbest"): "Wait for me" only, no click.
  final bool freeTempo;
  final bool guitar;
  final JudgeConfig config;
  final Duration anchorTimeout;
  final int requestedSampleRate;
  final PassCriteria criteria;
  final NoteAnalyzer _analyze;
  final int Function() _localUs;

  // ---- settings (changed only while idle) ----
  PracticeTempo _tempo;
  ({int first, int last})? _loopBars;
  bool _waitMode;
  bool _metronomeSound;

  PracticeTempo get tempo => _tempo;
  ({int first, int last})? get loopBars => _loopBars;
  bool get waitMode => _waitMode;
  bool get metronomeSound => _metronomeSound;
  bool get canEditSettings =>
      phase == PracticePhase.idle ||
      phase == PracticePhase.finished ||
      phase == PracticePhase.failed;

  set tempo(PracticeTempo next) => _edit(() => _tempo = next);
  set loopBars(({int first, int last})? next) => _edit(() {
    if (next == null) {
      _loopBars = null;
      return;
    }
    final first = next.first.clamp(0, score.barCount - 1);
    final last = next.last.clamp(first, score.barCount - 1);
    _loopBars = (first: first, last: last);
  });
  set waitMode(bool v) => _edit(() => _waitMode = freeTempo || v);
  set metronomeSound(bool v) => _edit(() => _metronomeSound = !freeTempo && v);

  void _edit(void Function() change) {
    if (!canEditSettings) return;
    change();
    _notify();
  }

  // ---- run state ----
  PracticePhase phase = PracticePhase.idle;
  String? failure;
  MetronomePlan? plan;
  MetronomeTimeline? timeline;
  PracticeTransport? _transport;
  double displayBeat = -4;
  MetronomeBeatState beat = const MetronomeBeatState(
    beat: -1,
    beatInBar: -1,
    phase: 0,
    countInRemaining: 4,
  );
  Map<int, StripMark> marks = const {};
  final List<NoteOutcome> outcomes = [];
  HearingMonitor hearing = HearingMonitor();
  PracticeRunSummary? summary;
  int? heldEvent;
  WaitStage waitStage = WaitStage.listening;
  bool get running =>
      phase == PracticePhase.running || phase == PracticePhase.starting;
  ({double start, double end})? get loopRange => _loopBars == null
      ? null
      : barRange(score, _loopBars!.first, _loopBars!.last);

  /// Live microphone strip state on the capture clock.
  MicStripState get micState => hearing.state(_clock.nowUs(_localUs()) ?? 0);

  int countOf(PracticeMark m) => outcomes.where((o) => o.mark == m).length;

  final _clock = CaptureClockEstimator();
  final _buffer = CaptureBuffer();
  final List<double> _floorLevels = [];
  final List<_Pending> _pending = [];
  StreamSubscription<AudioChunk>? _chunkSub;
  StreamSubscription<AudioSurfaceState>? _statusSub;
  StreamSubscription<MetronomeAnchor>? _anchorSub;
  Completer<MetronomeAnchor?>? _anchorWait;
  bool _analysisInFlight = false;
  bool _disposed = false;
  bool _stopping = false;
  int _runEpoch = 0;
  _WaitTarget? _wait;
  int _lastWaitCheckLocalUs = 0;
  int? _listenStartUs;
  Duration _activeDuration = Duration.zero;

  /// Microphone listening time of the last run (first chunk → finish).
  Duration get activeDuration => _activeDuration;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start({PracticeAudioCaptureAction? captureAction}) async {
    if (running || _disposed) {
      captureAction?.retire();
      return;
    }
    final epoch = ++_runEpoch;
    _reset();
    phase = PracticePhase.starting;
    _notify();
    _chunkSub ??= audio.chunks.listen(_onChunk);
    _statusSub ??= audio.status.listen(_onStatus);
    _anchorSub ??= audio.metronomeAnchors.listen(_onAnchor);
    await audio.start(
      sampleRate: requestedSampleRate,
      captureAction: captureAction,
      sessionMode: AudioSessionMode.playAndRecord,
    );
    if (epoch != _runEpoch) return;
  }

  void _reset() {
    _buffer.clear();
    _clock.reset();
    _floorLevels.clear();
    _pending.clear();
    outcomes.clear();
    marks = const {};
    hearing = HearingMonitor();
    summary = null;
    failure = null;
    plan = null;
    timeline = null;
    _transport = null;
    heldEvent = null;
    _wait = null;
    waitStage = WaitStage.listening;
    displayBeat = -4;
    _stopping = false;
    _listenStartUs = null;
    _activeDuration = Duration.zero;
  }

  void _onStatus(AudioSurfaceState s) {
    if (!running || _stopping) return;
    switch (s) {
      case AudioPermissionDenied():
        _fail('permission');
      case AudioUnavailable(:final reason):
        _fail(reason);
      case AudioSetupFailed(:final reason):
        _fail(reason);
      case AudioStopped():
        _fail('stopped');
      case AudioCalibrating():
        // Route or clock change after the grid exists: the grid is invalid.
        if (timeline != null) _fail('input_changed');
      case AudioStarting() || AudioStreaming():
        break;
    }
  }

  void _onChunk(AudioChunk c) {
    if (!running || _stopping) return;
    _clock.observeChunk(
      tStartUs: c.tStartUs,
      sampleCount: c.samples.length,
      sampleRate: c.sampleRate,
      localNowUs: _localUs(),
    );
    _listenStartUs ??= c.tStartUs;
    final level = _buffer.push(c);
    hearing.observeLevel(level);
    final t = timeline, p = plan;
    if (t == null) {
      if (p == null) unawaited(_beginGrid(c.sampleRate));
      return;
    }
    final b = t.beatAt(c.tStartUs);
    if (b >= 0 && b < p!.countInBeats - .25) _floorLevels.add(level);
    if (hearing.roomFloorDb == null && b >= p!.countInBeats - .25) {
      hearing.roomFloorDb = HearingMonitor.floorOf(_floorLevels);
    }
  }

  Future<void> _beginGrid(int sampleRate) async {
    final epoch = _runEpoch;
    final p = MetronomePlan(
      bpm: _tempo.bpm,
      sampleRate: sampleRate,
      beatsPerBar: score.beatsPerBar,
    );
    plan = p;
    MetronomeAnchor? anchor;
    if (_metronomeSound) {
      final clicks = MetronomeClicks.forSampleRate(sampleRate);
      _anchorWait = Completer<MetronomeAnchor?>();
      try {
        await audio.startMetronome(
          MetronomeStreamRequest(
            sampleRate: sampleRate,
            framesPerBeat: p.framesPerBeat,
            beatsPerBar: p.beatsPerBar,
            accent: clicks.accent,
            beat: clicks.beat,
          ),
        );
        anchor = await _anchorWait!.future.timeout(
          anchorTimeout,
          onTimeout: () => null,
        );
      } on Object {
        anchor = null;
      }
      _anchorWait = null;
    }
    if (epoch != _runEpoch || !running) return;
    final now = _clock.nowUs(_localUs()) ?? 0;
    timeline = anchor == null
        ? MetronomeTimeline(
            anchorUs: now + 400000,
            sampleRate: sampleRate,
            framesPerBeat: p.framesPerBeat,
            source: MetronomeAnchorSource.silent,
          )
        : MetronomeTimeline(
            anchorUs: anchor.anchorUs,
            sampleRate: sampleRate,
            framesPerBeat: anchor.framesPerBeat,
            outputLatencyUs: anchor.outputLatencyUs,
            source: MetronomeAnchorSource.native,
          );
    _transport = PracticeTransport(
      score: score,
      countInBeats: p.countInBeats,
      loop: loopRange,
      waitMode: _waitMode,
    );
    phase = PracticePhase.running;
    _notify();
  }

  void _onAnchor(MetronomeAnchor a) {
    final wait = _anchorWait;
    if (wait != null && !wait.isCompleted) {
      wait.complete(a);
      return;
    }
    // A later re-anchor (Android underrun) moves the grid; the beat length
    // stays the stream's own.
    final t = timeline;
    if (t != null && t.source == MetronomeAnchorSource.native) {
      timeline = MetronomeTimeline(
        anchorUs: a.anchorUs,
        sampleRate: t.sampleRate,
        framesPerBeat: t.framesPerBeat,
        outputLatencyUs: a.outputLatencyUs,
        latencyCorrectionUs: t.latencyCorrectionUs,
        source: MetronomeAnchorSource.native,
      );
    }
  }

  /// Called every frame by the screen (and directly by tests).
  void tick() {
    final t = timeline, transport = _transport, p = plan;
    if (phase != PracticePhase.running || t == null || transport == null) {
      return;
    }
    final now = _clock.nowUs(_localUs());
    if (now == null) return;
    final m = t.beatAt(now);
    beat = MetronomeBeatState.at(
      t,
      now,
      beatsPerBar: p!.beatsPerBar,
      countInBeats: p.countInBeats,
    );
    final step = transport.advance(m);
    displayBeat = step.displayBeat;
    for (final r in step.reached) {
      _expect(r, t);
    }
    if (_wait != null) _serviceWait(now, m);
    _servicePending(now);
    if (transport.finished &&
        _pending.isEmpty &&
        !_analysisInFlight &&
        _wait == null) {
      _finish(completed: true);
      return;
    }
    _notify();
  }

  void _expect(ReachedEvent r, MetronomeTimeline t) {
    final e = r.event;
    if (marks.containsKey(e.index)) {
      // A new loop pass shows the note as pending again.
      marks = Map.of(marks)..remove(e.index);
    }
    final expectedUs = t.beatTimeUs(r.metronomeBeat);
    if (_waitMode) {
      heldEvent = e.index;
      _wait = _WaitTarget(
        event: e,
        pass: r.pass,
        expectedUs: expectedUs,
        sinceLocalUs: _localUs(),
        listenFromUs: expectedUs - config.earlyMs * 1000,
      );
      waitStage = WaitStage.listening;
      return;
    }
    final i = e.index;
    final prev = i > 0 ? score.events[i - 1] : null;
    final next = i + 1 < score.events.length ? score.events[i + 1] : null;
    int us(double beats) => (beats * t.beatUs).round();
    _pending.add(
      _Pending(
        event: e,
        pass: r.pass,
        window: NoteWindow.forNote(
          expectedUs: expectedUs,
          durationUs: us(e.durationBeats),
          prevGapUs: prev == null ? null : us(e.startBeat - prev.startBeat),
          nextGapUs: next == null ? null : us(next.startBeat - e.startBeat),
          config: config,
        ),
      ),
    );
  }

  void _servicePending(int now) {
    if (_analysisInFlight || _pending.isEmpty) return;
    final p = _pending.first;
    final w = p.window;
    if (now < w.readyAtUs) return;
    _pending.removeAt(0);
    final from = w.searchFromUs - 100000;
    final slice = _buffer.slice(
      from,
      w.readyAtUs,
      flagFromUs: w.searchFromUs,
      flagToUs: w.readyAtUs,
    );
    final request = NoteJudgeRequest(
      samples: slice.samples,
      sampleRate: slice.sampleRate,
      kind: p.event.kind,
      expectedMidi: p.event.midi,
      expectedIndex: slice.indexOf(w.expectedUs),
      searchFrom: slice.indexOf(w.searchFromUs),
      searchTo: slice.indexOf(w.searchToUs),
      analysisMs: w.analysisMs,
      roomFloorDb: hearing.roomFloorDb,
      playback: slice.playback,
      config: config,
    );
    _run(request, (j) {
      _record(p.event, p.pass, j, w.expectedUs, attackUs: _attackUs(slice, j));
    });
  }

  int? _attackUs(CaptureSlice s, NoteJudgement j) =>
      j.attackIndex == null ? null : s.timeOf(j.attackIndex!);

  void _run(NoteJudgeRequest request, void Function(NoteJudgement) done) {
    final epoch = _runEpoch;
    _analysisInFlight = true;
    _analyze(request)
        .then((j) {
          _analysisInFlight = false;
          if (epoch != _runEpoch || _disposed) return;
          done(j);
          _notify();
        })
        .catchError((Object _) {
          _analysisInFlight = false;
          if (epoch != _runEpoch || _disposed) return;
          done(
            const NoteJudgement(
              PracticeMark.couldNotHear,
              reason: HearingReason.unclear,
            ),
          );
          _notify();
        });
  }

  void _serviceWait(int now, double m) {
    final w = _wait!;
    waitStage = waitStageOf(_localUs() - w.sinceLocalUs);
    if (_analysisInFlight) return;
    final local = _localUs();
    if (local - _lastWaitCheckLocalUs < 150000) return;
    _lastWaitCheckLocalUs = local;
    final rate = _buffer.sampleRate ?? requestedSampleRate;
    // Only the last 1.5 s: an answer older than that was already analysed.
    final from = math.max(
      math.max(w.listenFromUs, w.consumedUntilUs),
      now - 1500000,
    );
    if (now - from < (config.skipAfterOnsetMs + config.minAnalysisMs) * 1000) {
      return;
    }
    final slice = _buffer.slice(from - 100000, now);
    final searchFrom = slice.indexOf(from);
    final tail =
        ((config.skipAfterOnsetMs + config.minAnalysisMs) * rate / 1000)
            .round();
    final searchTo = slice.samples.length - tail;
    if (searchTo <= searchFrom) return;
    final available =
        ((slice.samples.length - searchFrom) * 1000 / rate).round() -
        config.skipAfterOnsetMs;
    final request = NoteJudgeRequest(
      samples: slice.samples,
      sampleRate: slice.sampleRate,
      kind: w.event.kind,
      expectedMidi: w.event.midi,
      // Prefer the latest attack: the learner is answering now.
      expectedIndex: searchTo,
      searchFrom: searchFrom,
      searchTo: searchTo,
      analysisMs: available.clamp(config.minAnalysisMs, config.analysisMs),
      roomFloorDb: hearing.roomFloorDb,
      playback: slice.playback,
      config: config,
    );
    _run(request, (j) {
      final target = _wait;
      if (target == null || !identical(target, w)) return;
      final at = _attackUs(slice, j);
      if (at == null) return; // nothing played yet: keep listening
      target.consumedUntilUs = at + 50000;
      hearing.observe(j, now);
      if (j.mark != PracticeMark.couldNotHear) {
        target.firstDecisive ??= j;
      }
      if (j.mark == PracticeMark.correct) {
        _record(
          w.event,
          w.pass,
          target.firstDecisive!,
          w.expectedUs,
          attackUs: at,
          observed: false,
        );
        _releaseWait();
      } else if (j.mark == PracticeMark.differentNote) {
        marks = Map.of(marks)
          ..[w.event.index] = StripMark(
            PracticeMark.differentNote,
            observedMidi: j.observedMidi,
          );
      }
    });
  }

  /// "Skip" in "Wait for me" (offered after 8 s).
  void skipHeld() {
    final w = _wait;
    if (w == null) return;
    _record(
      w.event,
      w.pass,
      w.firstDecisive ??
          const NoteJudgement(
            PracticeMark.couldNotHear,
            reason: HearingReason.skipped,
          ),
      w.expectedUs,
      observed: false,
    );
    _releaseWait();
    _notify();
  }

  void _releaseWait() {
    final t = timeline, transport = _transport;
    _wait = null;
    heldEvent = null;
    waitStage = WaitStage.listening;
    if (t == null || transport == null) return;
    final now = _clock.nowUs(_localUs());
    if (now != null) transport.releaseHeld(t.beatAt(now));
  }

  /// "Listen to this note": the expected note, synthesized on the device
  /// (never a recording). Chunks while it sounds are low confidence.
  Future<void> listenHeld() async {
    final held = heldEvent;
    if (held == null) return;
    final midi = score.events[held].midi;
    final rate = _buffer.sampleRate ?? requestedSampleRate;
    if (midi == null) return;
    final pcm = referenceNote(midi, sampleRate: rate);
    try {
      await audio.playCue(pcm, sampleRate: rate);
    } on Object {
      // A missing reference never stops practice.
    }
  }

  void _record(
    PracticeEvent e,
    int pass,
    NoteJudgement j,
    int expectedUs, {
    int? attackUs,
    bool observed = true,
  }) {
    final t = timeline;
    final timing =
        t != null &&
            t.calibrated &&
            attackUs != null &&
            j.mark == PracticeMark.correct
        ? (attackUs - expectedUs) / 1000
        : null;
    outcomes.add(
      NoteOutcome(
        eventIndex: e.index,
        bar: e.bar,
        pass: pass,
        mark: j.mark,
        reason: j.reason,
        expectedMidi: e.midi,
        observedMidi: j.observedMidi,
        centsFromExpected: j.centsFromExpected,
        timingMs: timing,
      ),
    );
    marks = Map.of(marks)
      ..[e.index] = StripMark(j.mark, observedMidi: j.observedMidi);
    if (observed) hearing.observe(j, _clock.nowUs(_localUs()) ?? 0);
  }

  void dismissSetupCard() {
    hearing.dismissSetupCard(_clock.nowUs(_localUs()) ?? 0);
    _notify();
  }

  /// User stop. A loop run ("practice") ends with its summary; a stopped
  /// single run is kept as a summary too but never counts for the gate.
  Future<void> stop() async {
    if (!running) return;
    if (outcomes.isEmpty) {
      ++_runEpoch;
      phase = PracticePhase.idle;
      await _closeAudio();
      _notify();
      return;
    }
    _finish(completed: false);
  }

  void _finish({required bool completed}) {
    ++_runEpoch;
    final start = _listenStartUs, now = _clock.nowUs(_localUs());
    _activeDuration = start == null || now == null
        ? Duration.zero
        : Duration(microseconds: math.max(0, now - start));
    summary = PracticeRunSummary.of(
      score: score,
      outcomes: List.of(outcomes),
      bpm: _tempo.bpm,
      openBpm: _tempo.openBpm,
      targetBpm: _tempo.targetBpm,
      completed: completed,
      loopUsed: _loopBars != null,
      waitUsed: _waitMode && !freeTempo,
      timingCalibrated: timeline?.calibrated ?? false,
      criteria: criteria,
    );
    phase = PracticePhase.finished;
    _pending.clear();
    _wait = null;
    heldEvent = null;
    unawaited(_closeAudio());
    _notify();
  }

  void _fail(String reason) {
    ++_runEpoch;
    failure = reason;
    phase = PracticePhase.failed;
    _pending.clear();
    _wait = null;
    heldEvent = null;
    unawaited(_closeAudio());
    _notify();
  }

  Future<void> _closeAudio() async {
    _stopping = true;
    try {
      await audio.stopMetronome();
      await audio.stop();
    } on Object {
      // The capture close latch reports itself on the next start.
    }
    _buffer.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_runEpoch;
    unawaited(_chunkSub?.cancel());
    unawaited(_statusSub?.cancel());
    unawaited(_anchorSub?.cancel());
    _buffer.clear();
    super.dispose();
  }
}

/// A short synthesized reference note (stiff-string model, deterministic).
Float64List referenceNote(int midi, {required int sampleRate}) {
  final hz = 440 * math.pow(2, (midi - 69) / 12).toDouble();
  final pluck = SyntheticString.pluck(
    f0Hz: hz,
    sampleRate: sampleRate,
    seconds: 1.2,
    pickNoiseLevel: 0,
    peak: .5,
  );
  // Fade the last 50 ms so the cue ends without a step.
  final fade = (sampleRate * .05).round();
  for (var i = 0; i < fade && i < pluck.length; i++) {
    pluck[pluck.length - 1 - i] *= i / fade;
  }
  return pluck;
}

final class _Pending {
  _Pending({required this.event, required this.pass, required this.window});
  final PracticeEvent event;
  final int pass;
  final NoteWindow window;
}

final class _WaitTarget {
  _WaitTarget({
    required this.event,
    required this.pass,
    required this.expectedUs,
    required this.sinceLocalUs,
    required this.listenFromUs,
  }) : consumedUntilUs = listenFromUs;
  final PracticeEvent event;
  final int pass;
  final int expectedUs, sinceLocalUs, listenFromUs;
  int consumedUntilUs;
  NoteJudgement? firstDecisive;
}
