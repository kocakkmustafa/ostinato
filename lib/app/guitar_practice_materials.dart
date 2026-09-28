// An offline, unapproved authoring contract. This file does not load audio,
// expose a learner task, change course progress, or certify playing ability.
// The source JSON intentionally lives under tool/, outside bundled assets.

const guitarPracticeCandidateStatus = 'candidate_unapproved';
const guitarPracticeSourceManifestSha256 =
    'cba7ebc0b0b3f1a2b4526ab25fbc4b4f85540ee5081242f6c2726a6e0b5fe8bb';

const guitarPracticeTargetLessonIds = <String>[
  'guitar.journey.notes.bass_e',
  'guitar.journey.reading.quarters_eighths',
  'guitar.journey.strum.accompaniment',
  'guitar.journey.harmony.blues_form',
  'guitar.journey.intermediate.blues_improv',
  'guitar.journey.independent.choose_piece',
  'guitar.journey.independent.arrange',
  'guitar.journey.independent.self_review',
];

final class _ExpectedAudio {
  const _ExpectedAudio(this.role, this.sha256, this.bytes, this.tempoBpm);

  final String role;
  final String sha256;
  final int bytes;
  final int? tempoBpm;
}

const _expectedAudio = <String, _ExpectedAudio>{
  'contour_07_a': _ExpectedAudio(
    'hidden_answer_contour',
    '917f8e654a80c55981c71fc0e8d38cdbca433959e283b3f4d0c85eac00a0d45a',
    98444,
    null,
  ),
  'contour_07_b': _ExpectedAudio(
    'hidden_answer_contour',
    '3d294c1d475d6055510c7c89a883e53516cf1c844b3ebc7661af015b62baeb57',
    98444,
    null,
  ),
  'contour_07_c': _ExpectedAudio(
    'hidden_answer_contour',
    '686ae8c63ce6453b5f533e8ff9cf68df1825de2c8b9f0adf9cdbe38d6b802306',
    98444,
    null,
  ),
  'contour_07_d': _ExpectedAudio(
    'hidden_answer_contour',
    '591680a3a812b365ebe457584d2a5b8057e6ba90ecba48f5eaf5d99197e96688',
    98444,
    null,
  ),
  'rhythm_13_a': _ExpectedAudio(
    'rhythm_echo_constant_beat',
    '927b87c5726f9deb45210eeb1d80cac1ca7e027815f0bacd1ea7e1cab6eb9ebd',
    440684,
    80,
  ),
  'rhythm_13_b': _ExpectedAudio(
    'rhythm_echo_constant_beat',
    '2aafb9aec7ee6ba2a4c6d3009e85e9cf4c08c766dcb716f1f7ec781a7f7f185b',
    440684,
    80,
  ),
  'backing_30': _ExpectedAudio(
    'continuous_16_bar_backing',
    '21aaec56aa3173b004ecadff5c797cf425cb9ce4d7085a8db1f709486b1b723b',
    2732044,
    72,
  ),
  'backing_40_54': _ExpectedAudio(
    'continuous_two_chorus_12_bar_backing',
    '0996fc581b0508858d25d704da0c0dbfaa340aebf55cec229f0e592e9a6b7bf4',
    3612044,
    80,
  ),
  'piece_55_melody': _ExpectedAudio(
    'eight_bar_original_reference_melody',
    'b29413326d7b5fe897362082d3e57f667f4d6ca740cb1d0af9fe6d44b5dfdb85',
    1310444,
    80,
  ),
  'piece_55_sparse': _ExpectedAudio(
    'eight_bar_original_reference_optional_harmony',
    '429e5323bc8548fe23986fb4a2d68b8fb9bc58902e65e3f607d03c398811eac4',
    1310444,
    80,
  ),
  'piece_55_backing': _ExpectedAudio(
    'eight_bar_original_play_along_without_melody',
    '6eecc71fb184e9f89755ba4cbf2d4b961a8738616305a91428a0469fc6a3d158',
    1310444,
    80,
  ),
};

