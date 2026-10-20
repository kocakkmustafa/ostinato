import '../app_theme.dart';
import 'package:flutter/material.dart';

import '../app_locale.dart';
import '../content.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import '../onboarding_store.dart';

/// İlk açılış — UI-BRIEF §2.1'den TÜRETİLDİ (icat edilmedi).
///
/// Brief dört adım tarif eder (O1 karşılama · O2 çalgı seçimi · O3 izinler ·
/// O4 yaş/vasi). Bu ekran ÜÇ taşır ve ikisini bilerek başka türlü çözer:
///
/// • **O2 (çalgı seçimi) burada YOK.** Brief onu "3 canlı + 39 çalgı yakında"
///   diye tarif ediyordu; o satırın kendisi süperseded (UI-BRIEF §4 uyarısı) ve
///   "39 çalgı yakında" bugün doğrudan M-F-186 ihlali olurdu. Üstelik seçim
///   ZATEN var: Kütüphane ekranı üç canlı çalgıyı kart olarak gösteriyor.
///   İlk açılışta bir seçim DAYATMAK, kullanıcıyı henüz okumadığı bir şey
///   hakkında karar vermeye zorlar ve arkasından aynı listeyi bir kez daha
///   gösterir. Karşılama BİTER, kütüphane AÇILIR — seçim orada.
///
/// • **O4 (yaş bandı / vasi onayı) burada YOK — adlı boşluk.** Çocuk rejiminin
///   TASARLANIP tasarlanmayacağı bile kurucu kararı değil bir açık soru
///   (`settings_screen.dart` aynı sınırı taşıyor). Var olmayan bir karara
///   yaş kapısı inşa etmek, kararı sessizce vermek olurdu.
///
/// • **İzin BURADA İSTENMEZ, burada AÇIKLANIR.** Gerekçe: kamerayı gerçekten
///   isteyen tek yer Kurulum Kontrolü'dür (`requestAndStartCamera`), ve o
///   istek zaten orada. İlk açılışta ikinci bir istek yolu açmak (a) iki
///   yolun zamanla ayrışacağı bir çatal yaratır, (b) kullanıcı reddederse onu
///   kütüphaneyi HİÇ görmeden bir çıkmaz sokağa oturtur. Bu ekran "neden
///   isteyeceğiz"i sistem diyaloğundan ÖNCE söyler — brief'in istediği de
///   buydu ("NEDEN gerektiği tek cümle, izin isteğinden ÖNCE").
// PLACEHOLDER(flow): yaş bandı / vasi onayı (O4) — bu akışta YOK. unblocked
// by: çocuk rejiminin tasarlanıp tasarlanmayacağına dair kurucu kararı;
// karar "evet" olursa kapı BURAYA girer (karşılamadan sonra, kütüphaneden
// önce), çünkü akışı durdurabilecek tek nokta burasıdır.
// source-only: adım AKIŞTA HİÇ YOK — var olmayan bir adımın kullanıcı
// cümlesi de olamaz; çocuk rejimi tasarlanırsa yüzey O ZAMAN doğar.
// closedPaths: none-known
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.repo,
    required this.store,
    required this.onFinished,
  });

  final ContentRepository repo;
  final OnboardingStore store;
  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  int _index = 0;

  static const int _stepCount = 3;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _stepCount - 1) {
      _pages.animateToPage(
        _index + 1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await widget.store.markComplete();
    if (!mounted) return;
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final _LibraryFacts facts = _LibraryFacts.from(widget.repo);
    return Scaffold(
      backgroundColor: OstinatoPalette.of(context).shell,
      body: DecoratedBox(
        decoration:  BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.7, -1),
            radius: 1.2,
            colors: <Color>[OstinatoPalette.of(context).voice.chip.withValues(alpha: .55), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              const SizedBox(height: 12),
              _MetronomeProgress(index: _index, count: _stepCount),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (int i) => setState(() => _index = i),
                  children: <Widget>[
                    const _WelcomeStep(),
                    _ScopeStep(facts: facts),
                    const _SensorsStep(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
                child: PrimaryButton(
                  key: const Key('onboarding-primary'),
                  label: _index == _stepCount - 1
                      ? localized(context, 'Open the library', 'Kütüphaneyi aç')
                      : localized(context, 'Continue', 'Devam et'),
                  onPressed: _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kütüphaneden OKUNAN sayılar — bu ekranda elle yazılmış TEK bir içerik
/// sayısı yoktur. Bir ders eklendiğinde/kilitlendiğinde karşılama ekranı
/// kendiliğinden doğru kalır; elle yazsaydık ilk içerik turunda bayatlardı
/// (O-029'un "vitrin korumasızdı" sınıfı).
final class _LibraryFacts {
  const _LibraryFacts({
    required this.instruments,
    required this.lessons,
    required this.locked,
    required this.demoOnly,
  });

  final int instruments;
  final int lessons;
  final int locked;
  final int demoOnly;

  static _LibraryFacts from(ContentRepository repo) {
    final List<Discipline> live = repo.disciplines
        .where((Discipline d) => d.status == 'live')
        .toList();
    final List<Lesson> all = <Lesson>[
      for (final Discipline d in live) ...d.lessons,
    ];
    return _LibraryFacts(
      instruments: live.length,
      lessons: all.length,
      locked: all.where((Lesson l) => l.kind == LessonKind.locked).length,
      demoOnly: all.where((Lesson l) => l.kind == LessonKind.demoOnly).length,
    );
  }
}

/// Metronomik ilerleme — üç kısa dikey çubuk, aktif olan uzun. Sayı
/// göstermez: bu bir ölçüm değil, bir konum.
class _MetronomeProgress extends StatelessWidget {
  const _MetronomeProgress({required this.index, required this.count});
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: localized(context, "Step {v0} of {v1}", "{v0} / {v1} adım", values: {"v0": index + 1, "v1": count}),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (int i = 0; i < count; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 7),
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            width: 3,
            height: i == index ? 18 : 9,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: i <= index ? OstinatoPalette.of(context).ink : OstinatoPalette.of(context).divider,
            ),
          ),
        ],
      ],
    ),
  );
}

/// Ortak sayfa iskeleti — içerik HER ZAMAN kaydırılabilir.
///
/// Bu bir stil tercihi değil, aile dersi #3'ün yapısal hâli: gerçek metin
/// fixture'dan uzun ve `flutter_test` varsayılan yüzeyi gerçek telefonun iki
/// katı. Sabit yükseklikli bir sayfa 375×812'de taşar ve taşma en dar cihazda
/// görülür. Kaydırılabilir bir sayfa TAŞAMAZ — punto ayarlayarak değil, taşma
/// sınıfını kaldırarak çözülür (ders #7).
class _Step extends StatelessWidget {
  const _Step({required this.children, this.top});
  final List<Widget> children;
  final Widget? top;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext ctx, BoxConstraints c) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      // Kısa adımda içerik dikeyde ortalanır, uzun adımda normal akar
      // (ekran kanıtı O-046: adım 1-2'de kartla düğme arasında ~200px ölü
      // boşluk vardı, adım 3'te ise taşma — aynı ekranda iki zıt kusur).
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: c.maxHeight - 46),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (top != null) ...<Widget>[top!, const SizedBox(height: 22)],
            ...children,
          ],
        ),
      ),
    ),
  );
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) => _Step(
    top: Center(
      child: SizedBox(
        width: 150,
        height: 178,
        // Karşılamanın görseli bir ikon DEĞİL, ürünün asıl iddiası:
        // arkadaki kama eğitmen BANDI, kesik çizgi bir konum. "Bant,
        // nokta değil" cümlesi burada çiziliyor. Açılar temsilîdir ve
        // hüküm taşımaz — bu yüzden yanında bir sayı yoktur.
        child: CustomPaint(
          // Kama GENİŞLETİLDİ ve KOYULAŞTIRILDI (ekran kanıtı O-046):
          // ±7° bu ölçekte ince bir dilim olarak çıkıyordu ve görselin
          // tek işi olan cümleyi — "band, not a point" — tam TERSİNDEN
          // söylüyordu. Açı hüküm taşımıyor (bu figürün yanında sayı
          // YOK, ölçüm iddiası YOK), o yüzden tek ölçüt OKUNABİLİRLİK.
          painter: SkeletonFigurePainter(
            color: OstinatoPalette.of(context).ink,
            markerColor: OstinatoPalette.of(context).textMuted,
            bandLowDeg: -15,
            bandHighDeg: 15,
            bandColor: OstinatoPalette.of(context).voice.band,
            markerDeg: 6,
          ),
        ),
      ),
    ),
    children: <Widget>[
      kicker(localized(context, 'Welcome', 'Hoş geldin')),
      const SizedBox(height: 10),
      Text(
        localized(
          context,
          'Build your guitar practice.',
          'Gitar çalışmanı geliştir.',
        ),
        key: const Key('onboarding-welcome-title'),
        style: hankenText(size: 30, weight: FontWeight.w600, height: 1.1),
      ),
      const SizedBox(height: 12),
      Text(
        localized(
          context,
          'Learn guitar through progressive lessons, practice tasks and '
              'self-checks. The course works without an account, camera or '
              'microphone. Your practice record stays on this device.',
          'Gitarı sıralı dersler, çalışma görevleri ve öz denetimlerle öğrenin. '
              'Kurs hesap, kamera veya mikrofon olmadan çalışır. Çalışma '
              'kaydınız bu cihazda kalır.',
        ),
        style: hankenText(
          size: 15,
          height: 1.55,
          color: OstinatoPalette.of(context).textBody,
        ),
      ),
      const SizedBox(height: 14),
      GlassCard(
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          localized(
            context,
            'Optional microphone practice shows approximate single-note '
                'observations after your permission. It does not grade your '
                'playing. Live camera practice and subscription sales are '
                'closed in this release.',
            'İsteğe bağlı mikrofon pratiği, izninizden sonra yaklaşık tek nota '
                'gözlemi gösterir. Çalma başarınızı puanlamaz. Bu sürümde canlı '
                'kamera pratiği ve abonelik satışı kapalıdır.',
          ),
          style: hankenText(
            size: 13.5,
            height: 1.55,
            color: OstinatoPalette.of(context).textBody,
          ),
        ),
      ),
    ],
  );
}

