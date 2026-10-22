import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:motion_content/motion_content.dart';
import 'flutter_bundle_content_asset_reader.dart';
import 'guitar_journey.dart' show GuitarText;

const ukuleleAsset = 'assets/content/ukulele_beginner.v1.json';
const ukuleleTuning = 'high-G:G4-C4-E4-A4';
const ukuleleOpenMidi4to1 = [67, 60, 64, 69];
const ukuleleChordFrets = {
  'C': [0, 0, 0, 3],
  'Am': [2, 0, 0, 0],
  'F': [2, 0, 1, 0],
  'G7': [0, 2, 1, 2],
};
Map<String, dynamic> _object(Object? value, Set<String> keys) {
  if (value is! Map<String, dynamic> ||
      value.length != keys.length ||
      !value.keys.toSet().containsAll(keys)) {
    throw const FormatException('Invalid ukulele content fields');
  }
  return value;
}

GuitarText _copy(Object? value) {
  final map = _object(value, {'en', 'tr'});
  for (final locale in ['en', 'tr']) {
    if (map[locale] is! String || (map[locale] as String).trim().isEmpty) {
      throw const FormatException('Missing ukulele translation');
    }
  }
  return GuitarText(map['en'] as String, map['tr'] as String);
}

List<int> _fourInts(Object? value, int max) {
  if (value is! List ||
      value.length != 4 ||
      value.any((n) => n is! int || n < 0 || n > max)) {
    throw const FormatException('Invalid ukulele chord coordinates');
  }
  return List<int>.unmodifiable(value.cast<int>());
}

final class UkuleleChord {
  UkuleleChord(Object? value) {
    final m = _object(value, {'id', 'title', 'frets4to1', 'fingers4to1'});
    if (m['id'] is! String || !ukuleleChordFrets.containsKey(m['id'])) {
      throw const FormatException('Unsupported ukulele chord');
    }
    id = m['id'] as String;
    title = _copy(m['title']);
    frets = _fourInts(m['frets4to1'], 3);
    fingers = _fourInts(m['fingers4to1'], 4);
    for (var i = 0; i < 4; i++) {
      if (frets[i] != ukuleleChordFrets[id]![i] ||
          (frets[i] == 0) != (fingers[i] == 0)) {
        throw const FormatException(
          'Chord does not match named beginner shape',
        );
      }
    }
  }
  late final String id;
  late final GuitarText title;
  late final List<int> frets, fingers;
}

final class UkuleleTabNote {
  UkuleleTabNote(Object? value) {
    final m = _object(value, {'string', 'fret'});
    if (m['string'] is! int ||
        (m['string'] as int) < 1 ||
        (m['string'] as int) > 4 ||
        m['fret'] is! int ||
        (m['fret'] as int) < 0 ||
        (m['fret'] as int) > 3) {
      throw const FormatException('Invalid ukulele tablature');
    }
    string = m['string'] as int;
    fret = m['fret'] as int;
  }
  late final int string, fret;
  String get pitch {
    final midi = ukuleleOpenMidi4to1[4 - string] + fret;
    const names = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    return '${names[midi % 12]}${midi ~/ 12 - 1}';
  }
}

final class UkuleleStudyBar {
  UkuleleStudyBar(Object? value) {
    final m = _object(value, {'chord', 'slots'});
    if (m['chord'] is! String ||
        !ukuleleChordFrets.containsKey(m['chord']) ||
        m['slots'] is! List ||
        (m['slots'] as List).length != 8 ||
        (m['slots'] as List).any(
          (s) => s is! String || !{'D', 'U', 'R', 'H'}.contains(s),
        ) ||
        (m['slots'] as List).first != 'D') {
      throw const FormatException('Invalid ukulele study bar');
    }
    chord = m['chord'] as String;
    slots = List<String>.unmodifiable((m['slots'] as List).cast<String>());
  }
  late final String chord;
  late final List<String> slots;
}

