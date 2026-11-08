import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../audio/practice_audio_lease.dart';
import '../../audio/practice_audio_root.dart';
import 'practice_score.dart';
import 'reference_passage.dart';

/// FK1 "Listen first" (`docs/design/fk1-referans-ses.md`): synthesizes a
/// lesson line off the UI isolate, stages it natively and plays it through a
/// reference-only output grant of the calling route. Playback releases itself
/// when the line has sounded; a route, account or lifecycle change fences it
/// at the audio root like any other lease.
enum ReferenceListenState { idle, preparing, playing, unavailable }

/// The three steps the controller needs from the audio root. Production uses
/// [ReferenceRoutePort.of]; tests use a fake.
abstract interface class ReferencePlaybackPort {
  Future<String?> stage(Float32List samples, int sampleRate);
  Future<PracticeAudioTicket?> open(String assetId);
  Future<void> release(PracticeAudioTicket ticket);
}

/// Sample rate of the synthesized line; the native mixer resamples.
const int kReferenceSampleRate = 44100;

final class ReferenceListenController extends ChangeNotifier {
  ReferenceListenController({
    Future<ReferencePassage> Function(PracticeScore score, int bpm)? render,
  }) : _render = render ?? _renderOffIsolate;

  final Future<ReferencePassage> Function(PracticeScore score, int bpm) _render;

  ReferenceListenState state = ReferenceListenState.idle;

  /// Tempo of the passage being prepared or played.
  int? bpm;

  /// The passage last played; [ReferencePassage.truncated] is shown.
  ReferencePassage? passage;

  /// Which clip [playClip] is preparing or playing (caller-defined).
  Object? tag;

  ReferencePlaybackPort? _port;
  PracticeAudioTicket? _ticket;
  Timer? _ended;
  int _epoch = 0;
  bool _disposed = false;

  bool get busy =>
      state == ReferenceListenState.preparing ||
      state == ReferenceListenState.playing;

  Future<void> play(
    ReferencePlaybackPort? port,
    PracticeScore score,
    int bpm,
  ) => playClip(
    port,
    () async {
      final rendered = await _render(score, bpm);
      passage = rendered;
      return (samples: rendered.samples, sampleRate: rendered.sampleRate);
    },
    bpm: bpm,
  );

  /// F2.6: plays any synthesized clip through the same staged reference path
  /// (drill sounds, "play my answer"). [tag] tells listeners which clip is
  /// sounding.
  Future<void> playClip(
    ReferencePlaybackPort? port,
    Future<({Float32List samples, int sampleRate})> Function() render, {
    int? bpm,
    Object? tag,
  }) async {
    await stop();
    final epoch = ++_epoch;
    this.bpm = bpm;
    this.tag = tag;
    if (port == null) return _set(ReferenceListenState.unavailable);
    _set(ReferenceListenState.preparing);
    try {
      final clip = await render();
      if (epoch != _epoch) return;
      final id = await port.stage(clip.samples, clip.sampleRate);
      if (epoch != _epoch) return;
      final ticket = id == null ? null : await port.open(id);
      if (epoch != _epoch) {
        if (ticket != null) await port.release(ticket);
        return;
      }
      if (ticket == null) return _set(ReferenceListenState.unavailable);
      _port = port;
      _ticket = ticket;
      final duration = Duration(
        microseconds: clip.samples.length * 1000000 ~/ clip.sampleRate,
      );
      // Release a little after the tail so the last note is not cut.
      _ended = Timer(
        duration + const Duration(milliseconds: 300),
        () => unawaited(stop()),
      );
      _set(ReferenceListenState.playing);
    } on Object {
      if (epoch == _epoch) _set(ReferenceListenState.unavailable);
    }
  }

  /// Stops and releases; completes once the release was requested.
  Future<void> stop() async {
    ++_epoch;
    _ended?.cancel();
    _ended = null;
    final port = _port, ticket = _ticket;
    _port = null;
    _ticket = null;
    if (state != ReferenceListenState.unavailable) {
      _set(ReferenceListenState.idle);
    }
    if (port != null && ticket != null) {
      try {
        await port.release(ticket);
      } on Object {
        // The audio root keeps an unconfirmed close sticky on its own.
      }
    }
  }

  void _set(ReferenceListenState next) {
    if (_disposed || state == next) return;
    state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(stop());
    _disposed = true;
    super.dispose();
  }
}

Future<ReferencePassage> _renderOffIsolate(PracticeScore score, int bpm) =>
    Isolate.run(
      () => renderReferencePassage(
        score,
        bpm: bpm,
        sampleRate: kReferenceSampleRate,
      ),
    );

/// The production port: the audio root above [context]'s route.
final class ReferenceRoutePort implements ReferencePlaybackPort {
  ReferenceRoutePort._(this._context, this._owner);

  /// Null outside an Ostinato audio root (tests, web).
  static ReferenceRoutePort? of(BuildContext context) {
    final owner = PracticeAudioCaptureScope.referenceOwnerOf(context);
    return owner == null ? null : ReferenceRoutePort._(context, owner);
  }

  final BuildContext _context;
  final PracticeAudioRootOwner _owner;

  @override
  Future<String?> stage(Float32List samples, int sampleRate) =>
      _owner.stageReference(samples, sampleRate);

  @override
  Future<PracticeAudioTicket?> open(String assetId) async {
    if (!_context.mounted) return null;
    final grant = PracticeAudioCaptureScope.referenceGrantFor(_context);
    if (grant == null) return null;
    final result = await grant.acquire(
      PracticeAudioSide.output,
      assetId: assetId,
    );
    return result.status == AudioRouteAcquireStatus.acquired
        ? result.ticket
        : null;
  }

  @override
  Future<void> release(PracticeAudioTicket ticket) async {
    await _owner.release(ticket);
  }
}
