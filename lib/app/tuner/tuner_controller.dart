import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:ostinato_audio/ostinato_audio.dart';

import '../audio/audio_continuity.dart';
import '../audio/audio_input_controller.dart';
import '../audio/practice_audio_root.dart';
import 'tuner_analysis.dart';
import 'tuner_check_memory.dart';
import 'tuner_guidance.dart';
import 'tunings.dart';

enum TunerPhase {
  idle,
  starting,
  calibrating,
  listening,
  permissionDenied,
  permissionDeniedPermanent,
  unsupportedInput,
  unavailable,
}

typedef TunerAnalyzer =
    Future<TunerAnalysis> Function(
      List<double> samples,
      int sampleRate,
      double roomFloorDb,
      PreciseTunerProfile profile,
    );

/// One point of the pitch trace: seconds before now and signed cents.
typedef TracePoint = ({int tUs, double cents});

/// Live tuner. PCM lives only in bounded RAM and is zeroed when dropped;
/// nothing is recorded, persisted or sent. Separate from the session tuning
/// gate in `GuitarNoteObservationController`, which is unchanged.
final class TunerController extends ChangeNotifier {
  TunerController({
    TuningPreset preset = TuningPresets.guitarStandard,
    AudioSource? source,
    TunerAnalyzer? analyzer,
    this.a4Hz = 440,
    this.toleranceCents = kDefaultTunerToleranceCents,
    TunerCheckMemory? memory,
  }) : _preset = preset,
       _session = TunerSessionState(preset),
       _source = source ?? AudioInputController(),
       _ownsSource = source == null,
       _analyzer = analyzer ?? _analyzeOffMain,
       _memory = memory ?? TunerCheckMemory.instance {
    if (_source is AudioInputController) {
      unawaited(_source.refreshCloseState().then((_) => _notify()));
    }
  }

  static const int sampleRate = 44100;
  static const Set<int> supportedSampleRates = {44100, 48000};
  static const int calibrationMs = 1000;
  static const int analysisIntervalMs = 250;
  static const int staleMs = 2500;
  static const int traceMs = 3000;

  final double a4Hz;
  final double toleranceCents;
  final AudioSource _source;
  final bool _ownsSource;
  final TunerAnalyzer _analyzer;
  final TunerCheckMemory _memory;

  TuningPreset _preset;
  TunerSessionState _session;
  TunerMode _mode = TunerMode.auto;

  TunerPhase phase = TunerPhase.idle;
  TunerReadout readout = const TunerReadout.listening();
  final List<TracePoint> _trace = [];

  StreamSubscription<AudioChunk>? _chunks;
  StreamSubscription<AudioSurfaceState>? _status;
  final List<double> _buffer = [];
  final List<double> _floorLevels = [];
  final _continuity = AudioContinuity();
  int _calibrationSamples = 0;
  double? _floor;
  int? _lastAnalysisUs, _lastReadingUs, _latestUs;
  bool _jobRunning = false, _active = false, _disposed = false;
  int _epoch = 0;

  TuningPreset get preset => _preset;
  TunerMode get mode => _mode;
  TunerSessionState get session => _session;
  List<TracePoint> get trace => List.unmodifiable(_trace);
  int? get latestUs => _latestUs;
  bool get isActive => _active;

  bool get captureGateReady {
    final source = _source;
    return source is! AudioInputController || source.captureGateReady;
  }

  bool get canStart => !_disposed && !_active && !_jobRunning && captureGateReady;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setPreset(TuningPreset preset) {
    if (identical(preset, _preset)) return;
    final instrumentChanged = preset.instrument != _preset.instrument;
    _preset = preset;
    _session = TunerSessionState(preset);
    if (instrumentChanged) _clearBuffer();
    _resetReadout();
    _notify();
  }

  void setMode(TunerMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    _resetReadout();
    _notify();
  }

  /// Manual mode target, or the answer to "which string are you playing?".
  void selectString(int index) {
    _session.select(index);
    if (_mode == TunerMode.auto) _mode = TunerMode.manual;
    _resetReadout();
    _notify();
  }

  void _resetReadout() {
    readout = const TunerReadout.listening();
    _trace.clear();
  }

  void _clearBuffer() {
    _epoch++;
    _buffer
      ..fillRange(0, _buffer.length, 0)
      ..clear();
    _lastAnalysisUs = null;
  }

  void _clearAll() {
    _clearBuffer();
    _floorLevels.clear();
    _floor = null;
    _calibrationSamples = 0;
    _continuity.reset();
    _lastReadingUs = null;
    _resetReadout();
  }

  Future<void> start({PracticeAudioCaptureAction? captureAction}) async {
    if (!canStart) {
      captureAction?.retire();
      return;
    }
    _clearAll();
    _active = true;
    phase = TunerPhase.starting;
    _notify();
    _status ??= _source.status.listen(_onStatus);
    _chunks ??= _source.chunks.listen(_onChunk);
    final source = _source;
    if (source is AudioInputController) {
      await source.start(sampleRate: sampleRate, captureAction: captureAction);
    } else {
      captureAction?.retire();
      await source.start(sampleRate: sampleRate);
    }
  }

  Future<void> stop() async {
    _active = false;
    _clearAll();
    phase = TunerPhase.idle;
    _notify();
    try {
      await _source.stop();
    } on Object {
      phase = TunerPhase.unavailable;
      _notify();
    }
  }

  void _close(TunerPhase terminal) {
    _active = false;
    _clearAll();
    phase = terminal;
    unawaited(_source.stop().catchError((Object _) {}));
  }

