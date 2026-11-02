import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/onboarding_store.dart';
import 'package:ostinato/app/screens/library_screen.dart';
import 'package:ostinato/app/screens/onboarding_screen.dart';
import 'package:ostinato/app/screens/settings_screen.dart';
import 'package:ostinato/app/screens/v1_home_copy.dart';
import 'package:ostinato/app/ui_copy.dart';
import 'package:ostinato/main.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';
import 'support/localized_widget_ready.dart';

/// İlk açılış akışı — O-039.
///
/// Bu dosyanın sınadığı şey metnin VARLIĞI değil (ders #2: varlık doğruluk
/// değildir), akışın KAPI olup olmadığı: ilk açılışta karşılama ZORUNLU mu,
/// ikinci açılışta GÖRÜNMÜYOR mu, ve ekrandaki sayılar kütüphaneden mi
/// TÜRÜYOR yoksa elle mi yazılmış.
void main() {
  setUpAll(prepareRootTranslations);
  TestWidgetsFlutterBinding.ensureInitialized();

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
  /// gerçek async okur, o da `runAsync` gerektirir. **D1 NOTU (2026-08-16):**
  /// bu ayrımın eski gerekçesinin bir yarısı (`google_fonts`un test-hatası
  /// `runAsync` penceresine taşması) fontlar paketlenince ORTADAN KALKTI —
  /// ama `rootBundle` async'i hâlâ gerçek, ayrım o yüzden BOZULMADI. Dallanma
  /// burada bu kod tabanının geri kalanıyla AYNI desenle sınanıyor.
  Future<void> boot(
    WidgetTester t,
    OnboardingStore store, {
    bool alreadyOnboarded = false,
  }) async {
    await t.pumpWidget(
      ContentRepositoryScope(
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
      ),
    );
    await settle(t);
  }

  for (final language in ['en', 'tr']) {
    testWidgets(
      'v1 course, three marks and camera-only-in-its-lesson copy in $language',
      (tester) async {
        Widget host(Widget child) => ContentRepositoryScope(
          repo: repo,
          cueText: cueText,
          child: MaterialApp(
            locale: Locale(language),
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            home: child,
          ),
        );
        await tester.pumpWidget(
          host(
            OnboardingScreen(
              repo: repo,
              store: InMemoryOnboardingStore(),
              onFinished: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        String t(UiCopy c) => language == 'tr' ? c.$2 : c.$1;
        expect(find.text(t(V1HomeCopy.welcomeTitle)), findsOneWidget);
        expect(find.text(t(V1HomeCopy.welcomeBody)), findsOneWidget);
        expect(
          find.textContaining(language == 'tr' ? '690 ders' : '690 lessons'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            language == 'tr'
                ? 'sonraki dersler Ostinato veya Motion+ aboneliği gerektirir'
                : 'later lessons need an Ostinato or Motion+ subscription',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('does not grade'), findsNothing);
        expect(find.textContaining('puanlamaz'), findsNothing);
        await tester.tap(find.byKey(const Key('onboarding-primary')));
        await settle(tester);
        expect(find.text(t(V1HomeCopy.scopePractice)), findsOneWidget);
        await tester.tap(find.byKey(const Key('onboarding-primary')));
        await settle(tester);
        expect(find.text(t(V1HomeCopy.cameraBody)), findsOneWidget);
        expect(find.text(t(V1HomeCopy.micBody)), findsOneWidget);
        expect(
          find.textContaining(
            language == 'tr' ? 'kamera izni istemez' : 'does not ask for camera',
          ),
          findsNothing,
        );
        await tester.pumpWidget(host(const SettingsScreen()));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            language == 'tr'
                ? 'canlı kamera duruş pratiği kapalıdır'
                : 'Live camera posture practice is closed',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            language == 'tr'
                ? 'Ham video bu cihazda saklanmaz ve cihazdan çıkmaz'
                : 'Raw video is never stored on this device',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  group('kabuk kapısı', () {
    testWidgets('İLK açılış: karşılama gelir, kütüphane GELMEZ', (
      WidgetTester t,
    ) async {
      await boot(t, InMemoryOnboardingStore());

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(
        find.byType(LibraryScreen),
        findsNothing,
        reason:
            'karşılama bir KAPI olmalı — atlanabilirse kullanıcı '
            'wellness beyanını ve izin gerekçesini hiç görmeden kameraya '
            'çıkar',
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('İKİNCİ açılış: doğrudan kütüphane', (WidgetTester t) async {
      await boot(
        t,
        InMemoryOnboardingStore(complete: true),
        alreadyOnboarded: true,
      );

      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('üç adım geçilir, işaret KAYDEDİLİR, kütüphane açılır', (
      WidgetTester t,
    ) async {
      final InMemoryOnboardingStore store = InMemoryOnboardingStore();
      await boot(t, store);

      expect(find.byKey(const Key('onboarding-welcome-title')), findsOneWidget);
      await t.tap(find.byKey(const Key('onboarding-primary')));
      await settle(t);
      expect(find.byKey(const Key('onboarding-scope-title')), findsOneWidget);

      await t.tap(find.byKey(const Key('onboarding-primary')));
      await settle(t);
      expect(find.byKey(const Key('onboarding-sensors-title')), findsOneWidget);
      expect(
        store.markCalls,
        0,
        reason:
            'son adıma VARMAK bitirmek değildir — işaret ancak '
            'kullanıcı akışı kapatınca yazılmalı',
      );

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
      },
    );
  });

  group('içerik adımı', () {
    // v1 (kurucu, 2026-11-01): eski duruş kataloğu sayıları kalktı; adım
    // bugün uygulamada olan dört şeyi sayar.
    testWidgets('dört v1 satırı, duruş kataloğu sayısı yok', (
      WidgetTester t,
    ) async {
      await boot(t, InMemoryOnboardingStore());
      await t.tap(find.byKey(const Key('onboarding-primary')));
      await settle(t);
      for (final key in [
        'onboarding-fact-practice',
        'onboarding-fact-setup',
        'onboarding-fact-streak',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
      // v1 store build: the pre-v1 written lessons are not linked, so the
      // scope list does not promise them.
      final written = ostinatoLegacyWrittenCoursesVisible
          ? findsOneWidget
          : findsNothing;
      expect(find.byKey(const Key('onboarding-fact-written')), written);
      expect(find.text(V1HomeCopy.scopeWritten.$1), written);
      expect(find.textContaining('posture'), findsNothing);
      expect(find.byKey(const Key('onboarding-fact-locked')), findsNothing);
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

    testWidgets('mikrofon kartı beyanla uyumlu konuşur', (
      WidgetTester t,
    ) async {
      await boot(t, InMemoryOnboardingStore());
      await t.tap(find.byKey(const Key('onboarding-primary')));
      await settle(t);
      await t.tap(find.byKey(const Key('onboarding-primary')));
      await settle(t);

      final String mic = t
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('onboarding-microphone-card')),
              matching: find.byType(Text),
            ),
          )
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
          File(
            'ios/Runner/Info.plist',
          ).readAsStringSync().contains('NSMicrophoneUsageDescription') ||
          File(
            'android/app/src/main/AndroidManifest.xml',
          ).readAsStringSync().contains('android.permission.RECORD_AUDIO');
      if (micDeclared) {
        expect(
          mic,
          isNot(contains('no microphone input in this build')),
          reason:
              'mikrofon artık BEYAN EDİLMİŞ — yokluk cümlesi bugün '
              'yanlış, kart güncellenmeli',
        );
        // v1: mikrofon ölçülü pratikte dinler; kart bunu ve sesin cihazda
        // kaldığını, çalınanın kaydedilmediğini söyler.
        expect(mic, contains('processed on this device'));
        expect(mic, contains('not recorded'));
      } else {
        expect(mic, contains('no microphone input in this build'));
        expect(mic.toLowerCase(), isNot(contains('listens')));
      }
    });

    testWidgets('wellness beyanı akışın İÇİNDE, ayarlara gömülü değil', (
      WidgetTester t,
    ) async {
      await boot(t, InMemoryOnboardingStore());
      await t.tap(find.byKey(const Key('onboarding-primary')));
      await settle(t);
      await t.tap(find.byKey(const Key('onboarding-primary')));
      await settle(t);

      final String text = t
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('onboarding-wellness-card')),
              matching: find.byType(Text),
            ),
          )
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
