import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:ostinato_audio/ostinato_audio.dart';

import '../../audio/audio_capture_channel.dart';
import '../../audio/audio_input_controller.dart';
import '../../audio/practice_audio_root.dart';
import 'audio_environment.dart';
import 'latency_calibration.dart';
import 'setup_profile_store.dart';

typedef LatencyEstimator =
    Future<LatencyCalibrationResult> Function(CalibrationRecording recording);

Future<LatencyCalibrationResult> estimateOffMain(CalibrationRecording r) =>
    Isolate.run(() => estimateRouteLatency(r));

/// Room step: quiet window (the guitar observer's 2 s `calibrationMs`,
/// median chunk level), then "play one string" until the level rises
/// [kHeardAboveFloorDb] above the room.
const int kRoomQuietMs = 2000;
const int kRoomListenMs = 10000;
const double kHeardAboveFloorDb = 12;

/// Above this the room is too loud for reliable notes (shown as a hint, the
/// step still completes).
const double kNoisyRoomDb = -45;

enum SetupAudioPhase {
  idle,
  starting,
  roomQuiet,
  roomPlay,
  clicking,
  analysing,
  done,
  failed,
}

/// Drives the two measuring steps of the setup wizard (F4.2) on one capture
/// controller: room + level (record only) and latency (play + record, 8
/// clicks). PCM stays in RAM for the step and is zeroed afterwards; nothing
/// is recorded to a file or sent. Results are written to [store].
final class SetupAudioController extends ChangeNotifier {
  SetupAudioController({
    required this.audio,
    required this.store,
    this.environment = const AudioEnvironmentProbe(),
    LatencyEstimator? estimator,
    this.anchorTimeout = const Duration(milliseconds: 1500),
    this.sampleRate = 48000,
    DateTime Function()? now,
  }) : _estimate = estimator ?? estimateOffMain,
       _now = now ?? DateTime.now;

  final AudioInputController audio;
  final SetupProfileStore store;
  final AudioEnvironmentProbe environment;
  final Duration anchorTimeout;
  final int sampleRate;
  final LatencyEstimator _estimate;
  final DateTime Function() _now;

  SetupAudioPhase phase = SetupAudioPhase.idle;

  /// Failure code: `permission`, `no_clicks` (stream did not start),
  /// `input_changed`, `route_unknown`, or a capture reason.
  String? failure;

  /// Live level (dBFS) for the meter, and the room floor once measured.
  double levelDb = -120;
  double? floorDb;
  RoomCheck? room;
  LatencyCalibrationResult? latency;
  CalibrationRoute? route;
  AudioRoute inputRoute = AudioRoute.unknown;

  _Task _task = _Task.none;
  int _epoch = 0;
  bool _disposed = false;
  bool _closing = false;
  StreamSubscription<AudioChunk>? _chunkSub;
  StreamSubscription<AudioSurfaceState>? _statusSub;
  StreamSubscription<MetronomeAnchor>? _anchorSub;

  // Room state.
  final List<double> _quietLevels = [];
  int _roomSamples = 0;
  int _playSamples = 0;
  double _peakDb = -120;

  // Latency state.
  final List<double> _recording = [];
  int? _recordingStartUs, _nextExpectedUs, _rate;
  Completer<MetronomeAnchor?>? _anchorWait;
  int? _anchorUs;
  bool _metronomeRequested = false;

  bool get busy =>
      phase != SetupAudioPhase.idle &&
      phase != SetupAudioPhase.done &&
      phase != SetupAudioPhase.failed;

  double get meter => ((levelDb + 80) / 60).clamp(0.0, 1.0);

  bool get roomNoisy => (floorDb ?? -120) > kNoisyRoomDb;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _listen() {
    _chunkSub ??= audio.chunks.listen(_onChunk);
    _statusSub ??= audio.status.listen(_onStatus);
    _anchorSub ??= audio.metronomeAnchors.listen(_onAnchor);
  }

  /// Step 2: room + level.
  Future<void> measureRoom({PracticeAudioCaptureAction? captureAction}) async {
    if (busy || _disposed) {
      captureAction?.retire();
      return;
    }
    _begin(_Task.room);
    room = null;
    floorDb = null;
    _quietLevels.clear();
    _roomSamples = 0;
    _playSamples = 0;
    _peakDb = -120;
    _listen();
    await audio.start(sampleRate: sampleRate, captureAction: captureAction);
  }