final class UkuleleLesson {
  UkuleleLesson(Object? value) {
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
        !RegExp(r'^ukulele-\d{2}$').hasMatch(m['id'] as String) ||
        m['diagrams'] is! List ||
        (m['diagrams'] as List).any(
          (id) =>
              id is! String ||
              !{
                'strings',
                'tab',
                'study',
                ...ukuleleChordFrets.keys,
              }.contains(id),
        ) ||
        (m['diagrams'] as List).toSet().length !=
            (m['diagrams'] as List).length) {
      throw const FormatException('Invalid ukulele lesson');
    }
    id = m['id'] as String;
    title = _copy(m['title']);
    sections = List<GuitarText>.unmodifiable([
      for (final key in ['teach', 'practice', 'check', 'recover'])
        _copy(m[key]),
    ]);
    diagrams = List<String>.unmodifiable(
      (m['diagrams'] as List).cast<String>(),
    );
  }
  late final String id;
  late final GuitarText title;
  late final List<GuitarText> sections;
  late final List<String> diagrams;
}

final class UkuleleCourse {
  UkuleleCourse.fromJson(Object? value) {
    final m = _object(value, {
      'schemaVersion',
      'id',
      'title',
      'entry',
      'exit',
      'tuning',
      'chords',
      'tab',
      'study',
      'lessons',
    });
    if (m['schemaVersion'] is! int ||
        m['schemaVersion'] != 1 ||
        m['id'] != 'ukulele.beginner' ||
        m['tuning'] != ukuleleTuning ||
        m['chords'] is! List ||
        m['tab'] is! List ||
        m['study'] is! List ||
        m['lessons'] is! List) {
      throw const FormatException('Invalid ukulele course');
    }
    title = _copy(m['title']);
    entry = _copy(m['entry']);
    exit = _copy(m['exit']);
    final shapes = [for (final item in m['chords'] as List) UkuleleChord(item)];
    if (shapes.length != 4 || shapes.map((c) => c.id).toSet().length != 4) {
      throw const FormatException('Incomplete ukulele chord set');
    }
    chords = Map<String, UkuleleChord>.unmodifiable({
      for (final c in shapes) c.id: c,
    });
    tab = List<UkuleleTabNote>.unmodifiable([
      for (final item in m['tab'] as List) UkuleleTabNote(item),
    ]);
    study = List<UkuleleStudyBar>.unmodifiable([
      for (final item in m['study'] as List) UkuleleStudyBar(item),
    ]);
    lessons = List<UkuleleLesson>.unmodifiable([
      for (final item in m['lessons'] as List) UkuleleLesson(item),
    ]);
    if (tab.length != 8 || study.length != 8 || lessons.length != 24) {
      throw const FormatException('Incomplete ukulele foundation');
    }
    for (var i = 0; i < lessons.length; i++) {
      if (lessons[i].id != 'ukulele-${(i + 1).toString().padLeft(2, '0')}') {
        throw const FormatException('Invalid ukulele lesson sequence');
      }
    }
  }
  late final GuitarText title, entry, exit;
  late final Map<String, UkuleleChord> chords;
  late final List<UkuleleTabNote> tab;
  late final List<UkuleleStudyBar> study;
  late final List<UkuleleLesson> lessons;
  static Future<UkuleleCourse> load({AssetBundle? bundle}) async {
    final result = await ContentBundleLoader(
      reader: FlutterBundleContentAssetReader(bundle: bundle),
      expectedAppId: 'com.yulalab.ostinato',
      currentCoreContract: currentMotionContentContract,
      manifestPath: 'assets/motion_content/manifest.json',
    ).load();
    if (result is ContentBlocked) throw ContentException(result.error);
    if (result is! ContentReady) {
      throw const FormatException('Ukulele package unavailable');
    }
    return UkuleleCourse.fromJson(
      jsonDecode(utf8.decode(await result.assets.read(ukuleleAsset))),
    );
  }
}