class _ScopeStep extends StatelessWidget {
  const _ScopeStep({required this.facts});
  final _LibraryFacts facts;

  @override
  Widget build(BuildContext context) => _Step(
    children: <Widget>[
      kicker(localized(context, 'What is here', 'İçerik')),
      const SizedBox(height: 10),
      Text(
        localized(
          context,
          'Small, and honest about it.',
          'Kapsamı sınırlı, açıklaması açık.',
        ),
        key: const Key('onboarding-scope-title'),
        style: hankenText(size: 28, weight: FontWeight.w600, height: 1.12),
      ),
      const SizedBox(height: 14),
      _FactRow(
        key: const Key('onboarding-fact-instruments'),
        value: '${facts.instruments}',
        label: localized(
          context,
          'instrument previews in the posture catalogue; live camera practice is closed',
          'çalgı ön izlemesi duruş kataloğunda; canlı kamera pratiği kapalıdır',
        ),
      ),
      _FactRow(
        key: const Key('onboarding-fact-lessons'),
        value: '${facts.lessons}',
        label: localized(
          context,
          'legacy posture lesson previews',
          'önceki duruş dersi ön izlemeleri',
        ),
      ),
      _FactRow(
        key: const Key('onboarding-fact-locked'),
        value: '${facts.locked}',
        label: localized(
          context,
          'are locked legacy posture previews. Their pages explain the missing '
              'reference or measurement evidence; live camera measurement and '
              'posture grading are unavailable in this release.',
          'kilitli eski duruş ön izlemesidir. Sayfaları eksik referans veya '
              'ölçüm kanıtını açıklar; bu sürümde canlı kamera ölçümü ve '
              'duruş puanlaması yoktur.',
        ),
      ),
      _FactRow(
        key: const Key('onboarding-fact-demo'),
        value: '${facts.demoOnly}',
        label: localized(
          context,
          'are legacy demonstration-only posture previews based on recorded '
              'teacher references. This release does not measure or grade '
              'your posture.',
          'ders, kaydedilmiş eğitmen referanslarına dayanan eski gösterim '
              'ön izlemesidir. Bu sürüm duruşunuzu ölçmez veya puanlamaz.',
        ),
      ),
      const SizedBox(height: 8),
      GlassCard(
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          localized(
            context,
            'Instrument pages describe recorded references and the measurement '
                "engine's limits. These historical findings are not measurements "
                'of your practice; live camera assessment and posture scoring '
                'are unavailable in this release.',
            'Çalgı sayfaları kaydedilmiş referansları ve ölçüm motorunun '
                'sınırlarını açıklar. Bu tarihsel bulgular sizin pratiğinizin '
                'ölçümü değildir; bu sürümde canlı kamera değerlendirmesi ve '
                'duruş puanlaması kapalıdır.',
          ),
          style: hankenText(
            size: 13.5,
            height: 1.55,
            color: OstinatoPalette.of(context).textBody,
          ),
        ),
      ),
    ],
  );
}

