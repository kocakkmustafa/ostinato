import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:motion_content/motion_content.dart' show computeSha256Hex;

/// Release capabilities describe the implemented adapter, not teaching or
/// physical accuracy acceptance. A manifest cannot invent a native provider.
enum InferenceCapability {
  approximate,
  releaseClosed,
  unsupported,
  calibrationRequired,
}

final class RuntimeArtifact {
  const RuntimeArtifact({
    required this.id,
    required this.path,
    required this.sha256,
  });
  final String id, path, sha256;

  factory RuntimeArtifact.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value.length != 3 ||
        value['id'] is! String ||
        (value['id'] as String).isEmpty ||
        value['path'] is! String ||
        !RegExp(
          r'^assets/[a-zA-Z0-9_./-]+$',
        ).hasMatch(value['path'] as String) ||
        (value['path'] as String).contains('..') ||
        value['sha256'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(value['sha256'] as String)) {
      throw const FormatException('Invalid runtime artifact');
    }
    return RuntimeArtifact(
      id: value['id'],
      path: value['path'],
      sha256: value['sha256'],
    );
  }

  bool matches(Uint8List bytes) => computeSha256Hex(bytes) == sha256;

  Future<Uint8List> readVerified(AssetBundle bundle) async {
    final data = await bundle.load(path);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (!matches(bytes)) {
      throw const FormatException('Runtime artifact hash mismatch');
    }
    return bytes;
  }
}

/// Bundled-only versioned activation root. Updating a provider/calibration is
/// an app release: update its code pin and acceptance evidence together. There
/// is no remote activation, persisted "latest", or unverified model fallback.
final class InferenceManifest {
  InferenceManifest._(
    this.revision,
    this.poseModel,
    this.postureReference,
    this.guitarObservation,
    Map<String, InferenceCapability> capabilities,
  ) : capabilities = Map.unmodifiable(capabilities);

  static const assetPath = 'assets/config/inference-manifest.v1.json';
  static const sha256 =
      '031fd0584030ba2dbec5b2a25cbf1cf20b8f6d37c4c16d5336af7061133bb690';
  static const poseProviderId = 'motion_camera.pose_landmarker';
  static const poseModelId = 'pose_landmarker_full/float16/1';
  static const poseModelPath = 'assets/models/pose_landmarker_full.v1.task';
  static const poseModelSha256 =
      '5134a3aad27a58b93da0088d431f366da362b44e3ccfbe3462b3827a839011b1';

  final String revision;
  final RuntimeArtifact poseModel, postureReference, guitarObservation;
  final Map<String, InferenceCapability> capabilities;

  InferenceCapability capability(String id) =>
      capabilities[id] ?? InferenceCapability.unsupported;

  factory InferenceManifest.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 ||
        json['schemaVersion'] is! int ||
        json['providerApiVersion'] != 1 ||
        json['providerApiVersion'] is! int ||
        json['poseProvider'] != poseProviderId ||
        json['poseInputSchema'] != 'pose33.normalized_image.v1' ||
        json['revision'] is! String ||
        (json['revision'] as String).isEmpty ||
        json['capabilities'] is! Map<String, dynamic>) {
      throw const FormatException('Incompatible inference manifest');
    }
    final pose = RuntimeArtifact.fromJson(json['poseModel']);
    if (pose.id != poseModelId ||
        pose.path != poseModelPath ||
        pose.sha256 != poseModelSha256) {
      throw const FormatException('Unsupported pose model');
    }
    final reference = RuntimeArtifact.fromJson(json['postureReference']);
    final guitar = RuntimeArtifact.fromJson(json['guitarObservation']);
    if (reference.id != 'ostinato.posture-reference.v1' ||
        reference.path != 'assets/config/posture-contract.json' ||
        guitar.id != 'guitar-observation.v1' ||
        guitar.path != 'assets/config/guitar-observation.v1.json') {
      throw const FormatException('Unsupported calibration binding');
    }
    const maximum = {
      'guitar.singleNote': InferenceCapability.approximate,
      'body.posture': InferenceCapability.releaseClosed,
      'piano.fingerKey': InferenceCapability.unsupported,
      'ukulele.singleNote': InferenceCapability.unsupported,
      'bass.singleNote': InferenceCapability.unsupported,
      'voice.pitch': InferenceCapability.unsupported,
    };
    final raw = json['capabilities'] as Map<String, dynamic>;
    if (raw.length != maximum.length) {
      throw const FormatException('Incomplete capability manifest');
    }
    for (final entry in maximum.entries) {
      if (raw[entry.key] != entry.value.name) {
        throw const FormatException(
          'Capability requires an implemented provider',
        );
      }
    }
    return InferenceManifest._(
      json['revision'],
      pose,
      reference,
      guitar,
      maximum,
    );
  }

  static Future<InferenceManifest> load({AssetBundle? bundle}) async {
    final data = await (bundle ?? rootBundle).load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (computeSha256Hex(bytes) != sha256) {
      throw const FormatException('Inference manifest hash mismatch');
    }
    return InferenceManifest.fromJson(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
    );
  }
}
