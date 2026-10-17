import 'dart:async';

import 'hand_source.dart';
import 'piano_hand_observer.dart';

/// Subscription/lifecycle bridge. The production factory accepts no replay
/// flag or injectable fixture. A real source needs a deliberate code update.
final class PianoHandSession {
  PianoHandSession.connect({
    required HandSource source,
    required this.observer,
    required this.targetMidi,
  }) : _source = source;
  factory PianoHandSession.production({required int targetMidi}) {
    final source = createProductionHandSource();
    return PianoHandSession.connect(
      source: source,
      targetMidi: targetMidi,
      observer: PianoHandObserver(
        provider: source.identity,
        expectedMode: HandEvidenceMode.production,
      ),
    );
  }
  final HandSource _source;
  final PianoHandObserver observer;
  final int targetMidi;
  final _observations = StreamController<PianoHandObservation>.broadcast();
  Stream<PianoHandObservation> get observations => _observations.stream;
  StreamSubscription<HandFrame>? _frames;
  StreamSubscription<HandSourceStatus>? _status;
  PianoAudioOnset? _latestAudio;
  bool _active = false, _retired = false, _disposed = false;
  Future<void>? _closing, _opening;
  void offerAudio(PianoAudioOnset event) {
    if (_active) _latestAudio = event;
  }

  Future<void> start() async {
    if (_retired || _disposed || _active) return;
    _active = true;
    if (!_source.identity.sameAs(observer.provider) ||
        _source.identity.mode != observer.expectedMode ||
        _source.identity.mode == HandEvidenceMode.unavailable) {
      _fault();
      return;
    }
    _frames = _source.frames.listen(
      (frame) {
        if (!_active || _disposed) return;
        _observations.add(
          observer.observe(frame, targetMidi: targetMidi, audio: _latestAudio),
        );
      },
      onError: (Object _) {
        _fault();
      },
    );
    _status = _source.status.listen(
      (state) {
        if (!_active || _disposed) return;
        if (state == HandSourceStatus.unsupported ||
            state == HandSourceStatus.unavailable ||
            state == HandSourceStatus.stopped) {
          _fault();
        }
      },
      onError: (Object _) {
        _fault();
      },
    );
    try {
      _opening = Future<void>.sync(_source.start);
      await _opening;
    } on Object {
      _fault();
    }
  }

  void _fault() {
    if (!_active || _disposed) return;
    _observations.add(
      PianoHandObservation(
        PianoHandState.unsupported,
        PianoHandReason.providerUnavailable,
        _source.identity.mode,
      ),
    );
    unawaited(stop().catchError((Object _) {}));
  }

  /// Call on route exit, account/background/model/calibration change. This
  /// session is retired, so a resume cannot silently reopen it.
  Future<void> stop() {
    _active = false;
    _retired = true;
    _latestAudio = null;
    observer.invalidate();
    return _closing ??= _finishStop();
  }

  Future<void> _finishStop() async {
    final frames = _frames, status = _status;
    _frames = null;
    _status = null;
    await Future.wait<void>([
      if (frames != null) frames.cancel(),
      if (status != null) status.cancel(),
      _source.stop(),
    ]);
    // Direct stop happens first; a pending start must also settle before this
    // bridge closes. Real sources must implement cancellation/owned release;
    // this software barrier does not attest physical camera release.
    await _opening?.catchError((Object _) {});
    await _source.stop();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await stop();
    } finally {
      try {
        await _source.dispose();
      } finally {
        await _observations.close();
      }
    }
  }
}
