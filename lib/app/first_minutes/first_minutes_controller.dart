import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../audio/mic_permission_gate.dart';
import '../drill/drill_sound.dart';
import '../practice/loop/reference_listen.dart';
import 'rhythm_tap_analysis.dart';

/// OST-P0-05 state machine: choose -> (voice) -> rhythm -> variation -> summary.
enum FirstMinutesStage { choose, voice, rhythm, variation, summary }

enum VoiceOutcome { none, granted, denied, permanent }

const int kFirstMinutesBpm = 80;
const int kFirstMinutesSampleRate = 44100;

/// The clip is two bars of four: one to listen to, one to tap along with.
const int kClipBeats = 8;
const int kListenBeats = 4;

/// Beats (of the clip) the learner is asked to tap: try 1 taps all four,
/// try 2 (the variation) leaves the third one empty.
const List<List<int>> kRoundBeats = <List<int>>[
  <int>[4, 5, 6, 7],
  <int>[4, 5, 7],
];

const double _beatSeconds = 60 / kFirstMinutesBpm;

/// Simple drum + metronome loop: a click on every beat (accent on 1) and a
/// low thump on 1 and 3. Synthesized in memory, same path as drill sounds.
Float32List renderRhythmLoop() => renderDrillSound(
  DrillSound(<DrillNote>[
    for (var i = 0; i < kClipBeats; i++) ...<DrillNote>[
      DrillNote(
        at: i * _beatSeconds,
        midi: 60,
        seconds: 0.05,
        gain: i % 4 == 0 ? 1 : 0.6,
        timbre: DrillTimbre.click,
      ),
      if (i % 2 == 0)
        DrillNote(at: i * _beatSeconds, midi: 36, seconds: 0.3, gain: 0.8),
    ],
  ]),
  sampleRate: kFirstMinutesSampleRate,
);

/// What a try sounded like: the beat plus a note at each tap, from memory.
Float32List renderTake(List<int> tapsFromBarStartUs) {
  const lead = 0.2;
  return renderDrillSound(
    DrillSound(<DrillNote>[
      for (var i = 0; i < kListenBeats; i++)
        DrillNote(
          at: lead + i * _beatSeconds,
          midi: 60,
          seconds: 0.05,
          gain: i == 0 ? 1 : 0.6,
          timbre: DrillTimbre.click,
        ),
      for (final t in tapsFromBarStartUs)
        if (t / 1e6 + lead >= 0 && t / 1e6 < kListenBeats * _beatSeconds + 0.2)
          DrillNote(at: t / 1e6 + lead, midi: 67, seconds: 0.25, gain: 0.9),
    ]),
    sampleRate: kFirstMinutesSampleRate,
  );
}

