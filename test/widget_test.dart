import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/posture_screen.dart';
import 'package:ostinato_posture/ostinato_posture.dart';

/// Canlı YOLUN widget seviyesindeki kanıtı — sahte kaynakla.
///
/// Kanıt sınıfı bilerek dar: bu testler "kamera çalışıyor" DEMEZ. Söyledikleri
/// şu: postür kareleri yüzeye ulaşıyor, tipli hâllerin her biri kendi ekranını
/// açıyor, gözlem işareti bant içinde SUSUYOR ve dışında GÖRÜNÜYOR, ve hiçbir
/// yerde sayısal puan yok.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ContentRepository repo;
  late CueTextResolver cueText;

  setUpAll(() async {
    repo = await ContentRepository.load();
    cueText = await CueTextResolver.load();
  });

  Future<FakePoseSource> pump(WidgetTester tester, List<double?> script) async {
    final FakePoseSource src = FakePoseSource(script);
    final Discipline d = repo.disciplines.firstWhere((Discipline x) => x.id == 'guitar');
    await tester.pumpWidget(MaterialApp(
      home: PostureScreen(
        discipline: d,
        contract: repo.contractFor('guitar'),
        cueText: cueText,
        source: src,
        sourceLabel: 'TEST SOURCE — synthetic',
      ),
    ));
    return src;
  }

  /// Bir kare it ve EKRANA ÇIKTIĞINDAN emin ol.
  ///
  /// Akış teslimi bir mikrotask sonra gelir: tek `pump()` bir ÖNCEKİ karenin
  /// setState'ini çizer. Bunu fark etmeden yazılan bir test, sınadığını
  /// sandığı kareden bir öncekini sınar — sessizce yanlış geçer.
  Future<void> feed(WidgetTester t, FakePoseSource src) async {
    src.pushOne();
    await t.pump(); // teslim
    await t.pump(); // çizim
  }

  testWidgets('açılışta Starting ekranı — "bağlandı ≠ canlı"', (WidgetTester t) async {
    await pump(t, <double?>[2.0]);
    expect(find.byKey(const Key('state-starting')), findsOneWidget);
    expect(find.byKey(const Key('state-measuring')), findsNothing);
  });

  testWidgets('kaynak akınca ölçüm ekranı ve BANT görünür', (WidgetTester t) async {
    final FakePoseSource src = await pump(t, <double?>[3.0]);
    await feed(t, src);
    expect(find.byKey(const Key('state-measuring')), findsOneWidget);
    expect(find.byKey(const Key('you-marker')), findsOneWidget);
    // Bant sayıları SÖZLEŞMEDEN gelir, widget'ta sabit değildir.
    expect(find.textContaining('0.4° to 6.4°'), findsOneWidget);
    expect(find.textContaining('7 guitar teachers'), findsOneWidget);
    await src.dispose();
  });

  testWidgets('kişi yoksa NoPersonVisible — hata DEĞİL, "0 derece" DEĞİL',
      (WidgetTester t) async {
    final FakePoseSource src = await pump(t, <double?>[null]);
    await feed(t, src);
    expect(find.byKey(const Key('state-no-person')), findsOneWidget);
    expect(find.textContaining('not an error'), findsOneWidget);
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
    // Şart 3: N + kaynak sınıfı CÜMLENİN İÇİNDE.
    expect(find.textContaining('None of the 7 guitar teachers'), findsOneWidget);
    await src.dispose();
  });


  group('işaret TAZELİĞİ — sim ekran-kanıtının yakaladığı kusurun regresyonu', () {
    // İlk sürümde işaret metni çözülüp SAKLANIYORDU: başlık "You: 18.0°"
    // derken işaret "You are at 20°" diyordu — ekranda birbiriyle çelişen
    // iki sayı. Bu testler o günü beklemeden kırar.
    testWidgets('işaretteki sayı BAŞLIKTAKİ sayıyla aynı kalır',
        (WidgetTester t) async {
      final FakePoseSource src = await pump(t, <double?>[22.0, 22.0, 22.0, 17.0]);
      for (int i = 0; i < 4; i++) {
        await feed(t, src);
      }
      expect(find.byKey(const Key('observation-cue')), findsOneWidget);
      expect(find.textContaining('You: 17.0°'), findsOneWidget);
      expect(find.textContaining('You are at 17° right now'), findsOneWidget,
          reason: 'işaret bayat bir ölçümde donmuş — ekranda çelişen iki sayı');
      expect(find.textContaining('You are at 22° right now'), findsNothing);
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


  group('çıkmaz-sokak yasağı + izin ayrımı (zeyil-3)', () {
    /// Hâli DOĞRUDAN dayatan minik kaynak: kurulum yollarını, gerçek kamera
    /// olmadan, yüzeyde sınamak için.
    Future<void> pumpState(WidgetTester t, SurfaceState forced) async {
      await t.pumpWidget(MaterialApp(
        home: PostureScreen(
          discipline: repo.disciplines.firstWhere((Discipline x) => x.id == 'guitar'),
          contract: repo.contractFor('guitar'),
          cueText: cueText,
          source: StaticStatusSource(forced),
          sourceLabel: 'TEST',
        ),
      ));
      await t.pump(); // teslim
      await t.pump(); // çizim
    }

    testWidgets('kurulum patlasa da EKRAN AÇILIR ve analiz-yokluğu BEYAN EDİLİR',
        (WidgetTester t) async {
      await pumpState(t, const SetupFailed('camera-permission-denied'));
      expect(find.byKey(const Key('state-setup-failed')), findsOneWidget,
          reason: 'kurulum hatası ekranı yok — "dokun, hiçbir şey olmaz" '
              'sessiz ölümü');
      expect(find.textContaining('not analysing anything'), findsOneWidget);
      // Ham detay sızmasın: sebep İSİMLİ, yığın izi değil.
      expect(find.textContaining('Exception'), findsNothing);
    });

    testWidgets('GEÇİCİ redde "tekrar dene" VAR', (WidgetTester t) async {
      await pumpState(t, const PermissionDeniedRetriable());
      expect(find.byKey(const Key('state-permission-retriable')), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('KALICI redde "tekrar dene" YOK — işlevsiz düğme gösterilmez',
        (WidgetTester t) async {
      await pumpState(t, const PermissionDeniedPermanent());
      expect(find.byKey(const Key('state-permission-permanent')), findsOneWidget);
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
      expect(RegExp(r'\b(score|Score|points|/10|/100)\b').hasMatch(s), isFalse,
          reason: 'puan dili göründü: "$s"');
    }
    await src.dispose();
  });
}
