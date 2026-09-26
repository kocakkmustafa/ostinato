import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

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

  List<GuitarJourneyLesson> get lessons => [
    for (final module in modules) ...module.lessons,
  ];

  static Future<GuitarJourneyCourse> load() async {
    final raw = await rootBundle.loadString(
      'assets/content/guitar_journey.v1.json',
    );
    return GuitarJourneyCourse.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
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
