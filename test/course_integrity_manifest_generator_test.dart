import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:motion_content/motion_content.dart';

import '../tool/build_guitar_integrity_manifest.dart' as generator;

const _manifestPath = 'assets/motion_content/manifest.json';
const _expectedAssets = <String, String>{
  'guitar-course-json': 'assets/content/guitar_journey.v1.json',
  'piano-course-json': 'assets/content/piano_beginner.v1.json',
  'ukulele-course-json': 'assets/content/ukulele_beginner.v1.json',
  'bass-course-json': 'assets/content/bass_beginner.v1.json',
  'vocal-course-json': 'assets/content/vocal_beginner.v1.json',
};

Future<Directory> _fixture() async {
  final root = await Directory.systemTemp.createTemp(
    'ostinato-course-manifest-',
  );
  addTearDown(() => root.delete(recursive: true));
  for (final path in _expectedAssets.values) {
    final file = File('${root.path}/$path');
    await file.parent.create(recursive: true);
    await file.writeAsString('{"fixture":0}\n');
  }
  return root;
}

Future<Uint8List> _seal(Directory root) async {
  final bytes = await generator.buildCourseIntegrityManifest(root);
  final file = File('${root.path}/$_manifestPath');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
  return bytes;
}

Future<void> _verify(Directory root, Uint8List bytes) =>
    ManifestBuilder().verify(
      manifestBytes: bytes,
      root: root,
      expectedAppId: 'com.yulalab.ostinato',
      currentCoreContract: currentMotionContentContract,
    );
Future<void> _rewrite(Directory root, Map<String, dynamic> value) async {
  value['catalogDigest'] = computeCatalogDigest(value);
  await File(
    '${root.path}/$_manifestPath',
  ).writeAsString('${canonicalJsonEncode(value)}\n');
}

Matcher _rejected(ContentErrorCode code) => isA<ContentException>().having(
  (exception) => exception.error.code,
  'content error',
  code,
);

