import '../app_theme.dart';
import 'package:flutter/material.dart';
import '../study_review.dart';
import 'package:ostinato_posture/ostinato_posture.dart';
import 'package:motion_account/motion_account.dart'
    show motionCameraCoachingAvailable;

import '../app_locale.dart';
import '../ostinato_release_policy.dart';
import '../content.dart';
import '../cue_text.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import '../retention/weekly_goal_card.dart';
import '../retention/weekly_goal_store.dart';
import '../tuner/tuner_copy.dart';
import '../tuner/tuner_screen.dart';
import '../account_connection.dart';
import '../curriculum/v1_lesson.dart';
import '../practice/loop/practice_progress_store.dart';
import '../practice/loop/v1_course_catalog.dart';
import '../ui_copy.dart';
import 'course_screen.dart';
import 'instrument_screen.dart';
import 'settings_screen.dart';
import 'ukulele_beginner_screen.dart';
import 'bass_beginner_screen.dart';
import 'v1_home_copy.dart';
import 'vocal_beginner_screen.dart';

/// Kütüphane — kabuğun giriş ekranı. Üç canlı çalgı, her biri kendi gradyan
/// kimliğinde bir kart. Zemin NÖTR kalır (§13); renk yalnız kartlarda.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
    super.key,
    required this.repo,
    required this.cueText,
    this.weeklyGoalStoreFactory,
  });

  final ContentRepository repo;
  final CueTextResolver cueText;
  final WeeklyGoalStore Function(String? accountUserId)? weeklyGoalStoreFactory;

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
      backgroundColor: OstinatoPalette.of(context).shell,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.7, -1),
            radius: 1.2,
            colors: <Color>[
              OstinatoPalette.of(context).voice.chip.withValues(alpha: .55),
              Colors.transparent,
            ],
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
                    Expanded(
                      child: Row(
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
                          Flexible(
                            child: Text(
                              'Ostinato',
                              style: hankenText(
                                size: 21,
                                weight: FontWeight.w600,
                                color: OstinatoPalette.of(context).ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
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
                        uiText(context, V1HomeCopy.homeSubtitle),
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
                        motionCameraCoachingAvailable
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
                            : uiText(context, V1HomeCopy.homeIntro),
                        style: hankenText(
                          size: 13,
                          color: OstinatoPalette.of(context).textMuted,
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
                    motionCameraCoachingAvailable
                        ? localized(context, "Start here", "Buradan başlayın")
                        : localized(
                            context,
                            "Explore lessons",
                            "Dersleri incele",
                          ),
                  ),
                  const SizedBox(height: 11),
                  for (final (Discipline d, Lesson l) in starters) ...<Widget>[
                    _StarterRow(discipline: d, lesson: l),
                    const SizedBox(height: 9),
                  ],
                ],
                if (ostinatoLegacyWrittenCoursesVisible)
                  const StudyReviewEntry()
                else
                  const SizedBox(height: 12),
                WeeklyGoalCard(storeFactory: weeklyGoalStoreFactory),
                // F4.1: the tuner is a free tool, reachable from home.
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                    key: const Key('tuner-entry'),
                    icon: const Icon(Icons.tune),
                    label: Text(uiText(context, TunerCopy.title)),
                    onPressed: () => openTuner(context),
                  ),
                ),
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
                // Pre-v1 written courses: hidden in the v1 store build.
                if (ostinatoLegacyWrittenCoursesVisible) ...<Widget>[
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
                ],
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
    final InstrumentHue hue = OstinatoPalette.of(
      context,
    ).instrument(discipline.id);
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
            border: Border.all(color: OstinatoPalette.of(context).glassBorder),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${catalogUpperName(context, discipline.id, discipline.displayName)} · $kindChip',
                      style: monoText(size: 8.5, color: hue.ink),
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
              Icon(Icons.chevron_right, size: 20, color: hue.ink),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstrumentCard extends StatelessWidget {
  const _InstrumentCard({required this.discipline, required this.contract});
  final Discipline discipline;

  /// Sözleşme YOKSA çubuk ÇİZİLMEZ. Boş bir ölçek çubuğu "bandı yok" değil
  /// "bandı sıfır" diye okunur — yokluğu yanlış anlatan bir görsel,
  /// yokluğu hiç göstermemekten kötüdür.
  final PostureContract? contract;

  @override
  Widget build(BuildContext context) {
    final InstrumentHue hue = OstinatoPalette.of(
      context,
    ).instrument(discipline.id);
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
            border: Border.all(color: OstinatoPalette.of(context).glassBorder),
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
                  Icon(Icons.chevron_right, color: hue.ink),
                ],
              ),
              const SizedBox(height: 10),
              // v1 (kurucu, 2026-11-01): eğitmen açı çubuğu kalktı. Gitar
              // ölçülü pratiğe açılır; ses ve piyano "Yakında".
              if (discipline.id == 'guitar')
                _MeasuredNextLine(color: hue.ink)
              else
                Text(
                  uiText(context, V1HomeCopy.comingSoon),
                  key: Key('coming-soon-${discipline.id}'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: hankenText(size: 12.5, color: hue.ink),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gitar kartının alt satırı: ölçülü pratikte açılan ilk geçilmemiş ders.
/// Katalog veya kayıt okunamazsa yalnız "Ölçülü pratik açık" kalır.
class _MeasuredNextLine extends StatefulWidget {
  const _MeasuredNextLine({required this.color});
  final Color color;

  @override
  State<_MeasuredNextLine> createState() => _MeasuredNextLineState();
}

class _MeasuredNextLineState extends State<_MeasuredNextLine> {
  Future<V1Lesson?>? _next;
  String? _accountId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = AccountScope.maybeOf(context)?.currentUserId;
    if (_next == null || id != _accountId) {
      _accountId = id;
      _next = _load(id);
    }
  }

  Future<V1Lesson?> _load(String? accountId) async {
    try {
      final catalog = await V1CourseCatalog.load();
      final records = await V1PracticeProgressStore(
        accountUserId: accountId,
      ).load();
      final checks = await V1LessonCheckStore(accountUserId: accountId).load();
      // Same pick as "Start next lesson": first open lesson not done.
      return V1CourseState(catalog, records, checks).next?.lesson;
    } on Object {
      // Fall back to the plain line.
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<V1Lesson?>(
    future: _next,
    builder: (context, snap) {
      final lesson = snap.data;
      return Text(
        lesson == null
            ? uiText(context, V1HomeCopy.guitarCardOpen)
            : uiText(
                context,
                V1HomeCopy.guitarCardNext,
                values: {'v0': lesson.title.of(context)},
              ),
        key: const Key('guitar-card-measured'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: hankenText(size: 12.5, color: widget.color),
      );
    },
  );
}
