import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_content/motion_content.dart' show computeSha256Hex;
import 'package:ostinato/app/inference_manifest.dart';
import 'package:ostinato/app/pose_model.dart';
import 'package:ostinato/app/audio/guitar_note_observation_controller.dart';

Map<String, dynamic> manifestJson() =>
    jsonDecode(File(InferenceManifest.assetPath).readAsStringSync())
        as Map<String, dynamic>;

final class BytesBundle extends CachingAssetBundle {
  BytesBundle(this.files);
  final Map<String, Uint8List> files;
  @override
  Future<ByteData> load(String key) async {
    final bytes = files[key];
    if (bytes == null) throw StateError('Missing test asset');
    return ByteData.sublistView(bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'bundled manifest binds real provider, model and calibration hashes',
    () async {
      final manifest = await InferenceManifest.load();
      expect(manifest.poseModel.sha256, InferenceManifest.poseModelSha256);
      expect(
        manifest.capability('guitar.singleNote'),
        InferenceCapability.approximate,
      );
      for (final name in [
        'piano.fingerKey',
        'ukulele.singleNote',
        'bass.singleNote',
        'voice.pitch',
        'unknown',
      ]) {
        expect(manifest.capability(name), InferenceCapability.unsupported);
      }
      expect(
        manifest.capability('body.posture'),
        InferenceCapability.releaseClosed,
      );
      await manifest.poseModel.readVerified(rootBundle);
      await manifest.postureReference.readVerified(rootBundle);
      await manifest.guitarObservation.readVerified(rootBundle);
      final config = await GuitarObservationConfig.load();
      expect(config.supportedSampleRates, {44100, 48000});
      expect(
        () => manifest.capabilities['piano.fingerKey'] =
            InferenceCapability.approximate,
        throwsUnsupportedError,
      );
    },
  );
  for (final entry in <String, Object?>{
    'schemaVersion': 2,
    'providerApiVersion': 2,
    'poseProvider': 'fixture',
    'poseInputSchema': 'hand21.v1',
  }.entries) {
    test('reject incompatible ${entry.key}', () {
      final json = manifestJson()..[entry.key] = entry.value;
      expect(() => InferenceManifest.fromJson(json), throwsFormatException);
    });
  }
  test(
    'config cannot open unimplemented hand provider or use another model',
    () {
      final json = manifestJson();
      (json['capabilities'] as Map)['piano.fingerKey'] = 'approximate';
      expect(() => InferenceManifest.fromJson(json), throwsFormatException);
      final other = manifestJson();
      (other['poseModel'] as Map)['id'] = 'latest';
      expect(() => InferenceManifest.fromJson(other), throwsFormatException);
    },
  );
  test(
    'untrusted manifest bytes fail even if structurally compatible',
    () async {
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(manifestJson())));
      await expectLater(
        InferenceManifest.load(
          bundle: BytesBundle({InferenceManifest.assetPath: bytes}),
        ),
        throwsFormatException,
      );
    },
  );
  test('calibration byte mismatch is refused', () async {
    final artifact = InferenceManifest.fromJson(
      manifestJson(),
    ).guitarObservation;
    await expectLater(
      artifact.readVerified(BytesBundle({artifact.path: Uint8List(16)})),
      throwsFormatException,
    );
  });
  test('artifact rejects malformed digest and path traversal', () {
    for (final path in [
      '../model.task',
      'assets/../model.task',
      'https://model.task',
    ]) {
      expect(
        () => RuntimeArtifact.fromJson({
          'id': 'model',
          'path': path,
          'sha256': '0' * 64,
        }),
        throwsFormatException,
      );
    }
  });
  late Directory directory;
  setUp(
    () async => directory = await Directory.systemTemp.createTemp(
      'ostinato-model-test-',
    ),
  );
  tearDown(() async => directory.delete(recursive: true));
  RuntimeArtifact artifact(Uint8List bytes) => RuntimeArtifact(
    id: 'isolated-test-model',
    path: 'assets/test.task',
    sha256: computeSha256Hex(bytes),
  );
  test(
    'content-addressed cache verifies existing bytes and supports release rollback',
    () async {
      final a = Uint8List.fromList([1, 2, 3]),
          b = Uint8List.fromList([4, 5, 6]);
      final pathA = await resolveVerifiedModelFile(
        artifact: artifact(a),
        directory: directory,
        bundle: BytesBundle({'assets/test.task': a}),
      );
      final pathB = await resolveVerifiedModelFile(
        artifact: artifact(b),
        directory: directory,
        bundle: BytesBundle({'assets/test.task': b}),
      );
      expect(pathA, isNot(pathB));
      final rollback = await resolveVerifiedModelFile(
        artifact: artifact(a),
        directory: directory,
        bundle: BytesBundle({}),
      );
      expect(rollback, pathA);
      expect(await File(pathA).readAsBytes(), a);
      expect(await File(pathB).readAsBytes(), b);
      expect(await directory.list().length, 2);
    },
  );
  test(
    'corrupt cached bytes are preserved and never returned or overwritten',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final pin = artifact(bytes);
      final path = '${directory.path}/pose-${pin.sha256}.task';
      await File(path).writeAsBytes([9, 9, 9]);
      await expectLater(
        resolveVerifiedModelFile(
          artifact: pin,
          directory: directory,
          bundle: BytesBundle({'assets/test.task': bytes}),
        ),
        throwsFormatException,
      );
      expect(await File(path).readAsBytes(), [9, 9, 9]);
    },
  );
  test(
    'legacy mutable filename is preserved but never used as the new model',
    () async {
      final legacy = File('${directory.path}/pose_landmarker_full.v1.task');
      await legacy.writeAsBytes([9, 9]);
      final bytes = Uint8List.fromList([1, 2, 3]);
      final path = await resolveVerifiedModelFile(
        artifact: artifact(bytes),
        directory: directory,
        bundle: BytesBundle({'assets/test.task': bytes}),
      );
      expect(path, isNot(legacy.path));
      expect(await File(path).readAsBytes(), bytes);
      expect(await legacy.readAsBytes(), [9, 9]);
    },
  );
  test('corrupt bundled model cannot create an active cache', () async {
    final pin = artifact(Uint8List.fromList([1, 2, 3]));
    await expectLater(
      resolveVerifiedModelFile(
        artifact: pin,
        directory: directory,
        bundle: BytesBundle({'assets/test.task': Uint8List(3)}),
      ),
      throwsFormatException,
    );
    expect(await directory.list().length, 0);
  });
}
