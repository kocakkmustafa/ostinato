import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Device-language foundation. Untranslated content stays in English until
/// its own reviewed translation is supplied.
const List<Locale> appSupportedLocales = <Locale>[Locale('en'), Locale('tr')];

const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];

String localized(BuildContext context, String english, String turkish) =>
    Localizations.localeOf(context).languageCode == 'tr' ? turkish : english;

/// Visible catalog metadata; unknown source values stay explicit.
String catalogTag(BuildContext context, String source) {
  if (Localizations.localeOf(context).languageCode != 'tr') {
    return source.toUpperCase();
  }
  return switch (source) {
    'beginner' => 'BAŞLANGIÇ',
    'setup' => 'KURULUM',
    'posture' => 'DURUŞ',
    _ => source.toUpperCase(),
  };
}

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
  'guitar': 'Guitar posture references and written lessons. Camera assessment and posture scoring are unavailable. Posture lessons do not use the microphone; the written guitar path has an optional single-note observer.',
  'voice': 'Voice posture references and written lessons. Camera assessment and posture scoring are unavailable. These posture lessons do not use the microphone.',
  'piano': 'Piano posture references and written lessons. Camera assessment and posture scoring are unavailable. These posture lessons do not measure your notes or their timing.',
};

const Map<String, String> _turkishDisciplineBlurbs = <String, String>{
  'guitar': 'Gitar duruş referansları ve yazılı dersler. Kamera değerlendirmesi ve duruş puanlaması kapalı. Duruş dersleri mikrofon kullanmaz; yazılı gitar yolunda isteğe bağlı tek nota gözlemi vardır.',
  'voice': 'Şan duruş referansları ve yazılı dersler. Kamera değerlendirmesi ve duruş puanlaması kapalı. Bu duruş dersleri mikrofon kullanmaz.',
  'piano': 'Piyano duruş referansları ve yazılı dersler. Kamera değerlendirmesi ve duruş puanlaması kapalı. Bu duruş dersleri notalarını veya zamanlamalarını ölçmez.',
};

const Map<String, String> _englishCourseGoals = <String, String>{
  'guitar.foundations': 'Set up your space, read the guitar posture references, and learn which eight open chords the notes describe. Camera assessment and posture scoring are unavailable; these posture lessons do not use the microphone.',
  'voice.foundations': 'Set up your space and read the recorded singing posture references. Camera assessment and posture scoring are unavailable; these posture lessons do not use the microphone.',
  'piano.foundations': 'Set up your space and read the recorded keyboard posture references. Camera assessment and posture scoring are unavailable.',
};

const Map<String, String> _turkishCourseGoals = <String, String>{
  'guitar.foundations': 'Alanını hazırla, gitar duruş referanslarını oku ve notlarda anlatılan sekiz açık akoru tanı. Kamera değerlendirmesi ve duruş puanlaması kapalı; bu duruş dersleri mikrofon kullanmaz.',
  'voice.foundations': 'Alanını hazırla ve kayıtlı şan duruş referanslarını oku. Kamera değerlendirmesi ve duruş puanlaması kapalı; bu duruş dersleri mikrofon kullanmaz.',
  'piano.foundations': 'Alanını hazırla ve kayıtlı klavye duruş referanslarını oku. Kamera değerlendirmesi ve duruş puanlaması kapalı.',
};

const Map<String, String> _turkishSourceClasses = <String, String>{
  'guitar teachers': 'gitar eğitmeni',
  'voice teachers': 'şan eğitmeni',
  'piano teachers': 'piyano eğitmeni',
};

String catalogBlurb(BuildContext context, String id, String english) =>
    '${localized(context, 'Posture catalogue preview. Live camera practice is closed in this release.', 'Duruş kataloğu ön izlemesi. Bu sürümde canlı kamera pratiği kapalıdır.')} '
    '${Localizations.localeOf(context).languageCode == 'tr' ? _turkishDisciplineBlurbs[id] ?? english : _englishDisciplineBlurbs[id] ?? english}';

String catalogGoal(BuildContext context, String id, String english) =>
    '${localized(context, 'Posture catalogue preview. Live camera practice is closed in this release.', 'Duruş kataloğu ön izlemesi. Bu sürümde canlı kamera pratiği kapalıdır.')} '
    '${Localizations.localeOf(context).languageCode == 'tr' ? _turkishCourseGoals[id] ?? english : _englishCourseGoals[id] ?? english}';

String catalogSourceClass(BuildContext context, String english) =>
    Localizations.localeOf(context).languageCode == 'tr'
    ? _turkishSourceClasses[english] ?? english
    : english;

String catalogName(BuildContext context, String id, String english) =>
    Localizations.localeOf(context).languageCode == 'tr'
    ? _turkishCatalogNames[id] ?? english
    : switch ((id, english)) {
        ('guitar.foundations.arms', 'Holding the guitar — measured, never graded') => 'Holding the guitar — posture reference',
        ('voice.foundations.arms' || 'piano.foundations.arms', 'Your arms — measured, never graded') => 'Your arms — posture reference',
        _ => english,
      };

String catalogUpperName(BuildContext context, String id, String english) {
  final String name = catalogName(context, id, english);
  return Localizations.localeOf(context).languageCode == 'tr'
      ? name.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase()
      : name.toUpperCase();
}
