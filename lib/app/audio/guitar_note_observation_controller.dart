import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ostinato_audio/ostinato_audio.dart';

import 'audio_input_controller.dart';
import 'audio_continuity.dart';
import '../inference_manifest.dart';
import 'audio_capture_channel.dart';
import 'practice_audio_root.dart';

final class GuitarObservationConfig {
  GuitarObservationConfig.fromJson(Map<String, dynamic> json) {
    final p = json['pitchGate'] as Map<String, dynamic>;
    final g = json['guard'] as Map<String, dynamic>;
    final s = json['practice'] as Map<String, dynamic>;
    double n(Map<String, dynamic> m, String key) => (m[key] as num).toDouble();
    pitch = GuitarSingleNoteConfig(
      windowSize: p['windowSize'] as int,
      hopSize: p['hopSize'] as int,
      minReliableWindows: p['minReliableWindows'] as int,
      minHz: n(p, 'minHz'),
      maxHz: n(p, 'maxHz'),
      yinThreshold: n(p, 'yinThreshold'),
      minPeriodicity: n(p, 'minPeriodicity'),
      minLevelAboveFloorDb: n(p, 'minLevelAboveFloorDb'),
      attackWindowUs: p['attackWindowUs'] as int,
      maxSpreadCents: n(p, 'maxSpreadCents'),
      maxCenterErrorCents: n(p, 'maxCenterErrorCents'),
    );
    guard = GuitarObservationGuardConfig(
      maxResidualPowerRatio: n(g, 'maxResidualPowerRatio'),
      minFundamentalPowerRatio: n(g, 'minFundamentalPowerRatio'),
      clippingPeak: n(g, 'clippingPeak'),
      maxClippedFraction: n(g, 'maxClippedFraction'),
      harmonicToleranceCents: n(g, 'harmonicToleranceCents'),
      minAnalysisHz: n(g, 'minAnalysisHz'),
      maxAnalysisHz: n(g, 'maxAnalysisHz'),
      minFftSamples: g['minFftSamples'] as int,
      lowStringMaxMidi: g['lowStringMaxMidi'] as int?,
      lowStringMinOddHarmonicPowerRatio:
          (g['lowStringMinOddHarmonicPowerRatio'] as num?)?.toDouble(),
    );
    // Tuning reads keep cents up to the half-semitone so a guitar 30-40 cents
    // off is measured, not refused; displayed notes keep the 35-cent gate.
    tuningPitch = GuitarSingleNoteConfig(
      windowSize: pitch.windowSize,
      hopSize: pitch.hopSize,
      minReliableWindows: pitch.minReliableWindows,
      minHz: pitch.minHz,
      maxHz: pitch.maxHz,
      yinThreshold: pitch.yinThreshold,
      minPeriodicity: pitch.minPeriodicity,
      minLevelAboveFloorDb: pitch.minLevelAboveFloorDb,
      attackWindowUs: pitch.attackWindowUs,
      maxSpreadCents: pitch.maxSpreadCents,
      maxCenterErrorCents: tuningMaxCenterErrorCents,
    );
    calibrationMs = s['calibrationMs'] as int;
    windowSamples = s['windowSamples'] as int;
    analysisIntervalMs = s['analysisIntervalMs'] as int;
    staleMs = s['staleMs'] as int;
    initialSampleRate = s['initialSampleRate'] as int;
    supportedSampleRates = (s['supportedSampleRates'] as List)
        .cast<int>()
        .toSet();
    if (calibrationMs <= 0 ||
        windowSamples < 8192 ||
        windowSamples > 16384 ||
        analysisIntervalMs < 100 ||
        staleMs < analysisIntervalMs ||
        !supportedSampleRates.contains(initialSampleRate)) {
      throw const FormatException('Invalid observation practice config');
    }
    GuitarPitchObserver(config: pitch, guard: guard);
    GuitarPitchObserver(config: tuningPitch, guard: guard);
  }
  static const tuningMaxCenterErrorCents = 50.0;
  late final GuitarSingleNoteConfig pitch, tuningPitch;
  late final GuitarObservationGuardConfig guard;
  late final int calibrationMs,
      windowSamples,
      analysisIntervalMs,
      staleMs,
      initialSampleRate;
  late final Set<int> supportedSampleRates;
  static Future<GuitarObservationConfig> load() async {
    final manifest = await InferenceManifest.load();
    if (manifest.capability('guitar.singleNote') !=
        InferenceCapability.approximate) {
      throw const FormatException('Guitar observation unavailable');
    }
    final bytes = await manifest.guitarObservation.readVerified(rootBundle);
    return GuitarObservationConfig.fromJson(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
    );
  }
}