  void _onStatus(AudioSurfaceState status) {
    if (_disposed || (!_active && status is! AudioStopped)) return;
    switch (status) {
      case AudioCalibrating(:final route):
        _clearAll();
        if (route != AudioRoute.speaker) {
          _close(TunerPhase.unsupportedInput);
        } else {
          phase = TunerPhase.calibrating;
        }
      case AudioPermissionDeniedPermanent():
        _active = false;
        _clearAll();
        phase = TunerPhase.permissionDeniedPermanent;
      case AudioPermissionDeniedRetriable():
        _active = false;
        _clearAll();
        phase = TunerPhase.permissionDenied;
      case AudioUnavailable() || AudioSetupFailed():
        _close(TunerPhase.unavailable);
      case AudioStopped():
        _active = false;
        _clearAll();
        if (phase != TunerPhase.unavailable &&
            phase != TunerPhase.unsupportedInput) {
          phase = TunerPhase.idle;
        }
      case AudioStarting():
        phase = TunerPhase.starting;
      case AudioStreaming():
        break;
    }
    _notify();
  }

  void _onChunk(AudioChunk chunk) {
    if (!_active || _disposed || phase == TunerPhase.unsupportedInput) return;
    if (!supportedSampleRates.contains(chunk.sampleRate) ||
        chunk.samples.isEmpty ||
        chunk.clockDomain != AudioClockDomain.monotonic ||
        chunk.samples.any((v) => !v.isFinite || v.abs() > 1)) {
      _close(TunerPhase.unavailable);
      _notify();
      return;
    }
    final continuity = _continuity.observe(
      startUs: chunk.tStartUs,
      sampleRate: chunk.sampleRate,
      sampleCount: chunk.samples.length,
    );
    if (continuity == AudioContinuityResult.invalid) {
      _close(TunerPhase.unavailable);
      _notify();
      return;
    }
    if (continuity == AudioContinuityResult.recalibrate) {
      _clearAll();
      phase = TunerPhase.calibrating;
      _continuity.observe(
        startUs: chunk.tStartUs,
        sampleRate: chunk.sampleRate,
        sampleCount: chunk.samples.length,
      );
    }
    final endUs =
        chunk.tStartUs +
        (chunk.samples.length * 1000000 / chunk.sampleRate).round();
    _latestUs = endUs;
    if (_floor == null) {
      final rms = math.sqrt(
        chunk.samples.fold<double>(0, (a, v) => a + v * v) /
            chunk.samples.length,
      );
      _floorLevels.add(20 * math.log(math.max(rms, 1e-9)) / math.ln10);
      _calibrationSamples += chunk.samples.length;
      if (_calibrationSamples >= chunk.sampleRate * calibrationMs / 1000) {
        _floorLevels.sort();
        _floor = _floorLevels[_floorLevels.length ~/ 2];
        _floorLevels.clear();
        phase = TunerPhase.listening;
        _notify();
      }
      return;
    }
    _buffer.addAll(chunk.samples);
    final limit =
        (tunerBufferMs(_preset.instrument.profile) * chunk.sampleRate / 1000)
            .round();
    if (_buffer.length > limit) {
      final drop = _buffer.length - limit;
      _buffer
        ..fillRange(0, drop, 0)
        ..removeRange(0, drop);
    }
    if (_lastReadingUs != null &&
        endUs - _lastReadingUs! > staleMs * 1000 &&
        readout.kind != TunerReadoutKind.listening) {
      _lastReadingUs = null;
      readout = const TunerReadout.listening();
      _notify();
    }
    if (_buffer.length < limit ~/ 2 ||
        _jobRunning ||
        (_lastAnalysisUs != null &&
            endUs - _lastAnalysisUs! < analysisIntervalMs * 1000)) {
      return;
    }
    _lastAnalysisUs = endUs;
    _jobRunning = true;
    final epoch = _epoch;
    final samples = List<double>.of(_buffer);
    final preset = _preset;
    _analyzer(samples, chunk.sampleRate, _floor!, preset.instrument.profile)
        .then(
          (analysis) {
            if (_disposed || !_active || epoch != _epoch) return;
            _apply(analysis, endUs);
          },
          onError: (Object _) {
            if (_disposed || !_active || epoch != _epoch) return;
            _close(TunerPhase.unavailable);
            _notify();
          },
        )
        .whenComplete(() {
          samples.fillRange(0, samples.length, 0);
          _jobRunning = false;
        });
  }

  void _apply(TunerAnalysis analysis, int atUs) {
    final next = guideTuner(
      mode: _mode,
      preset: _preset,
      reading: analysis.reading,
      refusal: analysis.refusal,
      selectedString: _session.focus,
      a4Hz: a4Hz,
      toleranceCents: toleranceCents,
    );
    // A pluck that is still waiting for its attack keeps the last readout.
    if (next.kind == TunerReadoutKind.listening) return;
    readout = next;
    _lastReadingUs = atUs;
    if (_session.apply(next) || next.stringIndex != null) {
      _memory.record(
        presetId: _preset.id,
        inTune: _session.inTuneCount,
        total: _preset.stringCount,
      );
    }
    final cents = next.cents;
    if (cents != null) _trace.add((tUs: atUs, cents: cents));
    _trace.removeWhere((p) => atUs - p.tUs > traceMs * 1000);
    _notify();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _active = false;
    _clearAll();
    unawaited(_chunks?.cancel());
    unawaited(_status?.cancel());
    unawaited(_source.stop().catchError((Object _) {}));
    if (_ownsSource) unawaited((_source as AudioInputController).dispose());
    super.dispose();
  }
}

Future<TunerAnalysis> _analyzeOffMain(
  List<double> samples,
  int sampleRate,
  double roomFloorDb,
  PreciseTunerProfile profile,
) => Isolate.run(
  () => analyzeTunerBuffer(
    samples,
    sampleRate: sampleRate,
    profile: profile,
    roomFloorDb: roomFloorDb,
  ),
);