const _contourAssets = <String>[
  'contour_07_a',
  'contour_07_b',
  'contour_07_c',
  'contour_07_d',
];
const _rhythmAssets = <String>['rhythm_13_a', 'rhythm_13_b'];
// Frozen renderer contracts: an internally consistent answer is insufficient
// if it describes a different cue than the WAV bound to that asset ID.
const _rhythmBars = <String, List<List<(String, int)>>>{
  'rhythm_13_a': [
    [('hit', 2), ('rest', 2), ('hit', 1), ('hit', 1), ('rest', 2)],
    [('hit', 2), ('hit', 2), ('rest', 2), ('hit', 2)],
  ],
  'rhythm_13_b': [
    [('hit', 2), ('hit', 2), ('rest', 2), ('hit', 2)],
    [('hit', 1), ('hit', 1), ('rest', 2), ('hit', 2), ('rest', 2)],
  ],
};
const _rhythmOnsets = <String, List<double>>{
  'rhythm_13_a': [0, 2, 2.5, 4, 5, 7],
  'rhythm_13_b': [0, 1, 3, 4, 4.5, 6],
};
const _pieceAssets = <String>[
  'piece_55_melody',
  'piece_55_sparse',
  'piece_55_backing',
];
const _pieceChords = <String>['C', 'Am', 'Fmaj7', 'G', 'C', 'Fmaj7', 'G', 'C'];
// Sounding pitches and durations from the frozen eight-bar renderer. TAB is
// checked independently against standard tuning below.
const _pieceEvents = <List<(String?, int)>>[
  [('E4', 2), ('G4', 2), ('E4', 2), ('C4', 2)],
  [('C4', 2), ('E4', 2), ('A3', 2), (null, 2)],
  [('F4', 2), ('E4', 2), ('C4', 2), ('A3', 2)],
  [('D4', 2), ('B3', 2), ('G3', 2), (null, 2)],
  [('E4', 2), ('G4', 1), ('E4', 1), ('C4', 4)],
  [('A3', 2), ('C4', 2), ('E4', 2), ('F4', 2)],
  [('G3', 2), ('B3', 1), ('D4', 1), ('B3', 2), ('G3', 2)],
  [('C4', 2), ('E4', 2), ('C4', 4)],
];
const _backing30Chords = <String>[
  'G',
  'D',
  'Em',
  'C',
  'G',
  'D',
  'Em',
  'C',
  'G',
  'D',
  'Em',
  'C',
  'G',
  'D',
  'Em',
  'C',
];
const _bluesChorus = <String>[
  'A',
  'A',
  'A',
  'A',
  'D',
  'D',
  'A',
  'A',
  'E',
  'D',
  'A',
  'E',
];
const _soundingMidi = <String, int>{
  'G3': 55,
  'A3': 57,
  'B3': 59,
  'C4': 60,
  'D4': 62,
  'E4': 64,
  'F4': 65,
  'G4': 67,
};
const _tab = <String, (int, int)>{
  'E4': (1, 0),
  'F4': (1, 1),
  'G4': (1, 3),
  'B3': (2, 0),
  'C4': (2, 1),
  'D4': (2, 3),
  'G3': (3, 0),
  'A3': (3, 2),
};

Map<String, dynamic> _object(Object? value, String path) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$path: object required');
  }
  return value;
}

List<dynamic> _array(Object? value, String path) {
  if (value is! List<dynamic>) {
    throw FormatException('$path: array required');
  }
  return value;
}

String _string(Object? value, String path) {
  if (value is! String || value.isEmpty) {
    throw FormatException('$path: nonempty string required');
  }
  return value;
}

int _integer(Object? value, String path) {
  if (value is! int) throw FormatException('$path: integer required');
  return value;
}

void _fields(
  Map<String, dynamic> json,
  String path,
  Set<String> required, [
  Set<String> optional = const {},
]) {
  if (!json.keys.toSet().containsAll(required) ||
      json.keys.toSet().difference(required.union(optional)).isNotEmpty) {
    throw FormatException('$path: unexpected or missing fields');
  }
}

