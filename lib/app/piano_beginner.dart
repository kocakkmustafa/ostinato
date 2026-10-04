import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:motion_content/motion_content.dart';
import 'flutter_bundle_content_asset_reader.dart';
import 'guitar_journey.dart' show GuitarText;

const pianoAsset = 'assets/content/piano_beginner.v1.json';

Map<String, dynamic> _object(Object? value, Set<String> keys) {
  if (value is! Map<String, dynamic> ||
      value.length != keys.length ||
      !value.keys.toSet().containsAll(keys)) {
    throw const FormatException('Invalid piano content fields');
  }
  return value;
}

GuitarText _copy(Object? value) {
  final map = _object(value, {'en', 'tr'});
  for (final locale in ['en', 'tr']) {
    if (map[locale] is! String || (map[locale] as String).trim().isEmpty) {
      throw const FormatException('Missing piano translation');
    }
  }
  return GuitarText(map['en'] as String, map['tr'] as String);
}

final class PianoLesson {
  PianoLesson(Object? value) {
    final map = _object(value, {
      'id',
      'title',
      'teach',
      'practice',
      'check',
      'recover',
    });
    if (map['id'] is! String ||
        !RegExp(r'^piano-\d{2}$').hasMatch(map['id'] as String)) {
      throw const FormatException('Invalid piano lesson id');
    }
    id = map['id'] as String;
    title = _copy(map['title']);
    sections = [
      for (final key in ['teach', 'practice', 'check', 'recover'])
        _copy(map[key]),
    ];
  }
  late final String id;
  late final GuitarText title;
  late final List<GuitarText> sections;
}

final class PianoCourse {
  PianoCourse.fromJson(Object? value) {
    final map = _object(value, {
      'schemaVersion',
      'id',
      'title',
      'entry',
      'exit',
      'lessons',
    });
    if (map['schemaVersion'] is! int ||
        map['schemaVersion'] != 1 ||
        map['id'] != 'piano.beginner' ||
        map['lessons'] is! List) {
      throw const FormatException('Invalid piano course');
    }
    title = _copy(map['title']);
    entry = _copy(map['entry']);
    exit = _copy(map['exit']);
    lessons = [
      for (final lesson in map['lessons'] as List) PianoLesson(lesson),
    ];
    if (lessons.length != 16) {
      throw const FormatException('Incomplete piano course');
    }
    for (var i = 0; i < lessons.length; i++) {
      if (lessons[i].id != 'piano-${(i + 1).toString().padLeft(2, '0')}') {
        throw const FormatException('Invalid piano lesson sequence');
      }
    }
  }
  late final GuitarText title, entry, exit;
  late final List<PianoLesson> lessons;
  static Future<PianoCourse> load({AssetBundle? bundle}) async {
    final result = await ContentBundleLoader(
      reader: FlutterBundleContentAssetReader(bundle: bundle),
      expectedAppId: 'com.yulalab.ostinato',
      currentCoreContract: currentMotionContentContract,
      manifestPath: 'assets/motion_content/manifest.json',
    ).load();
    if (result is ContentBlocked) throw ContentException(result.error);
    if (result is! ContentReady) {
      throw const FormatException('Piano package unavailable');
    }
    return PianoCourse.fromJson(
      jsonDecode(utf8.decode(await result.assets.read(pianoAsset))),
    );
  }
}
