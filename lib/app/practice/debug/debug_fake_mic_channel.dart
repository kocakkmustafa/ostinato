import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:ostinato_audio/ostinato_audio.dart';

import '../../audio/audio_capture_channel.dart';
import '../../audio/audio_input_controller.dart';
import 'package:permission_handler/permission_handler.dart';

import '../loop/practice_score.dart';

/// DEBUG ONLY — a simulated microphone for the iOS simulator / emulator,
/// where no guitar is plugged in. Reached only through
/// `practice_audio_input.dart` behind `kDebugMode` **and**
/// `--dart-define=OSTINATO_FAKE_MIC=…`; both are compile-time constants, so a
/// profile or release build contains no reference to this file (tree-shaken).
/// It has no user-visible text.
///
/// What it does, on the same timeline as the metronome:
/// - emits PCM chunks on a timer, stamped from a sample counter (continuous
///   capture clock), with a low noise floor;
/// - answers `startMetronome` with an anchor and plays the clicks back into
///   the "microphone" [roundTripUs] later (so the E50 calibration measures
///   it), with a weaker room reflection;
/// - with a [FakeMicPerformance], plucks the lesson's notes (synthesized
///   string, never a recording) on the heard beats; [FakeMicMode.mixed]
///   deliberately plays some different notes and leaves some silent so all
///   three marks appear;
/// - without a performance (setup wizard, tuner) it plucks an in-tune open
///   string every 3 s after the first 3 s, so the room/level step and the
///   tuner have something to hear.
///
/// Limits: "Wait for me" and runs without the click are not followed (the
/// performer plays to the click grid only).
enum FakeMicMode {
  /// Every note as written (a gate pass is possible).
  clean,

  /// Note `i % 8 == 2` a whole tone up (different note), `i % 8 == 5` not
  /// played (couldn't hear), the rest as written.
  mixed,
}

/// What the simulated player plays once the click stream starts.
final class FakeMicPerformance {
  const FakeMicPerformance({
    required this.score,
    required this.countInBeats,
    this.loop,
  });

  final PracticeScore score;
  final int countInBeats;
  final ({double start, double end})? loop;
}

