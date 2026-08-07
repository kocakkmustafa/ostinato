import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/onboarding_store.dart';
import 'package:ostinato/app/screens/library_screen.dart';
import 'package:ostinato/app/screens/onboarding_screen.dart';
import 'package:ostinato/main.dart';

/// İlk açılış akışı — O-039.
///
/// Bu dosyanın sınadığı şey metnin VARLIĞI değil (ders #2: varlık doğruluk
/// değildir), akışın KAPI olup olmadığı: ilk açılışta karşılama ZORUNLU mu,
/// ikinci açılışta GÖRÜNMÜYOR mu, ve ekrandaki sayılar kütüphaneden mi
/// TÜRÜYOR yoksa elle mi yazılmış.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late ContentRepository repo;
  late CueTextResolver cueText;
  setUpAll(() async {
    repo = await ContentRepository.load();
    // Kabuk açılışta bunu da yüklüyor; `rootBundle` string'leri ÖNBELLEKLER,
    // burada bir kez okumak testteki açılışı deterministik yapar.
    cueText = await CueTextResolver.load();

  });

  // Ders #3: gerçek metin fixture'dan uzun, `flutter_test` varsayılanı ~800pt
  // — gerçek telefonun iki katı. En dar yaygın hedefe SABİTLE.
  setUp(() {
    final TestWidgetsFlutterBinding b =
        TestWidgetsFlutterBinding.ensureInitialized();
    b.platformDispatcher.views.first.physicalSize = const Size(375, 812);
    b.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(b.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(b.platformDispatcher.views.first.resetDevicePixelRatio);
  });

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  /// Kabuğu AÇ — `OstinatoHome` HAZIR bağımlılıklarla pump edilir.
  ///
  /// `OstinatoApp`i pump etmiyoruz: onun `FutureBuilder`ı `rootBundle`dan
  /// gerçek async okur, o da `runAsync` gerektirir, o da `google_fonts`un
  /// kaçınılmaz test hatasını testi düşüren bir bölgeye taşır (bkz.
  /// `OstinatoHome` üstündeki şerh). Dallanma o yüzden ayrıldı; burada bu
  /// kod tabanının geri kalanıyla AYNI desenle sınanıyor.
  Future<void> boot(WidgetTester t, OnboardingStore store,
      {bool alreadyOnboarded = false}) async {
    await t.pumpWidget(ContentRepositoryScope(
      repo: repo,
      cueText: cueText,
      child: MaterialApp(
        home: OstinatoHome(
          repo: repo,
          cueText: cueText,
          store: store,
          alreadyOnboarded: alreadyOnboarded,
        ),
      ),
    ));
    await settle(t);
  }

  group('kabuk kapısı', () {
    testWidgets('İLK açılış: karşılama gelir, kütüphane GELMEZ',
        (WidgetTester t) async {
      await boot(t, InMemoryOnboardingStore());

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(LibraryScreen), findsNothing,
          reason: 'karşılama bir KAPI olmalı — atlanabilirse kullanıcı '
              'wellness beyanını ve izin gerekçesini hiç görmeden kameraya '
              'çıkar');
      expect(t.takeException(), isNull);
    });

    testWidgets('İKİNCİ açılış: doğrudan kütüphane', (WidgetTester t) async {
      await boot(t, InMemoryOnboardingStore(complete: true),
          alreadyOnboarded: true);

      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('üç adım geçilir, işaret KAYDEDİLİR, kütüphane açılır',
        (WidgetTester t) async {
      final InMemoryOnboardingStore store = InMemoryOnboardingStore();
      await boot(t, store);

      expect(find.byKey(const Key('onboarding-welcome-title')), findsOneWidget);
      await t.tap(find.byKey(const Key('onboarding-primary')));
      await settle(t);
      expect(find.byKey(const Key('onboarding-scope-title')), findsOneWidget);

      await t.tap(find.byKey(const Key('onboarding-primary')));
      await settle(t);
      expect(find.byKey(const Key('onboarding-sensors-title')), findsOneWidget);
      expect(store.markCalls, 0,
          reason: 'son adıma VARMAK bitirmek değildir — işaret ancak '
              'kullanıcı akışı kapatınca yazılmalı');

      await t.tap(find.byKey(const Key('onboarding-primary')));
      await settle(t);

      expect(store.markCalls, 1);
      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets(
        'depo YAZAMASA bile aynı oturumda karşılama tekrar GÖSTERİLMEZ',
        (WidgetTester t) async {
      // `FileOnboardingStore.markComplete` sessizce başarısız olabiliyor
      // (bilerek — bkz. gerekçesi). O durumda bile bu oturumda kullanıcı
      // akışa geri düşmemeli.
      await boot(t, _DeafStore());
      for (int i = 0; i < 3; i++) {
        await t.tap(find.byKey(const Key('onboarding-primary')));
        await settle(t);
      }
      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('içerik türetimi', () {
    /// Ekrandaki sayılar ELLE yazılmış olsaydı ilk içerik turunda bayatlardı.
    /// Bu test onların kütüphaneden TÜREDİĞİNİ ölçer: beklenen değerler
    /// burada da sabit DEĞİL, aynı `repo`dan hesaplanır — test ile ekran
    /// aynı kaynağı okur, ikisi birlikte kayar ya da birlikte kalır.
    testWidgets('kapsam sayıları library.json ile aynı', (WidgetTester t) async {
      final List<Discipline> live =
          repo.disciplines.where((Discipline d) => d.status == 'live').toList();
      final List<Lesson> all =
          <Lesson>[for (final Discipline d in live) ...d.lessons];
      final int locked =
          all.where((Lesson l) => l.kind == LessonKind.locked).length;
      final int demo =
          all.where((Lesson l) => l.kind == LessonKind.demoOnly).length;

      await boot(t, InMemoryOnboardingStore());
      await t.tap(find.byKey(const Key('onboarding-primary')));
      await settle(t);

      String valueOf(String key) => t
          .widgetList<Text>(find.descendant(
              of: find.byKey(Key(key)), matching: find.byType(Text)))
          .first
          .data!;

      expect(valueOf('onboarding-fact-instruments'), '${live.length}');
      expect(valueOf('onboarding-fact-lessons'), '${all.length}');
      expect(valueOf('onboarding-fact-locked'), '$locked');
      expect(valueOf('onboarding-fact-demo'), '$demo');

      // Türetimin gerçekten BİR ŞEY saydığı ayrıca sınanır: sıfır sayan bir
      // türetim de "eşleşir" ve sessizce geçerdi.
      //
      // ⚠️ Buradaki iddialar YAPISAL, içerik BOYUTUNA bağlı DEĞİL (JabLab
      // dersi): önceki hâli `all.length >= 19` diyordu ve o gece 19→28'e
      // çıktı. Taban bir kez doğruyken bile yanlış türden bir iddiaydı —
      // ürünün büyüklüğünü değil, türetimin çalıştığını ölçmeliyiz.
      expect(live.length, greaterThan(0));
      expect(all.length, greaterThan(live.length),
          reason: 'her çalgının en az bir dersi olmalı');
      expect(locked, greaterThan(0),
          reason: 'kilitli ders sayısı 0 ise "kilitli" satırı anlamsız');
      expect(demo, greaterThan(0));
    });
  });

  group('dürüstlük sınırları', () {
    testWidgets('üç adımın hiçbiri 375×812de TAŞMAZ', (WidgetTester t) async {
      await boot(t, InMemoryOnboardingStore());
      for (int step = 0; step < 3; step++) {
        expect(t.takeException(), isNull);
        if (step < 2) {
          await t.tap(find.byKey(const Key('onboarding-primary')));
          await settle(t);
        }
      }
    });

    testWidgets('mikrofon kartı YOKLUĞU söyler, yeteneği DEĞİL',
        (WidgetTester t) async {
      await boot(t, InMemoryOnboardingStore());
      await t.tap(find.byKey(const Key('onboarding-primary')));
      await settle(t);
      await t.tap(find.byKey(const Key('onboarding-primary')));
      await settle(t);

      final String mic = t
          .widgetList<Text>(find.descendant(
              of: find.byKey(const Key('onboarding-microphone-card')),
              matching: find.byType(Text)))
          .map((Text w) => w.data ?? '')
          .join(' ');

      // Bu ekran mikrofon izni İSTEMEDİĞİNE göre, mikrofonu ANMASI ancak
      // yokluğunu söylemek için meşrudur. `tools/validate_surface_honesty.py`
      // bunu tüm yüzeyde mekanik olarak kolluyor; buradaki kontrol o kapının
      // TAM BU KARTTA canlı olduğunu gösterir.
      //
      // ⚠️ BU TEST KENDİ SINIRINI TAŞIR (O-066 · JabLab J-144 sınıfının
      // GELECEKTEKİ hâli). Bugün doğru bir cümleyi koruyor. Ama mikrofon
      // kablolandığı gün o cümle YANLIŞ olacak, doğru hamle onu SİLMEK
      // olacak — ve bu test tam o anda kırmızı yanıp **düzeltmeye
      // direnecek**. Kusuru bugün sabitlemiyor; YARIN sabitleyecek.
      //
      // Bu yüzden iddia, kapının kullandığı AYNI çapaya bağlandı: izin
      // beyanı. İzin geldiği gün test kendini emekliye ayırır ve yerini
      // kural B/C'nin TERS YÖNÜ alır (O-059) — o da eski cümleyi zaten
      // kırmızı yakacak. İki katman, tek çapa, çelişki yok.
      final bool micDeclared =
          File('ios/Runner/Info.plist').readAsStringSync()
                  .contains('NSMicrophoneUsageDescription') ||
              File('android/app/src/main/AndroidManifest.xml')
                  .readAsStringSync()
                  .contains('android.permission.RECORD_AUDIO');
      if (micDeclared) {
        expect(mic, isNot(contains('no microphone input in this build')),
            reason: 'mikrofon artık BEYAN EDİLMİŞ — yokluk cümlesi bugün '
                'yanlış, kart güncellenmeli');
      } else {
        expect(mic, contains('no microphone input in this build'));
      }
      expect(mic.toLowerCase(), isNot(contains('listens')));
    });

    testWidgets('wellness beyanı akışın İÇİNDE, ayarlara gömülü değil',
        (WidgetTester t) async {
      await boot(t, InMemoryOnboardingStore());
      await t.tap(find.byKey(const Key('onboarding-primary')));
      await settle(t);
      await t.tap(find.byKey(const Key('onboarding-primary')));
      await settle(t);

      final String text = t
          .widgetList<Text>(find.descendant(
              of: find.byKey(const Key('onboarding-wellness-card')),
              matching: find.byType(Text)))
          .map((Text w) => w.data ?? '')
          .join(' ');
      expect(text, contains('does not diagnose'));
      expect(text, contains('not'));
    });
  });
}

/// `markComplete` çağrısını YUTAN depo — dosyaya yazamayan cihazın hâli.
final class _DeafStore implements OnboardingStore {
  @override
  Future<bool> isComplete() async => false;
  @override
  Future<void> markComplete() async {}
}