enum NoteObservationPhase {
  idle,
  starting,
  checkingInput,
  calibrating,
  listening,
  noResult,
  analysisTimedOut,
  analysisSettling,
  permissionDenied,
  permissionDeniedPermanent,
  unsupportedInput,
  unavailable,
}

/// Session tuning read from sustained notes, not an external tuner.
enum NoteTuning { unknown, inTune, check, tuneFirst }

typedef NoteAnalyzer =
    Future<GuitarNoteObservationResult> Function(
      List<double>,
      int,
      int,
      double,
    );

/// Tuning-only reading of the same window (wider centre limit).
typedef TuningAnalyzer =
    Future<GuitarNoteObservation?> Function(List<double>, int, int, double);

typedef _NoteAnalysis =
    Future<(GuitarNoteObservationResult, GuitarNoteObservation?)> Function(
      List<double>,
      int,
      int,
      double,
    );

/// Optional, target-free observer. PCM and digital noise floor exist only in
/// bounded RAM; there is no persistence, analytics, file or network dependency.
final class GuitarNoteObservationController extends ChangeNotifier {
  GuitarNoteObservationController({
    required this.config,
    AudioSource? source,
    NoteAnalyzer? analyzer,
    TuningAnalyzer? tuningAnalyzer,
  }) : _source = source ?? AudioInputController(),
       _ownsSource = source == null,
       _analysis = analyzer == null && tuningAnalyzer == null
           ? ((samples, rate, time, floor) =>
                 _analyzeOffMain(samples, rate, time, floor, config))
           : ((samples, rate, time, floor) async {
               final result =
                   await (analyzer ??
                       (s, r, t, f) => _analyzeOffMain(
                         s,
                         r,
                         t,
                         f,
                         config,
                       ).then((v) => v.$1))(samples, rate, time, floor);
               final tuning = tuningAnalyzer == null
                   ? result.observation
                   : await tuningAnalyzer(samples, rate, time, floor);
               return (result, tuning);
             }) {
    if (_source is AudioInputController) {
      unawaited(refreshCaptureStatus());
    }
  }
  final GuitarObservationConfig config;
  final AudioSource _source;
  final bool _ownsSource;
  final _NoteAnalysis _analysis;
  StreamSubscription<AudioChunk>? _chunks;
  StreamSubscription<AudioSurfaceState>? _status;
  final List<double> _window = [];
  final _continuity = AudioContinuity();
  final List<double> _floorLevels = [];
  Timer? _stale, _pendingStale, _routeResolveTimer;
  int _analysisToken = 0;
  int _nextJobId = 0;
  int? _runningJobId;
  List<double>? _analysisSamples;
  Future<void>? _sourceClosing;
  NoteObservationPhase? _terminalStopPhase;
  int _epoch = 0, _calibrationSamples = 0;
  int? _lastAnalysisUs;
  double? _floor;
  bool _active = false, _disposed = false, _sourceCloseFailed = false;
  AudioRoute _route = AudioRoute.unknown;
  NoteObservationPhase phase = NoteObservationPhase.idle;
  GuitarNoteObservation? observation;
  GuitarSingleNoteReason? refusal;

  /// Three consecutive tuning reads of one note within
  /// [tuningRunSpreadCents] make one sustained-note measurement; a later
  /// sustained note replaces it, so retuning is picked up without a control.
  /// Leaving a state needs [tuningHysteresisCents] past its boundary.
  static const tuningRunLength = 3;
  static const tuningRunSpreadCents = 10.0;
  static const tuningCheckCents = 20.0;
  static const tuningFirstCents = 30.0;
  static const tuningHysteresisCents = 2.0;

  /// Open-string corrections from the E34 synthetic string model (B = 1e-4):
  /// stiff strings read sharp. A modelling assumption, not a calibration of
  /// real strings; the nearest open string (lower on a tie) applies.
  static const tuningCorrectionCents = <int, double>{
    40: -4.1,
    45: -3.8,
    50: -3.9,
    55: -4.1,
    59: -3.8,
    64: -2.9,
  };
  static double tuningCorrection(int midi) {
    var best = 40;
    for (final open in tuningCorrectionCents.keys) {
      if ((open - midi).abs() < (best - midi).abs()) best = open;
    }
    return tuningCorrectionCents[best]!;
  }

