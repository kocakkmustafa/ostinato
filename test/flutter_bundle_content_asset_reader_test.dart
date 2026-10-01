import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_content/motion_content.dart';
import 'package:ostinato/app/flutter_bundle_content_asset_reader.dart';
import 'package:ostinato/app/guitar_journey.dart';

const String _manifestPath = 'assets/motion_content/manifest.json';
const String _coursePath = 'assets/content/guitar_journey.v1.json';
const String _corePin = 'f2ea161c7e974d57b114ba7773836c72be17a381';
// Current reviewed course asset. Any authored course change requires a repin.
const int _courseByteLength = 995884;
const String _courseSha256 =
    'bf553f62d91927be66b88210103b982bed17c357b4b643cb9b50f57a3e105a18';

String _packageBlock(String source, String package) {
  final matches = RegExp(
    '^  ${RegExp.escape(package)}:',
    multiLine: true,
  ).allMatches(source).toList();
  expect(matches, hasLength(1), reason: '$package must appear exactly once');
  final start = matches.single.start;
  final rest = source.substring(matches.single.end);
  final next = RegExp(
    r'^  [A-Za-z_][A-Za-z0-9_]*:',
    multiLine: true,
  ).firstMatch(rest);
  return source.substring(
    start,
    next == null ? source.length : matches.single.end + next.start,
  );
}

final class _ManifestOverlayBundle extends CachingAssetBundle {
  _ManifestOverlayBundle(this.manifestBytes);

  final Uint8List manifestBytes;
  final List<String> requestedPaths = <String>[];

  @override
  Future<ByteData> load(String key) {
    requestedPaths.add(key);
    if (key == _manifestPath) {
      return Future<ByteData>.value(
        ByteData.view(
          manifestBytes.buffer,
          manifestBytes.offsetInBytes,
          manifestBytes.lengthInBytes,
        ),
      );
    }
    return rootBundle.load(key);
  }
}

Uint8List _manifestBytes({String? assetPath, String? assetSha256}) {
  final Map<String, Object?> manifest = <String, Object?>{
    'schemaVersion': 1,
    'contentVersion': '1.0.0',
    'appId': 'com.yulalab.ostinato',
    'minimumCoreContract': '1.0.0',
    'locales': <String>['tr', 'en'],
    'courses': <Object?>[
      <String, Object?>{
        'id': 'guitar-bridge-test',
        'order': 0,
        'visibility': 'free',
        'title': <String, String>{'tr': 'Gitar', 'en': 'Guitar'},
        'description': <String, String>{
          'tr': 'Paket doğrulama testi',
          'en': 'Bundle verification test',
        },
        'lessonIds': <String>['guitar-asset-test'],
      },
    ],
    'lessons': <Object?>[
      <String, Object?>{
        'id': 'guitar-asset-test',
        'type': 'practice',
        'title': <String, String>{'tr': 'Ders', 'en': 'Lesson'},
        'description': <String, String>{'tr': 'Test', 'en': 'Test'},
        'instruction': <String, String>{'tr': 'Oku', 'en': 'Read'},
        'accessibilityLabel': <String, String>{
          'tr': 'Dersi aç',
          'en': 'Open lesson',
        },
        'modelIds': <String>[],
        'assetIds': <String>['guitar-asset'],
      },
    ],
    'models': <Object?>[],
    'assets': <Object?>[
      <String, Object?>{
        'id': 'guitar-asset',
        'path': assetPath ?? _coursePath,
        'byteLength': _courseByteLength,
        'sha256': assetSha256 ?? _courseSha256,
      },
    ],
  };
  manifest['catalogDigest'] = computeCatalogDigest(manifest);
  return Uint8List.fromList(utf8.encode(jsonEncode(manifest)));
}

