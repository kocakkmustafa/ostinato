import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_content/motion_content.dart';
import 'package:ostinato/app/account_connection.dart';
import 'package:ostinato/app/course/media/lesson_media_catalog.dart';
import 'package:ostinato/app/course/media/lesson_media_slot.dart';

final class _OverlayBundle extends CachingAssetBundle {
  _OverlayBundle(this.overlay);

  final Map<String, Uint8List> overlay;
  final List<String> sourceReads = [];
  final List<String> mediaReads = [];

  @override
  Future<ByteData> load(String key) async {
    if (key == 'assets/motion_content/ostinato_source_pins_v2k.json') {
      sourceReads.add(key);
    }
    if (key.startsWith('assets/content/media/')) mediaReads.add(key);
    final bytes = overlay[key];
    return bytes == null ? rootBundle.load(key) : ByteData.sublistView(bytes);
  }
}

final class _Fixture {
  _Fixture() {
    final courseBytes = File(
      'assets/content/guitar_journey.v1.json',
    ).readAsBytesSync();
    final course = jsonDecode(utf8.decode(courseBytes)) as Map<String, dynamic>;
    final firstModule =
        (course['modules'] as List).first as Map<String, dynamic>;
    final firstLesson = (firstModule['lessons'] as List).first;
    lessonId = firstLesson['id'] as String;
    source = LessonMediaSourcePin(
      app: 'ostinato',
      assetId: 'ostinato.guitar.journey.start.parts.v8e.demo',
      lessonId: lessonId,
      sceneId: 'ostinato:$lessonId:orientation',
      variantStem:
          'ostinato/guitar-journey-start-parts--bd7825d2/orientation--073d547b2a4ce9e1a10d894bbb15b530d9e26398490b5cf6a280c742e097d64d--master-format-pending',
      courseSourceSha256: computeSha256Hex(courseBytes),
      lessonCanonicalSha256: computeSha256Hex(
        Uint8List.fromList(utf8.encode(canonicalJsonEncode(firstLesson))),
      ),
      productionSpecSha256:
          '073d547b2a4ce9e1a10d894bbb15b530d9e26398490b5cf6a280c742e097d64d',
      sourceCueSha256:
          '82f49f9b65c8eb0075add7c569f18a8143090c7a876f1f20e4cb397c177d4fcb',
      idempotencyKey:
          'motion-media-v1:073d547b2a4ce9e1a10d894bbb15b530d9e26398490b5cf6a280c742e097d64d',
      productionState: 'PREPRODUCTION_UNGENERATED',
      sourcePinSha256:
          '1ac1a16f559a778c9e575d8aeb840b4e061d6ea7559b9e4b14ee6340448dddfc',
    );
    final stem = 'assets/content/media/${source.variantStem}';
    video = Uint8List.fromList([
      0,
      0,
      0,
      12,
      0x66,
      0x74,
      0x79,
      0x70,
      0x69,
      0x73,
      0x6f,
      0x6d,
    ]);
    tr = Uint8List.fromList(
      utf8.encode(
        'WEBVTT - Motion locale=tr\n\n'
        '00:00:00.000 --> 00:00:00.800\nTelleri göster\n',
      ),
    );
    en = Uint8List.fromList(
      utf8.encode(
        'WEBVTT - Motion locale=en\n\n'
        '00:00:00.000 --> 00:00:00.800\nShow the strings\n',
      ),
    );
    bundle = _OverlayBundle({
      '$stem.mp4': video,
      '$stem.tr.vtt': tr,
      '$stem.en.vtt': en,
    });
    candidate = LessonMediaCandidate(
      source: source,
      manifestSha256: ostinatoMediaManifestSha256,
      video: _file('$stem.mp4', video),
      durationMs: 1000,
      captions: {
        'tr': _file('$stem.tr.vtt', tr),
        'en': _file('$stem.en.vtt', en),
      },
    );
  }

  late final String lessonId;
  late final LessonMediaSourcePin source;
  late final LessonMediaCandidate candidate;
  late final Uint8List video, tr, en;
  late final _OverlayBundle bundle;

  LessonMediaFile _file(String path, Uint8List bytes) => LessonMediaFile(
    path: path,
    bytes: bytes.length,
    sha256: computeSha256Hex(bytes),
  );

  LessonMediaSourcePin sourceWith({
    String? app,
    String? assetId,
    String? lessonId,
    String? sceneId,
    String? variantStem,
    String? courseSha,
    String? lessonSha,
    String? specSha,
    String? cueSha,
    String? idempotencyKey,
    String? productionState,
    String? sourcePinSha,
  }) => LessonMediaSourcePin(
    app: app ?? source.app,
    assetId: assetId ?? source.assetId,
    lessonId: lessonId ?? source.lessonId,
    sceneId: sceneId ?? source.sceneId,
    variantStem: variantStem ?? source.variantStem,
    courseSourceSha256: courseSha ?? source.courseSourceSha256,
    lessonCanonicalSha256: lessonSha ?? source.lessonCanonicalSha256,
    productionSpecSha256: specSha ?? source.productionSpecSha256,
    sourceCueSha256: cueSha ?? source.sourceCueSha256,
    idempotencyKey: idempotencyKey ?? source.idempotencyKey,
    productionState: productionState ?? source.productionState,
    sourcePinSha256: sourcePinSha ?? source.sourcePinSha256,
  );