  NoteTuning tuning = NoteTuning.unknown;
  double? tuningCents;
  final List<GuitarNoteObservation> _tuningRun = [];
  bool get isActive => _active;
  bool get isCaptureStopping => _sourceClosing != null;
  bool get captureStopFailed => _sourceCloseFailed;
  AudioCaptureClosePhase get captureClosePhase =>
      _source is AudioInputController
      ? _source.captureCloseState.phase
      : AudioCaptureClosePhase.clear;
  bool get captureClosePending =>
      _source is AudioInputController && _source.captureClosePending;
  bool get canRetryCaptureClose =>
      _source is AudioInputController && _source.captureNeedsExplicitRetry;
  bool get captureGateReady =>
      _source is! AudioInputController || _source.captureGateReady;
  bool get canStart =>
      !_disposed &&
      !_active &&
      _runningJobId == null &&
      _sourceClosing == null &&
      !_sourceCloseFailed &&
      captureGateReady;

  Future<void> refreshCaptureStatus() async {
    final source = _source;
    if (source is AudioInputController) {
      await source.refreshCloseState();
      _notify();
    }
  }

  Future<void> retryCaptureClose() async {
    final source = _source;
    if (source is! AudioInputController || !canRetryCaptureClose) return;
    try {
      await source.retryClose();
      _sourceCloseFailed = false;
      if (!_active) phase = NoteObservationPhase.idle;
    } on Object {
      _sourceCloseFailed = true;
      phase = NoteObservationPhase.unavailable;
    }
    await refreshCaptureStatus();
  }

  @visibleForTesting
  int get bufferedSamples => _window.length;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _clear() {
    _epoch++;
    for (var i = 0; i < _window.length; i++) {
      _window[i] = 0;
    }
    _window.clear();
    final analysisSamples = _analysisSamples;
    if (analysisSamples != null) {
      analysisSamples.fillRange(0, analysisSamples.length, 0);
    }
    _floorLevels.clear();
    _floor = null;
    _calibrationSamples = 0;
    _lastAnalysisUs = null;
    _continuity.reset();
    _stale?.cancel();
    _pendingStale?.cancel();
    _routeResolveTimer?.cancel();
    _stale = null;
    _pendingStale = null;
    _routeResolveTimer = null;
    _analysisToken++;
    observation = null;
    refusal = null;
    tuning = NoteTuning.unknown;
    tuningCents = null;
    _tuningRun.clear();
  }

  void _recordTuning(GuitarNoteObservation? reading) {
    if (reading == null) {
      _tuningRun.clear();
      return;
    }
    _tuningRun.add(reading);
    if (_tuningRun.length > tuningRunLength) _tuningRun.removeAt(0);
    if (_tuningRun.length < tuningRunLength ||
        _tuningRun.any((v) => v.midi != reading.midi)) {
      return;
    }
    final cents = _tuningRun.map((v) => v.centsFromCenter).toList()..sort();
    if (cents.last - cents.first > tuningRunSpreadCents) return;
    final measured = cents[cents.length ~/ 2] + tuningCorrection(reading.midi);
    tuningCents = measured;
    tuning = _nextTuning(measured.abs());
  }

  NoteTuning _nextTuning(double cents) {
    NoteTuning band(double a) => a > tuningFirstCents
        ? NoteTuning.tuneFirst
        : a > tuningCheckCents
        ? NoteTuning.check
        : NoteTuning.inTune;
    final plain = band(cents);
    if (tuning == NoteTuning.unknown || plain == tuning) return plain;
    // Towards a worse state the value must clear that state's lower bound;
    // towards a better state it must fall below its upper bound.
    final worse = plain.index > tuning.index;
    final shifted = band(
      worse ? cents - tuningHysteresisCents : cents + tuningHysteresisCents,
    );
    return shifted == tuning ? tuning : shifted;
  }

  void _settlePendingStatus() {
    if (!_active &&
        _runningJobId == null &&
        _sourceClosing == null &&
        phase == NoteObservationPhase.analysisSettling) {
      _terminalStopPhase = null;
      phase = NoteObservationPhase.idle;
    }
  }

  Future<void> _stopSource() {
    final closing = _sourceClosing;
    if (closing != null) return closing;
    // Install the pending-close state before invoking the source: a source
    // may announce AudioStopped synchronously from stop().
    final next = Future<void>.microtask(_source.stop).catchError((Object _) {
      _sourceCloseFailed = true;
      _terminalStopPhase = NoteObservationPhase.unavailable;
      phase = NoteObservationPhase.unavailable;
      _notify();
    });
    _sourceClosing = next;
    _notify();
    unawaited(
      next.whenComplete(() {
        if (!identical(_sourceClosing, next)) return;
        _sourceClosing = null;
        _settlePendingStatus();
        _notify();
      }),
    );
    return next;
  }

