import 'dart:math' as math;

import 'hand_source.dart';

enum PianoFinger { thumb, indexFinger, middle, ring, little }

enum PianoHandState {
  unsupported,
  calibrationRequired,
  unobservable,
  hover,
  contactCandidate,
}

enum PianoHandReason {
  providerUnavailable,
  replayOnly,
  unsupportedTask,
  missingKeyboardMap,
  incompatibleKeyboardMap,
  invalidHandFrame,
  wrongHand,
  lowVisibility,
  outsideKeyboard,
  ambiguousKey,
  wrongKey,
  noAudioOnset,
  missingClockCalibration,
  clockChanged,
  calibrationExpired,
  clockDiscontinuity,
  audioMismatch,
  audioAlreadyUsed,
  projectedFingerAndIndependentOnset,
}

final class KeyboardPoint {
  const KeyboardPoint(this.x, this.y);
  final double x, y;
  bool get valid =>
      x.isFinite && y.isFinite && x >= 0 && x <= 1 && y >= 0 && y <= 1;
}

/// Four convex image-plane corners. Adjacent borders are ambiguous at the
/// exact boundary, never silently assigned to the target note.
final class PianoKeyRegion {
  PianoKeyRegion({required this.midi, required List<KeyboardPoint> corners})
    : corners = List.unmodifiable(corners);
  final int midi;
  final List<KeyboardPoint> corners;
  static const _epsilon = 1e-9;
  static double _cross(KeyboardPoint a, KeyboardPoint b, KeyboardPoint c) =>
      (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
  bool get valid {
    if (corners.length != 4 || corners.any((p) => !p.valid)) return false;
    final turns = [
      for (var i = 0; i < 4; i++)
        _cross(corners[i], corners[(i + 1) % 4], corners[(i + 2) % 4]),
    ];
    return turns.every((v) => v > _epsilon) ||
        turns.every((v) => v < -_epsilon);
  }

  bool contains(HandPoint point) {
    final p = KeyboardPoint(point.x, point.y);
    final turns = [
      for (var i = 0; i < 4; i++) _cross(corners[i], corners[(i + 1) % 4], p),
    ];
    return turns.every((v) => v >= -_epsilon) ||
        turns.every((v) => v <= _epsilon);
  }

  bool overlapsInterior(PianoKeyRegion other) {
    for (final polygon in [corners, other.corners]) {
      for (var i = 0; i < 4; i++) {
        final a = polygon[i], b = polygon[(i + 1) % 4];
        final nx = -(b.y - a.y), ny = b.x - a.x;
        final p = corners.map((v) => v.x * nx + v.y * ny);
        final q = other.corners.map((v) => v.x * nx + v.y * ny);
        if (p.reduce(math.max) <= q.reduce(math.min) + _epsilon ||
            q.reduce(math.max) <= p.reduce(math.min) + _epsilon) {
          return false;
        }
      }
    }
    return true;
  }
}

final class PianoKeyboardMap {
  PianoKeyboardMap({
    required this.schemaVersion,
    required this.id,
    required this.sha256,
    required this.provider,
    required this.binding,
    required this.minimumVisibility,
    required List<PianoKeyRegion> keys,
  }) : keys = List.unmodifiable(keys);
  final int schemaVersion;
  final String id, sha256;
  final HandProviderIdentity provider;
  final HandCaptureBinding binding;
  final double minimumVisibility;
  final List<PianoKeyRegion> keys;
  bool get valid {
    if (schemaVersion != 1 ||
        id.trim().isEmpty ||
        !_hash(sha256) ||
        !provider.isSpecified ||
        !binding.isValid ||
        !minimumVisibility.isFinite ||
        minimumVisibility <= 0 ||
        minimumVisibility > 1 ||
        keys.length != 5 ||
        keys.any((k) => !k.valid) ||
        keys
            .map((k) => k.midi)
            .toSet()
            .difference(PianoHandObserver.notes)
            .isNotEmpty ||
        keys.map((k) => k.midi).toSet().length != 5) {
      return false;
    }
    for (var i = 0; i < keys.length; i++) {
      for (var j = i + 1; j < keys.length; j++) {
        if (keys[i].overlapsInterior(keys[j])) return false;
      }
    }
    return true;
  }
}

/// All tolerances come from an explicit calibration artifact, not defaults
/// presented as measured accuracy. No shipping calibration is supplied.
final class PianoClockCalibration {
  const PianoClockCalibration({
    required this.schemaVersion,
    required this.id,
    required this.sha256,
    required this.handClockId,
    required this.handCaptureId,
    required this.audioClockId,
    required this.audioCaptureId,
    required this.audioProvider,
    required this.audioMinusHandUs,
    required this.maximumSkewUs,
    required this.maximumFrameGapUs,
    required this.validFromHandUs,
    required this.validUntilHandUs,
    required this.minimumAudioConfidence,
  });
  final int schemaVersion,
      audioMinusHandUs,
      maximumSkewUs,
      maximumFrameGapUs,
      validFromHandUs,
      validUntilHandUs;
  final String id,
      sha256,
      handClockId,
      handCaptureId,
      audioClockId,
      audioCaptureId;
  final HandProviderIdentity audioProvider;
  final double minimumAudioConfidence;
  bool get valid =>
      schemaVersion == 1 &&
      id.trim().isNotEmpty &&
      _hash(sha256) &&
      [
        handClockId,
        handCaptureId,
        audioClockId,
        audioCaptureId,
      ].every((s) => s.trim().isNotEmpty) &&
      audioProvider.isSpecified &&
      audioProvider.inputSchema == 'audio.monophonic_onset.v1' &&
      maximumSkewUs > 0 &&
      maximumFrameGapUs > 0 &&
      validFromHandUs >= 0 &&
      validUntilHandUs > validFromHandUs &&
      minimumAudioConfidence.isFinite &&
      minimumAudioConfidence > 0 &&
      minimumAudioConfidence <= 1;
}

final class PianoAudioOnset {
  const PianoAudioOnset({
    required this.provider,
    required this.captureId,
    required this.clockId,
    required this.eventId,
    required this.tUs,
    required this.midi,
    required this.confidence,
    required this.monophonic,
  });
  final HandProviderIdentity provider;
  final String captureId, clockId, eventId;
  final int tUs, midi;
  final double confidence;
  final bool monophonic;
}

final class PianoHandObservation {
  const PianoHandObservation(
    this.state,
    this.reason,
    this.mode, {
    this.midi,
    this.finger,
  });
  final PianoHandState state;
  final PianoHandReason reason;
  final HandEvidenceMode mode;
  final int? midi;
  final PianoFinger? finger;
  // No progress, mastery, force or verified-contact result exists here.
}

/// Scoped software observation for piano.beginner/piano-05. Even a candidate
/// means projected finger + independent onset, never verified physical touch.
/// Construct a fresh observer/capture/calibration after any lifecycle change.
final class PianoHandObserver {
  PianoHandObserver({
    required this.provider,
    required this.expectedMode,
    this.keyboardMap,
    this.clockCalibration,
  });
  static const courseId = 'piano.beginner';
  static const lessonId = 'piano-05';
  static const notes = {60, 62, 64, 65, 67};
  final HandProviderIdentity provider;
  final HandEvidenceMode expectedMode;
  final PianoKeyboardMap? keyboardMap;
  final PianoClockCalibration? clockCalibration;
  int? _lastHandUs, _lastUsedAudioUs;
  String? _lastUsedAudioId;
  bool _invalidated = false;
  void invalidate() => _invalidated = true;

