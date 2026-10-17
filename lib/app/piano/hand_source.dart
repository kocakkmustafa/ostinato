import 'dart:async';

/// Producer provenance is part of every frame/event. Replay never becomes a
/// production observation by changing a user preference or fallback flag.
enum HandEvidenceMode { production, replay, unavailable }

enum PhysicalHand { right, left, unknown }

enum HandSourceStatus { unsupported, starting, observing, stopped, unavailable }

final class HandProviderIdentity {
  const HandProviderIdentity({
    required this.id,
    required this.version,
    required this.artifactSha256,
    required this.mode,
    required this.inputSchema,
  });
  final String id, version, inputSchema;
  final String? artifactSha256;
  final HandEvidenceMode mode;
  bool get isSpecified =>
      id.trim().isNotEmpty &&
      RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) &&
      artifactSha256 != null &&
      RegExp(r'^[0-9a-f]{64}$').hasMatch(artifactSha256!);
  bool sameAs(HandProviderIdentity other) =>
      id == other.id &&
      version == other.version &&
      artifactSha256 == other.artifactSha256 &&
      mode == other.mode &&
      inputSchema == other.inputSchema;
}

/// Fresh captureId on start, account/lifecycle change or camera reconfiguration.
/// Points are upright normalized IMAGE coordinates; no world/depth/force claim.
final class HandCaptureBinding {
  const HandCaptureBinding({
    required this.captureId,
    required this.cameraId,
    required this.clockId,
    required this.width,
    required this.height,
    required this.rotationDegrees,
    required this.mirrored,
  });
  final String captureId, cameraId, clockId;
  final int width, height, rotationDegrees;
  final bool mirrored;
  bool get isValid =>
      captureId.trim().isNotEmpty &&
      cameraId.trim().isNotEmpty &&
      clockId.trim().isNotEmpty &&
      width > 0 &&
      height > 0 &&
      const [0, 90, 180, 270].contains(rotationDegrees);
  bool sameAs(HandCaptureBinding other) =>
      captureId == other.captureId &&
      cameraId == other.cameraId &&
      clockId == other.clockId &&
      width == other.width &&
      height == other.height &&
      rotationDegrees == other.rotationDegrees &&
      mirrored == other.mirrored;
}

final class HandPoint {
  const HandPoint(this.x, this.y, this.confidence);
  final double x, y, confidence;
  bool get isValid =>
      x.isFinite &&
      y.isFinite &&
      confidence.isFinite &&
      x >= 0 &&
      x <= 1 &&
      y >= 0 &&
      y <= 1 &&
      confidence >= 0 &&
      confidence <= 1;
}

final class HandFrame {
  HandFrame({
    required this.provider,
    required this.binding,
    required this.hand,
    required this.tUs,
    required List<HandPoint> points,
  }) : points = List.unmodifiable(points);
  final HandProviderIdentity provider;
  final HandCaptureBinding binding;
  final PhysicalHand hand;
  final int tUs;

  /// Standard 21-point ordering: wrist 0; thumb tip 4; remaining tips 8/12/16/20.
  final List<HandPoint> points;
}

abstract interface class HandSource {
  HandProviderIdentity get identity;
  Stream<HandFrame> get frames;
  Stream<HandSourceStatus> get status;
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}

/// The shipping composition has no hand tracker, model, permission or camera
/// acquisition. A real provider needs a reviewed implementation and app update.
HandSource createProductionHandSource() => const UnsupportedHandSource();

final class UnsupportedHandSource implements HandSource {
  const UnsupportedHandSource();
  @override
  HandProviderIdentity get identity => const HandProviderIdentity(
    id: 'ostinato.hand.unavailable',
    version: '1.0.0',
    artifactSha256: null,
    mode: HandEvidenceMode.unavailable,
    inputSchema: 'hand21.normalized_image.v1',
  );
  @override
  Stream<HandFrame> get frames => const Stream.empty();
  @override
  Stream<HandSourceStatus> get status =>
      Stream.value(HandSourceStatus.unsupported);
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}
