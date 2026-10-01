import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_content/motion_content.dart';
import 'package:ostinato/app/course/media/ostinato_source_projection_pin.dart';

Future<Uint8List> _assetBytes(String path) async {
  final data = await rootBundle.load(path);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Flutter bundle carries the exact source-only guitar identities',
    () async {
      final courseBytes = await _assetBytes(
        OstinatoSourceProjectionPin.coursePath,
      );
      final sliceBytes = await _assetBytes(
        OstinatoSourceProjectionPin.slicePath,
      );
      final projectionBytes = await _assetBytes(
        OstinatoSourceProjectionPin.projectionPath,
      );

      expect(sliceBytes.length, 302679);
      expect(projectionBytes.length, 285711);
      expect(
        computeSha256Hex(courseBytes),
        OstinatoSourceProjectionPin.courseSha256,
      );
      expect(
        computeSha256Hex(sliceBytes),
        OstinatoSourceProjectionPin.sliceSha256,
      );
      expect(
        computeSha256Hex(projectionBytes),
        OstinatoSourceProjectionPin.projectionSha256,
      );

      final course =
          jsonDecode(utf8.decode(courseBytes)) as Map<String, dynamic>;
      final slice = jsonDecode(utf8.decode(sliceBytes)) as Map<String, dynamic>;
      final projection =
          jsonDecode(utf8.decode(projectionBytes)) as Map<String, dynamic>;
      expect(slice['appId'], OstinatoSourceProjectionPin.appId);
      expect(projection['appId'], OstinatoSourceProjectionPin.appId);
      expect(
        (course['modules'] as List<dynamic>)
            .expand(
              (module) =>
                  (module as Map<String, dynamic>)['lessons'] as List<dynamic>,
            )
            .length,
        OstinatoSourceProjectionPin.lessonCount,
      );
      expect(
        slice['courseSourceSHA256'],
        OstinatoSourceProjectionPin.courseSha256,
      );
      expect(projection['courseSourceSHA256'], slice['courseSourceSHA256']);
      expect(
        projection['sourceCatalogSHA256'],
        OstinatoSourceProjectionPin.sourceCatalogSha256,
      );
      expect(
        projection['sourceManifestSHA256'],
        OstinatoSourceProjectionPin.sourceManifestSha256,
      );
      expect(slice['holds'], isEmpty);
      expect(
        (slice['lessons'] as List<dynamic>).length,
        OstinatoSourceProjectionPin.lessonCount,
      );
      final rows = projection['rows'] as List<dynamic>;
      expect(rows.length, OstinatoSourceProjectionPin.variantCount);
      expect(
        rows.map((row) => (row as List<dynamic>)[1]).toSet().length,
        OstinatoSourceProjectionPin.lessonCount,
      );
      expect(
        rows.map((row) => (row as List<dynamic>)[3]).toSet().length,
        OstinatoSourceProjectionPin.sceneCount,
      );
      expect(
        rows.where((row) => (row as List<dynamic>)[10] == true).length,
        OstinatoSourceProjectionPin.heldCount,
      );
    },
  );
}
