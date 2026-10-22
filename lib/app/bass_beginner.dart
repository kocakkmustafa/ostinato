import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:motion_content/motion_content.dart';
import 'flutter_bundle_content_asset_reader.dart';
import 'guitar_journey.dart' show GuitarText;

const bassAsset = 'assets/content/bass_beginner.v1.json';
const bassTuning = 'standard:E1-A1-D2-G2';
const bassPitchConvention = 'sounding:C4=middle-C;staff=one-octave-higher';
const bassOpenMidi4to1 = [28, 33, 38, 43];
Map<String, dynamic> _object(Object? value, Set<String> keys) {
  if (value is! Map<String, dynamic> ||
      value.length != keys.length ||
      !value.keys.toSet().containsAll(keys)) {
    throw const FormatException('Invalid bass content fields');
  }
  return value;
}

GuitarText _copy(Object? value) {
  final m = _object(value, {'en', 'tr'});
  for (final locale in ['en', 'tr']) {
    if (m[locale] is! String || (m[locale] as String).trim().isEmpty) {
      throw const FormatException('Missing bass translation');
    }
  }
  return GuitarText(m['en'] as String, m['tr'] as String);
}

void _coordinates(Map<String, dynamic> m) {
  if (m['string'] is! int ||
      (m['string'] as int) < 1 ||
      (m['string'] as int) > 4 ||
      m['fret'] is! int ||
      (m['fret'] as int) < 0 ||
      (m['fret'] as int) > 3) {
    throw const FormatException('Invalid beginner bass coordinates');
  }
}

String bassPitch(int string, int fret) {
  final midi = bassOpenMidi4to1[4 - string] + fret;
  return '${const ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'][midi % 12]}${midi ~/ 12 - 1}';
}

final class BassTabNote {
  BassTabNote(Object? value) {
    final m = _object(value, {'string', 'fret'});
    _coordinates(m);
    string = m['string'] as int;
    fret = m['fret'] as int;
  }
  late final int string, fret;
  String get pitch => bassPitch(string, fret);
}

final class BassEvent {
  BassEvent(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['kind'] is! String ||
        !const ['note', 'hold', 'rest'].contains(value['kind'])) {
      throw const FormatException('Invalid bass event');
    }
    kind = value['kind'] as String;
    final m = _object(
      value,
      kind == 'note' ? {'kind', 'string', 'fret'} : {'kind'},
    );
    if (kind == 'note') {
      _coordinates(m);
      string = m['string'] as int;
      fret = m['fret'] as int;
    } else {
      string = null;
      fret = null;
    }
  }
  late final String kind;
  late final int? string, fret;
  String? get pitch => kind == 'note' ? bassPitch(string!, fret!) : null;
}

final class BassStudyBar {
  BassStudyBar(Object? value) {
    final m = _object(value, {'events'});
    if (m['events'] is! List || (m['events'] as List).length != 8) {
      throw const FormatException('Bass bar must have eight half-beat events');
    }
    events = List<BassEvent>.unmodifiable([
      for (final e in m['events'] as List) BassEvent(e),
    ]);
    if (events.first.kind != 'note') {
      throw const FormatException('Beginner bar starts with an explicit note');
    }
  }
  late final List<BassEvent> events;
}

final class BassLesson {
  BassLesson(Object? value) {
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
        !RegExp(r'^bass-\d{2}$').hasMatch(m['id'] as String) ||
        m['diagrams'] is! List) {
      throw const FormatException('Invalid bass lesson');
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
              !const [
                'strings',
                'frets',
                'pairs',
                'tab',
                'staff',
                'study',
              ].contains(id),
        ) ||
        raw.toSet().length != raw.length) {
      throw const FormatException('Invalid bass diagrams');
    }
    diagrams = List<String>.unmodifiable(raw.cast<String>());
  }
  late final String id;
  late final GuitarText title;
  late final List<GuitarText> sections;
  late final List<String> diagrams;
}

final class BassCourse {
  BassCourse.fromJson(Object? value) {
    final m = _object(value, {
      'schemaVersion',
      'id',
      'title',
      'entry',
      'exit',
      'tuning',
      'pitchConvention',
      'tab',
      'study',
      'lessons',
    });
    if (m['schemaVersion'] is! int ||
        m['schemaVersion'] != 1 ||
        m['id'] != 'bass.beginner' ||
        m['tuning'] != bassTuning ||
        m['pitchConvention'] != bassPitchConvention ||
        m['tab'] is! List ||
        m['study'] is! List ||
        m['lessons'] is! List) {
      throw const FormatException('Invalid bass course');
    }
    title = _copy(m['title']);
    entry = _copy(m['entry']);
    exit = _copy(m['exit']);
    tab = List<BassTabNote>.unmodifiable([
      for (final n in m['tab'] as List) BassTabNote(n),
    ]);
    study = List<BassStudyBar>.unmodifiable([
      for (final b in m['study'] as List) BassStudyBar(b),
    ]);
    lessons = List<BassLesson>.unmodifiable([
      for (final l in m['lessons'] as List) BassLesson(l),
    ]);
    if (tab.length != 8 || study.length != 8 || lessons.length != 24) {
      throw const FormatException('Incomplete bass foundation');
    }
    for (var i = 0; i < lessons.length; i++) {
      if (lessons[i].id != 'bass-${(i + 1).toString().padLeft(2, '0')}') {
        throw const FormatException('Invalid bass lesson sequence');
      }
    }
  }
  late final GuitarText title, entry, exit;
  late final List<BassTabNote> tab;
  late final List<BassStudyBar> study;
  late final List<BassLesson> lessons;
  static Future<BassCourse> load({AssetBundle? bundle}) async {
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
      throw const FormatException('Bass package unavailable');
    }
    return BassCourse.fromJson(
      jsonDecode(utf8.decode(await result.assets.read(bassAsset))),
    );
  }
}