void main() {
  test('CLI requires exactly one explicit write/check mode', () async {
    final previous = exitCode;
    try {
      for (final args in <List<String>>[
        [],
        ['--unknown'],
        ['--check', '--write'],
        ['--write', '--allow-stale'],
      ]) {
        final diagnostics = StringBuffer();
        await generator.runCourseIntegrityManifestCli(
          args,
          writeError: diagnostics.writeln,
        );
        expect(exitCode, 64);
        expect(
          diagnostics.toString(),
          'Use --write or --check from the Ostinato app root.\n',
        );
      }
    } finally {
      exitCode = previous;
    }
  });
  test(
    'real five-course manifest is exactly reproducible canonical bytes',
    () async {
      expect(generator.courseIntegrityAssets, _expectedAssets);
      final expected = await generator.buildCourseIntegrityManifest(
        Directory.current,
      );
      expect(expected, File(_manifestPath).readAsBytesSync());
      expect(
        await generator.courseIntegrityManifestIsCurrent(Directory.current),
        isTrue,
      );
      await _verify(Directory.current, expected);
    },
  );
  test(
    'repeated builds are deterministic and every source contributes real length/hash',
    () async {
      final root = await _fixture();
      final bytes = await _seal(root);
      expect(await generator.buildCourseIntegrityManifest(root), bytes);
      final manifest = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      expect(manifest['assets'], hasLength(5));
      for (final asset in manifest['assets'] as List) {
        final source = File('${root.path}/${asset['path']}').readAsBytesSync();
        expect(asset['byteLength'], source.length);
        expect(asset['sha256'], computeSha256Hex(source));
      }
      await _verify(root, bytes);
    },
  );
  for (final entry in _expectedAssets.entries) {
    test(
      '${entry.key} deletion refuses both regeneration and current check',
      () async {
        final root = await _fixture();
        await _seal(root);
        await File('${root.path}/${entry.value}').delete();
        await expectLater(
          generator.buildCourseIntegrityManifest(root),
          throwsA(_rejected(ContentErrorCode.missingAsset)),
        );
        await expectLater(
          generator.courseIntegrityManifestIsCurrent(root),
          throwsA(_rejected(ContentErrorCode.missingAsset)),
        );
      },
    );
    test(
      '${entry.key} same-size source change is stale and hash-refused',
      () async {
        final root = await _fixture();
        final sealed = await _seal(root);
        await File(
          '${root.path}/${entry.value}',
        ).writeAsString('{"fixture":1}\n');
        expect(await generator.courseIntegrityManifestIsCurrent(root), isFalse);
        await expectLater(
          _verify(root, sealed),
          throwsA(_rejected(ContentErrorCode.hashMismatch)),
        );
      },
    );
    test('${entry.key} changed byte count is stale and size-refused', () async {
      final root = await _fixture();
      final sealed = await _seal(root);
      await File(
        '${root.path}/${entry.value}',
      ).writeAsString('{"fixture":0}\n\n');
      expect(await generator.courseIntegrityManifestIsCurrent(root), isFalse);
      await expectLater(
        _verify(root, sealed),
        throwsA(_rejected(ContentErrorCode.sizeMismatch)),
      );
    });
  }
  test(
    'extra hash-valid manifest member does not become an approved source',
    () async {
      final root = await _fixture();
      final bytes = await _seal(root);
      final manifest = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final extra = File('${root.path}/assets/content/extra_beginner.v1.json');
      await extra.writeAsString('{"fixture":0}\n');
      final data = extra.readAsBytesSync();
      (manifest['assets'] as List).add({
        'id': 'extra-course-json',
        'path': 'assets/content/extra_beginner.v1.json',
        'byteLength': data.length,
        'sha256': computeSha256Hex(data),
      });
      await _rewrite(root, manifest);
      // Valid byte integrity is insufficient: authored membership must also match.
      await _verify(
        root,
        File('${root.path}/$_manifestPath').readAsBytesSync(),
      );
      expect(await generator.courseIntegrityManifestIsCurrent(root), isFalse);
    },
  );
  test(
    'removed declared member remains stale even with a valid new digest',
    () async {
      final root = await _fixture();
      final bytes = await _seal(root);
      final manifest = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      (manifest['assets'] as List).removeLast();
      await _rewrite(root, manifest);
      expect(await generator.courseIntegrityManifestIsCurrent(root), isFalse);
    },
  );
  for (final field in ['byteLength', 'sha256']) {
    test(
      'forged $field cannot be hidden by recomputing the catalog digest',
      () async {
        final root = await _fixture();
        final bytes = await _seal(root);
        final manifest = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final asset =
            (manifest['assets'] as List).first as Map<String, dynamic>;
        asset[field] = field == 'byteLength'
            ? (asset[field] as int) + 1
            : '0' * 64;
        await _rewrite(root, manifest);
        expect(await generator.courseIntegrityManifestIsCurrent(root), isFalse);
        await expectLater(
          _verify(root, File('${root.path}/$_manifestPath').readAsBytesSync()),
          throwsA(
            _rejected(
              field == 'byteLength'
                  ? ContentErrorCode.sizeMismatch
                  : ContentErrorCode.hashMismatch,
            ),
          ),
        );
      },
    );
  }
  test(
    'semantically identical noncanonical formatting is still refused',
    () async {
      final root = await _fixture();
      final bytes = await _seal(root);
      await File('${root.path}/$_manifestPath').writeAsString(
        const JsonEncoder.withIndent(
          '  ',
        ).convert(jsonDecode(utf8.decode(bytes))),
      );
      expect(await generator.courseIntegrityManifestIsCurrent(root), isFalse);
    },
  );
  test(
    'missing manifest is unavailable; symlink source cannot be signed',
    () async {
      final root = await _fixture();
      expect(await generator.courseIntegrityManifestIsCurrent(root), isFalse);
      final file = File('${root.path}/${_expectedAssets.values.first}');
      final target = File('${root.path}/target.json');
      await target.writeAsString('{"fixture":0}\n');
      await file.delete();
      await Link(file.path).create(target.path);
      await expectLater(
        generator.buildCourseIntegrityManifest(root),
        throwsA(_rejected(ContentErrorCode.unsafePath)),
      );
    },
  );
}
