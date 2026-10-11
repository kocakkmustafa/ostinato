import 'package:flutter/material.dart';
import 'package:ostinato_posture/ostinato_posture.dart';
import 'package:motion_account/motion_account.dart'
    show motionPaidFeaturesAvailable;

import '../app_locale.dart';
import '../content.dart';
import '../cue_text.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import 'course_screen.dart';
import 'instrument_screen.dart';
import 'settings_screen.dart';
import 'ukulele_beginner_screen.dart';
import 'bass_beginner_screen.dart';
import 'vocal_beginner_screen.dart';

/// Kütüphane — kabuğun giriş ekranı. Üç canlı çalgı, her biri kendi gradyan
/// kimliğinde bir kart. Zemin NÖTR kalır (§13); renk yalnız kartlarda.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, required this.repo, required this.cueText});

  final ContentRepository repo;
  final CueTextResolver cueText;

  @override
  Widget build(BuildContext context) {
    final List<Discipline> live = repo.disciplines
        .where((Discipline d) => d.status == 'live')
        .toList();
    // Şerit ÜÇ karttan bağımsız türetilir: canlı disiplinin bildirdiği
    // `starterLessonId` çözülebiliyorsa kalem var, çözülemiyorsa YOK.
    final List<(Discipline, Lesson)> starters = <(Discipline, Lesson)>[
      for (final Discipline d in live)
        if (d.starterLesson case final Lesson l) (d, l),
    ];
    return Scaffold(
      backgroundColor: OstinatoColors.shell,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.7, -1),
            radius: 1.2,
            colors: <Color>[Color(0x8CDACDF6), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                Color(0xFFFFD9BE),
                                Color(0xFFDACDF6),
                                Color(0xFFC4EADB),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          'Ostinato',
                          style: hankenText(
                            size: 21,
                            weight: FontWeight.w600,
                            color: OstinatoColors.ink,
                          ),
                        ),
                      ],
                    ),
                    GlassIconButton(
                      icon: '⚙',
                      semanticLabel: localized(context, 'Settings', 'Ayarlar'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        localized(
                          context,
                          'Written lessons. Posture references.',
                          'Yazılı dersler. Duruş referansları.',
                        ),
                        style: hankenText(
                          size: 16.5,
                          weight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 7),
                      // DÜZELTME (2026-08-07): önceki cümle "the microphone
                      // listens to what you play" diyordu. Bu build'de
                      // mikrofon GİRİŞİ YOK — `Info.plist`te
                      // `NSMicrophoneUsageDescription`, manifest'te
                      // `RECORD_AUDIO` yok, hiçbir kod yolu ses yakalamıyor.
                      // Kurulum Kontrolü bunu zaten doğru söylüyordu
                      // (`setup-room-gap-body`); giriş ekranı onu
                      // yalanlıyordu. Ürünün TEK CÜMLESİ (UI-BRIEF §0)
                      // mikrofonu içeriyor — o ÜRÜNÜN cümlesi; bu ekran
                      // BU BUILD'i anlatır.
                      // DÜZELTME-2 (O-099): "nine upper-body points" ölçüme
                      // uymuyordu — kamera DÖRT landmark okuyor (iki omuz +
                      // iki kalça) ve TEK açı ölçüyor. Dokuz, figürün düğüm
                      // sayısı.
                      Text(
                        motionPaidFeaturesAvailable
                            ? localized(
                                context,
                                'Put your phone where it can see you. The camera '
                                    'reads your two shoulders and your two hips while '
                                    'you practise, and measures one thing: how far your '
                                    'trunk leans. These posture lessons do not use the microphone.',
                                'Telefonu sizi görebileceği bir yere koyun. '
                                    'Kamera çalışırken iki omzunuzu ve iki kalçanızı '
                                    'okur; yalnız gövde eğiminizi ölçer. '
                                    'Bu duruş dersleri mikrofon kullanmaz.',
                              )
                            : localized(
                                context,
                                'Explore guitar, voice, and piano posture '
                                    'references. Camera lessons and subscriptions '
                                    'are not open in this release. The guitar learning path has '
                                    'an optional on-device single-note observer.',
                                'Gitar, ses ve piyano için duruş referanslarını '
                                    'incele. Kamera dersleri ve abonelikler bu '
                                    'sürümde açık değil. Gitar öğrenme yolunda isteğe bağlı '
                                    'cihaz üstü tek nota gözlemi vardır.',
                              ),
                        style: hankenText(
                          size: 13,
                          color: OstinatoColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                // "START HERE" şeridi (DESIGN-AHEAD §1.2). Hangi ders olduğu
                // BURADA YAZMIYOR — her çalgının `starterLessonId`'sinden
                // çözülüyor (`library.json`, gerekçesi `_why_starter`da).
                // Şeridi hiç çizmemek ile boş çizmek arasındaki fark kasıtlı:
                // çözülemeyen kimlik yüzeyde SESSİZ kalır, kapı KIRMIZI verir.
                //
                // D16 (2026-08-16, O-139/O-140 ölçümü → koordinatör kararı):
                // şerit BURAYA taşındı — eskiden "Your instruments"tan SONRA
                // duruyordu ve katlamadan 515-684pt aşağıdaydı (375×812).
                // Yönlendirme, yönlendirdiği seçimin ALTINDAYSA kullanıcı onu
                // ancak yardım etmesi gereken kararı verdikten SONRA görür —
                // artık intro kartından hemen sonra, katlama ÜSTÜNDE.
                // `test/library_fold_test.dart` yeni konumu ölçüp beyanla
                // karşılaştırır; bu yorum yerleşimi AÇIKLAR, KORUMAZ.
                if (starters.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 22),
                  kicker(
                    localized(
                      context,
                      motionPaidFeaturesAvailable
                          ? 'Start here'
                          : 'Explore lessons',
                      motionPaidFeaturesAvailable
                          ? 'Buradan başlayın'
                          : 'Dersleri incele',
                    ),
                  ),
                  const SizedBox(height: 11),
                  for (final (Discipline d, Lesson l) in starters) ...<Widget>[
                    _StarterRow(discipline: d, lesson: l),
                    const SizedBox(height: 9),
                  ],
                ],
                const SizedBox(height: 22),
                kicker(localized(context, 'Your instruments', 'Çalgılarınız')),
                const SizedBox(height: 11),
                for (final Discipline d in live) ...<Widget>[
                  _InstrumentCard(
                    discipline: d,
                    contract: repo.contractOrNull(d.id),
                  ),
                  const SizedBox(height: 11),
                ],
                ListTile(
                  key: const Key('ukulele-beginner-entry'),
                  title: Text(localized(context, 'Ukulele', 'Ukulele')),
                  subtitle: Text(
                    localized(
                      context,
                      'Written beginner course · high-G GCEA · self-observation',
                      'Yazılı başlangıç kursu · yüksek Sol GCEA · öz gözlem',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const UkuleleBeginnerScreen(),
                    ),
                  ),
                ),
                ListTile(
                  key: const Key('bass-beginner-entry'),
                  title: Text(localized(context, 'Bass', 'Bas')),
                  subtitle: Text(
                    localized(
                      context,
                      'Written beginner course · four-string EADG · self-observation',
                      'Yazılı başlangıç kursu · dört telli EADG · öz gözlem',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BassBeginnerScreen(),
                    ),
                  ),
                ),
                ListTile(
                  key: const Key('vocal-written-course'),
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(
                    localized(
                      context,
                      'Voice · written practice',
                      'Vokal · yazılı çalışma',
                    ),
                  ),
                  subtitle: Text(
                    localized(
                      context,
                      'Comfortable beginner course · personal pitch direction · self-observation',
                      'Rahat başlangıç kursu · kişisel perde yönü · öz gözlem',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const VocalBeginnerScreen(),
                    ),
                  ),
                ),
                // 0-24° PAYLAŞILAN ölçek açıklaması (DESIGN-AHEAD §1.3).
                // Tasarımın taslak cümlesi piyanonun dar bandını "üç
                // eğitmen en ince kanıt" diye AÇIKLIYORDU — o cümle
                // yazılmadı: bant genişliği ölçülen ARALIKTAN gelir, kaynak
                // SAYISINDAN değil, ve ikisini nedensel bağlamak
                // ölçmediğimiz bir ilişkiyi iddia etmek olurdu. Sayılar
                // yan yana duruyor; bağı kuran cümle KURULMADI.
                const SizedBox(height: 6),
                Text(
                  localized(
                    context,
                    'The bar on each card is the range those teachers actually '
                        'occupy, drawn on one shared 0–24° scale so the three can '
                        'be compared. It is a range, not a target: no point inside '
                        'it is more correct than another.',
                    'Her karttaki çubuk, eğitmenlerin bulunduğu gerçek '
                        'aralığı ortak 0–24° ölçeğinde gösterir. Bu bir hedef '
                        'değil aralıktır; içindeki bir nokta diğerinden daha '
                        'doğru değildir.',
                  ),
                  key: const Key('library-band-scale-note'),
                  style: hankenText(
                    size: 12,
                    height: 1.5,
                    color: OstinatoColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "START HERE" şeridinin tek kalemi — çalgının renk kimliğini taşır ama
/// kartın gradyanını TEKRARLAMAZ: şerit kartların altında ikinci bir vitrin
/// değil, onların içine açılan tek bir kapı.
///
/// Dersin görsel sınıfını (`GUIDE`/`SCORED`) gösterir. Gösterilmese "başla"
/// diyen üç satır aynı şeyi vaat ediyor sanılırdı; oysa gitarınki ölçüm
/// iddiası TAŞIMAYAN bir yönerge dersi. Sınıf farkı kurs listesinde zaten
/// görünüyor — burada gizlenmesi o listeyle çelişirdi.
class _StarterRow extends StatelessWidget {
  const _StarterRow({required this.discipline, required this.lesson});
  final Discipline discipline;
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final InstrumentHue hue = InstrumentHues.of(discipline.id);
    final String kindChip = switch (lesson.kind) {
      LessonKind.guide => localized(context, 'GUIDE', 'REHBER'),
      LessonKind.scored => localized(context, 'REFERENCE', 'REFERANS'),
      LessonKind.demoOnly => localized(
        context,
        'REFERENCE · NO SCORING',
        'REFERANS · PUAN YOK',
      ),
      LessonKind.locked => localized(context, 'LOCKED', 'KİLİTLİ'),
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('starter-${discipline.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => lessonScreenFor(
              discipline: discipline,
              lesson: lesson,
              hue: hue,
            ),
          ),
        ),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: hue.soft.first,
            border: Border.all(color: Colors.white.withValues(alpha: .8)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${catalogUpperName(context, discipline.id, discipline.displayName)} · $kindChip',
                      style: monoText(
                        size: 8.5,
                        color: hue.ink.withValues(alpha: .85),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      catalogName(context, lesson.id, lesson.displayName),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: hankenText(
                        size: 14.5,
                        weight: FontWeight.w500,
                        color: hue.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: hue.ink.withValues(alpha: .6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// PAYLAŞILAN ölçeğin üst ucu (DESIGN-AHEAD §1.3). Bir EŞİK DEĞİL, bir
/// ÇİZİM ölçeği: hiçbir hüküm bu sayıdan türemiyor, yalnız üç çalgının
/// bandı AYNI eksende karşılaştırılabilsin diye sabit. Tasarımın verdiği
/// 24° korundu; bugünkü en geniş bant 6.4° ve gözlem eşiği 14° — ikisi de
/// ölçeğin içinde kalıyor, yani ölçek ölçümü kırpmıyor.
const double _sharedScaleMaxDeg = 24;

class _InstrumentCard extends StatelessWidget {
  const _InstrumentCard({required this.discipline, required this.contract});
  final Discipline discipline;

  /// Sözleşme YOKSA çubuk ÇİZİLMEZ. Boş bir ölçek çubuğu "bandı yok" değil
  /// "bandı sıfır" diye okunur — yokluğu yanlış anlatan bir görsel,
  /// yokluğu hiç göstermemekten kötüdür.
  final PostureContract? contract;

  @override
  Widget build(BuildContext context) {
    final InstrumentHue hue = InstrumentHues.of(discipline.id);
    // Eğitmen sayısı+anlaşma derecesini göstermek için kartın kendi kapsam
    // sözcüğü — gerçek sayılar contract'tan gelir, burada yalnız etiket için
    // discipline metninden türetilen kaba bir konum çizilir (hüküm taşımaz).
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => InstrumentScreenRoute(discipline: discipline),
          ),
        ),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: hue.gradient,
            border: Border.all(color: Colors.white.withValues(alpha: .8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  // Bugün "Guitar/Voice/Piano" (kısa) ama sabit genişlikli
                  // chevron'un yanında Expanded olmadan aynı taşma sınıfı
                  // bekliyor (bkz. live_screen.dart başlık düzeltmesi).
                  Expanded(
                    child: Text(
                      catalogName(
                        context,
                        discipline.id,
                        discipline.displayName,
                      ),
                      style: hankenText(
                        size: 22,
                        weight: FontWeight.w600,
                        color: hue.ink,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: hue.ink.withValues(alpha: .6),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (contract != null) ...<Widget>[
                const SizedBox(height: 10),
                HorizontalBandTrack(
                  key: Key('band-scale-${discipline.id}'),
                  lowDeg: contract!.bandLowDeg,
                  highDeg: contract!.bandHighDeg,
                  maxDeg: _sharedScaleMaxDeg,
                  color: hue.ink,
                  height: 8,
                ),
                const SizedBox(height: 6),
                Text(
                  '${contract!.teacherCount} '
                  '${catalogSourceClass(context, contract!.sourceClass)} · '
                  '${contract!.bandLowDeg.toStringAsFixed(1)}–'
                  '${contract!.bandHighDeg.toStringAsFixed(1)}° / '
                  '${_sharedScaleMaxDeg.toStringAsFixed(0)}°',
                  style: monoText(
                    size: 8.5,
                    color: hue.ink.withValues(alpha: .85),
                  ),
                ),
                const SizedBox(height: 10),
              ] else
                const SizedBox(height: 6),
              Text(
                catalogBlurb(context, discipline.id, discipline.blurb),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: hankenText(
                  size: 12.5,
                  color: hue.ink.withValues(alpha: .8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
