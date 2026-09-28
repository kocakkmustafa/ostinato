import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_content/motion_content.dart';
import 'package:ostinato/app/guitar_journey.dart';
import 'package:ostinato/app/onboarding_store.dart';
import 'package:ostinato/app/screens/library_screen.dart';
import 'package:ostinato/main.dart';

const String _manifestPath = 'assets/motion_content/manifest.json';
const String _coursePath = 'assets/content/guitar_journey.v1.json';

final class _AssetOverlayBundle extends CachingAssetBundle {
  _AssetOverlayBundle({
    this.courseBytes,
    this.missingManifest = false,
    this.missingCourse = false,
  });

  final Uint8List? courseBytes;
  final bool missingManifest;
  final bool missingCourse;
  final List<String> requestedPaths = <String>[];

  @override
  Future<ByteData> load(String key) {
    requestedPaths.add(key);
    if ((key == _manifestPath && missingManifest) ||
        (key == _coursePath && missingCourse)) {
      throw StateError('asset unavailable: $key');
    }
    if (key == _coursePath && courseBytes != null) {
      final bytes = courseBytes!;
      return Future<ByteData>.value(
        ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes),
      );
    }
    return rootBundle.load(key);
  }
}

Future<ContentException> _rejection(_AssetOverlayBundle bundle) async {
  try {
    await GuitarJourneyCourse.load(bundle: bundle);
  } on ContentException catch (error) {
    return error;
  }
  throw StateError('Expected the course integrity gate to reject the bundle');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('real packaged manifest verifies the 60-lesson guitar course', () async {
    final bundle = _AssetOverlayBundle();
    final course = await GuitarJourneyCourse.load(bundle: bundle);

    expect(course.id, 'guitar.journey');
    expect(course.modules, hasLength(10));
    expect(course.lessons, hasLength(60));
    expect(bundle.requestedPaths.first, _manifestPath);
    expect(
      bundle.requestedPaths.where((path) => path == _coursePath),
      hasLength(2),
    );
  });

  test('same-length, parseable guitar course tamper is blocked', () async {
    final originalData = await rootBundle.load(_coursePath);
    final original = Uint8List.sublistView(originalData);
    final changed = Uint8List.fromList(original);
    changed[changed.length - 1] = original.last == 10 ? 32 : 10;
    expect(changed.length, original.length);
    expect(() => jsonDecode(utf8.decode(changed)), returnsNormally);
    final bundle = _AssetOverlayBundle(courseBytes: changed);

    final error = await _rejection(bundle);
    expect(error.error.code, ContentErrorCode.hashMismatch);
    expect(bundle.requestedPaths, contains(_manifestPath));
    expect(bundle.requestedPaths, contains(_coursePath));
  });

  test('missing manifest blocks before course bytes are read', () async {
    final bundle = _AssetOverlayBundle(missingManifest: true);

    final error = await _rejection(bundle);
    expect(error.error.code, ContentErrorCode.missingAsset);
    expect(bundle.requestedPaths, <String>[_manifestPath]);
  });

  test('missing course asset reports a typed read failure', () async {
    final bundle = _AssetOverlayBundle(missingCourse: true);

    final error = await _rejection(bundle);
    expect(error.error.code, ContentErrorCode.missingAsset);
    expect(bundle.requestedPaths, contains(_coursePath));
  });

  testWidgets('startup does not expose the library on guitar hash mismatch', (
    tester,
  ) async {
    final originalData = await rootBundle.load(_coursePath);
    final changed = Uint8List.fromList(Uint8List.sublistView(originalData));
    changed[changed.length - 1] = changed.last == 10 ? 32 : 10;
    final bundle = _AssetOverlayBundle(courseBytes: changed);

    await tester.pumpWidget(
      OstinatoApp(
        store: InMemoryOnboardingStore(complete: true),
        guitarCourseBundle: bundle,
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();

    expect(find.byType(LibraryScreen), findsNothing);
    expect(
      find.byKey(const Key('ostinato-content-load-failure')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Course content could not be loaded'),
      findsOneWidget,
    );
    expect(find.text('Support code: CONTENT_HASHMISMATCH'), findsOneWidget);
    expect(find.textContaining('ContentError('), findsNothing);

    tester.binding.platformDispatcher.localesTestValue = const <Locale>[
      Locale('tr'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    await tester.pumpAndSettle();
    expect(find.textContaining('Kurs içeriği yüklenemedi'), findsOneWidget);
    expect(find.text('Destek kodu: CONTENT_HASHMISMATCH'), findsOneWidget);
    expect(find.byType(LibraryScreen), findsNothing);
  });
}