  LessonMediaCandidate candidateWith({
    LessonMediaSourcePin? source,
    String? manifestSha,
  }) => LessonMediaCandidate(
    source: source ?? this.source,
    manifestSha256: manifestSha ?? ostinatoMediaManifestSha256,
    video: candidate.video,
    durationMs: candidate.durationMs,
    captions: candidate.captions,
  );

  LessonMediaCatalog catalog([LessonMediaCandidate? replacement]) =>
      LessonMediaCatalog.synthetic(candidates: [replacement ?? candidate]);

  Future<InspectedLessonMedia?> inspect([LessonMediaCatalog? custom]) =>
      (custom ?? catalog()).inspect(
        bundle: bundle,
        lessonId: lessonId,
        sceneId: source.sceneId,
        variantStem: source.variantStem,
        locale: 'tr',
        durationProbe: (_) async => 1000,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('shipping catalog is empty and never inspects bundled course', () async {
    final fixture = _Fixture();
    final result = await fixture.inspect(const LessonMediaCatalog.empty());
    expect(result, isNull);
    expect(fixture.bundle.sourceReads, isEmpty);
    expect(fixture.bundle.mediaReads, isEmpty);
  });

  test(
    'source and byte inspected synthetic candidate is still hidden',
    () async {
      final fixture = _Fixture();
      final result = await fixture.inspect();
      expect(result, isNotNull);
      expect(result!.visible, isFalse);
      expect(result.releaseEligible, isFalse);
      expect(result.progressEffect, 0);
    },
  );

  test(
    'changed video or missing caption closes the media inspection',
    () async {
      final fixture = _Fixture();
      fixture.bundle.overlay[fixture.candidate.video.path] = Uint8List.fromList(
        [...fixture.video.sublist(0, 11), 0],
      );
      expect(await fixture.inspect(), isNull);
      fixture.bundle.overlay[fixture.candidate.video.path] = fixture.video;
      fixture.bundle.overlay.remove(fixture.candidate.captions['en']!.path);
      expect(await fixture.inspect(), isNull);
    },
  );

  test(
    'caption paths stay fixed while an inspection awaits its probe',
    () async {
      final fixture = _Fixture();
      final captions = <String, LessonMediaFile>{...fixture.candidate.captions};
      final original = captions['tr']!;
      final wrongRootPath =
          'assets/content/other/${fixture.source.variantStem}.tr.vtt';
      fixture.bundle.overlay[wrongRootPath] = fixture.tr;
      final candidate = LessonMediaCandidate(
        source: fixture.source,
        manifestSha256: ostinatoMediaManifestSha256,
        video: fixture.candidate.video,
        durationMs: fixture.candidate.durationMs,
        captions: captions,
      );
      final probeStarted = Completer<void>();
      final pendingProbe = Completer<int?>();
      final inspection = fixture
          .catalog(candidate)
          .inspect(
            bundle: fixture.bundle,
            lessonId: fixture.lessonId,
            sceneId: fixture.source.sceneId,
            variantStem: fixture.source.variantStem,
            locale: 'tr',
            durationProbe: (_) {
              probeStarted.complete();
              return pendingProbe.future;
            },
          );

      await probeStarted.future.timeout(const Duration(seconds: 5));
      captions['tr'] = LessonMediaFile(
        path: wrongRootPath,
        bytes: original.bytes,
        sha256: original.sha256,
      );
      pendingProbe.complete(1000);

      final result = await inspection;
      expect(result, isNotNull);
      expect(candidate.captions['tr'], same(original));
      expect(fixture.bundle.mediaReads, contains(original.path));
      expect(result!.visible, isFalse);
      expect(result.releaseEligible, isFalse);
      expect(result.progressEffect, 0);
    },
  );

  test('an unselected wrong-root row closes the whole catalog', () async {
    final fixture = _Fixture();
    final otherSource = fixture.sourceWith(sceneId: 'unselected-scene');
    final wrongStem = 'assets/content/other/${otherSource.variantStem}';
    final malformed = LessonMediaCandidate(
      source: otherSource,
      manifestSha256: ostinatoMediaManifestSha256,
      video: fixture._file('$wrongStem.mp4', fixture.video),
      durationMs: 1000,
      captions: {
        'tr': fixture._file('$wrongStem.tr.vtt', fixture.tr),
        'en': fixture._file('$wrongStem.en.vtt', fixture.en),
      },
    );
    final catalog = LessonMediaCatalog.synthetic(
      candidates: [fixture.candidate, malformed],
    );

    expect(await fixture.inspect(catalog), isNull);
    expect(fixture.bundle.sourceReads, isEmpty);
  });

  test(
    'wrong source row, old manifest and duplicate candidates are rejected',
    () async {
      final fixture = _Fixture();
      final wrong = <LessonMediaCandidate>[
        fixture.candidateWith(source: fixture.sourceWith(app: 'choreia')),
        fixture.candidateWith(source: fixture.sourceWith(assetId: 'other')),
        fixture.candidateWith(source: fixture.sourceWith(lessonId: 'other')),
        fixture.candidateWith(source: fixture.sourceWith(sceneId: 'other')),
        fixture.candidateWith(source: fixture.sourceWith(variantStem: 'other')),
        fixture.candidateWith(source: fixture.sourceWith(courseSha: 'c' * 64)),
        fixture.candidateWith(source: fixture.sourceWith(lessonSha: 'c' * 64)),
        fixture.candidateWith(source: fixture.sourceWith(specSha: 'c' * 64)),
        fixture.candidateWith(source: fixture.sourceWith(cueSha: 'c' * 64)),
        fixture.candidateWith(
          source: fixture.sourceWith(idempotencyKey: 'motion-media-v1:old'),
        ),
        fixture.candidateWith(
          source: fixture.sourceWith(productionState: 'GENERATED'),
        ),
        fixture.candidateWith(
          source: fixture.sourceWith(sourcePinSha: 'c' * 64),
        ),
        fixture.candidateWith(
          source: fixture.sourceWith(
            sourcePinSha:
                '2ae012bfe3db1c0ad3bbbbd8b38cdd8afe9f2255c4e3f84dd37b03ab32ab1e20',
          ),
        ),
        fixture.candidateWith(
          manifestSha:
              '5399b0fd21bd7148de9c845ecaf288e391fef4c6e2ae98503fd9134fd39e8628',
        ),
        fixture.candidateWith(
          manifestSha:
              'deb767cc1060cb475bf5664e0c662b44b0a0ad8318288b4e65faa3c472cb6324',
        ),
        fixture.candidateWith(
          manifestSha:
              '21008cbf5a58d01c3ef4a12c879f1b6da4e8d8ea5111f8340d53d35f9ec02c8b',
        ),
      ];
      for (final candidate in wrong) {
        expect(await fixture.inspect(fixture.catalog(candidate)), isNull);
      }
      expect(
        await fixture.inspect(
          LessonMediaCatalog.synthetic(
            candidates: [fixture.candidate, fixture.candidate],
          ),
        ),
        isNull,
      );
    },
  );

  test('forged QA catalog cannot supply a self-declared pin', () async {
    final fixture = _Fixture();
    final path = File('assets/motion_content/ostinato_source_pins_v2k.json');
    final original = await path.readAsBytes();
    final decoded = jsonDecode(utf8.decode(original)) as Map<String, dynamic>;
    final lesson = (decoded['lessons'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((row) => row['lessonId'] == fixture.lessonId);
    final scene = (lesson['scenes'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((row) => row['sceneId'] == fixture.source.sceneId);
    final variant = (scene['variants'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((row) => row['stem'] == fixture.source.variantStem);
    variant['sourcePinSHA256'] = 'c' * 64;
    fixture.bundle.overlay[path.path] = Uint8List.fromList(
      utf8.encode(jsonEncode(decoded)),
    );
    final candidate = fixture.candidateWith(
      source: fixture.sourceWith(sourcePinSha: 'c' * 64),
    );
    expect(await fixture.inspect(fixture.catalog(candidate)), isNull);
    expect(fixture.bundle.sourceReads, hasLength(1));
    expect(fixture.bundle.mediaReads, isEmpty);
    expect(computeSha256Hex(original), ostinatoMediaSourceCatalogSha256);
    expect(decoded['counts'], containsPair('variants', 420));
  });

  testWidgets('shipping lesson slot is invisible', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonMediaSlot.empty(
            lessonId: 'guitar.journey.start.parts',
            locale: 'tr',
          ),
        ),
      ),
    );
    final slot = tester.widget<LessonMediaSlot>(find.byType(LessonMediaSlot));
    expect(slot.catalog.isEmpty, isTrue);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    expect(find.textContaining('video'), findsNothing);
  });

  testWidgets('account change discards an in-flight synthetic inspection', (
    tester,
  ) async {
    final fixture = _Fixture();
    final pending = Completer<int?>();
    final observations = <InspectedLessonMedia?>[];
    final catalog = fixture.catalog();
    var probeCalls = 0;
    Future<int?> probe(Uint8List _) {
      probeCalls++;
      return pending.future;
    }

    Widget host(String accountId) => MaterialApp(
      home: AccountScope(
        connection: null,
        currentUserId: accountId,
        child: Scaffold(
          body: LessonMediaSlot(
            catalog: catalog,
            bundle: fixture.bundle,
            lessonId: fixture.lessonId,
            sceneId: fixture.source.sceneId,
            variantStem: fixture.source.variantStem,
            locale: 'tr',
            durationProbe: probe,
            onInspectionChanged: observations.add,
          ),
        ),
      ),
    );

    await tester.pumpWidget(host('account-a'));
    await tester.pumpAndSettle();
    expect(probeCalls, 1);
    await tester.pumpWidget(host('account-b'));
    await tester.pump();
    pending.complete(1000);
    await tester.pump();
    expect(observations.whereType<InspectedLessonMedia>(), isEmpty);
  });
}