  void _closeCaptureWithStatus(NoteObservationPhase terminal) {
    _active = false;
    _clear();
    _terminalStopPhase = terminal;
    phase = terminal;
    unawaited(_stopSource());
  }

  Future<void> start({PracticeAudioCaptureAction? captureAction}) async {
    if (!canStart) {
      captureAction?.retire();
      return;
    }
    _terminalStopPhase = null;
    _clear();
    _active = true;
    phase = NoteObservationPhase.starting;
    _notify();
    _status ??= _source.status.listen(_onStatus);
    _chunks ??= _source.chunks.listen(_onChunk);
    final source = _source;
    if (source is AudioInputController) {
      await source.start(
        sampleRate: config.initialSampleRate,
        captureAction: captureAction,
      );
    } else {
      captureAction?.retire();
      await source.start(sampleRate: config.initialSampleRate);
    }
  }

  void _onStatus(AudioSurfaceState status) {
    if (_disposed || (!_active && status is! AudioStopped)) return;
    switch (status) {
      case AudioCalibrating(:final route):
        if (!_active) return;
        if (_runningJobId != null) {
          // A route/reset invalidates the old samples. Keeping capture open
          // while its analysis is still pending would leave no usable path.
          _closeCaptureWithStatus(NoteObservationPhase.analysisSettling);
          return;
        }
        if (route == AudioRoute.unknown &&
            _route == AudioRoute.unknown &&
            _routeResolveTimer?.isActive == true) {
          // Repeated unresolved route notices must not extend the first
          // discovery deadline while the microphone remains open.
          return;
        }
        _clear();
        _route = route;
        if (route == AudioRoute.unknown) {
          // Native startup can announce unknown before its first audio read.
          // Give it the existing calibration window to identify the input,
          // then close capture rather than leaving an unsupported route open.
          final routeEpoch = _epoch;
          phase = NoteObservationPhase.checkingInput;
          _routeResolveTimer = Timer(
            Duration(milliseconds: config.calibrationMs),
            () {
              if (_disposed ||
                  !_active ||
                  _epoch != routeEpoch ||
                  _route != AudioRoute.unknown) {
                return;
              }
              _closeCaptureWithStatus(NoteObservationPhase.unsupportedInput);
            },
          );
        } else if (route != AudioRoute.speaker) {
          _closeCaptureWithStatus(NoteObservationPhase.unsupportedInput);
          return;
        } else {
          phase = NoteObservationPhase.calibrating;
        }
      case AudioPermissionDeniedPermanent():
        _clear();
        _active = false;
        phase = NoteObservationPhase.permissionDeniedPermanent;
      case AudioPermissionDeniedRetriable():
        _clear();
        _active = false;
        phase = NoteObservationPhase.permissionDenied;
      case AudioUnavailable() || AudioSetupFailed():
        // Observe the same singleflight stop as the source's terminal error.
        // The UI must refresh when its native close receipt settles, while
        // retaining an unavailable result rather than a playing verdict.
        _closeCaptureWithStatus(NoteObservationPhase.unavailable);
        return;
      case AudioStopped():
        final terminal = _terminalStopPhase;
        _clear();
        _active = false;
        phase =
            terminal ??
            (_runningJobId == null
                ? NoteObservationPhase.idle
                : NoteObservationPhase.analysisSettling);
      case AudioStarting():
        phase = NoteObservationPhase.starting;
      case AudioStreaming():
        break;
    }
    _notify();
  }

