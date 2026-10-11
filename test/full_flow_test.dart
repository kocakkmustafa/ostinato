import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';
import 'package:ostinato/app/onboarding_store.dart';
import 'package:ostinato/app/screens/live_screen.dart';
import 'package:ostinato/app/screens/review_screen.dart';
import 'package:ostinato/main.dart';
import 'package:ostinato_posture/ostinato_posture.dart';

/// **A1 — TAM AKIŞ: ilk açılış → seçim → oturum → sonuç.** (O-122)
///
/// Ölçüt (`YAYIN-HAZIRLIK-OLCUTU.md` A1): *"En az bir TAM AKIŞ baştan sona
/// çalışıyor"*, kanıt: *"yürüyüş testi, **taze kurulumdan**,
/// `NavigatorObserver` tanığıyla"*.
///
/// ─────────────────────────────────────────────────────────────────────
/// ## 🔴 BU TESTİN KAPSAMI VE **KAPSAMADIĞI** — adıyla
///
/// Bu dosya İKİ ayrı iddiayı ayırır, çünkü aile kuralı bunu şart koşuyor:
/// *UI yürüyüşü ile motorun gerçeği iki ayrı iddiadır.*
///
/// ### ✅ GERÇEK DOKUNUŞLA kanıtlanan (kullanıcının yaptığı)
///   taze kurulum → onboarding (3 perde, **bayrak set edilmeden**) → Kütüphane
///   → Gitar → kurs → ders → **"Begin the setup check"** → Kurulum Kontrolü
///
/// ### ⚠️ **ZERK EDİLEN TEK BACAK — koşum tarafından KURULUR, dokunulmaz**
///   Kurulum Kontrolü → Canlı Oturum.
///   **Neden:** ürünün o düğmesi (`setup_check_screen.dart:490`) yalnız
///   `_Stage.passed`ta doğar ve o aşama **GERÇEK KAMERA KARESİ** ister.
///   Widget testinde kare yoktur; koşum `LiveScreenRoute`u sahte bir
///   `PoseSource` ile **kendisi push eder**.
///   ⛔ Bu bacak bu testle **KANITLANMIŞ SAYILMAZ** — kanıtı `A12` (gerçek
///   cihazda koşu) verir. Burada yazılı olması, sessiz kalmasından iyidir.
///
/// ### ✅ ZERKTEN SONRA yine ÜRÜNÜN KENDİ KODU
///   Canlı oturum → **"Stop and see the summary"** (gerçek dokunuş) →
///   `live_screen.dart:179 _stop()` → `pushReplacement` → Sonuç ekranı,
///   ve özet **ölçülen** kareden türer (`SessionSummary`), elle kurulmaz.
///
/// > ***BİR AKIŞI "TAM" İLAN ETMEK, ZERK EDİLEN BACAĞI SAYMAMAK DEĞİL,
/// > ONU ADIYLA SAYMAKTIR.***
/// ─────────────────────────────────────────────────────────────────────
class _FlowWitness extends NavigatorObserver {
  final List<String> events = <String>[];
  @override
  void didPush(Route<dynamic> r, Route<dynamic>? p) {
    if (r is PageRoute) events.add('push');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute is PageRoute) events.add('replace');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ContentRepository repo;
  late CueTextResolver cueText;
  late Discipline guitar;
  setUpAll(() async {
    repo = await ContentRepository.load();
    cueText = await CueTextResolver.load();
    guitar = repo.disciplines.firstWhere((Discipline d) => d.id == 'guitar');
  });

