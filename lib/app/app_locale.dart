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
  'guitar.foundations.arms': 'Gitarı tutuş: ölçülür, puanlanmaz',
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
  'voice.foundations.arms': 'Kolların: ölçülür, puanlanmaz',
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
  'piano.foundations.arms': 'Kolların: ölçülür, puanlanmaz',
  'piano.foundations.light_and_frame': 'Işık, kadraj ve ölçüm sınırları',
  'piano.foundations.shoulder_tension': 'Omuz gerginliği',
  'piano.foundations.hands_and_wrists': 'Bilekler, parmaklar ve el biçimi',
};

const Map<String, String> _turkishDisciplineBlurbs = <String, String>{
  'guitar':
      'Telefonu gitarınızla oturuşunuzu görecek yere koyun. '
      'Oturuşunuzu gerçek eğitmenlerin duruşlarıyla karşılaştırırız. '
      'Bu duruş dersleri mikrofon kullanmaz; gitar öğrenme yolunda isteğe bağlı tek nota gözlemi vardır.',
  'voice':
      'Telefonu sizi belden yukarı görecek yere koyun. Duruşunuzu '
      'altı bağımsız şan eğitmeniyle karşılaştırırız. Bu ses dersleri mikrofon '
      'kullanmaz; sesinizi dinlemez.',
  'piano':
      'Telefonu piyano başında sizi belden yukarı görecek yere koyun. '
      'Oturuşunuzu üç bağımsız piyano eğitmeniyle karşılaştırırız. '
      'Bu piyano dersleri mikrofon kullanmaz; odanızdaki notaların zamanlamasını ölçmez.',
};

const Map<String, String> _turkishCourseGoals = <String, String>{
  'guitar.foundations':
      'Alanını hazırla, gerçek gitar eğitmenlerinin oturuş '
      'biçimini öğren ve kursun kapsadığı sekiz açık akoru tanı. Duruşun '
      'canlı denetlenir; akor çalışması anlatılır ancak dinlenmez. Bu duruş dersleri '
      'mikrofon kullanmaz.',
  'voice.foundations':
      'Alanını hazırla ve deneyimli şan eğitmenlerinin '
      'duruşunu öğren. Kurulum sırasında gövden canlı denetlenir; referans '
      'şarkı söylerken duruşu da kapsar, fakat bu sürüm şarkıya ne zaman '
      'başladığını algılayamaz.',
  'piano.foundations':
      'Alanını hazırla ve deneyimli eğitmenlerin klavye '
      'başındaki oturuşunu öğren.',
};

const Map<String, String> _turkishSourceClasses = <String, String>{
  'guitar teachers': 'gitar eğitmeni',
  'voice teachers': 'şan eğitmeni',
  'piano teachers': 'piyano eğitmeni',
};

String catalogBlurb(BuildContext context, String id, String english) =>
    '${localized(context, 'Posture catalogue preview. Live camera practice is closed in this release.', 'Duruş kataloğu ön izlemesi. Bu sürümde canlı kamera pratiği kapalıdır.')} '
    '${Localizations.localeOf(context).languageCode == 'tr' ? _turkishDisciplineBlurbs[id] ?? english : english}';

String catalogGoal(BuildContext context, String id, String english) =>
    '${localized(context, 'Posture catalogue preview. Live camera practice is closed in this release.', 'Duruş kataloğu ön izlemesi. Bu sürümde canlı kamera pratiği kapalıdır.')} '
    '${Localizations.localeOf(context).languageCode == 'tr' ? _turkishCourseGoals[id] ?? english : english}';

String catalogSourceClass(BuildContext context, String english) =>
    Localizations.localeOf(context).languageCode == 'tr'
    ? _turkishSourceClasses[english] ?? english
    : english;

String catalogName(BuildContext context, String id, String english) =>
    Localizations.localeOf(context).languageCode == 'tr'
    ? _turkishCatalogNames[id] ?? english
    : english;

String catalogUpperName(BuildContext context, String id, String english) {
  final String name = catalogName(context, id, english);
  return Localizations.localeOf(context).languageCode == 'tr'
      ? name.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase()
      : name.toUpperCase();
}
