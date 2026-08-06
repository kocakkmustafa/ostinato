import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';
import 'package:ostinato/app/screens/live_screen.dart';
import 'package:ostinato_posture/ostinato_posture.dart';

/// Canlı YOLUN widget seviyesindeki kanıtı — sahte kaynakla.
///
/// Kanıt sınıfı bilerek dar: bu testler "kamera çalışıyor" DEMEZ. Söyledikleri
/// şu: postür kareleri yüzeye ulaşıyor, tipli hâllerin her biri kendi ekranını
/// açıyor, gözlem işareti bant içinde SUSUYOR ve dışında GÖRÜNÜYOR, ve hiçbir
/// yerde sayısal puan yok.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // google_fonts ağ erişimi denemesin — testler deterministik/çevrimdışı kalır.
  GoogleFonts.config.allowRuntimeFetching = false;

  late ContentRepository repo;
  late CueTextResolver cueText;
  late Discipline guitar;
  late Lesson postureLesson;

  setUpAll(() async {
    repo = await ContentRepository.load();
    cueText = await CueTextResolver.load();
    guitar = repo.disciplines.firstWhere((Discipline d) => d.id == 'guitar');
    postureLesson = guitar.lessons
        .firstWhere((Lesson l) => l.id == 'guitar.foundations.posture');
  });

  Future<FakePoseSource> pump(WidgetTester tester, List<double?> script) async {
    final FakePoseSource src = FakePoseSource(script);
    // ContentRepositoryScope MaterialApp'i SARAR (main.dart ile AYNI kural)
    // — Navigator'ın Overlay'i MaterialApp içinde kurulur, push edilen her
    // route'un Scope'u görebilmesi için Scope Overlay'in DIŞINDA olmalı.
    await tester.pumpWidget(ContentRepositoryScope(
      repo: repo,
      cueText: cueText,
      child: MaterialApp(
        home: LiveScreenRoute(
          discipline: guitar,
          lesson: postureLesson,
          hue: InstrumentHues.guitar,
          source: src,
          skipCountdown: true,
        ),
      ),
    ));
    return src;
  }

  /// Bir kare it ve EKRANA ÇIKTIĞINDAN emin ol.
  ///
  /// Akış teslimi bir mikrotask sonra gelir: tek `pump()` bir ÖNCEKİ karenin
  /// setState'ini çizer. Bunu fark etmeden yazılan bir test, sınadığı
  /// sandığı kareden bir öncekini sınar — sessizce yanlış geçer.
  Future<void> feed(WidgetTester t, FakePoseSource src) async {
    src.pushOne();
    await t.pump(); // teslim
    await t.pump(); // çizim
  }

  testWidgets('açılışta ölçüm başlamadan önce bir hâl gösterilir',
      (WidgetTester t) async {
    await pump(t, <double?>[2.0]);
    // FakePoseSource senkron başlar; ilk kare henüz akmadan Starting
    // GÖRÜLEBİLİR ya da doğrudan ilk kareye geçilebilir — asıl kanıt: ekran
    // çökmez, tipli bir ağaç kurulur (kabuk widget testlerinin amacı budur).
    expect(find.byType(LiveScreenRoute), findsOneWidget);
  });

  testWidgets('kaynak akınca ölçüm ekranı ve BANT görünür', (WidgetTester t) async {
    final FakePoseSource src = await pump(t, <double?>[3.0]);
    await feed(t, src);
    expect(find.byKey(const Key('live-measuring')), findsOneWidget);
    expect(find.byKey(const Key('you-marker')), findsOneWidget);
    // Bant sayıları SÖZLEŞMEDEN gelir, widget'ta sabit değildir.
    expect(find.textContaining('0.4–6.4°'), findsOneWidget);
    expect(find.textContaining('N=7'), findsOneWidget);
    await src.dispose();
  });

  testWidgets('kişi yoksa "göremiyorum" bandı — hata DEĞİL, "0 derece" DEĞİL',
      (WidgetTester t) async {
    final FakePoseSource src = await pump(t, <double?>[null]);
    await feed(t, src);
    expect(find.byKey(const Key('live-blind')), findsOneWidget);
    expect(find.textContaining("I can’t see you"), findsOneWidget);
    await src.dispose();
  });

  testWidgets('POZİTİF İKİZ: bant içinde işaret YOK', (WidgetTester t) async {
    final FakePoseSource src = await pump(t, <double?>[3.0, 2.8, 3.2, 2.5, 3.1]);
    for (int i = 0; i < 5; i++) {
      await feed(t, src);
    }
    expect(find.byKey(const Key('observation-cue')), findsNothing,
        reason: 'bant içindeyken işaret göründü — sözleşme bozuk');
    await src.dispose();
  });

  testWidgets('İKİZ: sürdürülen sapmada işaret GÖRÜNÜR ve KAYNAĞINI taşır',
      (WidgetTester t) async {
    final FakePoseSource src = await pump(t, <double?>[22.0, 22.0, 22.0, 22.0]);
    for (int i = 0; i < 4; i++) {
      await feed(t, src);
    }
    expect(find.byKey(const Key('observation-cue')), findsOneWidget,
        reason: 'sapma sürdü ama işaret doğmadı — hep-sessiz yüzey');
    // Şart 3: N + kaynak sınıfı CÜMLENİN İÇİNDE — golden katalogdan.
    expect(find.textContaining('None of the 7 guitar teachers'), findsOneWidget);
    await src.dispose();
  });

  group('işaret TAZELİĞİ — O-034 rejresyonu (bayat-çözülmüş-metin)', () {
    testWidgets('işaretteki sayı GÜNCEL ölçümle senkron kalır',
        (WidgetTester t) async {
      final FakePoseSource src = await pump(t, <double?>[22.0, 22.0, 22.0, 17.0]);
      for (int i = 0; i < 4; i++) {
        await feed(t, src);
      }
      expect(find.byKey(const Key('observation-cue')), findsOneWidget);
      // Golden şablon measuredDeg'i tam sayıya yuvarlar (ObservationCue.slots,
      // toStringAsFixed(0)) — "17°", "17.0°" DEĞİL.
      expect(find.textContaining('You are at 17° right now'), findsOneWidget);
      expect(find.textContaining('You are at 22° right now'), findsNothing,
          reason: 'işaret bayat bir ölçümde donmuş — ekranda çelişen sayı');
      await src.dispose();
    });

    testWidgets('banda dönünce işaret SUSAR (şart 6, canlı)',
        (WidgetTester t) async {
      final FakePoseSource src = await pump(t, <double?>[22.0, 22.0, 22.0, 3.0]);
      for (int i = 0; i < 3; i++) {
        await feed(t, src);
      }
      expect(find.byKey(const Key('observation-cue')), findsOneWidget);
      await feed(t, src); // banda döndü
      expect(find.byKey(const Key('observation-cue')), findsNothing,
          reason: 'banda dönüldü ama işaret ekranda kaldı');
      await src.dispose();
    });
  });

  group('çıkmaz-sokak yasağı + izin ayrımı (zeyil-3, tur-2 ile canlı)', () {
    Future<void> pumpState(WidgetTester t, SurfaceState forced) async {
      await t.pumpWidget(ContentRepositoryScope(
        repo: repo,
        cueText: cueText,
        child: MaterialApp(
          home: LiveScreenRoute(
            discipline: guitar,
            lesson: postureLesson,
            hue: InstrumentHues.guitar,
            source: StaticStatusSource(forced),
            skipCountdown: true,
          ),
        ),
      ));
      await t.pump();
      await t.pump();
    }

    testWidgets('kurulum patlasa da EKRAN AÇILIR ve analiz-yokluğu BEYAN EDİLİR',
        (WidgetTester t) async {
      await pumpState(t, const SetupFailed('camera-permission-denied'));
      expect(find.byKey(const Key('live-setup-failed')), findsOneWidget,
          reason: 'kurulum hatası ekranı yok — "dokun, hiçbir şey olmaz" '
              'sessiz ölümü');
      expect(find.textContaining('not analysing anything'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
    });

    testWidgets('GEÇİCİ redde "tekrar dene" VAR', (WidgetTester t) async {
      await pumpState(t, const PermissionDeniedRetriable());
      expect(find.byKey(const Key('live-permission-retriable')), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('KALICI redde "tekrar dene" YOK — işlevsiz düğme gösterilmez',
        (WidgetTester t) async {
      await pumpState(t, const PermissionDeniedPermanent());
      expect(find.byKey(const Key('live-permission-permanent')), findsOneWidget);
      expect(find.text('Try again'), findsNothing,
          reason: 'sistem bir daha sormaz — "tekrar dene" yalan bir düğme olur');
      expect(find.text('Open Settings'), findsOneWidget);
    });
  });

  testWidgets('K8: ekranda YÜZDE/PUAN yok', (WidgetTester t) async {
    final FakePoseSource src = await pump(t, <double?>[3.0]);
    await feed(t, src);
    final Iterable<Text> texts = t.widgetList<Text>(find.byType(Text));
    for (final Text w in texts) {
      final String s = w.data ?? '';
      expect(s.contains('%'), isFalse, reason: 'yüzde göründü: "$s"');
      // "no score" / "No score" İSTİSNA: K8'i YOKLUĞUYLA doğrulayan cümle
      // ("No score, and none is coming") — yasak olan SAYISAL puan dili,
      // yokluğun kendisi değil. "no score"u çıkarıp geri kalanı taranır.
      final String withoutNoScore =
          s.replaceAll(RegExp(r'\bno score\b', caseSensitive: false), '');
      expect(RegExp(r'\b(score|Score|points|/10|/100)\b').hasMatch(withoutNoScore),
          isFalse, reason: 'puan dili göründü: "$s"');
    }
    await src.dispose();
  });
}