  PianoHandObservation observe(
    HandFrame frame, {
    required int targetMidi,
    String selectedCourseId = courseId,
    String selectedLessonId = lessonId,
    PianoAudioOnset? audio,
  }) {
    PianoHandObservation result(
      PianoHandState state,
      PianoHandReason reason, {
      PianoFinger? finger,
      int? midi,
    }) => PianoHandObservation(
      state,
      reason,
      provider.mode,
      finger: finger,
      midi: midi,
    );
    if (provider.mode == HandEvidenceMode.unavailable ||
        !provider.isSpecified ||
        provider.inputSchema != 'hand21.normalized_image.v1') {
      return result(
        PianoHandState.unsupported,
        PianoHandReason.providerUnavailable,
      );
    }
    if (provider.mode != expectedMode || frame.provider.mode != expectedMode) {
      return result(PianoHandState.unsupported, PianoHandReason.replayOnly);
    }
    if (selectedCourseId != courseId ||
        selectedLessonId != lessonId ||
        !notes.contains(targetMidi)) {
      return result(
        PianoHandState.unsupported,
        PianoHandReason.unsupportedTask,
      );
    }
    final map = keyboardMap;
    if (map == null) {
      return result(
        PianoHandState.calibrationRequired,
        PianoHandReason.missingKeyboardMap,
      );
    }
    if (!map.valid ||
        !map.provider.sameAs(provider) ||
        !map.binding.sameAs(frame.binding) ||
        !frame.provider.sameAs(provider)) {
      _invalidated = true;
      return result(
        PianoHandState.calibrationRequired,
        PianoHandReason.incompatibleKeyboardMap,
      );
    }
    if (_invalidated) {
      return result(
        PianoHandState.calibrationRequired,
        PianoHandReason.clockDiscontinuity,
      );
    }
    final clock = clockCalibration;
    if (frame.tUs < 0 ||
        (_lastHandUs != null &&
            (frame.tUs <= _lastHandUs! ||
                (clock != null &&
                    clock.valid &&
                    frame.tUs - _lastHandUs! > clock.maximumFrameGapUs)))) {
      _invalidated = true;
      return result(
        PianoHandState.calibrationRequired,
        PianoHandReason.clockDiscontinuity,
      );
    }
    _lastHandUs = frame.tUs;
    if (frame.hand != PhysicalHand.right) {
      return result(PianoHandState.unobservable, PianoHandReason.wrongHand);
    }
    if (frame.points.length != 21 || frame.points.any((p) => !p.isValid)) {
      return result(
        PianoHandState.unobservable,
        PianoHandReason.invalidHandFrame,
      );
    }
    final finger = PianoFinger.values[[60, 62, 64, 65, 67].indexOf(targetMidi)];
    final first = finger.index * 4 + 1, tip = first + 3;
    if ([
      0,
      for (var i = first; i <= tip; i++) i,
    ].any((i) => frame.points[i].confidence < map.minimumVisibility)) {
      return result(PianoHandState.unobservable, PianoHandReason.lowVisibility);
    }
    final hits = map.keys
        .where((key) => key.contains(frame.points[tip]))
        .toList();
    if (hits.length != 1) {
      return result(
        PianoHandState.unobservable,
        hits.isEmpty
            ? PianoHandReason.outsideKeyboard
            : PianoHandReason.ambiguousKey,
      );
    }
    if (hits.single.midi != targetMidi) {
      return result(PianoHandState.unobservable, PianoHandReason.wrongKey);
    }
    if (audio == null) {
      return result(
        PianoHandState.hover,
        PianoHandReason.noAudioOnset,
        midi: targetMidi,
        finger: finger,
      );
    }
    if (clock == null || !clock.valid) {
      return result(
        PianoHandState.calibrationRequired,
        PianoHandReason.missingClockCalibration,
      );
    }
    if (clock.handClockId != frame.binding.clockId ||
        clock.handCaptureId != frame.binding.captureId ||
        clock.audioClockId != audio.clockId ||
        clock.audioCaptureId != audio.captureId) {
      _invalidated = true;
      return result(
        PianoHandState.calibrationRequired,
        PianoHandReason.clockChanged,
      );
    }
    if (frame.tUs < clock.validFromHandUs ||
        frame.tUs > clock.validUntilHandUs) {
      _invalidated = true;
      return result(
        PianoHandState.calibrationRequired,
        PianoHandReason.calibrationExpired,
      );
    }
    if (!audio.provider.sameAs(clock.audioProvider) ||
        audio.provider.mode != expectedMode ||
        !audio.monophonic ||
        audio.eventId.trim().isEmpty ||
        audio.tUs < 0 ||
        audio.midi != targetMidi ||
        !audio.confidence.isFinite ||
        audio.confidence > 1 ||
        audio.confidence < clock.minimumAudioConfidence ||
        (audio.tUs - (frame.tUs + clock.audioMinusHandUs)).abs() >
            clock.maximumSkewUs) {
      return result(PianoHandState.unobservable, PianoHandReason.audioMismatch);
    }
    if (_lastUsedAudioUs != null && audio.tUs < _lastUsedAudioUs!) {
      _invalidated = true;
      return result(
        PianoHandState.calibrationRequired,
        PianoHandReason.clockDiscontinuity,
      );
    }
    if (audio.eventId == _lastUsedAudioId || audio.tUs == _lastUsedAudioUs) {
      return result(
        PianoHandState.hover,
        PianoHandReason.audioAlreadyUsed,
        midi: targetMidi,
        finger: finger,
      );
    }
    _lastUsedAudioId = audio.eventId;
    _lastUsedAudioUs = audio.tUs;
    return result(
      PianoHandState.contactCandidate,
      PianoHandReason.projectedFingerAndIndependentOnset,
      midi: targetMidi,
      finger: finger,
    );
  }
}

bool _hash(String value) => RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