void _status(Map<String, dynamic> json, String path) {
  if (json['status'] != guitarPracticeCandidateStatus) {
    throw FormatException('$path: only unapproved candidates allowed');
  }
}

List<String> _strings(Object? value, String path) =>
    List.unmodifiable(_array(value, path).map((item) => _string(item, path)));

void _sameList(List<String> actual, List<String> expected, String path) {
  if (actual.length != expected.length ||
      List.generate(
        actual.length,
        (i) => actual[i] == expected[i],
      ).contains(false)) {
    throw FormatException('$path: wrong order or reference');
  }
}

final class GuitarCandidateAudioAsset {
  const GuitarCandidateAudioAsset({
    required this.id,
    required this.sourcePath,
    required this.role,
    required this.sha256,
    required this.bytes,
    required this.durationSeconds,
    required this.tempoBpm,
  });

  final String id;
  final String sourcePath;
  final String role;
  final String sha256;
  final int bytes;
  final double durationSeconds;
  final int? tempoBpm;

  factory GuitarCandidateAudioAsset.fromJson(
    String id,
    Map<String, dynamic> json,
  ) {
    final expected = _expectedAudio[id];
    if (expected == null) throw FormatException('Unknown audio candidate $id');
    _fields(
      json,
      id,
      {'path', 'role', 'sha256', 'bytes', 'durationSeconds', 'status'},
      {'tempoBpm'},
    );
    _status(json, id);
    final path = _string(json['path'], '$id.path');
    final role = _string(json['role'], '$id.role');
    final sha = _string(json['sha256'], '$id.sha256');
    final bytes = _integer(json['bytes'], '$id.bytes');
    final duration = json['durationSeconds'];
    final bpm = json['tempoBpm'];
    if (path != 'wav/$id.wav' ||
        role != expected.role ||
        sha != expected.sha256 ||
        bytes != expected.bytes ||
        duration is! num ||
        !duration.toDouble().isFinite ||
        (duration.toDouble() - (bytes - 44) / 48000).abs() > 0.001 ||
        bpm != expected.tempoBpm) {
      throw FormatException('$id: candidate manifest metadata mismatch');
    }
    return GuitarCandidateAudioAsset(
      id: id,
      sourcePath: path,
      role: role,
      sha256: sha,
      bytes: bytes,
      durationSeconds: duration.toDouble(),
      tempoBpm: bpm as int?,
    );
  }
}

sealed class GuitarPracticeLessonTask {
  const GuitarPracticeLessonTask(this.lessonId);
  final String lessonId;
  List<String> get assetIds;
}

final class GuitarContourCue {
  const GuitarContourCue(this.assetId, this.answerDirection, this.pitches);
  final String assetId;
  final String answerDirection;
  final List<String> pitches;
}

final class GuitarContourTask extends GuitarPracticeLessonTask {
  const GuitarContourTask(super.lessonId, this.cues);
  final List<GuitarContourCue> cues;
  @override
  List<String> get assetIds =>
      List.unmodifiable(cues.map((cue) => cue.assetId));
}

final class GuitarRhythmEvent {
  const GuitarRhythmEvent(this.kind, this.ticks);
  final String kind;
  final int ticks;
}

final class GuitarRhythmCue {
  const GuitarRhythmCue(this.assetId, this.bars, this.attackBeatOffsets);
  final String assetId;
  final List<List<GuitarRhythmEvent>> bars;
  final List<double> attackBeatOffsets;
}

final class GuitarRhythmTask extends GuitarPracticeLessonTask {
  const GuitarRhythmTask(super.lessonId, this.tempoBpm, this.cues);
  final int tempoBpm;
  final List<GuitarRhythmCue> cues;
  @override
  List<String> get assetIds =>
      List.unmodifiable(cues.map((cue) => cue.assetId));
}

