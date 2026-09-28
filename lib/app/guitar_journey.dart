import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:motion_content/motion_content.dart';

import 'flutter_bundle_content_asset_reader.dart';

const String _guitarCourseAssetPath = 'assets/content/guitar_journey.v1.json';
const String _guitarIntegrityManifestPath =
    'assets/motion_content/manifest.json';

/// Original course copy is a separate, versioned asset. The legacy measured
/// posture library keeps its own honesty and lesson-status contract.
final class GuitarText {
  const GuitarText(this.en, this.tr);
  final String en;
  final String tr;

  String of(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'tr' ? tr : en;

  factory GuitarText.fromJson(Map<String, dynamic> json) =>
      GuitarText(json['en'] as String, json['tr'] as String);
}

GuitarText _text(Object? value) =>
    GuitarText.fromJson(value as Map<String, dynamic>);

String? _lessonProgressRevision(Object? value) {
  if (value == null) return null;
  if (value is! String || !RegExp(r'^[A-Za-z0-9._-]{1,64}$').hasMatch(value)) {
    throw const FormatException('Invalid guitar lesson progress revision');
  }
  return value;
}

final class GuitarJourneySource {
  const GuitarJourneySource({
    required this.id,
    required this.title,
    required this.url,
  });
  final String id;
  final String title;
  final String url;

  factory GuitarJourneySource.fromJson(Map<String, dynamic> json) =>
      GuitarJourneySource(
        id: json['id'] as String,
        title: json['title'] as String,
        url: json['url'] as String,
      );
}

final class GuitarChordShape {
  const GuitarChordShape({
    required this.id,
    required this.label,
    required this.frets6to1,
    required this.exampleFingers6to1,
  });
  final String id;
  final GuitarText label;
  final List<int?> frets6to1;
  final List<int?> exampleFingers6to1;

  factory GuitarChordShape.fromJson(Map<String, dynamic> json) =>
      GuitarChordShape(
        id: json['id'] as String,
        label: _text(json['label']),
        frets6to1: (json['frets6to1'] as List<dynamic>).cast<int?>(),
        exampleFingers6to1: (json['exampleFingers6to1'] as List<dynamic>)
            .cast<int?>(),
      );
}

final class GuitarTuningString {
  const GuitarTuningString(this.number, this.note, this.hz);
  final int number;
  final String note;
  final double hz;

  factory GuitarTuningString.fromJson(Map<String, dynamic> json) =>
      GuitarTuningString(
        json['string'] as int,
        json['note'] as String,
        (json['hz'] as num).toDouble(),
      );
}

/// An original fixed score for reading practice. Pitches are sounding guitar
/// pitches; standard treble-clef guitar notation is written an octave higher.
final class GuitarJourneyScoreEvent {
  const GuitarJourneyScoreEvent({required this.sounding, required this.ticks});

  final String? sounding;
  final int ticks;

  bool get isRest => sounding == null;
  String? get written => sounding == null
      ? null
      : '${sounding![0]}${int.parse(sounding!.substring(1)) + 1}';

  factory GuitarJourneyScoreEvent.fromJson(Map<String, dynamic> json) {
    final ticks = json['ticks'];
    if (ticks is! int || (ticks != 1 && ticks != 2)) {
      throw const FormatException('Invalid first-read note duration');
    }
    if (json['rest'] == true) {
      if (json.keys.toSet().difference({'rest', 'ticks'}).isNotEmpty ||
          json.length != 2 ||
          ticks != 2) {
        throw const FormatException('Invalid first-read quarter rest');
      }
      return GuitarJourneyScoreEvent(sounding: null, ticks: ticks);
    }
    const allowed = {'E4', 'F4', 'G4', 'B3', 'C4', 'D4', 'G3'};
    final sounding = json['sounding'];
    if (json.keys.toSet().difference({'sounding', 'ticks'}).isNotEmpty ||
        json.length != 2 ||
        sounding is! String ||
        !allowed.contains(sounding)) {
      throw const FormatException('Invalid first-read sounding pitch');
    }
    return GuitarJourneyScoreEvent(sounding: sounding, ticks: ticks);
  }
}

final class GuitarJourneyFirstReadScore {
  const GuitarJourneyFirstReadScore(this.bars);

  final List<List<GuitarJourneyScoreEvent>> bars;