final class FirstMinutesController extends ChangeNotifier {
  FirstMinutesController({
    int Function()? nowUs,
    ReferenceListenController? listen,
  }) : _nowUs = nowUs ?? _stopwatchUs,
       _listen = listen ?? ReferenceListenController() {
    _listen.addListener(_onListen);
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  static final Stopwatch _clock = Stopwatch()..start();
  static int _stopwatchUs() => _clock.elapsedMicroseconds;

  final int Function() _nowUs;
  final ReferenceListenController _listen;

  FirstMinutesStage stage = FirstMinutesStage.choose;
  VoiceOutcome voiceOutcome = VoiceOutcome.none;
  bool voiceBusy = false;

  /// 0 = try 1, 1 = the variation.
  int round = 0;
  bool roundActive = false;
  bool beatUnavailable = false;

  /// Tap times (device clock) of the round in progress. Memory only.
  final List<int> _taps = <int>[];
  int? _clipStartUs;
  bool _wasPlaying = false;
  final List<TapMeasurement?> results = <TapMeasurement?>[null, null];
  final List<List<int>> _takes = <List<int>>[<int>[], <int>[]];

  Object? get playingTag => _listen.busy ? _listen.tag : null;
  bool get playing => _listen.state == ReferenceListenState.playing;
  int get tapCount => _taps.length;
  int get expectedTaps => kRoundBeats[round].length;

  static const int _beatUs = 60 * 1000000 ~/ kFirstMinutesBpm;

  List<int> _beatTimes() {
    final start = _clipStartUs ?? 0;
    return [for (final b in kRoundBeats[round]) start + b * _beatUs];
  }

  /// Per expected beat, the deviation of the taps so far (null = no tap).
  List<double?> get liveDeviations => _clipStartUs == null
      ? List<double?>.filled(expectedTaps, null)
      : measureTaps(tapTimesUs: _taps, beatTimesUs: _beatTimes()).deviationsMs;

  void _set(FirstMinutesStage s) {
    stage = s;
    notifyListeners();
  }

  void chooseTap() {
    round = 0;
    beatUnavailable = false;
    _set(FirstMinutesStage.rhythm);
  }

  void chooseVoice() {
    voiceOutcome = VoiceOutcome.none;
    _set(FirstMinutesStage.voice);
  }

  Future<void> backToChoice() async {
    roundActive = false;
    await _listen.stop();
    beatUnavailable = false;
    _set(FirstMinutesStage.choose);
  }

  /// Asked only on the voice path, at the moment of use. A denial is a
  /// normal answer, never an error.
  Future<void> requestVoice() async {
    if (voiceBusy) return;
    voiceBusy = true;
    notifyListeners();
    try {
      var status = await MicPermissionGate.status();
      if (!status.isGranted &&
          !status.isPermanentlyDenied &&
          !status.isRestricted) {
        status = await MicPermissionGate.request();
      }
      voiceOutcome = status.isGranted
          ? VoiceOutcome.granted
          : (status.isPermanentlyDenied || status.isRestricted)
          ? VoiceOutcome.permanent
          : VoiceOutcome.denied;
    } on Object {
      voiceOutcome = VoiceOutcome.denied;
    } finally {
      voiceBusy = false;
      notifyListeners();
    }
  }

  Future<void> startRound(ReferencePlaybackPort? port) async {
    _taps.clear();
    _clipStartUs = null;
    _wasPlaying = false;
    beatUnavailable = false;
    results[round] = null;
    roundActive = true;
    notifyListeners();
    await _listen.playClip(
      port,
      () async =>
          (samples: renderRhythmLoop(), sampleRate: kFirstMinutesSampleRate),
      bpm: kFirstMinutesBpm,
      tag: 'round',
    );
  }

  void tap() {
    if (!roundActive || !playing || _clipStartUs == null) return;
    _taps.add(_nowUs());
    notifyListeners();
  }

  void _onListen() {
    final state = _listen.state;
    if (roundActive) {
      if (state == ReferenceListenState.playing && !_wasPlaying) {
        _wasPlaying = true;
        _clipStartUs = _nowUs();
      } else if (state == ReferenceListenState.unavailable) {
        roundActive = false;
        beatUnavailable = true;
      } else if (state == ReferenceListenState.idle && _wasPlaying) {
        _finishRound();
        return;
      }
    }
    notifyListeners();
  }

  void _finishRound() {
    roundActive = false;
    final m = measureTaps(tapTimesUs: _taps, beatTimesUs: _beatTimes());
    results[round] = m;
    final barStart = (_clipStartUs ?? 0) + kListenBeats * _beatUs;
    _takes[round] = [for (final t in _taps) t - barStart];
    _taps.clear();
    stage = round == 0
        ? FirstMinutesStage.variation
        : FirstMinutesStage.summary;
    notifyListeners();
  }

  void startVariation() {
    round = 1;
    beatUnavailable = false;
    _set(FirstMinutesStage.rhythm);
  }

  Future<void> playTake(int index, ReferencePlaybackPort? port) async {
    final taps = List<int>.of(_takes[index]);
    await _listen.playClip(
      port,
      () async =>
          (samples: renderTake(taps), sampleRate: kFirstMinutesSampleRate),
      tag: 'take$index',
    );
  }

  Future<void> stopPlayback() => _listen.stop();

  @override
  void dispose() {
    _disposed = true;
    _listen.removeListener(_onListen);
    _listen.dispose();
    super.dispose();
  }
}
