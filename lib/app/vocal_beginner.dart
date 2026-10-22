import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:motion_content/motion_content.dart';
import 'flutter_bundle_content_asset_reader.dart';
import 'guitar_journey.dart' show GuitarText;

const vocalAsset = 'assets/content/vocal_beginner.v1.json';
const vocalPitchMode = 'personal-relative:L-M-H;no-fixed-interval';
Map<String, dynamic> _object(Object? value, Set<String> keys) {
  if (value is! Map<String, dynamic> ||
      value.length != keys.length ||
      !value.keys.toSet().containsAll(keys)) {
    throw const FormatException('Invalid vocal content fields');
  }
  return value;
}

GuitarText _copy(Object? value) {
  final m = _object(value, {'en', 'tr'});
  for (final locale in ['en', 'tr']) {
    if (m[locale] is! String || (m[locale] as String).trim().isEmpty) {
      throw const FormatException('Missing vocal translation');
    }
  }
  return GuitarText(m['en'] as String, m['tr'] as String);
}

final class VocalEvent {
  VocalEvent(Object? value) {
    if (value is! Map<String, dynamic> ||
        !const ['voice', 'hold', 'rest'].contains(value['kind'])) {
      throw const FormatException('Invalid vocal event');
    }
    kind = value['kind'] as String;
    final m = _object(
      value,
      kind == 'voice' ? {'kind', 'tone', 'syllable'} : {'kind'},
    );
    if (kind == 'voice') {
      if (!const ['L', 'M', 'H'].contains(m['tone'])) {
        throw const FormatException('Invalid personal tone');
      }
      tone = m['tone'] as String;
      syllable = _copy(m['syllable']);
    } else {
      tone = null;
      syllable = null;
    }
  }
  late final String kind;
  late final String? tone;
  late final GuitarText? syllable;
}

final class VocalStudyBar {
  VocalStudyBar(Object? value) {
    final m = _object(value, {'events'});
    if (m['events'] is! List || (m['events'] as List).length != 8) {
      throw const FormatException('Eight half-beats required');
    }
    events = List<VocalEvent>.unmodifiable([
      for (final e in m['events'] as List) VocalEvent(e),
    ]);
    if (events.first.kind == 'hold') {
      throw const FormatException('Bar must establish voice or silence');
    }
  }
  late final List<VocalEvent> events;
}

final class VocalLesson {
  VocalLesson(Object? value) {
    final m = _object(value, {
      'id',
      'title',
      'teach',
      'practice',
      'check',
      'recover',
      'diagrams',
    });
    if (m['id'] is! String ||
        !RegExp(r'^vocal-\d{2}$').hasMatch(m['id'] as String) ||
        m['diagrams'] is! List) {
      throw const FormatException('Invalid vocal lesson');
    }
    id = m['id'] as String;
    title = _copy(m['title']);
    sections = List<GuitarText>.unmodifiable([
      for (final key in ['teach', 'practice', 'check', 'recover'])
        _copy(m[key]),
    ]);
    final raw = m['diagrams'] as List;
    if (raw.any(
          (id) =>
              id is! String ||
              !const ['rhythm', 'contour', 'study'].contains(id),
        ) ||
        raw.toSet().length != raw.length) {
      throw const FormatException('Invalid vocal diagrams');
    }
    diagrams = List<String>.unmodifiable(raw.cast<String>());
  }
  late final String id;
  late final GuitarText title;
  late final List<GuitarText> sections;
  late final List<String> diagrams;
}

final class VocalCourse {
  VocalCourse.fromJson(Object? value) {
    final m = _object(value, {
      'schemaVersion',
      'id',
      'pitchMode',
      'title',
      'entry',
      'exit',
      'rhythmSymbols',
      'contour',
      'paperAnswers',
      'study',
      'lessons',
    });
    if (m['schemaVersion'] is! int ||
        m['schemaVersion'] != 1 ||
        m['id'] != 'voice.beginner.written' ||
        m['pitchMode'] != vocalPitchMode) {
      throw const FormatException('Invalid vocal course');
    }
    final symbols = _object(m['rhythmSymbols'], {'voice', 'hold', 'rest'});
    if (symbols['voice'] != 'V' ||
        symbols['hold'] != '=' ||
        symbols['rest'] != 'R') {
      throw const FormatException('Ambiguous rhythm symbols');
    }
    title = _copy(m['title']);
    entry = _copy(m['entry']);
    exit = _copy(m['exit']);
    final answers = _object(m['paperAnswers'], {'rhythm', 'contour'});
    rhythmAnswer = _copy(answers['rhythm']);
    contourAnswer = _copy(answers['contour']);
    if (m['contour'] is! List || (m['contour'] as List).length != 2) {
      throw const FormatException('Two contour bars required');
    }
    contour = List<List<String>>.unmodifiable([
      for (final row in m['contour'] as List) _contourRow(row),
    ]);
    if (m['study'] is! List || m['lessons'] is! List) {
      throw const FormatException('Missing vocal practice');
    }
    study = List<VocalStudyBar>.unmodifiable([
      for (final bar in m['study'] as List) VocalStudyBar(bar),
    ]);
    lessons = List<VocalLesson>.unmodifiable([
      for (final lesson in m['lessons'] as List) VocalLesson(lesson),
    ]);
    if (study.length != 8 || lessons.length != 22) {
      throw const FormatException('Incomplete vocal foundation');
    }
    for (var i = 0; i < lessons.length; i++) {
      if (lessons[i].id != 'vocal-${(i + 1).toString().padLeft(2, '0')}') {
        throw const FormatException('Invalid vocal lesson sequence');
      }
      final expected = switch (i + 1) {
        6 => ['rhythm'],
        9 => ['contour'],
        13 || 14 || 15 => ['study'],
        _ => <String>[],
      };
      if (lessons[i].diagrams.join(',') != expected.join(',')) {
        throw const FormatException('Practice diagram mismatch');
      }
    }
  }
  static List<String> _contourRow(Object? row) {
    if (row is! List ||
        row.length != 4 ||
        row.any(
          (e) => e is! String || !const ['L', 'M', 'H', 'R'].contains(e),
        )) {
      throw const FormatException('Invalid contour');
    }
    return List<String>.unmodifiable(row.cast<String>());
  }

  late final GuitarText title, entry, exit, rhythmAnswer, contourAnswer;
  late final List<List<String>> contour;
  late final List<VocalStudyBar> study;
  late final List<VocalLesson> lessons;
  static Future<VocalCourse> load({AssetBundle? bundle}) async {
    final result = await ContentBundleLoader(
      reader: FlutterBundleContentAssetReader(bundle: bundle),
      expectedAppId: 'com.yulalab.ostinato',
      currentCoreContract: currentMotionContentContract,
      manifestPath: 'assets/motion_content/manifest.json',
    ).load();
    if (result is ContentBlocked) {
      throw ContentException(result.error);
    }
    if (result is! ContentReady) {
      throw const FormatException('Vocal package unavailable');
    }
    return VocalCourse.fromJson(
      jsonDecode(utf8.decode(await result.assets.read(vocalAsset))),
    );
  }
}
