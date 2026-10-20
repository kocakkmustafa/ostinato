import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import 'app_translation_catalog.dart';
export 'app_translation_catalog.dart' show AppDecimal, resolveAppLocales;

/// Fourteen approved presentation locales; device preferences resolve in order.
const List<Locale> appSupportedLocales = ostinatoSupportedLocales;
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  AppTranslationsDelegate(),
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

String localized(
  BuildContext context,
  String english,
  String turkish, {
  Map<String, Object?> values = const {},
  num? pluralCount,
}) =>
    (AppTranslations.maybeOf(context) ??
            AppTranslations(
              Localizations.maybeLocaleOf(context) ?? const Locale('en'),
              const {},
            ))
        .text(english, turkish, values: values, pluralCount: pluralCount);

String appDecimal(BuildContext context, num value, int digits) {
  final format = NumberFormat.decimalPattern(
    intlLocaleName(Localizations.localeOf(context)),
  );
  format.minimumFractionDigits = digits;
  format.maximumFractionDigits = digits;
  return format.format(value);
}

String appInteger(BuildContext context, int value) =>
    appDecimal(context, value, 0);

/// Technical pitch symbols remain explicit when conventional local names differ.
String musicPitch(BuildContext context, String pitch) {
  final match = RegExp(r'^([A-G])([#♯b♭]?)(-?\d+)$').firstMatch(pitch);
  if (match == null) return pitch;
  final localName = switch (match.group(1)) {
    'C' => localized(context, 'C', 'Do'),
    'D' => localized(context, 'D', 'Re'),
    'E' => localized(context, 'E', 'Mi'),
    'F' => localized(context, 'F', 'Fa'),
    'G' => localized(context, 'G', 'Sol'),
    'A' => localized(context, 'A', 'La'),
    'B' => localized(context, 'B', 'Si'),
    _ => match.group(1)!,
  };
  if (localName == match.group(1)) return pitch;
  return '$pitch ($localName${match.group(2)}${match.group(3)})';
}

String catalogTag(BuildContext context, String source) => switch (source) {
  'beginner' => localized(context, 'BEGINNER', 'BAŞLANGIÇ'),
  'setup' => localized(context, 'SETUP', 'KURULUM'),
  'posture' => localized(context, 'POSTURE', 'DURUŞ'),
  _ => source.toUpperCase(),
};

/// Display-only labels keyed by stable content IDs. The content contract and
/// measurement configuration continue to use the original IDs and copy.
const Map<String, String> _turkishCatalogNames = <String, String>{
  'guitar': 'Gitar',
  'guitar.foundations': 'Temeller',
  'guitar.foundations.camera_space': 'Kamera ve alan',
  'guitar.foundations.posture': 'Oturma duruşu',
  'guitar.foundations.teacher_range': 'Eğitmenler ne kadar farklı?',
  'guitar.foundations.posture_under_play': 'Çalarken dik kalmak',
  'guitar.foundations.arms': 'Gitarı tutuş: duruş referansı',
  'guitar.foundations.foot_support': 'Ayak desteği ve gitar açısı',
  'guitar.foundations.open_chords': 'Açık akorlar',
  'guitar.foundations.light_and_frame': 'Işık, kadraj ve ölçüm sınırları',
  'guitar.foundations.strum_timing': 'Ritimli pena vuruşları',
  'guitar.foundations.chords_beyond_eight': 'Sekiz akorun ötesi',
  'voice': 'Ses',
  'voice.foundations': 'Temeller',
  'voice.foundations.camera_space': 'Kamera ve alan',
  'voice.foundations.posture': 'Şarkı söylemeden önce duruşun',
  'voice.foundations.teacher_range': 'Eğitmenler ne kadar farklı?',
  'voice.foundations.posture_under_sing': 'Şarkı söylerken açık duruş',
  'voice.foundations.sustained_note': 'Uzatılmış nota',
  'voice.foundations.arms': 'Kolların: duruş referansı',
  'voice.foundations.light_and_frame': 'Işık, kadraj ve ölçüm sınırları',
  'voice.foundations.vibrato': 'Vibrato',
  'voice.foundations.knees_and_chin': 'Kilitli dizler ve yukarı kalkık çene',
  'piano': 'Piyano',
  'piano.foundations': 'Temeller',
  'piano.foundations.camera_space': 'Kamera ve alan',
  'piano.foundations.posture': 'Piyano başında oturuş',
  'piano.foundations.teacher_range': 'Eğitmenler ne kadar farklı?',
  'piano.foundations.posture_under_play': 'Çalarken dengeli oturuş',
  'piano.foundations.five_finger': 'Beş parmak çalışmaları',
  'piano.foundations.arms': 'Kolların: duruş referansı',
  'piano.foundations.light_and_frame': 'Işık, kadraj ve ölçüm sınırları',
  'piano.foundations.shoulder_tension': 'Omuz gerginliği',
  'piano.foundations.hands_and_wrists': 'Bilekler, parmaklar ve el biçimi',
};