  /// Step 3: 8 clicks, E50 first-arrival estimate, saved per route.
  Future<void> calibrateLatency({
    PracticeAudioCaptureAction? captureAction,
  }) async {
    if (busy || _disposed) {
      captureAction?.retire();
      return;
    }
    _begin(_Task.latency);
    latency = null;
    route = null;
    _clearRecording();
    _metronomeRequested = false;
    _anchorUs = null;
    _listen();
    await audio.start(
      sampleRate: sampleRate,
      captureAction: captureAction,
      sessionMode: AudioSessionMode.playAndRecord,
    );
  }

  void _begin(_Task task) {
    ++_epoch;
    _task = task;
    _closing = false;
    failure = null;
    inputRoute = AudioRoute.unknown;
    phase = SetupAudioPhase.starting;
    _notify();
  }

  void _onStatus(AudioSurfaceState s) {
    if (!busy || _closing) return;
    switch (s) {
      case AudioPermissionDenied():
        _fail('permission');
      case AudioUnavailable(:final reason) || AudioSetupFailed(:final reason):
        _fail(reason);
      case AudioStopped():
        _fail('stopped');
      case AudioCalibrating(:final route):
        if (_anchorUs != null || phase == SetupAudioPhase.roomPlay) {
          _fail('input_changed');
        } else if (route != AudioRoute.unknown) {
          inputRoute = route;
        }
      case AudioStarting() || AudioStreaming():
        break;
    }
  }

  void _onChunk(AudioChunk c) {
    if (!busy || _closing) return;
    switch (_task) {
      case _Task.room:
        _roomChunk(c);
      case _Task.latency:
        _latencyChunk(c);
      case _Task.none:
        break;
    }
  }

  void _roomChunk(AudioChunk c) {
    final level = chunkLevelDb(c.samples);
    levelDb = level;
    if (phase == SetupAudioPhase.starting) phase = SetupAudioPhase.roomQuiet;
    if (phase == SetupAudioPhase.roomQuiet) {
      _quietLevels.add(level);
      _roomSamples += c.samples.length;
      if (_roomSamples >= c.sampleRate * kRoomQuietMs ~/ 1000) {
        floorDb = medianLevelDb(_quietLevels);
        _quietLevels.clear();
        phase = SetupAudioPhase.roomPlay;
      }
      _notify();
      return;
    }
    if (phase != SetupAudioPhase.roomPlay) return;
    _playSamples += c.samples.length;
    _peakDb = math.max(_peakDb, level);
    final floor = floorDb!;
    final heard = level >= floor + kHeardAboveFloorDb;
    if (heard || _playSamples >= c.sampleRate * kRoomListenMs ~/ 1000) {
      unawaited(_finishRoom(heard: heard));
      return;
    }
    _notify();
  }

  Future<void> _finishRoom({required bool heard}) async {
    final epoch = _epoch;
    final check = RoomCheck(
      floorDb: floorDb!,
      peakDb: _peakDb,
      heard: heard,
      at: _now().toUtc(),
    );
    room = check;
    phase = SetupAudioPhase.done;
    await _close();
    if (epoch != _epoch) return;
    try {
      await store.update(
        (p) => p.copyWith(
          room: check,
          roomStep: SetupStepRecord(SetupStepState.done, check.at),
        ),
      );
    } on Object {
      // The result still shows; only saving failed.
    }
    _notify();
  }

  void _latencyChunk(AudioChunk c) {
    final rate = c.sampleRate;
    if (_rate != null && _rate != rate) {
      _fail('input_changed');
      return;
    }
    // A gap in the capture clock would misplace every click.
    final expected = _nextExpectedUs;
    if (expected != null && (c.tStartUs - expected).abs() > 2000) {
      _fail('input_changed');
      return;
    }
    _rate = rate;
    _recordingStartUs ??= c.tStartUs;
    _nextExpectedUs = c.tStartUs + (c.samples.length * 1e6 / rate).round();
    _recording.addAll(c.samples);
    levelDb = chunkLevelDb(c.samples);
    if (!_metronomeRequested) {
      _metronomeRequested = true;
      unawaited(_startClicks(rate));
    }
    final anchor = _anchorUs;
    if (anchor != null) {
      final rec = _recordingOf(anchor);
      if (_nextExpectedUs! >= rec.endUs) {
        unawaited(_analyse(rec));
        return;
      }
    }
    _notify();
  }