  void _onChunk(AudioChunk chunk) {
    if (!_active || _disposed || _route != AudioRoute.speaker) return;
    if (!config.supportedSampleRates.contains(chunk.sampleRate) ||
        chunk.samples.isEmpty ||
        chunk.samples.any((v) => !v.isFinite || v.abs() > 1)) {
      _closeCaptureWithStatus(NoteObservationPhase.unavailable);
      return;
    }
    if (chunk.clockDomain != AudioClockDomain.monotonic) {
      _closeCaptureWithStatus(NoteObservationPhase.unavailable);
      return;
    }
    final continuity = _continuity.observe(
      startUs: chunk.tStartUs,
      sampleRate: chunk.sampleRate,
      sampleCount: chunk.samples.length,
    );
    if (continuity == AudioContinuityResult.invalid) {
      _closeCaptureWithStatus(NoteObservationPhase.unavailable);
      return;
    }
    if (continuity == AudioContinuityResult.recalibrate) {
      if (_runningJobId != null) {
        _closeCaptureWithStatus(NoteObservationPhase.analysisSettling);
        return;
      }
      _clear();
      phase = NoteObservationPhase.calibrating;
      _continuity.observe(
        startUs: chunk.tStartUs,
        sampleRate: chunk.sampleRate,
        sampleCount: chunk.samples.length,
      );
      _notify();
    }
    if (_floor == null) {
      final rms = math.sqrt(
        chunk.samples.fold<double>(0, (a, v) => a + v * v) /
            chunk.samples.length,
      );
      _floorLevels.add(20 * math.log(math.max(rms, 1e-9)) / math.ln10);
      _calibrationSamples += chunk.samples.length;
      if (_calibrationSamples >=
          chunk.sampleRate * config.calibrationMs / 1000) {
        _floorLevels.sort();
        _floor = _floorLevels[_floorLevels.length ~/ 2];
        _floorLevels.clear();
        phase = NoteObservationPhase.listening;
        _notify();
      }
      return;
    }
    _window.addAll(chunk.samples);
    if (_window.length > config.windowSamples) {
      _window.removeRange(0, _window.length - config.windowSamples);
    }
    final epoch = _epoch;
    if (_window.length < config.windowSamples ||
        _runningJobId != null ||
        (_lastAnalysisUs != null &&
            chunk.tStartUs - _lastAnalysisUs! <
                config.analysisIntervalMs * 1000)) {
      return;
    }
    final jobId = ++_nextJobId;
    _runningJobId = jobId;
    final token = ++_analysisToken;
    final samples = List<double>.of(_window);
    _analysisSamples = samples;
    _pendingStale?.cancel();
    _pendingStale = Timer(Duration(milliseconds: config.staleMs), () {
      if (epoch != _epoch || !_active || _disposed || token != _analysisToken) {
        return;
      }
      // Isolate.run cannot cancel an unresolved Future. Stop recording and
      // keep this one job in flight until it actually settles; never start a
      // second analysis merely because the display timer elapsed.
      _closeCaptureWithStatus(NoteObservationPhase.analysisTimedOut);
    });
    _lastAnalysisUs = chunk.tStartUs;
    final startUs =
        chunk.tStartUs +
        ((chunk.samples.length - samples.length) * 1000000 / chunk.sampleRate)
            .round();
    _analysis(samples, chunk.sampleRate, startUs, _floor!)
        .then(
          (analysis) {
            final (result, tuningReading) = analysis;
            if (_disposed ||
                !_active ||
                epoch != _epoch ||
                token != _analysisToken) {
              return;
            }
            _pendingStale?.cancel();
            _stale?.cancel();
            _stale = Timer(Duration(milliseconds: config.staleMs), () {
              if (epoch != _epoch || !_active || _disposed) return;
              observation = null;
              phase = NoteObservationPhase.noResult;
              _notify();
            });
            observation = result.observation;
            refusal = result.reason;
            _recordTuning(tuningReading);
            phase = observation == null
                ? NoteObservationPhase.noResult
                : NoteObservationPhase.listening;
            _notify();
          },
          onError: (Object _) {
            if (_disposed ||
                !_active ||
                epoch != _epoch ||
                token != _analysisToken) {
              return;
            }
            _closeCaptureWithStatus(NoteObservationPhase.unavailable);
          },
        )
        .whenComplete(() {
          samples.fillRange(0, samples.length, 0);
          if (identical(_analysisSamples, samples)) _analysisSamples = null;
          if (_runningJobId != jobId) return;
          _runningJobId = null;
          _settlePendingStatus();
          _notify();
        });
  }

  Future<void> stop() async {
    _active = false;
    _terminalStopPhase = _runningJobId == null
        ? null
        : NoteObservationPhase.analysisSettling;
    _clear();
    phase = _terminalStopPhase ?? NoteObservationPhase.idle;
    final closing = _stopSource();
    _notify();
    await closing;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _active = false;
    _terminalStopPhase = null;
    _clear();
    unawaited(_chunks?.cancel());
    unawaited(_status?.cancel());
    unawaited(_stopSource());
    if (_ownsSource) unawaited((_source as AudioInputController).dispose());
    super.dispose();
  }
}

Future<(GuitarNoteObservationResult, GuitarNoteObservation?)> _analyzeOffMain(
  List<double> samples,
  int rate,
  int time,
  double floor,
  GuitarObservationConfig config,
) => Isolate.run(() {
  GuitarNoteObservationResult observe(GuitarSingleNoteConfig pitch) =>
      GuitarPitchObserver(
        config: pitch,
        guard: config.guard,
      ).observe(samples, sampleRate: rate, tStartUs: time, roomFloorDb: floor);
  return (observe(config.pitch), observe(config.tuningPitch).observation);
});
