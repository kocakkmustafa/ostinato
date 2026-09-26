import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ostinato_audio/ostinato_audio.dart';

import 'audio_input_controller.dart';

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
  }
  late final GuitarSingleNoteConfig pitch;
  late final GuitarObservationGuardConfig guard;
  late final int calibrationMs,
      windowSamples,
      analysisIntervalMs,
      staleMs,
      initialSampleRate;
  late final Set<int> supportedSampleRates;
  static Future<GuitarObservationConfig> load() async =>
      GuitarObservationConfig.fromJson(
        jsonDecode(
              await rootBundle.loadString(
                'assets/config/guitar-observation.v1.json',
              ),
            )
            as Map<String, dynamic>,
      );
}

enum NoteObservationPhase {
  idle,
  starting,
  calibrating,
  listening,
  noResult,
  permissionDenied,
  permissionDeniedPermanent,
  unsupportedInput,
  unavailable,
}

typedef NoteAnalyzer =
    Future<GuitarNoteObservationResult> Function(
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
  }) : _source = source ?? AudioInputController(),
       _ownsSource = source == null,
       _analyzer =
           analyzer ??
           ((samples, rate, time, floor) =>
               _analyzeOffMain(samples, rate, time, floor, config));
  final GuitarObservationConfig config;
  final AudioSource _source;
  final bool _ownsSource;
  final NoteAnalyzer _analyzer;
  StreamSubscription<AudioChunk>? _chunks;
  StreamSubscription<AudioSurfaceState>? _status;
  final List<double> _window = [];
  final List<double> _floorLevels = [];
  Timer? _stale, _pendingStale;
  int _analysisToken = 0;
  int _epoch = 0, _calibrationSamples = 0;
  int? _rate, _lastAnalysisUs;
  double? _floor;
  bool _active = false, _disposed = false, _busy = false;
  AudioRoute _route = AudioRoute.unknown;
  NoteObservationPhase phase = NoteObservationPhase.idle;
  GuitarNoteObservation? observation;
  GuitarSingleNoteReason? refusal;
  bool get isActive => _active;
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
    _floorLevels.clear();
    _floor = null;
    _calibrationSamples = 0;
    _rate = null;
    _lastAnalysisUs = null;
    _stale?.cancel();
    _pendingStale?.cancel();
    _stale = null;
    _pendingStale = null;
    _analysisToken++;
    observation = null;
    refusal = null;
  }

  Future<void> start() async {
    if (_disposed || _active) return;
    _clear();
    _active = true;
    phase = NoteObservationPhase.starting;
    _notify();
    _status ??= _source.status.listen(_onStatus);
    _chunks ??= _source.chunks.listen(_onChunk);
    await _source.start(sampleRate: config.initialSampleRate);
  }

  void _onStatus(AudioSurfaceState status) {
    if (_disposed || (!_active && status is! AudioStopped)) return;
    switch (status) {
      case AudioCalibrating(:final route):
        if (!_active) return;
        _clear();
        _route = route;
        phase = route == AudioRoute.speaker
            ? NoteObservationPhase.calibrating
            : NoteObservationPhase.unsupportedInput;
      case AudioPermissionDeniedPermanent():
        _clear();
        _active = false;
        phase = NoteObservationPhase.permissionDeniedPermanent;
      case AudioPermissionDeniedRetriable():
        _clear();
        _active = false;
        phase = NoteObservationPhase.permissionDenied;
      case AudioUnavailable() || AudioSetupFailed():
        _clear();
        _active = false;
        phase = NoteObservationPhase.unavailable;
      case AudioStopped():
        _clear();
        _active = false;
        phase = NoteObservationPhase.idle;
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
      _clear();
      phase = NoteObservationPhase.unavailable;
      _active = false;
      unawaited(_source.stop());
      _notify();
      return;
    }
    if (_rate != null && _rate != chunk.sampleRate) {
      _clear();
      phase = NoteObservationPhase.calibrating;
    }
    _rate = chunk.sampleRate;
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
        _busy ||
        (_lastAnalysisUs != null &&
            chunk.tStartUs - _lastAnalysisUs! <
                config.analysisIntervalMs * 1000)) {
      return;
    }
    _busy = true;
    final token = ++_analysisToken;
    _pendingStale?.cancel();
    _pendingStale = Timer(Duration(milliseconds: config.staleMs), () {
      if (epoch != _epoch || !_active || _disposed || token != _analysisToken) {
        return;
      }
      _analysisToken++;
      observation = null;
      phase = NoteObservationPhase.noResult;
      _notify();
    });
    _lastAnalysisUs = chunk.tStartUs;
    final samples = List<double>.of(_window);
    final startUs =
        chunk.tStartUs +
        ((chunk.samples.length - samples.length) * 1000000 / chunk.sampleRate)
            .round();
    _analyzer(samples, chunk.sampleRate, startUs, _floor!)
        .then(
          (result) {
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
            observation = null;
            phase = NoteObservationPhase.noResult;
            _notify();
          },
        )
        .whenComplete(() {
          samples.fillRange(0, samples.length, 0);
          _busy = false;
        });
  }

  Future<void> stop() async {
    _active = false;
    _clear();
    phase = NoteObservationPhase.idle;
    _notify();
    await _source.stop();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _active = false;
    _clear();
    unawaited(_chunks?.cancel());
    unawaited(_status?.cancel());
    unawaited(_source.stop());
    if (_ownsSource) unawaited((_source as AudioInputController).dispose());
    super.dispose();
  }
}

Future<GuitarNoteObservationResult> _analyzeOffMain(
  List<double> samples,
  int rate,
  int time,
  double floor,
  GuitarObservationConfig config,
) => Isolate.run(
  () => GuitarPitchObserver(
    config: config.pitch,
    guard: config.guard,
  ).observe(samples, sampleRate: rate, tStartUs: time, roomFloorDb: floor),
);