ContentBundleLoader _loader(_ManifestOverlayBundle bundle) =>
    ContentBundleLoader(
      reader: FlutterBundleContentAssetReader(bundle: bundle),
      expectedAppId: 'com.yulalab.ostinato',
      currentCoreContract: SemanticVersion.parse('1.0.0'),
      manifestPath: _manifestPath,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('content, camera, and core keep one immutable source pin', () {
    final descriptor = File('pubspec.yaml').readAsStringSync();
    final lock = File('pubspec.lock').readAsStringSync();
    for (final package in <String>[
      'motion_core',
      'motion_camera',
      'motion_content',
    ]) {
      final expectedRef = RegExp(
        r'^      ref: ' + RegExp.escape(_corePin) + r'$',
        multiLine: true,
      );
      expect(
        expectedRef.allMatches(_packageBlock(descriptor, package)),
        hasLength(1),
      );
      final locked = _packageBlock(lock, package);
      expect(expectedRef.allMatches(locked), hasLength(1));
      final expectedResolvedRef = RegExp(
        r'^      resolved-ref: ' + RegExp.escape(_corePin) + r'$',
        multiLine: true,
      );
      expect(expectedResolvedRef.allMatches(locked), hasLength(1));
      if (package == 'motion_content') {
        expect(
          RegExp(
            r'^    version: "0\.1\.0"$',
            multiLine: true,
          ).allMatches(locked),
          hasLength(1),
        );
      }
    }
  });

  test('reads pinned guitar bytes and parses the active course', () async {
    final _ManifestOverlayBundle bundle = _ManifestOverlayBundle(
      _manifestBytes(),
    );
    final ContentLoadResult result = await _loader(bundle).load();

    expect(result, isA<ContentReady>());
    final ContentReady ready = result as ContentReady;
    expect(ready.catalog.manifest.assets.single.path, _coursePath);
    expect(bundle.requestedPaths, <String>[_manifestPath, _coursePath]);

    final Uint8List bytes = await ready.assets.read(_coursePath);
    expect(bytes.length, _courseByteLength);
    expect(computeSha256Hex(bytes), _courseSha256);
    final GuitarJourneyCourse course = GuitarJourneyCourse.fromJson(
      (jsonDecode(utf8.decode(bytes)) as Map).cast<String, dynamic>(),
    );
    expect(course.id, 'guitar.journey');
    expect(course.modules, hasLength(10));
    expect(course.lessons, hasLength(60));
    expect(bundle.requestedPaths.last, _coursePath);
  });

  test('wrong pinned hash blocks course before exposure', () async {
    final _ManifestOverlayBundle bundle = _ManifestOverlayBundle(
      _manifestBytes(assetSha256: List<String>.filled(64, '0').join()),
    );
    final ContentLoadResult result = await _loader(bundle).load();

    expect(result, isA<ContentBlocked>());
    expect(
      (result as ContentBlocked).error.code,
      ContentErrorCode.hashMismatch,
    );
  });

  test('unsafe manifest path blocks without a course bundle read', () async {
    final _ManifestOverlayBundle bundle = _ManifestOverlayBundle(
      _manifestBytes(assetPath: 'assets/content/../private.json'),
    );
    final ContentLoadResult result = await _loader(bundle).load();

    expect(result, isA<ContentBlocked>());
    expect((result as ContentBlocked).error.code, ContentErrorCode.unsafePath);
    expect(bundle.requestedPaths, <String>[_manifestPath]);
  });

  test('direct reader rejects unsafe path before Flutter lookup', () async {
    final _ManifestOverlayBundle bundle = _ManifestOverlayBundle(
      _manifestBytes(),
    );
    final FlutterBundleContentAssetReader reader =
        FlutterBundleContentAssetReader(bundle: bundle);

    await expectLater(
      reader.read('../private.json'),
      throwsA(
        isA<ContentException>().having(
          (ContentException error) => error.error.code,
          'code',
          ContentErrorCode.unsafePath,
        ),
      ),
    );
    expect(bundle.requestedPaths, isEmpty);
  });
}