  factory GuitarJourneyFirstReadScore.fromJson(Map<String, dynamic> json) {
    if (json.keys.toSet().difference({
          'meter',
          'ticksPerQuarter',
          'pitchFrame',
          'bars',
        }).isNotEmpty ||
        json.length != 4 ||
        json['meter'] != '4/4' ||
        json['ticksPerQuarter'] != 2 ||
        json['pitchFrame'] != 'sounding' ||
        json['bars'] is! List<dynamic>) {
      throw const FormatException('Invalid first-read score header');
    }
    final rawBars = json['bars'] as List<dynamic>;
    if (rawBars.length != 4) {
      throw const FormatException('First-read score requires four bars');
    }
    final bars = <List<GuitarJourneyScoreEvent>>[];
    for (final rawBar in rawBars) {
      if (rawBar is! List<dynamic>) {
        throw const FormatException('Invalid first-read bar');
      }
      final events = <GuitarJourneyScoreEvent>[
        for (final item in rawBar)
          GuitarJourneyScoreEvent.fromJson(item as Map<String, dynamic>),
      ];
      if (events.fold<int>(0, (sum, event) => sum + event.ticks) != 8) {
        throw const FormatException(
          'First-read 4/4 bar must contain eight ticks',
        );
      }
      var startTick = 0;
      for (var index = 0; index < events.length; index++) {
        final event = events[index];
        if (event.ticks == 1) {
          final partnerIndex = startTick.isEven ? index + 1 : index - 1;
          if (partnerIndex < 0 ||
              partnerIndex >= events.length ||
              events[partnerIndex].ticks != 1 ||
              events[partnerIndex].isRest) {
            throw const FormatException(
              'First-read eighth notes must form an adjacent pair in one beat',
            );
          }
        }
        startTick += event.ticks;
      }
      bars.add(List.unmodifiable(events));
    }
    return GuitarJourneyFirstReadScore(List.unmodifiable(bars));
  }
}

final class GuitarJourneyLabDrill {
  const GuitarJourneyLabDrill({
    required this.id,
    required this.stage,
    required this.task,
    required this.minutesRange,
    required this.rounds,
    required this.optionalExtension,
    this.firstReadScore,
  });

  final String id;
  final String stage;
  final GuitarText task;
  final List<int> minutesRange;
  final int rounds;
  final bool optionalExtension;
  final GuitarJourneyFirstReadScore? firstReadScore;

  factory GuitarJourneyLabDrill.fromJson(Map<String, dynamic> json) {
    final stage = json['stage'] as String;
    final minutes = List<int>.from(json['suggested_minutes_range'] as List);
    final rounds = json['suggested_rounds'] as int;
    if (!const ['foundation', 'connected', 'transfer'].contains(stage) ||
        minutes.length != 2 ||
        minutes.first < 1 ||
        minutes.last < minutes.first ||
        rounds < 1) {
      throw const FormatException('Invalid guitar practice drill');
    }
    return GuitarJourneyLabDrill(
      id: json['id'] as String,
      stage: stage,
      task: _text(json['task']),
      minutesRange: minutes,
      rounds: rounds,
      optionalExtension: json['optional_extension'] == true,
      firstReadScore: json['firstReadScore'] == null
          ? null
          : GuitarJourneyFirstReadScore.fromJson(
              json['firstReadScore'] as Map<String, dynamic>,
            ),
    );
  }
}

final class GuitarJourneyLearningLab {
  const GuitarJourneyLearningLab({
    required this.technicalFocus,
    required this.drills,
    required this.earTraining,
    required this.retentionTask,
    required this.reviewDays,
    required this.masteryCriteria,
    required this.sensorBoundary,
  });

  final GuitarText technicalFocus;
  final List<GuitarJourneyLabDrill> drills;
  final GuitarText earTraining;
  final GuitarText retentionTask;
  final List<int> reviewDays;
  final List<GuitarText> masteryCriteria;
  final GuitarText sensorBoundary;

  factory GuitarJourneyLearningLab.fromJson(Map<String, dynamic> json) {
    final retention = json['retention'] as Map<String, dynamic>;
    return GuitarJourneyLearningLab(
      technicalFocus: _text(json['technicalFocus']),
      drills: [
        for (final drill in json['drills'] as List<dynamic>)
          GuitarJourneyLabDrill.fromJson(drill as Map<String, dynamic>),
      ],
      earTraining: _text(json['earTraining']),
      retentionTask: _text(retention['task']),
      reviewDays: List<int>.from(retention['suggested_days'] as List),
      masteryCriteria: [
        for (final criterion in json['masteryCriteria'] as List<dynamic>)
          _text(criterion),
      ],
      sensorBoundary: _text(json['sensorBoundary']),
    );
  }
}

final class GuitarJourneyLesson {
  const GuitarJourneyLesson({
    required this.id,
    required this.title,
    required this.minutes,
    required this.prerequisiteIds,
    required this.objective,
    required this.teachingSteps,
    required this.practice,
    required this.selfCheck,
    required this.commonError,
    required this.adaptation,
    required this.stopSignal,
    required this.sourceIds,
    required this.shapeIds,
    required this.mediaStatus,
    required this.capstone,
    this.learningLab,
    this.progressRevision,
  });

  final String id;
  final GuitarText title;
  final int minutes;
  final List<String> prerequisiteIds;
  final GuitarText objective;
  final List<GuitarText> teachingSteps;
  final GuitarText practice;
  final GuitarText selfCheck;
  final GuitarText commonError;
  final GuitarText adaptation;
  final GuitarText stopSignal;
  final List<String> sourceIds;
  final List<String> shapeIds;
  final String mediaStatus;
  final bool capstone;
  final GuitarJourneyLearningLab? learningLab;

  /// Set only when a newly required lesson task is active. Historical records
  /// remain readable, while this lesson starts a separate self-report key.
  final String? progressRevision;

