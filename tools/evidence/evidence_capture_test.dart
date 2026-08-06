import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';
import 'package:ostinato/app/screens/lesson_demo_screen.dart';
import 'package:ostinato/app/screens/lesson_scored_screen.dart';
import 'package:ostinato/app/screens/live_screen.dart';
import 'package:ostinato/app/screens/review_screen.dart';
import 'package:ostinato/app/screens/settings_screen.dart';
import 'package:ostinato_posture/ostinato_posture.dart';

/// Ekran-kanıtı üreticisi — O-037'nin kapanışı (koordinatör tetiği,
/// 2026-08-06). Simülatörün dokunma-enjeksiyonu bu turda İKİNCİ KEZ tıkandı
/// — kardeş süreçler kapatıldıktan SONRA bile (kayıt: DEFTER O-037, ikinci
/// arıza notu). "Enjeksiyon yine tıkanırsa ısrar etme, İSİMLİ DURDUR" —
/// bu dosya o duruşun kendisi: gerçek dokunma-gezinmesi yerine GERÇEK widget
/// ağacını (gerçek `ContentRepository`, gerçek golden katalog, sahte METİN
/// YOK) doğrudan pump edip `RepaintBoundary.toImage()` ile KALICI PNG
/// üretiyor. Kanıt sınıfı FARKLI: "dokunarak ekrana ulaştım" değil, "ekranı
/// gerçek veriyle inşa edip GÖZLE okudum" — ikisi de meşru, ama aynı şey
/// DEĞİL, karıştırılmasın.
///
/// 375×812 (Lissom standardı, iPhone 13 mini sınıfı) — dar cihaz, geniş
/// değil; aynı zamanda `real_content_overflow_test.dart`ın kanıtladığı
/// genişlikle BİREBİR aynı.
///
/// M-F-281 disiplini (Live): gözlem işareti PERİYODİK (~%7.4 görünür).
/// Tek rastgele kare YETMEZ — burada `cue_cooldown_visibility_test.dart`ın
/// PROVEN tick-15 ilk-ateşleme senaryosu AYNEN tekrarlanıyor (zamanı
/// KONTROL EDEN deterministik yol), rastgele bir ana güvenilmiyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  // ÖLÇÜLDÜ (2026-08-06), ÜÇ ayrı düzeltme denendi ve HİÇBİRİ istisnayı
  // testin KENDİ gövdesinde yakalanabilir kılmadı: (1) `--use-test-fonts`
  // gerçek glif yerine blok çiziyor — Dart ayarından bağımsız. (2)
  // `runAsync` (capture'daki asıl düzeltme, GEÇERLİ ve KORUNUYOR — o
  // olmadan test 10 dk asılı kalıyordu) `allowRuntimeFetching=false` ile
  // birleşince google_fonts'un "font not found in application assets"
  // istisnasını framework'ün İÇ zamanlamasında (testin gövdesi bittikten
  // SONRA) açığa çıkarıyor — `takeException` drain'i iki ayrı yerde
  // (capture öncesi/sonrası) denendi, YAKALAYAMADI. (3) fetch'i AÇMAK
  // istisna sınıfını değiştirdi ama ortadan KALDIRMADI (ağ isteği bu test
  // ortamından ULAŞAMIYOR: "Failed to load font with url:
  // fonts.gstatic.com/..."), ÜSTELİK ağa bağımlı bir test kalıcı kapı
  // için YANLIŞ yön olurdu.
  //
  // BU YÜZDEN bu dosya BİLEREK `test/` dışında yaşıyor — `flutter test`in
  // varsayılan süpürmesine (dolayısıyla `run_gates.sh`a) hiç girmiyor,
  // yalnız açıkça çağrıldığında koşuyor. Ölçülen istisna GLİF'i etkiler,
  // VERİYİ değil — PNG'ler DÜZEN kanıtı (CustomPainter/vektör, glif
  // sorunundan ETKİLENMEZ), `dumpText`in ürettiği .txt'ler gerçek
  // `Text.data` dizeleri (piksel değil) — ikisi birlikte "ekranı gerçek
  // veriyle inşa edip GÖZLE okudum" kanıtını TAM karşılıyor, testin kendi
  // PASS/FAIL durumu bu kanıtın geçerliliğini DEĞİŞTİRMİYOR.

  late ContentRepository repo;
  late CueTextResolver cueText;
  setUpAll(() async {
    repo = await ContentRepository.load();
    cueText = await CueTextResolver.load();
    Directory('docs/evidence').createSync(recursive: true);
  });

  setUp(() {
    final TestWidgetsFlutterBinding binding =
        TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize =
        const Size(375, 812) * 2;
    binding.platformDispatcher.views.first.devicePixelRatio = 2.0;
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);
  });

  final GlobalKey captureKey = GlobalKey();

  Widget harness(Widget child) => ContentRepositoryScope(
        repo: repo,
        cueText: cueText,
        child: MaterialApp(
          home: RepaintBoundary(key: captureKey, child: child),
        ),
      );

  Future<void> capture(WidgetTester t, String filename) async {
    await t.pump(const Duration(milliseconds: 50));
    final RenderRepaintBoundary boundary = captureKey.currentContext!
        .findRenderObject()! as RenderRepaintBoundary;
    // ÖLÇÜLEN KÖK NEDEN (2026-08-06): `toImage`/`toByteData` motorun GERÇEK
    // (sahte-zaman değil) async işi — düz `await` ile çağrılınca testin
    // fake-async bölgesinde TAMAMLANMASI garanti değil (10 dakikalık çerçeve
    // zaman aşımına kadar asılı kaldığı ölçüldü). `runAsync` bölgeyi geçici
    // olarak GERÇEK zamana açar — standart Flutter test-görüntü deseni.
    await t.runAsync(() async {
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final ByteData? bytes =
          await image.toByteData(format: ui.ImageByteFormat.png);
      File('docs/evidence/$filename').writeAsBytesSync(bytes!.buffer
          .asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      image.dispose();
    });
  }

  /// Ekrandaki HER `Text` widget'ının GERÇEK `.data` dizesini, görünüm
  /// sırasına yakın biçimde bir .txt'e yazar — piksel değil, ASIL METİN.
  /// `RichText`i de (golden-katalog cümleleri bazı ekranlarda `RichText`
  /// olarak geliyor — kilitli-ders "Read why ›" deseni) kapsar.
  void dumpText(WidgetTester t, String filename) {
    final List<String> lines = <String>[];
    for (final Text w in t.widgetList<Text>(find.byType(Text))) {
      final String? d = w.data;
      if (d != null && d.trim().isNotEmpty) lines.add(d);
    }
    for (final RichText w in t.widgetList<RichText>(find.byType(RichText))) {
      final StringBuffer sb = StringBuffer();
      void walk(InlineSpan s) {
        if (s is TextSpan) {
          if (s.text != null) sb.write(s.text);
          s.children?.forEach(walk);
        }
      }
      walk(w.text);
      final String joined = sb.toString().trim();
      if (joined.isNotEmpty) lines.add('[RichText] $joined');
    }
    File('docs/evidence/$filename').writeAsStringSync(lines.join('\n'));
  }

  /// `takeException()`i BEKLENEN GoogleFonts istisnasını (ölçüldü: bkz.
  /// dosya başı notu — `allowRuntimeFetching=false` + yerel .ttf yok, her
  /// zaman olan ama önceden `--use-test-fonts` tarafından sessizce
  /// yutulan bir durum) DRAIN eder; başka bir istisna çıkarsa test yine
  /// BAŞARISIZ olur — sahte bir "temiz" geçiş üretmiyoruz.
  Future<void> expectOnlyFontException(WidgetTester t) async {
    // Font-yükleme reddi GERÇEK event-loop'ta olur (bkz. `capture`'daki
    // runAsync notu) — boş bir `runAsync` burada AYNI gerçek-zaman
    // penceresini açıp reddi `capture()`dan ÖNCE, burada yakalanabilir
    // hâle getiriyor.
    await t.runAsync(() async {});
    while (true) {
      final Object? e = t.takeException();
      if (e == null) return;
      expect(e.toString(), contains('allowRuntimeFetching'),
          reason: 'beklenmeyen istisna: $e');
    }
  }

  Discipline guitar() =>
      repo.disciplines.firstWhere((Discipline d) => d.id == 'guitar');

  testWidgets('01 — Demo lesson (guitar, en uzun gerçek başlık)',
      (WidgetTester t) async {
    final Discipline d = guitar();
    final Lesson l =
        d.lessons.firstWhere((Lesson x) => x.kind == LessonKind.demoOnly);
    await t.pumpWidget(harness(LessonDemoScreenRoute(
        discipline: d, lesson: l, hue: InstrumentHues.guitar)));
    await t.pump();
    await expectOnlyFontException(t);
    await capture(t, '01-demo-lesson-guitar.png');
    dumpText(t, '01-demo-lesson-guitar.txt');
  });

  testWidgets('02 — Scored lesson (guitar/sitting posture) — "Nine upper-body '
      'landmarks" + kesikli-kol figürü YAN YANA', (WidgetTester t) async {
    final Discipline d = guitar();
    final Lesson l = d.lessons
        .firstWhere((Lesson x) => x.id == 'guitar.foundations.posture');
    await t.pumpWidget(harness(LessonScoredScreenRoute(
        discipline: d, lesson: l, hue: InstrumentHues.guitar)));
    await t.pump();
    await expectOnlyFontException(t);
    await capture(t, '02-scored-lesson-guitar-posture.png');
    dumpText(t, '02-scored-lesson-guitar-posture.txt');
  });

  // 03 — Setup Check: BİLEREK bu dosyada YOK. `SetupCheckScreenRoute`
  // `initState()`'te GERÇEK `MotionCameraController()` kurar (LiveScreenRoute
  // gibi enjekte edilebilir bir `source` almaz) — widget-test ortamında bu
  // platform-kanalına bağlanmayı DENER ve YANIT gelmediği için `_start()`
  // asla çözülmez, `flutter test` süresiz ASILI KALIR (ölçüldü: 2+ dakika
  // sıfır çıktı, öldürülmek zorunda kalındı). Bu O-036'nın (tur-2) AYNI
  // donanım sınırının bir başka yüzü — simülatörde gerçek kamera yok, burada
  // "yok"un sonucu sessiz beklemek değil KİLİTLENMEK. İsimli sınır olarak
  // bırakılıyor, sahte bir "starting" karesi üretmek için motoru değiştirmek
  // bu turun kapsamı değil.

  testWidgets('04a — Live, bant-içi (nötr an, kesikli-kol figürü)',
      (WidgetTester t) async {
    final Discipline d = guitar();
    final Lesson l = d.lessons
        .firstWhere((Lesson x) => x.id == 'guitar.foundations.posture');
    final FakePoseSource src = FakePoseSource(<double?>[3.0, 2.8, 3.1, 2.9]);
    await t.pumpWidget(harness(LiveScreenRoute(
      discipline: d,
      lesson: l,
      hue: InstrumentHues.guitar,
      source: src,
      skipCountdown: true,
    )));
    for (int i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 180));
    }
    await expectOnlyFontException(t);
    await capture(t, '04a-live-measuring-inband.png');
    dumpText(t, '04a-live-measuring-inband.txt');
    await src.dispose();
  });

  testWidgets(
      '04b — Live, gözlem işareti GÖRÜNÜR (M-F-281: proven tick-15, '
      'rastgele kare DEĞİL — cue_cooldown_visibility_test.dart ile AYNI '
      'senaryo)', (WidgetTester t) async {
    final Discipline d = guitar();
    final Lesson l = d.lessons
        .firstWhere((Lesson x) => x.id == 'guitar.foundations.posture');
    final FakePoseSource src = FakePoseSource(<double?>[
      2.0, 2.4, 3.1, 2.8, 3.4, 2.2, 2.9, 3.3, 2.5, 3.0,
      null, null, null,
      16.0, 18.0, 19.5, 21.0, 22.0, 20.5, 19.0, 20.0, 21.5, 22.5,
    ], stepUs: 180000);
    await t.pumpWidget(harness(LiveScreenRoute(
      discipline: d,
      lesson: l,
      hue: InstrumentHues.guitar,
      source: src,
      skipCountdown: true,
    )));
    // Proven ilk-ateşleme penceresi: tick 15-27 (bkz.
    // cue_cooldown_visibility_test.dart). 18'de duruyoruz — ateşlemiş VE
    // henüz silinmemiş olduğu ölçülmüş bir kare.
    for (int i = 0; i <= 18; i++) {
      await t.pump(const Duration(milliseconds: 180));
    }
    expect(find.byKey(const Key('observation-cue')), findsOneWidget,
        reason: 'proven tick aralığında işaret yok — senaryo kaydı bozuldu');
    await expectOnlyFontException(t);
    await capture(t, '04b-live-observation-cue.png');
    dumpText(t, '04b-live-observation-cue.txt');
    await src.dispose();
  });

  testWidgets('05 — Review (özet ekranı, gerçek SessionSummary)',
      (WidgetTester t) async {
    final Discipline d = guitar();
    final Lesson l = d.lessons
        .firstWhere((Lesson x) => x.id == 'guitar.foundations.posture');
    const SessionSummary summary = SessionSummary(
      elapsedSeconds: 92,
      sampleCount: 72,
      outCount: 9,
      history: <double>[
        3.0, 4.2, 5.8, 7.1, 6.4, 4.9, 3.2, 2.1, 3.8, 5.5,
        6.9, 5.2, 3.6, 2.8, 4.1, 5.9, 7.3, 6.2, 4.4, 3.0,
      ],
    );
    await t.pumpWidget(harness(ReviewScreenRoute(
      discipline: d,
      lesson: l,
      hue: InstrumentHues.guitar,
      summary: summary,
    )));
    await t.pump();
    await expectOnlyFontException(t);
    await capture(t, '05-review.png');
    dumpText(t, '05-review.txt');
  });

  testWidgets('06 — Settings', (WidgetTester t) async {
    await t.pumpWidget(harness(const SettingsScreen()));
    await t.pump();
    await expectOnlyFontException(t);
    await capture(t, '06-settings.png');
    dumpText(t, '06-settings.txt');
  });
}
