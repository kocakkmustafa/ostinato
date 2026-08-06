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
    final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
    final ByteData? bytes =
        await image.toByteData(format: ui.ImageByteFormat.png);
    File('docs/evidence/$filename').writeAsBytesSync(
        bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
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
    expect(t.takeException(), isNull);
    await capture(t, '01-demo-lesson-guitar.png');
  });

  testWidgets('02 — Scored lesson (guitar/sitting posture) — "Nine upper-body '
      'landmarks" + kesikli-kol figürü YAN YANA', (WidgetTester t) async {
    final Discipline d = guitar();
    final Lesson l = d.lessons
        .firstWhere((Lesson x) => x.id == 'guitar.foundations.posture');
    await t.pumpWidget(harness(LessonScoredScreenRoute(
        discipline: d, lesson: l, hue: InstrumentHues.guitar)));
    await t.pump();
    expect(t.takeException(), isNull);
    await capture(t, '02-scored-lesson-guitar-posture.png');
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
    expect(t.takeException(), isNull);
    await capture(t, '04a-live-measuring-inband.png');
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
    await capture(t, '04b-live-observation-cue.png');
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
    expect(t.takeException(), isNull);
    await capture(t, '05-review.png');
  });

  testWidgets('06 — Settings', (WidgetTester t) async {
    await t.pumpWidget(harness(const SettingsScreen()));
    await t.pump();
    expect(t.takeException(), isNull);
    await capture(t, '06-settings.png');
  });
}