  String progressVersionFor(String courseContentVersion) =>
      progressRevision == null
      ? courseContentVersion
      : '$courseContentVersion~$progressRevision';

  factory GuitarJourneyLesson.fromJson(Map<String, dynamic> json) =>
      GuitarJourneyLesson(
        id: json['id'] as String,
        title: _text(json['title']),
        minutes: json['minutes'] as int,
        prerequisiteIds: List<String>.from(
          json['prerequisiteIds'] as List<dynamic>,
        ),
        objective: _text(json['objective']),
        teachingSteps: [
          for (final step in json['teachingSteps'] as List<dynamic>)
            _text(step),
        ],
        practice: _text(json['practice']),
        selfCheck: _text(json['selfCheck']),
        commonError: _text(json['commonError']),
        adaptation: _text(json['adaptation']),
        stopSignal: _text(json['stopSignal']),
        sourceIds: List<String>.from(json['sourceIds'] as List<dynamic>),
        shapeIds: List<String>.from(json['shapeIds'] as List<dynamic>),
        mediaStatus:
            (json['mediaBrief'] as Map<String, dynamic>)['status'] as String,
        capstone: json['capstone'] == 'original_performance',
        progressRevision: _lessonProgressRevision(json['progressRevision']),
        learningLab: json['learningLab'] == null
            ? null
            : GuitarJourneyLearningLab.fromJson(
                json['learningLab'] as Map<String, dynamic>,
              ),
      );
}

final class GuitarJourneyModule {
  const GuitarJourneyModule({
    required this.id,
    required this.title,
    required this.goal,
    required this.lessons,
  });
  final String id;
  final GuitarText title;
  final GuitarText goal;
  final List<GuitarJourneyLesson> lessons;

  factory GuitarJourneyModule.fromJson(Map<String, dynamic> json) =>
      GuitarJourneyModule(
        id: json['id'] as String,
        title: _text(json['title']),
        goal: _text(json['goal']),
        lessons: [
          for (final lesson in json['lessons'] as List<dynamic>)
            GuitarJourneyLesson.fromJson(lesson as Map<String, dynamic>),
        ],
      );
}

final class GuitarJourneyCourse {
  const GuitarJourneyCourse({
    required this.id,
    required this.contentVersion,
    required this.title,
    required this.summary,
    required this.completionStatement,
    required this.modules,
    required this.sources,
    required this.chordShapes,
    required this.tuning,
    this.curriculumRevision,
    this.progressSemantics,
  });

  final String id;
  final String contentVersion;
  final GuitarText title;
  final GuitarText summary;
  final GuitarText completionStatement;
  final List<GuitarJourneyModule> modules;
  final Map<String, GuitarJourneySource> sources;
  final Map<String, GuitarChordShape> chordShapes;
  final List<GuitarTuningString> tuning;
  final String? curriculumRevision;
  final GuitarText? progressSemantics;

  List<GuitarJourneyLesson> get lessons => [
    for (final module in modules) ...module.lessons,
  ];

  /// Verifies the packaged course bytes before any lesson is exposed.
  /// The manifest is an asset-integrity envelope, not a second curriculum.
  static Future<GuitarJourneyCourse> load({AssetBundle? bundle}) async {
    final ContentLoadResult result = await ContentBundleLoader(
      reader: FlutterBundleContentAssetReader(bundle: bundle),
      expectedAppId: 'com.yulalab.ostinato',
      currentCoreContract: currentMotionContentContract,
      manifestPath: _guitarIntegrityManifestPath,
    ).load();
    if (result is ContentBlocked) throw ContentException(result.error);
    if (result is! ContentReady) {
      throw const ContentException(
        ContentError(code: ContentErrorCode.capability),
      );
    }
    final bytes = await result.assets.read(_guitarCourseAssetPath);
    return GuitarJourneyCourse.fromJson(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
    );
  }

  factory GuitarJourneyCourse.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported guitar course schema');
    }
    final sources = [
      for (final source in json['sources'] as List<dynamic>)
        GuitarJourneySource.fromJson(source as Map<String, dynamic>),
    ];
    return GuitarJourneyCourse(
      id: json['id'] as String,
      contentVersion: json['contentVersion'] as String,
      curriculumRevision: json['curriculumRevision'] as String?,
      progressSemantics: json['progressSemantics'] == null
          ? null
          : _text(json['progressSemantics']),
      title: _text(json['title']),
      summary: _text(json['summary']),
      completionStatement: _text(json['completionStatement']),
      modules: [
        for (final module in json['modules'] as List<dynamic>)
          GuitarJourneyModule.fromJson(module as Map<String, dynamic>),
      ],
      sources: {for (final source in sources) source.id: source},
      chordShapes: {
        for (final shape in json['chordShapes'] as List<dynamic>)
          (shape as Map<String, dynamic>)['id'] as String:
              GuitarChordShape.fromJson(shape),
      },
      tuning: [
        for (final item in json['tuning'] as List<dynamic>)
          GuitarTuningString.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}