// Release display copy; the historical reference dataset stays unchanged.
const Map<String, String> _englishDisciplineBlurbs = <String, String>{
  'guitar':
      'Guitar posture references and written lessons. Camera assessment and posture scoring are unavailable. Posture lessons do not use the microphone; the written guitar path has an optional single-note observer.',
  'voice':
      'Voice posture references and written lessons. Camera assessment and posture scoring are unavailable. These posture lessons do not use the microphone.',
  'piano':
      'Piano posture references and written lessons. Camera assessment and posture scoring are unavailable. These posture lessons do not measure your notes or their timing.',
};

const Map<String, String> _turkishDisciplineBlurbs = <String, String>{
  'guitar':
      'Gitar duruş referansları ve yazılı dersler. Kamera değerlendirmesi ve duruş puanlaması kapalı. Duruş dersleri mikrofon kullanmaz; yazılı gitar yolunda isteğe bağlı tek nota gözlemi vardır.',
  'voice':
      'Şan duruş referansları ve yazılı dersler. Kamera değerlendirmesi ve duruş puanlaması kapalı. Bu duruş dersleri mikrofon kullanmaz.',
  'piano':
      'Piyano duruş referansları ve yazılı dersler. Kamera değerlendirmesi ve duruş puanlaması kapalı. Bu duruş dersleri notalarını veya zamanlamalarını ölçmez.',
};

const Map<String, String> _englishCourseGoals = <String, String>{
  'guitar.foundations':
      'Set up your space, read the guitar posture references, and learn which eight open chords the notes describe. Camera assessment and posture scoring are unavailable; these posture lessons do not use the microphone.',
  'voice.foundations':
      'Set up your space and read the recorded singing posture references. Camera assessment and posture scoring are unavailable; these posture lessons do not use the microphone.',
  'piano.foundations':
      'Set up your space and read the recorded keyboard posture references. Camera assessment and posture scoring are unavailable.',
};

const Map<String, String> _turkishCourseGoals = <String, String>{
  'guitar.foundations':
      'Alanını hazırla, gitar duruş referanslarını oku ve notlarda anlatılan sekiz açık akoru tanı. Kamera değerlendirmesi ve duruş puanlaması kapalı; bu duruş dersleri mikrofon kullanmaz.',
  'voice.foundations':
      'Alanını hazırla ve kayıtlı şan duruş referanslarını oku. Kamera değerlendirmesi ve duruş puanlaması kapalı; bu duruş dersleri mikrofon kullanmaz.',
  'piano.foundations':
      'Alanını hazırla ve kayıtlı klavye duruş referanslarını oku. Kamera değerlendirmesi ve duruş puanlaması kapalı.',
};

const Map<String, String> _turkishSourceClasses = <String, String>{
  'guitar teachers': 'gitar eğitmeni',
  'voice teachers': 'şan eğitmeni',
  'piano teachers': 'piyano eğitmeni',
};

String catalogBlurb(BuildContext context, String id, String english) {
  final known = _catalogBlurbSources[id] == english;
  final en = known ? _englishDisciplineBlurbs[id] ?? english : english;
  final tr = known ? _turkishDisciplineBlurbs[id] ?? en : en;
  return '${localized(context, 'Posture catalogue preview. Live camera practice is closed in this release.', 'Duruş kataloğu ön izlemesi. Bu sürümde canlı kamera pratiği kapalıdır.')} ${localized(context, en, tr)}';
}

String catalogGoal(BuildContext context, String id, String english) {
  final known = _catalogGoalSources[id] == english;
  final en = known ? _englishCourseGoals[id] ?? english : english;
  final tr = known ? _turkishCourseGoals[id] ?? en : en;
  return '${localized(context, 'Posture catalogue preview. Live camera practice is closed in this release.', 'Duruş kataloğu ön izlemesi. Bu sürümde canlı kamera pratiği kapalıdır.')} ${localized(context, en, tr)}';
}

String catalogSourceClass(BuildContext context, String english) =>
    localized(context, english, _turkishSourceClasses[english] ?? english);

String catalogName(BuildContext context, String id, String english) {
  if (_catalogNameSources[id] != english) return english;
  final en = switch ((id, english)) {
    (
      'guitar.foundations.arms',
      'Holding the guitar — measured, never graded',
    ) =>
      'Holding the guitar — posture reference',
    (
      'voice.foundations.arms' || 'piano.foundations.arms',
      'Your arms — measured, never graded',
    ) =>
      'Your arms — posture reference',
    _ => english,
  };
  return localized(context, en, _turkishCatalogNames[id] ?? en);
}