class _FactRow extends StatelessWidget {
  const _FactRow({super.key, required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 42,
          child: Text(
            value,
            style: hankenText(size: 26, weight: FontWeight.w600, height: 1),
          ),
        ),
        const SizedBox(width: 10),
        // Expanded ŞART: sayı sabit genişlikte, etiket gerçek metinle
        // uzuyor. Bu satır sınıfı bu kod tabanında daha önce taştı
        // (`library_screen.dart` başlığı, `live_screen.dart` başlığı).
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              label,
              style: hankenText(
                size: 13.5,
                height: 1.5,
                color: OstinatoPalette.of(context).textBody,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SensorsStep extends StatelessWidget {
  const _SensorsStep();

  @override
  Widget build(BuildContext context) => _Step(
    children: <Widget>[
      kicker(
        localized(context, 'Sensors and your data', 'Sensörler ve verileriniz'),
      ),
      const SizedBox(height: 10),
      Text(
        localized(context, 'What we will ask for.', 'Hangi izni isteyeceğiz?'),
        key: const Key('onboarding-sensors-title'),
        style: hankenText(size: 28, weight: FontWeight.w600, height: 1.12),
      ),
      const SizedBox(height: 14),
      _SensorCard(
        title: localized(context, 'The camera', 'Kamera'),
        key: const Key('onboarding-camera-card'),
        // DÜZELTME (O-099, koordinatör hükmü 2026-08-12): cümle "nine
        // upper-body points — hips, shoulders, neck" diyordu. Ölçüldü:
        // canlı zincir `specs:[trunkTilt]` = TEK açı, güven kapısı
        // `required:LmRegion.torso` = DÖRT landmark, ve "neck" HİÇ
        // okunmuyor. "Dokuz" figürün düğüm sayısıydı — sayı gerçek,
        // BİRİMİ yanlış. Kural: her sayı saydığı şeyin yanında durur.
        body: localized(
          context,
          'Live camera posture practice is closed in this release. The guitar '
              'course does not ask for camera access and uses your own practice '
              'record rather than an automatic posture grade.',
          'Bu sürümde canlı kamera duruş pratiği kapalıdır. Gitar kursu kamera '
              'izni istemez; otomatik duruş puanı yerine kendi çalışma '
              'kaydınızı kullanır.',
        ),
      ),
      const SizedBox(height: 12),
      // Sıra DEĞİŞTİ (2026-08-07, ekran kanıtı O-046): bu kart en sondaydı
      // ve 375×812'de görüntü kenarında CÜMLE ORTASINDA kesiliyordu —
      // "it does not treat anything," diye. Metin VARDI ve DOĞRUYDU,
      // yani hiçbir test bunu göremezdi (Lissom'un M-F-296 sınıfı:
      // okunabilirlik `find.textContaining` ile ölçülemez). Uygulamanın
      // etik olarak en yüklü cümlesi, kaydırmaya bağlı olmamalı.
      _SensorCard(
        title: localized(context, 'Not a medical tool', 'Tıbbi araç değil'),
        key: const Key('onboarding-wellness-card'),
        body: localized(
          context,
          'Ostinato teaches guitar practice. It does not diagnose or treat '
              'conditions and does not provide health advice. Stop if practice '
              'hurts and seek advice from a qualified healthcare professional.',
          'Ostinato gitar çalışmasını öğretir. Tanı veya tedavi hizmeti ya da '
              'sağlık tavsiyesi vermez. Çalışırken ağrı olursa durun ve bir '
              'sağlık uzmanına danışın.',
        ),
      ),
      const SizedBox(height: 12),
      _SensorCard(
        title: localized(
          context,
          'Optional single-note microphone',
          'İsteğe bağlı tek nota mikrofonu',
        ),
        key: const Key('onboarding-microphone-card'),
        body: localized(
          context,
          'The guitar learning path offers approximate single-note observation. '
              'You choose when to start and grant microphone permission. Audio stays on this device '
              'in temporary memory and is never recorded or uploaded. The course works without it; '
              'no chord or playing-success score is produced.',
          'Gitar öğrenme yolunda yaklaşık tek nota gözlemi vardır. Başlatmayı ve mikrofon '
              'iznini siz seçersiniz. Ses bu cihazda geçici bellekte kalır; kaydedilmez veya yüklenmez. '
              'Kurs mikrofonsuz çalışır; akor veya çalma başarısı puanı üretilmez.',
        ),
      ),
      const SizedBox(height: 12),
      _SensorCard(
        title: localized(context, 'Your video', 'Videonuz'),
        key: const Key('onboarding-video-card'),
        // D14 (2026-08-16, O-153): "nothing is stored" DÜZELTİLDİ —
        // oturum SONUCU artık saklanıyor. Video/ham ölçüm hâlâ
        // saklanmıyor (bu iddia DOĞRU kaldı, o yüzden korundu);
        // yalnız yeni gerçeği anlatan ikinci cümle YENİDEN yazıldı.
        body: localized(
          context,
          'The course does not capture video. Lesson progress and self-checks '
              'stay in local app storage. Existing posture-session summaries '
              'also stay on this device; they are not uploaded to your account.',
          'Kurs video yakalamaz. Ders ilerlemesi ve öz denetimler yerel uygulama '
              'alanında kalır. Önceki duruş seansı özetleri de bu cihazda kalır; '
              'hesabınıza yüklenmez.',
        ),
      ),
    ],
  );
}

class _SensorCard extends StatelessWidget {
  const _SensorCard({super.key, required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: OstinatoPalette.of(context).controlSurface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: OstinatoPalette.of(context).glassBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        kicker(title),
        const SizedBox(height: 9),
        Text(
          body,
          style: hankenText(
            size: 13.5,
            height: 1.55,
            color: OstinatoPalette.of(context).textBody,
          ),
        ),
      ],
    ),
  );
}