  setUp(() {
    final TestWidgetsFlutterBinding b =
        TestWidgetsFlutterBinding.ensureInitialized();
    b.platformDispatcher.views.first.physicalSize = const Size(375, 812);
    b.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(b.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(b.platformDispatcher.views.first.resetDevicePixelRatio);
  });

  testWidgets('A1 — taze kurulumdan SONUÇ yüzeyine tek TAM AKIŞ',
      (WidgetTester t) async {
    final _FlowWitness w = _FlowWitness();
    final List<String> leg = <String>[];

    Future<void> tap(Finder f, String what) async {
      expect(f.evaluate(), isNotEmpty, reason: '"$what" ekranda YOK');
      try {
        await t.ensureVisible(f.first);
        await t.pump();
      } on Object {/* kaydırılabilir ata yok — zaten görünür olabilir */}
      await t.tap(f.first, warnIfMissed: true);
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      leg.add('👆 $what');
    }

    /// Ekranın KENDİ ÖZÜNDEN bir cümle — *ulaşmak ≠ çalışmak.*
    void substance(String where, Pattern must) {
      final Iterable<String> texts =
          t.widgetList<Text>(find.byType(Text)).map((Text x) => x.data ?? '');
      expect(texts.any((String x) => x.contains(must)), isTrue,
          reason: '$where yüzeyine varıldı ama ÖZÜ yok — kabuk çizilmiş, '
              'içerik boş');
      leg.add('   ✓ $where: özü var');
    }

    // ── ① TAZE KURULUM ────────────────────────────────────────────────
    // `alreadyOnboarded: false` + boş depo = ilk açılış. Onboarding
    // BAYRAK SET EDİLEREK değil, DÜĞMEYE BASILARAK geçilecek (A2).
    await t.pumpWidget(ContentRepositoryScope(
      repo: repo,
      cueText: cueText,
      child: MaterialApp(
        navigatorObservers: <NavigatorObserver>[w],
        home: OstinatoHome(
          repo: repo,
          cueText: cueText,
          store: InMemoryOnboardingStore(),
          alreadyOnboarded: false,
        ),
      ),
    ));
    await t.pump();
    expect(find.byKey(const Key('onboarding-primary')), findsOneWidget,
        reason: 'taze kurulumda onboarding AÇILMADI — akışın başı yok');
    leg.add('① taze kurulum → Onboarding');

    for (int i = 0; i < 3; i++) {
      await tap(find.byKey(const Key('onboarding-primary')),
          'onboarding perde ${i + 1}');
    }
    substance('Kütüphane', 'Written lessons. Posture references.');

    // ── ② SEÇİM ──────────────────────────────────────────────────────
    await tap(find.text('Guitar'), 'Gitar');
    substance('Çalgı', 'not all the same kind of gap');

    final Course course = guitar.courses.first;
    await tap(find.text(course.displayName), 'kurs: ${course.displayName}');

    final Lesson lesson = course.lessons
        .firstWhere((Lesson l) => l.kind == LessonKind.scored);
    await tap(find.text(lesson.displayName), 'ders: ${lesson.displayName}');
    substance('Ders', lesson.displayName);

    // ── ③ KURULUM KONTROLÜ — hâlâ GERÇEK DOKUNUŞ ─────────────────────
    await tap(find.text('Begin the setup check'), 'Begin the setup check');
    substance('Kurulum Kontrolü', 'Find your frame');
    final int tappedLegs = w.events.length;

    // ── ④ ⚠️ ZERK EDİLEN BACAK — burada DOKUNMUYORUZ, KURUYORUZ ───────
    // Kurulumun "Start the lesson" düğmesi `_Stage.passed`ta doğar ve o
    // aşama gerçek kare ister. Koşum, ürünün push edeceği ekranı AYNI
    // parametrelerle (`setup_check_screen.dart:490-493`) kendisi kurar —
    // tek fark: `source` ZERK EDİLİR.
    final FakePoseSource fake = FakePoseSource(
      // Bandın içinde (ders metni: 0.4°–6.4°) — hüküm belirlensin diye
      // KASITLI olarak istikrarlı; "Steady." beklentisi böylece TÜRETİLİR.
      List<double?>.generate(24, (int i) => 2.0 + (i % 5) * 0.4),
      stepUs: 100000,
    );
    addTearDown(() async {
      await fake.stop();
      await fake.dispose();
    });
    final BuildContext ctx = t.element(find.byType(Scaffold).first);
    // ignore: use_build_context_synchronously
    unawaitedPush(ctx, guitar, lesson, fake);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    leg.add('④ ⚠️ ZERK: SetupCheck → Live (koşum kurdu, DOKUNULMADI)');
    expect(find.byType(LiveScreenRoute), findsOneWidget,
        reason: 'zerk edilen canlı oturum ekrana gelmedi');

    // ── ⑤ OTURUM — sahte kare akıyor, ÜRÜN kodu ölçüyor ───────────────
    for (int i = 0; i < 26; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    substance('Canlı oturum', '°');

    // ── ⑥ SONUÇ — yine GERÇEK DOKUNUŞ, ürünün kendi düğmesi ───────────
    await tap(find.text('Stop and see the summary'),
        'Stop and see the summary');
    await t.pump(const Duration(milliseconds: 400));

    expect(find.byType(ReviewScreenRoute), findsOneWidget,
        reason: 'oturum bitti ama SONUÇ yüzeyine geçilmedi — akış son '
            'adımında kopuyor');
    // ignore: avoid_print
    print('\n─── SONUÇ YÜZEYİNDE KURULU METİNLER ───');
    for (final String x in t
        .widgetList<Text>(find.byType(Text))
        .map((Text e) => e.data ?? '')
        .where((String e) => e.trim().isNotEmpty)) {
      // ignore: avoid_print
      print('   | ${x.length > 100 ? '${x.substring(0, 100)}…' : x}');
    }
    // 🪤 ÖLÇÜLDÜ (O-122): bölüm etiketleri `kicker()`ten geçer ve
    // `ostinato_theme.dart:180` onları `toUpperCase()` yapar. Kaynakta
    // 'What we measured' yazan şey ekranda 'WHAT WE MEASURED'dır.
    // > ***BİR YÜZEYİ KAYNAK DİZGESİYLE ARAMAK, ÜRÜNÜN ÇİZDİĞİNİ DEĞİL
    // > YAZARIN YAZDIĞINI ARAMAKTIR.***
    substance('Sonuç', 'WHAT WE MEASURED');
    substance('Sonuç', 'WHAT WE DID NOT JUDGE');
    // ⭐ Ve asıl kanıt bir ETİKET değil, ÖLÇÜLMÜŞ BİR CÜMLE: bu satır yalnız
    // `nothingReadable == false` dalında doğar (`review_screen.dart:188`),
    // yani zerk edilen karelerin ürünün ölçüm hattından GEÇTİĞİNİN kanıtı.
    substance('Sonuç', 'Your trunk stayed inside');

    // ⚖️ SONUÇ ÖLÇÜLEN VERİDEN TÜREMELİ — kabuk değil.
    // `SessionSummary.verdict` sıfır okunabilir karede 'Nothing we could
    // read.' der; bandın içinde kalındıysa 'Steady.'. Sahte kaynak bandın
    // İÇİNDE olduğu için beklenti TÜRETİLMİŞTİR, elle yazılmamıştır.
    final Iterable<String> reviewTexts =
        t.widgetList<Text>(find.byType(Text)).map((Text x) => x.data ?? '');
    expect(reviewTexts.any((String x) => x.contains('Nothing we could read')),
        isFalse,
        reason: 'SONUÇ yüzeyi "hiçbir kare okunamadı" diyor — oturum '
            'boyunca zerk edilen 24 kare ekrana HİÇ ULAŞMAMIŞ demektir; '
            'akış görünüşte tamam, ÖLÇÜM bacağı kopuk');

    // ── ⑦ TANIK ──────────────────────────────────────────────────────
    // ignore: avoid_print
    print('\n═══ A1 — TAM AKIŞ ═══');
    for (final String l in leg) {
      // ignore: avoid_print
      print('   $l');
    }
    // ignore: avoid_print
    print('   tanık: ${w.events.length} rota olayı ${w.events}\n'
        '   ⚠️ bunun ${w.events.length - tappedLegs} tanesi ZERK SONRASI: '
        '1 koşum-push + 1 ürün-replace (Live→Review)\n'
        '   ✅ DOKUNARAK yürünen bacak: $tappedLegs rota olayı\n');
    expect(w.events.length, greaterThanOrEqualTo(tappedLegs + 2),
        reason: 'zerkten sonra iki rota olayı beklenir (koşumun push\'u + '
            'ürünün Live→Review replace\'i); eksikse özet ekranına rota '
            'DEĞİŞTİRMEDEN varılmış demektir');
    expect(w.events.last, 'replace',
        reason: 'son olay `pushReplacement` olmalı — `live_screen.dart` '
            '`_stop()` oturumu geri dönülemez biçimde kapatır; `push` '
            'görünürse kullanıcı geri gelip biten bir oturuma düşebilir');
  });
}

/// Zerk edilen bacağın TEK yeri — çağrı sitesi ürünün kendi push'uyla
/// AYNI parametreleri taşır (`setup_check_screen.dart:490-493`), tek fark
/// `source`. Ayrı bir fonksiyon çünkü zerk noktasının **tek ve görünür**
/// olması gerekiyor: dağılırsa, sonraki okuyucu bunu dokunuş sanır.
void unawaitedPush(BuildContext ctx, Discipline discipline, Lesson lesson,
    PoseSource source) {
  Navigator.of(ctx).push(MaterialPageRoute<void>(
    builder: (_) => LiveScreenRoute(
      discipline: discipline,
      lesson: lesson,
      hue: InstrumentHues.guitar,
      source: source,
      skipCountdown: true,
    ),
  ));
}
