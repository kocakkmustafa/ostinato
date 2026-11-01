import '../app_theme.dart';
import 'package:flutter/material.dart';

import '../app_locale.dart';
import '../content.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import '../onboarding_store.dart';
import '../ui_copy.dart';
import 'v1_home_copy.dart';

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
                    const _ScopeStep(),
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

/// Metronomik ilerleme — üç kısa dikey çubuk, aktif olan uzun. Sayı
/// göstermez: bu bir ölçüm değil, bir konum.
class _MetronomeProgress extends StatelessWidget {
  const _MetronomeProgress({required this.index, required this.count});
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: localized(
      context,
      "Step {v0} of {v1}",
      "{v0} / {v1} adım",
      values: {"v0": index + 1, "v1": count},
    ),
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
              color: i <= index
                  ? OstinatoPalette.of(context).ink
                  : OstinatoPalette.of(context).divider,
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
        uiText(context, V1HomeCopy.welcomeTitle),
        key: const Key('onboarding-welcome-title'),
        style: hankenText(size: 30, weight: FontWeight.w600, height: 1.1),
      ),
      const SizedBox(height: 12),
      Text(
        uiText(context, V1HomeCopy.welcomeBody),
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
          uiText(context, V1HomeCopy.welcomeNote),
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
  const _ScopeStep();

  @override
  Widget build(BuildContext context) => _Step(
    children: <Widget>[
      kicker(localized(context, 'What is here', 'İçerik')),
      const SizedBox(height: 10),
      Text(
        uiText(context, V1HomeCopy.scopeTitle),
        key: const Key('onboarding-scope-title'),
        style: hankenText(size: 28, weight: FontWeight.w600, height: 1.12),
      ),
      const SizedBox(height: 14),
      _FactRow(
        key: const Key('onboarding-fact-practice'),
        value: '♩',
        label: uiText(context, V1HomeCopy.scopePractice),
      ),
      _FactRow(
        key: const Key('onboarding-fact-setup'),
        value: '◎',
        label: uiText(context, V1HomeCopy.scopeSetup),
      ),
      _FactRow(
        key: const Key('onboarding-fact-streak'),
        value: '↻',
        label: uiText(context, V1HomeCopy.scopeStreak),
      ),
      _FactRow(
        key: const Key('onboarding-fact-written'),
        value: '¶',
        label: uiText(context, V1HomeCopy.scopeWritten),
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
        title: uiText(context, V1HomeCopy.micTitle),
        key: const Key('onboarding-microphone-card'),
        body: uiText(context, V1HomeCopy.micBody),
      ),
      const SizedBox(height: 12),
      _SensorCard(
        title: uiText(context, V1HomeCopy.cameraTitle),
        key: const Key('onboarding-camera-card'),
        // K8 (kurucu, 2026-11-01): kamera yalnız birkaç S1 kurulum dersinde
        // el/bilek duruşu için; izin o derste istenir, görüntü cihazda kalır.
        body: uiText(context, V1HomeCopy.cameraBody),
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
        title: uiText(context, V1HomeCopy.progressTitle),
        key: const Key('onboarding-progress-card'),
        body: uiText(context, V1HomeCopy.progressBody),
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