final class DebugFakeMicChannel
    implements
        AudioCaptureChannel,
        AudioCuePlaybackChannel,
        AudioMetronomeChannel,
        AudioCaptureCloseControl {
  DebugFakeMicChannel({
    this.mode = FakeMicMode.mixed,
    this.performance,
    this.routeTag = 'ios:BuiltInMic',
    this.roundTripUs = 70000,
    this.reportedOutputLatencyUs = 12000,
    this.chunkMs = 10,
    int Function()? clockUs,
    this.autoPump = true,
  }) : _clockUs = clockUs ?? _stopwatchUs;

  final FakeMicMode mode;

  /// Read when the click stream starts (the screen's current lesson, count
  /// in and loop). Null: idle plucks only.
  final FakeMicPerformance? Function()? performance;
  final String routeTag;

  /// Simulated speaker → room → microphone delay of the click stream.
  final int roundTripUs;

  /// What the "native" anchor claims as output latency (the rest is what
  /// calibration has to find).
  final int reportedOutputLatencyUs;
  final int chunkMs;

  static final Stopwatch _clock = Stopwatch()..start();
  static int _stopwatchUs() => _clock.elapsedMicroseconds;
  final int Function() _clockUs;

  /// Tests drive time themselves ([pumpNow]) instead of a periodic timer.
  final bool autoPump;

  final _events = StreamController<RawAudioEvent>.broadcast();
  final _rng = math.Random(7);
  final List<_Voice> _voices = [];
  Timer? _timer;
  bool _running = false;
  String? _attemptId, _lastClosedAttemptId;
  int _nextAttempt = 0;
  AudioSessionMode? _sessionMode;
  int _rate = 48000;
  int _t0Us = 0;
  int _cursor = 0;
  int _playbackUntil = -1;

  // Click stream.
  MetronomeStreamRequest? _metronome;
  int _anchorSample = 0;
  int _nextClickBeat = 0;
  List<_Note> _notes = const [];
  int _nextNote = 0;
  int _nextIdlePluck = 0;
  int _idleString = 0;

  @override
  Stream<RawAudioEvent> get events => _events.stream;

  @override
  String? get attemptId => _attemptId;

  @override
  Future<AudioCaptureCloseState> readCloseState() async => _running
      ? AudioCaptureCloseState(
          phase: AudioCaptureClosePhase.running,
          attemptId: _attemptId,
          attemptInFlight: false,
          resourcesReleased: false,
          requiresExplicitRetry: false,
        )
      : const AudioCaptureCloseState.clear();

  @override
  Future<void> start({required int sampleRate}) =>
      _start(sampleRate, AudioSessionMode.recordOnly);

  @override
  Future<void> startPlayAndRecord({
    required int sampleRate,
    AudioCaptureContextClaim? claim,
  }) => _start(sampleRate, AudioSessionMode.playAndRecord);

  Future<void> _start(int sampleRate, AudioSessionMode mode) async {
    if (sampleRate != 44100 && sampleRate != 48000) {
      throw PlatformException(code: 'unsupported_sample_rate');
    }
    _attemptId = 'debug-fake-mic-${++_nextAttempt}';
    _sessionMode = mode;
    _rate = sampleRate;
    _running = true;
    _t0Us = _clockUs();
    _cursor = 0;
    _voices.clear();
    _metronome = null;
    _notes = const [];
    _playbackUntil = -1;
    _nextIdlePluck = 3 * sampleRate;
    _idleString = 0;
    // After start returns, like the native route report.
    Timer.run(() {
      if (_running) _events.add(RawRouteChangedEvent(routeTag));
    });
    if (autoPump) {
      _timer = Timer.periodic(Duration(milliseconds: chunkMs), (_) => _pump());
    }
  }

  int _usOf(int sample) => _t0Us + (sample * 1e6 / _rate).round();

  /// Emits every chunk that is due by the clock (tests).
  @visibleForTesting
  void pumpNow() => _pump();

  void _pump() {
    if (!_running) return;
    final due = ((_clockUs() - _t0Us) * _rate / 1e6).floor();
    final size = _rate * chunkMs ~/ 1000;
    var guard = 0;
    while (_running && _cursor + size <= due && guard++ < 50) {
      final from = _cursor;
      _schedule(from + size + _rate);
      final pcm = Float64List(size);
      for (var i = 0; i < size; i++) {
        pcm[i] = (_rng.nextDouble() * 2 - 1) * .002;
      }
      for (final v in _voices) {
        v.mixInto(pcm, from);
      }
      _voices.removeWhere((v) => v.endSample <= from + size);
      for (var i = 0; i < size; i++) {
        pcm[i] = pcm[i].clamp(-1.0, 1.0);
      }
      _cursor += size;
      _events.add(
        RawAudioChunkEvent(
          samples: pcm,
          sampleRate: _rate,
          tNativeUs: _usOf(from),
          playbackActive:
              _sessionMode == AudioSessionMode.playAndRecord &&
              from <= _playbackUntil,
        ),
      );
    }
  }

  /// Adds every sound that starts before [horizon] (samples).
  void _schedule(int horizon) {
    final lag = (roundTripUs * _rate / 1e6).round();
    final m = _metronome;
    if (m != null) {
      while (true) {
        final at = _anchorSample + _nextClickBeat * m.framesPerBeat + lag;
        if (at >= horizon) break;
        final click = _nextClickBeat % m.beatsPerBar == 0 ? m.accent : m.beat;
        _voices
          ..add(_Voice(at, click, .3))
          // A weaker reflection 9 ms later (the first-arrival rule's case).
          ..add(_Voice(at + (.009 * _rate).round(), click, .1));
        _nextClickBeat++;
      }
      while (_nextNote < _notes.length) {
        final n = _notes[_nextNote];
        final at = _anchorSample + (n.beat * m.framesPerBeat).round() + lag;
        if (at >= horizon) break;
        _nextNote++;
        if (n.midi == null) continue;
        _voices.add(
          _Voice(
            at + (n.offsetMs * _rate / 1000).round(),
            _pluck(
              n.midi!,
              seed: _nextNote,
              seconds: n.beats * m.framesPerBeat / _rate,
            ),
            1,
          ),
        );
      }
      return;
    }
    if (performance != null) return;
    // Idle: open strings in turn, in tune (room step, tuner).
    const open = [40, 45, 50, 55, 59, 64];
    while (_nextIdlePluck < horizon) {
      _voices.add(
        _Voice(_nextIdlePluck, _pluck(open[_idleString % 6], seed: 3), 1),
      );
      _idleString++;
      _nextIdlePluck += 3 * _rate;
    }
  }

  /// A plucked string the player damps when the next note starts: it fades
  /// over the last 100 ms (a hard cut would itself read as an attack).
  Float64List _pluck(int midi, {required int seed, double seconds = 2.5}) {
    final p = SyntheticString.pluck(
      f0Hz: 440 * math.pow(2, (midi - 69) / 12).toDouble(),
      sampleRate: _rate,
      seconds: seconds.clamp(.3, 2.5),
      seed: seed,
    );
    final fade = (_rate * .1).round();
    for (var i = 0; i < fade; i++) {
      p[p.length - 1 - i] *= i / fade;
    }
    return p;
  }

  List<_Note> _plan(FakeMicPerformance p) {
    final events = p.score.events;
    final loop = p.loop;
    final start = loop?.start ?? 0;
    final end = loop?.end ?? p.score.totalBeats;
    final passes = loop == null ? 1 : 40;
    final out = <_Note>[];
    for (var pass = 0; pass < passes; pass++) {
      for (final e in events) {
        if (e.startBeat < start || e.startBeat >= end) continue;
        final i = e.index;
        final expected = e.midi ?? 40; // rhythm notes: any clear pluck
        int? midi = expected;
        if (mode == FakeMicMode.mixed) {
          if (i % 8 == 2) midi = expected + 2;
          if (i % 8 == 5) midi = null;
        }
        final next = e.index + 1 < events.length
            ? events[e.index + 1].startBeat
            : e.startBeat + e.durationBeats;
        out.add(
          _Note(
            beat: p.countInBeats + pass * (end - start) + e.startBeat - start,
            beats: math.max(e.durationBeats, next - e.startBeat),
            midi: midi,
            // A human spread around the heard click: −8 … +12 ms.
            offsetMs: mode == FakeMicMode.clean ? 4 : (i * 7) % 21 - 8,
          ),
        );
      }
    }
    return out;
  }

  @override
  Future<void> playCue(Float64List samples, {required int sampleRate}) async {
    if (!_running) throw PlatformException(code: 'playback_unavailable');
    if (_sessionMode != AudioSessionMode.playAndRecord) {
      throw PlatformException(code: 'playback_not_enabled');
    }
    if (sampleRate != _rate || !isValidCuePcm(samples, sampleRate)) {
      throw PlatformException(code: 'bad_args');
    }
    final at = _cursor + (.02 * _rate).round();
    _voices.add(_Voice(at, Float64List.fromList(samples), .25));
    _playbackUntil = at + samples.length + (.3 * _rate).round();
  }

  @override
  Future<void> startMetronome(MetronomeStreamRequest request) async {
    if (!_running) throw PlatformException(code: 'playback_unavailable');
    if (_sessionMode != AudioSessionMode.playAndRecord) {
      throw PlatformException(code: 'playback_not_enabled');
    }
    if (request.sampleRate != _rate || !request.isValid) {
      throw PlatformException(code: 'bad_args');
    }
    final now = ((_clockUs() - _t0Us) * _rate / 1e6).floor();
    _metronome = request;
    _anchorSample = math.max(now, _cursor) + request.leadInMs * _rate ~/ 1000;
    _nextClickBeat = 0;
    final p = performance?.call();
    _notes = p == null ? const [] : _plan(p);
    _nextNote = 0;
    final anchorUs = _usOf(_anchorSample);
    final attempt = _attemptId;
    Timer(Duration(milliseconds: autoPump ? 40 : 0), () {
      if (!_running || _attemptId != attempt || _metronome != request) return;
      _events.add(
        RawMetronomeAnchorEvent(
          anchorUs: anchorUs,
          sampleRate: request.sampleRate,
          framesPerBeat: request.framesPerBeat,
          outputLatencyUs: reportedOutputLatencyUs,
        ),
      );
    });
  }

  @override
  Future<void> stopMetronome() async {
    _metronome = null;
    _notes = const [];
    _voices.clear();
  }

  @override
  Future<void> stop() async {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _metronome = null;
    _voices.clear();
    _lastClosedAttemptId = _attemptId ?? _lastClosedAttemptId;
    _attemptId = null;
  }

  @override
  Future<void> stopAttempt(String id) async {
    if (_attemptId != id && _lastClosedAttemptId != id) {
      throw PlatformException(code: 'stale_capture_attempt');
    }
    await stop();
  }

  @override
  Future<void> retryStopAttempt(String id) => stopAttempt(id);
}

final class _Note {
  const _Note({
    required this.beat,
    required this.beats,
    required this.midi,
    required this.offsetMs,
  });
  final double beat;

  /// Until the next note (the string is damped then).
  final double beats;
  final int? midi;
  final int offsetMs;
}

final class _Voice {
  _Voice(this.startSample, this.pcm, this.gain);
  final int startSample;
  final Float64List pcm;
  final double gain;

  int get endSample => startSample + pcm.length;

  void mixInto(Float64List out, int outStart) {
    final from = math.max(startSample, outStart);
    final to = math.min(endSample, outStart + out.length);
    for (var t = from; t < to; t++) {
      out[t - outStart] += gain * pcm[t - startSample];
    }
  }
}

/// A capture controller on the fake channel. Permission is not requested:
/// the simulated input needs no microphone.
AudioInputController debugFakeMicInput({
  required FakeMicMode mode,
  FakeMicPerformance? Function()? performance,
}) => AudioInputController(
  channel: DebugFakeMicChannel(mode: mode, performance: performance),
  requestMicrophonePermission: () async => PermissionStatus.granted,
);