  CalibrationRecording _recordingOf(int anchorUs) => CalibrationRecording(
    samples: Float64List(0),
    sampleRate: _rate!,
    startUs: _recordingStartUs!,
    anchorUs: anchorUs,
    framesPerBeat: calibrationFramesPerBeat(_rate!),
  );

  Future<void> _startClicks(int rate) async {
    final epoch = _epoch;
    phase = SetupAudioPhase.clicking;
    _notify();
    final click = calibrationClick(rate);
    _anchorWait = Completer<MetronomeAnchor?>();
    MetronomeAnchor? anchor;
    try {
      await audio.startMetronome(
        MetronomeStreamRequest(
          sampleRate: rate,
          framesPerBeat: calibrationFramesPerBeat(rate),
          beatsPerBar: 4,
          accent: click,
          beat: click,
          leadInMs: 300,
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
    if (epoch != _epoch || !busy) return;
    if (anchor == null) {
      _fail('no_clicks');
      return;
    }
    _anchorUs = anchor.anchorUs;
  }

  void _onAnchor(MetronomeAnchor a) {
    final wait = _anchorWait;
    if (wait != null && !wait.isCompleted) wait.complete(a);
  }

  Future<void> _analyse(CalibrationRecording shape) async {
    final epoch = _epoch;
    phase = SetupAudioPhase.analysing;
    _notify();
    final recording = CalibrationRecording(
      samples: Float64List.fromList(_recording),
      sampleRate: shape.sampleRate,
      startUs: shape.startUs,
      anchorUs: shape.anchorUs,
      framesPerBeat: shape.framesPerBeat,
    );
    _clearRecording();
    await _close();
    if (epoch != _epoch) return;
    LatencyCalibrationResult result;
    try {
      result = await _estimate(recording);
    } on Object {
      result = const LatencyNotHeard(0);
    } finally {
      recording.samples.fillRange(0, recording.samples.length, 0);
    }
    if (epoch != _epoch || _disposed) return;
    final env = await environment.read();
    if (epoch != _epoch || _disposed) return;
    final r = calibrationRouteOf(inputRoute, env);
    route = r;
    latency = result;
    if (result is LatencyMeasured) {
      final measured = result.latency;
      if (r == null) {
        phase = SetupAudioPhase.failed;
        failure = 'route_unknown';
        _notify();
        return;
      }
      try {
        await store.update(
          (p) => p
              .withLatency(r, measured)
              .copyWith(
                latencyStep: SetupStepRecord(
                  SetupStepState.done,
                  measured.measuredAt,
                ),
              ),
        );
      } on Object {
        // Shown but not kept; the badge stays in practice.
      }
    }
    phase = SetupAudioPhase.done;
    _notify();
  }

  void _clearRecording() {
    for (var i = 0; i < _recording.length; i++) {
      _recording[i] = 0;
    }
    _recording.clear();
    _recordingStartUs = null;
    _nextExpectedUs = null;
    _rate = null;
  }

  void _fail(String reason) {
    ++_epoch;
    failure = reason;
    phase = SetupAudioPhase.failed;
    _clearRecording();
    _quietLevels.clear();
    unawaited(_close());
    _notify();
  }

  /// Stops a running step (leaving the step or the wizard).
  Future<void> cancel() async {
    if (!busy) return;
    ++_epoch;
    phase = SetupAudioPhase.idle;
    _clearRecording();
    await _close();
    _notify();
  }

  Future<void> _close() async {
    _closing = true;
    try {
      await audio.stopMetronome();
      await audio.stop();
    } on Object {
      // The capture close latch reports itself on the next start.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    _clearRecording();
    unawaited(_chunkSub?.cancel());
    unawaited(_statusSub?.cancel());
    unawaited(_anchorSub?.cancel());
    super.dispose();
  }
}

enum _Task { none, room, latency }