final class GuitarBackingTask extends GuitarPracticeLessonTask {
  const GuitarBackingTask(
    super.lessonId,
    this.assetId,
    this.tempoBpm,
    this.barChords,
  );
  final String assetId;
  final int tempoBpm;
  final List<String> barChords;
  @override
  List<String> get assetIds => [assetId];
}

final class GuitarPreparedPieceTask extends GuitarPracticeLessonTask {
  const GuitarPreparedPieceTask(super.lessonId, this.pieceId, this.assetIds);
  final String pieceId;
  @override
  final List<String> assetIds;
}

final class GuitarPreparedEvent {
  const GuitarPreparedEvent({
    required this.ticks,
    this.sounding,
    this.stringNumber,
    this.fret,
  });
  final int ticks;
  final String? sounding;
  final int? stringNumber;
  final int? fret;
  bool get isRest => sounding == null;
  String? get written => sounding == null
      ? null
      : '${sounding![0]}${int.parse(sounding!.substring(1)) + 1}';
}

final class GuitarPreparedPiece {
  const GuitarPreparedPiece(this.id, this.titleEn, this.titleTr, this.bars);
  final String id;
  final String titleEn;
  final String titleTr;
  final List<List<GuitarPreparedEvent>> bars;

  factory GuitarPreparedPiece.fromJson(Map<String, dynamic> json) {
    _fields(json, 'preparedPiece', {
      'id',
      'status',
      'title',
      'meter',
      'ticksPerQuarter',
      'pitchFrame',
      'writtenOctaveOffset',
      'tempoBpm',
      'countInBars',
      'barChords',
      'bars',
    });
    _status(json, 'preparedPiece');
    if (json['id'] != 'return_home_v1' ||
        json['meter'] != '4/4' ||
        json['ticksPerQuarter'] != 2 ||
        json['pitchFrame'] != 'sounding' ||
        json['writtenOctaveOffset'] != 1 ||
        json['tempoBpm'] != 80 ||
        json['countInBars'] != 1) {
      throw const FormatException('Invalid eight-bar prepared piece header');
    }
    final title = _object(json['title'], 'preparedPiece.title');
    _fields(title, 'preparedPiece.title', {'en', 'tr'});
    final chords = _strings(json['barChords'], 'preparedPiece.barChords');
    _sameList(chords, _pieceChords, 'preparedPiece.barChords');
    final rawBars = _array(json['bars'], 'preparedPiece.bars');
    if (rawBars.length != 8) {
      throw const FormatException('Prepared piece requires eight bars');
    }
    final bars = <List<GuitarPreparedEvent>>[];
    for (var index = 0; index < rawBars.length; index++) {
      final rawEvents = _array(rawBars[index], 'piece bar ${index + 1}');
      if (rawEvents.isEmpty) {
        throw FormatException('Empty piece bar ${index + 1}');
      }
      if (rawEvents.length != _pieceEvents[index].length) {
        throw FormatException('Piece bar ${index + 1} differs from renderer');
      }
      final events = <GuitarPreparedEvent>[];
      var position = 0;
      for (final raw in rawEvents) {
        final event = _object(raw, 'piece event');
        final ticks = _integer(event['ticks'], 'piece event ticks');
        if (ticks != 1 && ticks != 2 && ticks != 4) {
          throw const FormatException('Invalid prepared piece duration');
        }
        if (event['rest'] == true) {
          _fields(event, 'piece rest', {'rest', 'ticks'});
          if (ticks != 2) {
            throw const FormatException('Only quarter rests are authored');
          }
          events.add(GuitarPreparedEvent(ticks: ticks));
        } else {
          _fields(event, 'piece note', {'sounding', 'string', 'fret', 'ticks'});
          final pitch = _string(event['sounding'], 'piece sounding');
          final stringNumber = _integer(event['string'], 'piece string');
          final fret = _integer(event['fret'], 'piece fret');
          final expectedTab = _tab[pitch];
          const openMidi = <int>[0, 64, 59, 55, 50, 45, 40];
          if (expectedTab == null ||
              stringNumber != expectedTab.$1 ||
              fret != expectedTab.$2 ||
              openMidi[stringNumber] + fret != _soundingMidi[pitch]) {
            throw const FormatException('Sounding pitch and TAB disagree');
          }
          events.add(
            GuitarPreparedEvent(
              ticks: ticks,
              sounding: pitch,
              stringNumber: stringNumber,
              fret: fret,
            ),
          );
        }
        if (ticks == 4 && position % 2 != 0 ||
            ticks == 2 && position % 2 != 0) {
          throw const FormatException('Note crosses a beat boundary');
        }
        position += ticks;
      }
      if (position != 8) {
        throw FormatException('Piece bar ${index + 1} is not eight ticks');
      }
      for (var i = 0; i < events.length; i++) {
        final expected = _pieceEvents[index][i];
        if (events[i].sounding != expected.$1 ||
            events[i].ticks != expected.$2) {
          throw FormatException('Piece bar ${index + 1} differs from renderer');
        }
      }
      var onset = 0;
      for (var i = 0; i < events.length; i++) {
        if (events[i].ticks == 1) {
          final pairIndex = onset.isEven ? i + 1 : i - 1;
          if (pairIndex < 0 ||
              pairIndex >= events.length ||
              events[pairIndex].ticks != 1) {
            throw const FormatException('Unpaired eighth note');
          }
        }
        onset += events[i].ticks;
      }
      bars.add(List.unmodifiable(events));
    }
    return GuitarPreparedPiece(
      json['id'] as String,
      _string(title['en'], 'piece title.en'),
      _string(title['tr'], 'piece title.tr'),
      List.unmodifiable(bars),
    );
  }
}

