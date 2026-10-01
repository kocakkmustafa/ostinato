import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/guitar_practice_materials.dart';

void main() {
  Map<String, dynamic> source() =>
      jsonDecode(
            File('tool/guitar_practice_materials.v1.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  Map<String, dynamic> copy(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  List<dynamic> tasks(Map<String, dynamic> value) =>
      value['lessonTasks'] as List<dynamic>;

  Map<String, dynamic> piece(Map<String, dynamic> value) =>
      value['preparedPiece'] as Map<String, dynamic>;

  String sha256OfWorkspaceManifest(File file) {
    final command = Platform.isMacOS
        ? 'shasum'
        : Platform.isWindows
        ? 'certutil'
        : 'sha256sum';
    final arguments = Platform.isMacOS
        ? ['-a', '256', file.path]
        : Platform.isWindows
        ? ['-hashfile', file.path, 'SHA256']
        : [file.path];
    final result = Process.runSync(command, arguments);
    final digest = RegExp(
      r'\b[a-fA-F0-9]{64}\b',
    ).firstMatch(result.stdout.toString());
    if (result.exitCode != 0 || digest == null) {
      throw TestFailure('Could not hash optional workspace manifest');
    }
    return digest.group(0)!.toLowerCase();
  }

  test('authored candidate is typed, exact, and outside shipped assets', () {
    final raw = source();
    final catalog = GuitarPracticeMaterials.fromJson(raw);
    expect(raw['status'], guitarPracticeCandidateStatus);
    expect(raw['sourceManifestSha256'], guitarPracticeSourceManifestSha256);
    expect(catalog.assets.length, 11);
    expect(catalog.lessonTasks.keys.toList(), guitarPracticeTargetLessonIds);
    expect(catalog.lessonTasks.values.first, isA<GuitarContourTask>());
    expect(catalog.lessonTasks.values.elementAt(1), isA<GuitarRhythmTask>());
    expect(catalog.lessonTasks.values.elementAt(2), isA<GuitarBackingTask>());
    expect(
      catalog.lessonTasks.values.elementAt(5),
      isA<GuitarPreparedPieceTask>(),
    );
    expect(catalog.piece.bars.length, 8);
    expect(
      catalog.piece.bars.map((bar) => bar.fold<int>(0, (n, e) => n + e.ticks)),
      everyElement(8),
    );
    expect(catalog.piece.bars[0][0].sounding, 'E4');
    expect(catalog.piece.bars[0][0].written, 'E5');
    expect(catalog.piece.bars[0][0].stringNumber, 1);
    expect(catalog.piece.bars[0][0].fret, 0);
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('guitar_practice_materials'), isFalse);
    expect(pubspec.contains('assets/audio/guitar_journey'), isFalse);
  });

  test('candidate metadata and score match the original source manifest', () {
    final raw = source();
    // scratch/ is workspace evidence, not a repository or Flutter asset. In
    // standalone app CI the fixed digest and per-asset identities in the
    // parser remain the portable baseline; here we additionally compare the
    // preserved original manifest when it is present.
    final file = File(
      '../../../scratch/2026-09-28-ostinato-original-audio-candidates-v1/'
      'candidate-manifest.json',
    );
    if (!file.existsSync()) {
      expect(raw['sourceManifestSha256'], guitarPracticeSourceManifestSha256);
      expect(GuitarPracticeMaterials.fromJson(raw).assets.length, 11);
      return;
    }
    expect(sha256OfWorkspaceManifest(file), raw['sourceManifestSha256']);
    final manifest =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final sourceAssets = manifest['assets'] as Map<String, dynamic>;
    final candidateAssets = raw['assets'] as Map<String, dynamic>;
    expect(candidateAssets.keys.toSet(), sourceAssets.keys.toSet());
    expect((raw['format'] as Map)['sampleRateHz'], manifest['sampleRateHz']);
    expect((raw['format'] as Map)['channels'], manifest['channels']);
    expect((raw['format'] as Map)['sampleBits'], manifest['sampleBits']);
    for (final id in sourceAssets.keys) {
      final expected = sourceAssets[id] as Map<String, dynamic>;
      final actual = candidateAssets[id] as Map<String, dynamic>;
      for (final field in [
        'path',
        'sha256',
        'bytes',
        'durationSeconds',
        'role',
      ]) {
        expect(actual[field], expected[field], reason: '$id.$field');
      }
      expect(actual['tempoBpm'], expected['tempoBpm'], reason: '$id tempo');
    }
    final authoredTasks = tasks(raw);
    final contourCues =
        (authoredTasks[0] as Map<String, dynamic>)['cues'] as List<dynamic>;
    for (final cue in contourCues) {
      final item = cue as Map<String, dynamic>;
      final contract =
          (sourceAssets[item['assetId']] as Map<String, dynamic>)['contract']
              as Map<String, dynamic>;
      expect(item['answerDirection'], contract['answerDirection']);
      expect(item['soundingPitches'], contract['soundingPitches']);
    }
    final rhythmCues =
        (authoredTasks[1] as Map<String, dynamic>)['cues'] as List<dynamic>;
    for (final cue in rhythmCues) {
      final item = cue as Map<String, dynamic>;
      final contract =
          (sourceAssets[item['assetId']] as Map<String, dynamic>)['contract']
              as Map<String, dynamic>;
      expect(item['bars'], contract['bars']);
      expect(
        item['attackBeatOffsetsAfterCountIn'],
        contract['attackBeatOffsetsAfterCountIn'],
      );
    }
    for (final taskIndex in [2, 3, 4]) {
      final item = authoredTasks[taskIndex] as Map<String, dynamic>;
      final contract =
          (sourceAssets[item['assetId']] as Map<String, dynamic>)['contract']
              as Map<String, dynamic>;
      expect(item['barChords'], contract['barChords']);
      expect(item['countInBars'], contract['countInBars']);
    }
    final expectedPiece =
        (sourceAssets['piece_55_melody'] as Map<String, dynamic>)['contract']
            as Map<String, dynamic>;
    expect(piece(raw)['barChords'], expectedPiece['barChords']);
    final actualEvents = <Map<String, dynamic>>[];
    final bars = piece(raw)['bars'] as List<dynamic>;
    for (var barIndex = 0; barIndex < bars.length; barIndex++) {
      var tick = 0;
      for (final rawEvent in bars[barIndex] as List<dynamic>) {
        final event = rawEvent as Map<String, dynamic>;
        actualEvents.add({
          'bar': barIndex + 1,
          'startTick': tick,
          'sounding': event['sounding'],
          'ticks': event['ticks'],
        });
        tick += event['ticks'] as int;
      }
    }
    expect(actualEvents, expectedPiece['events']);
    for (final id in ['piece_55_sparse', 'piece_55_backing']) {
      final contract =
          (sourceAssets[id] as Map<String, dynamic>)['contract']
              as Map<String, dynamic>;
      expect(contract['barChords'], expectedPiece['barChords']);
      expect(contract['events'], expectedPiece['events']);
    }
  });

  test('unapproved status and skill-evidence boundary fail closed', () {
    final raw = source();
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (value) => value['status'] = 'active',
      (value) => (tasks(value)[0] as Map)['status'] = 'active',
      (value) => (value['assets'] as Map)['contour_07_a']['status'] = 'active',
      (value) => piece(value)['status'] = 'active',
      (value) => (value['evidence'] as Map)['learnerScoring'] = true,
      (value) => (value['evidence'] as Map)['trainingGroundTruth'] = true,
    ]) {
      final bad = copy(raw);
      mutate(bad);
      expect(
        () => GuitarPracticeMaterials.fromJson(bad),
        throwsFormatException,
      );
    }
  });

  test('asset identities, roles, and exact eight refs fail closed', () {
    final raw = source();
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (value) => (value['assets'] as Map).remove('piece_55_backing'),
      (value) => (value['assets'] as Map)['surprise'] =
          (value['assets'] as Map)['contour_07_a'],
      (value) => (value['assets'] as Map)['contour_07_a']['sha256'] =
          List.filled(64, '0').join(),
      (value) => (value['assets'] as Map)['contour_07_a']['role'] =
          'eight_bar_original_reference_melody',
      (value) => tasks(value).removeLast(),
      (value) => tasks(value).add(tasks(value).last),
      (value) => (tasks(value)[0] as Map)['lessonId'] = 'wrong.lesson',
      (value) => ((tasks(value)[0] as Map)['cues'] as List)[0]['assetId'] =
          'contour_07_b',
      (value) => ((tasks(value)[5] as Map)['assetIds'] as List).removeLast(),
    ]) {
      final bad = copy(raw);
      mutate(bad);
      expect(
        () => GuitarPracticeMaterials.fromJson(bad),
        throwsFormatException,
      );
    }
  });

  test('invalid rhythm, measure length, chord plan, and pitch TAB fail', () {
    final raw = source();
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (value) =>
          (((tasks(value)[1] as Map)['cues'] as List)[0]['bars']
                  as List)[0][0][1] =
              3,
      (value) => (piece(value)['bars'] as List).removeLast(),
      (value) => ((piece(value)['bars'] as List)[0] as List)[0]['ticks'] = 4,
      (value) => (piece(value)['barChords'] as List)[0] = 'G',
      (value) => ((piece(value)['bars'] as List)[0] as List)[0]['string'] = 2,
      (value) =>
          ((piece(value)['bars'] as List)[0] as List)[0]['sounding'] = 'F4',
    ]) {
      final bad = copy(raw);
      mutate(bad);
      expect(
        () => GuitarPracticeMaterials.fromJson(bad),
        throwsFormatException,
      );
    }
  });

  test('renderer pins reject valid-looking rhythm and melody drift', () {
    final wrongRhythm = copy(source());
    final cues =
        (tasks(wrongRhythm)[1] as Map<String, dynamic>)['cues']
            as List<dynamic>;
    final a = cues[0] as Map<String, dynamic>;
    final b = cues[1] as Map<String, dynamic>;
    a['bars'] = b['bars'];
    a['attackBeatOffsetsAfterCountIn'] = b['attackBeatOffsetsAfterCountIn'];
    expect(
      () => GuitarPracticeMaterials.fromJson(wrongRhythm),
      throwsFormatException,
    );

    final wrongMelody = copy(source());
    final lastBar = (piece(wrongMelody)['bars'] as List<dynamic>).last as List;
    final finalNote = lastBar.last as Map<String, dynamic>;
    expect(finalNote['sounding'], 'C4');
    finalNote['sounding'] = 'E4';
    finalNote['string'] = 1;
    finalNote['fret'] = 0;
    expect(
      () => GuitarPracticeMaterials.fromJson(wrongMelody),
      throwsFormatException,
    );
  });

  test(
    'the shipped 60th first-read remains four bars and no revision ships',
    () {
      final course =
          jsonDecode(
                File(
                  'assets/content/guitar_journey.v1.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final lessons = <Map<String, dynamic>>[
        for (final module in course['modules'] as List<dynamic>)
          for (final lesson in (module as Map)['lessons'] as List<dynamic>)
            lesson as Map<String, dynamic>,
      ];
      expect(lessons.length, 60);
      expect(
        lessons.where((lesson) => lesson.containsKey('progressRevision')),
        isEmpty,
      );
      expect(lessons.last['id'], 'guitar.journey.independent.next_cycle');
      final drills =
          (lessons.last['learningLab'] as Map<String, dynamic>)['drills']
              as List;
      final firstRead =
          (drills.cast<Map<String, dynamic>>().singleWhere(
                (drill) => drill.containsKey('firstReadScore'),
              ))['firstReadScore']
              as Map<String, dynamic>;
      expect(firstRead['meter'], '4/4');
      expect(firstRead['ticksPerQuarter'], 2);
      expect(firstRead['pitchFrame'], 'sounding');
      final bars = firstRead['bars'] as List<dynamic>;
      expect(bars.length, 4);
      final notation = [
        for (final bar in bars)
          [
            for (final event in bar as List<dynamic>)
              '${(event as Map)['sounding'] ?? 'rest'}:${event['ticks']}',
          ].join(' '),
      ];
      expect(notation, [
        'E4:2 F4:2 G4:2 F4:2',
        'B3:2 C4:1 D4:1 C4:2 rest:2',
        'G3:2 B3:2 D4:1 C4:1 B3:2',
        'E4:2 G4:2 rest:2 E4:2',
      ]);
    },
  );
}