String catalogUpperName(BuildContext context, String id, String english) {
  final name = catalogName(context, id, english);
  return Localizations.localeOf(context).languageCode == 'tr'
      ? name.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase()
      : name.toUpperCase();
}

// Exact source binding prevents stale translated metadata after edits.
const _catalogNameSources = <String, String>{
  "guitar": "Guitar",
  "guitar.foundations": "Foundations",
  "guitar.foundations.camera_space": "Camera and space",
  "guitar.foundations.posture": "Sitting posture",
  "guitar.foundations.teacher_range": "How much teachers actually differ",
  "guitar.foundations.posture_under_play": "Staying upright while you play",
  "guitar.foundations.arms": "Holding the guitar — measured, never graded",
  "guitar.foundations.foot_support": "Foot support and instrument tilt",
  "guitar.foundations.open_chords": "Open chords",
  "guitar.foundations.light_and_frame": "Light, distance, and when we refuse",
  "guitar.foundations.strum_timing": "Strumming in time",
  "guitar.foundations.chords_beyond_eight": "Chords outside the eight",
  "voice": "Voice",
  "voice.foundations": "Foundations",
  "voice.foundations.camera_space": "Camera and space",
  "voice.foundations.posture": "How you stand before you sing",
  "voice.foundations.teacher_range": "How much teachers actually differ",
  "voice.foundations.posture_under_sing": "Staying open while you sing",
  "voice.foundations.sustained_note": "Sustained note",
  "voice.foundations.arms": "Your arms — measured, never graded",
  "voice.foundations.light_and_frame": "Light, distance, and when we refuse",
  "voice.foundations.vibrato": "Vibrato",
  "voice.foundations.knees_and_chin": "Locked knees and a lifted chin",
  "piano": "Piano",
  "piano.foundations": "Foundations",
  "piano.foundations.camera_space": "Camera and space",
  "piano.foundations.posture": "How you sit at the keyboard",
  "piano.foundations.teacher_range": "How much teachers actually differ",
  "piano.foundations.posture_under_play": "Staying settled while you play",
  "piano.foundations.five_finger": "Five-finger patterns",
  "piano.foundations.arms": "Your arms — measured, never graded",
  "piano.foundations.light_and_frame": "Light, distance, and when we refuse",
  "piano.foundations.shoulder_tension": "Shoulder tension",
  "piano.foundations.hands_and_wrists": "Wrists, fingers, hand shape",
};

// Exact source binding prevents stale translated metadata after edits.
const _catalogBlurbSources = <String, String>{
  "guitar":
      "Put your phone where it can see you sitting with your guitar. We check your sitting posture against how real teachers sit. These posture lessons do not use microphone input, so every judgement comes from the camera.",
  "voice":
      "Put your phone where it can see you from the waist up. We check how you hold yourself against six independent singing teachers. These posture lessons do not use microphone input, so we watch your posture and never listen to your voice.",
  "piano":
      "Put your phone where it can see you at the keyboard from the waist up. We check how you sit against three independent piano teachers. These posture lessons do not use microphone input, so your notes are never timed in your room.",
};

// Exact source binding prevents stale translated metadata after edits.
const _catalogGoalSources = <String, String>{
  "guitar.foundations":
      "Set up your space, sit the way real guitar teachers sit, and learn which eight open chords this course covers. Your posture is checked live; the chord work is described, not heard — there is no microphone input in these posture lessons.",
  "voice.foundations":
      "Set up your space and learn to hold yourself the way experienced singing teachers do. Your trunk is checked live while you set up; the reference also covers posture during singing, but this build cannot tell when you start.",
  "piano.foundations":
      "Set up your space and learn to sit at the keyboard the way experienced teachers sit.",
};

/// Whole metadata templates keep unit/order/plural rules in the catalog.
String lessonMetadata(BuildContext context, int minutes, String focus) =>
    focus.isEmpty
    ? localized(context, '{v0} MIN', '{v0} DK', values: {'v0': minutes})
    : localized(
        context,
        '{v0} MIN · {v1}',
        '{v0} DK · {v1}',
        values: {'v0': minutes, 'v1': catalogTag(context, focus)},
      );

String courseMetadata(
  BuildContext context,
  String level,
  int minutes,
  int lessons,
) => localized(
  context,
  '{v0} · {v1} MIN · {v2} LESSONS',
  '{v0} · {v1} DK · {v2} DERS',
  values: {'v0': catalogTag(context, level), 'v1': minutes, 'v2': lessons},
  pluralCount: lessons,
);