final class GuitarPracticeMaterials {
  const GuitarPracticeMaterials(this.assets, this.lessonTasks, this.piece);
  final Map<String, GuitarCandidateAudioAsset> assets;
  final Map<String, GuitarPracticeLessonTask> lessonTasks;
  final GuitarPreparedPiece piece;

  factory GuitarPracticeMaterials.fromJson(Map<String, dynamic> json) {
    _fields(json, 'materials', {
      'schemaVersion',
      'status',
      'sourceManifestSha256',
      'provenance',
      'evidence',
      'format',
      'assets',
      'lessonTasks',
      'preparedPiece',
    });
    _status(json, 'materials');
    if (json['schemaVersion'] != 1 ||
        json['sourceManifestSha256'] != guitarPracticeSourceManifestSha256 ||
        json['provenance'] !=
            'Original mathematical synthesis; no external recording, sample, voice, or downloaded media') {
      throw const FormatException('Invalid candidate provenance');
    }
    final evidence = _object(json['evidence'], 'evidence');
    _fields(evidence, 'evidence', {
      'educatorApproved',
      'devicePlaybackAccepted',
      'trainingGroundTruth',
      'learnerScoring',
      'completionEvidence',
    });
    if (evidence['educatorApproved'] != false ||
        evidence['devicePlaybackAccepted'] != false ||
        evidence['trainingGroundTruth'] != false ||
        evidence['learnerScoring'] != false ||
        evidence['completionEvidence'] != 'self_report_only') {
      throw const FormatException(
        'Candidate cannot claim accepted skill evidence',
      );
    }
    final format = _object(json['format'], 'format');
    _fields(format, 'format', {
      'container',
      'encoding',
      'sampleRateHz',
      'channels',
      'sampleBits',
    });
    if (format['container'] != 'WAV' ||
        format['encoding'] != 'PCM_S16LE' ||
        format['sampleRateHz'] != 24000 ||
        format['channels'] != 1 ||
        format['sampleBits'] != 16) {
      throw const FormatException('Unexpected candidate audio format');
    }
    final rawAssets = _object(json['assets'], 'assets');
    if (rawAssets.keys
            .toSet()
            .difference(_expectedAudio.keys.toSet())
            .isNotEmpty ||
        _expectedAudio.keys
            .toSet()
            .difference(rawAssets.keys.toSet())
            .isNotEmpty) {
      throw const FormatException('Exactly eleven candidate assets required');
    }
    final assets = <String, GuitarCandidateAudioAsset>{};
    for (final id in _expectedAudio.keys) {
      assets[id] = GuitarCandidateAudioAsset.fromJson(
        id,
        _object(rawAssets[id], 'assets.$id'),
      );
    }
    final rawTasks = _array(json['lessonTasks'], 'lessonTasks');
    if (rawTasks.length != guitarPracticeTargetLessonIds.length) {
      throw const FormatException('Exactly eight lesson references required');
    }
    final tasks = <String, GuitarPracticeLessonTask>{};
    for (var i = 0; i < rawTasks.length; i++) {
      final raw = _object(rawTasks[i], 'lessonTasks[$i]');
      final id = _string(raw['lessonId'], 'lesson ID');
      if (id != guitarPracticeTargetLessonIds[i] || tasks.containsKey(id)) {
        throw const FormatException(
          'Wrong, duplicate, or reordered lesson reference',
        );
      }
      _status(raw, id);
      GuitarPracticeLessonTask task;
      if (i == 0) {
        _fields(raw, id, {'lessonId', 'kind', 'status', 'cues'});
        if (raw['kind'] != 'contour') {
          throw FormatException('$id: wrong task kind');
        }
        final rawCues = _array(raw['cues'], '$id.cues');
        if (rawCues.length != 4) {
          throw FormatException('$id: four cues required');
        }
        final cues = <GuitarContourCue>[];
        const expectedPitches = <String, List<String>>{
          'contour_07_a': ['E4', 'G4'],
          'contour_07_b': ['G4', 'F4'],
          'contour_07_c': ['E4', 'F4'],
          'contour_07_d': ['G4', 'E4'],
        };
        for (var j = 0; j < rawCues.length; j++) {
          final cue = _object(rawCues[j], '$id.cues[$j]');
          _fields(cue, '$id.cues[$j]', {
            'assetId',
            'answerDirection',
            'soundingPitches',
          });
          final assetId = _string(cue['assetId'], 'contour asset');
          if (assetId != _contourAssets[j]) {
            throw const FormatException('Wrong contour asset reference');
          }
          final pitches = _strings(cue['soundingPitches'], 'contour pitches');
          _sameList(pitches, expectedPitches[assetId]!, 'contour pitches');
          final direction = _string(cue['answerDirection'], 'contour answer');
          if (direction !=
              (_soundingMidi[pitches[1]]! > _soundingMidi[pitches[0]]!
                  ? 'up'
                  : 'down')) {
            throw const FormatException('Incorrect contour answer key');
          }
          cues.add(GuitarContourCue(assetId, direction, pitches));
        }
        task = GuitarContourTask(id, List.unmodifiable(cues));
      } else if (i == 1) {
        _fields(raw, id, {'lessonId', 'kind', 'status', 'tempoBpm', 'cues'});
        if (raw['kind'] != 'rhythmEcho' || raw['tempoBpm'] != 80) {
          throw FormatException('$id: wrong rhythm task');
        }
        final rawCues = _array(raw['cues'], '$id.cues');
        if (rawCues.length != 2) {
          throw FormatException('$id: two cues required');
        }
        final cues = <GuitarRhythmCue>[];
        for (var j = 0; j < rawCues.length; j++) {
          final cue = _object(rawCues[j], '$id.cues[$j]');
          _fields(cue, '$id.cues[$j]', {
            'assetId',
            'countInBars',
            'attackBeatOffsetsAfterCountIn',
            'bars',
          });
          final assetId = _string(cue['assetId'], 'rhythm asset');
          if (assetId != _rhythmAssets[j] || cue['countInBars'] != 1) {
            throw const FormatException('Wrong rhythm asset or count-in');
          }
          final rawBars = _array(cue['bars'], 'rhythm bars');
          if (rawBars.length != 2) {
            throw const FormatException('Rhythm cue requires two bars');
          }
          final bars = <List<GuitarRhythmEvent>>[];
          final onsets = <double>[];
          for (var barIndex = 0; barIndex < 2; barIndex++) {
            final rawEvents = _array(rawBars[barIndex], 'rhythm bar');
            final expectedEvents = _rhythmBars[assetId]![barIndex];
            if (rawEvents.length != expectedEvents.length) {
              throw const FormatException('Rhythm cue differs from renderer');
            }
            final events = <GuitarRhythmEvent>[];
            var tick = 0;
            for (
              var eventIndex = 0;
              eventIndex < rawEvents.length;
              eventIndex++
            ) {
              final rawEvent = rawEvents[eventIndex];
              final pair = _array(rawEvent, 'rhythm event');
              if (pair.length != 2 ||
                  (pair[0] != 'hit' && pair[0] != 'rest') ||
                  (pair[1] != 1 && pair[1] != 2)) {
                throw const FormatException('Invalid rhythm event');
              }
              final expected = expectedEvents[eventIndex];
              if (pair[0] != expected.$1 || pair[1] != expected.$2) {
                throw const FormatException('Rhythm cue differs from renderer');
              }
              if (pair[0] == 'hit') onsets.add(barIndex * 4 + tick / 2);
              events.add(GuitarRhythmEvent(pair[0] as String, pair[1] as int));
              tick += pair[1] as int;
            }
            if (tick != 8) throw const FormatException('Rhythm bar is not 4/4');
            bars.add(List.unmodifiable(events));
          }
          final rawOffsets = _array(
            cue['attackBeatOffsetsAfterCountIn'],
            'rhythm attack offsets',
          );
          if (rawOffsets.length != onsets.length ||
              List.generate(onsets.length, (k) {
                final value = rawOffsets[k];
                return value is num &&
                    (value.toDouble() - onsets[k]).abs() < 0.0001 &&
                    (value.toDouble() - _rhythmOnsets[assetId]![k]).abs() <
                        0.0001;
              }).contains(false)) {
            throw const FormatException('Rhythm hit onsets disagree with bars');
          }
          cues.add(
            GuitarRhythmCue(
              assetId,
              List.unmodifiable(bars),
              List.unmodifiable(onsets),
            ),
          );
        }
        task = GuitarRhythmTask(id, 80, List.unmodifiable(cues));
      } else if (i <= 4) {
        _fields(raw, id, {
          'lessonId',
          'kind',
          'status',
          'assetId',
          'tempoBpm',
          'countInBars',
          'barChords',
        });
        final expectedAsset = i == 2 ? 'backing_30' : 'backing_40_54';
        final expectedChords = i == 2
            ? _backing30Chords
            : [..._bluesChorus, ..._bluesChorus];
        final expectedBpm = i == 2 ? 72 : 80;
        if (raw['kind'] != 'continuousBacking' ||
            raw['assetId'] != expectedAsset ||
            raw['tempoBpm'] != expectedBpm ||
            raw['countInBars'] != 1) {
          throw FormatException('$id: wrong continuous backing reference');
        }
        final chords = _strings(raw['barChords'], '$id.barChords');
        _sameList(chords, expectedChords, '$id.barChords');
        task = GuitarBackingTask(id, expectedAsset, expectedBpm, chords);
      } else {
        _fields(raw, id, {'lessonId', 'kind', 'status', 'pieceId', 'assetIds'});
        final assetIds = _strings(raw['assetIds'], '$id.assetIds');
        _sameList(assetIds, _pieceAssets, '$id.assetIds');
        if (raw['kind'] != 'preparedPiece' ||
            raw['pieceId'] != 'return_home_v1') {
          throw FormatException('$id: wrong prepared piece reference');
        }
        task = GuitarPreparedPieceTask(id, 'return_home_v1', assetIds);
      }
      tasks[id] = task;
    }
    final piece = GuitarPreparedPiece.fromJson(
      _object(json['preparedPiece'], 'preparedPiece'),
    );
    return GuitarPracticeMaterials(
      Map.unmodifiable(assets),
      Map.unmodifiable(tasks),
      piece,
    );
  }
}
