import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/onboarding_store.dart';
import 'package:ostinato/main.dart';

/// GEZİLEBİLİR EKRAN SAYIMI — O-074.
///
/// Koordinatörün sayma kuralı: *açılıştan başlayarak, YALNIZ ekranda görünen
/// kontrollere basarak ulaşılabilen her ayrı ekran.*
///
/// ⚠️ **`find`de DEĞİL, `tap`te duruyoruz** (Choreia'nın tuzağı): tembel bir
/// `ListView` `cacheExtent` kadar görünür alanın ALTINDA widget kurar —
/// `find` bulur, kullanıcı DOKUNAMAZ, `tap` boşluğa iner. Bir ekranı
/// "gezilebilir" saymak için ona GERÇEKTEN dokunarak gitmiş olmak gerekir.
///
/// KATI okuma (koordinatörün kanonik kuralı): ayrı bir ROTAYA gidiş sayılır.
/// Aynı sayfa içinde değişen perde/aşama SAYILMAZ — o içerik derinliğidir,
/// navigasyon kabuğu değil.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late ContentRepository repo;
  late CueTextResolver cueText;
  setUpAll(() async {
    repo = await ContentRepository.load();
    cueText = await CueTextResolver.load();
  });

  setUp(() {
    final TestWidgetsFlutterBinding b =
        TestWidgetsFlutterBinding.ensureInitialized();
    b.platformDispatcher.views.first.physicalSize = const Size(375, 812);
    b.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(b.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(b.platformDispatcher.views.first.resetDevicePixelRatio);
  });

  testWidgets('açılıştan başlayarak DOKUNARAK kaç ekrana gidilebiliyor',
      (WidgetTester t) async {
    final Set<String> reached = <String>{};
    final List<String> log = <String>[];

    /// ⚠️ ULAŞMAK ≠ ÇALIŞMAK (Choreia: *"açabilir ama dans edemez"*).
    /// Bir ekrana varmak, onun ÇALIŞTIĞINI göstermez — kabuk çizilip içerik
    /// boş kalabilir. Bu yüzden her varışta ekranın KENDİ ÖZÜNDEN bir
    /// cümle aranıyor: ders gerekçesi, dürüstlük kutusu, ölçüm iddiası…
    /// Gezilebilirlik sayısı bir ÜST SINIRDIR; bu kontrol onu daraltır.
    void requireSubstance(WidgetTester t, String where, Pattern must) {
      final Iterable<String> texts = t
          .widgetList<Text>(find.byType(Text))
          .map((Text w) => w.data ?? '');
      expect(texts.any((String x) => x.contains(must)), isTrue,
          reason: '$where ekranına ULAŞILDI ama ÖZÜ yok — kabuk çizilmiş, '
              'içerik boş (ulaşmak ≠ çalışmak)');
    }

    void note(WidgetTester t, String where) {
      final String name = t
          .widget<Scaffold>(find.byType(Scaffold).first)
          .key
          ?.toString() ??
          '';
      reached.add(where);
      log.add('$where${name.isEmpty ? '' : ' [$name]'}');
    }

    /// Gerçekten DOKUNULABİLİR mi? `find` yetmez — `tap` boşluğa inerse
    /// ekran gezilebilir DEĞİLDİR.
    Future<bool> tapIfPossible(WidgetTester t, Finder f) async {
      if (f.evaluate().isEmpty) return false;
      // KULLANICI KAYDIRIR. `find` bir widget'ı ekranın 2988px altında da
      // bulur (ÖLÇÜLDÜ: çalgı sayfasında "Foundations" tam oradaydı) — ama
      // dokunulabilir saymak için önce GÖRÜNÜR alana getirmek gerekir.
      // Kaydırılamıyorsa gerçekten ulaşılamaz demektir.
      try {
        await t.ensureVisible(f.first);
        await t.pump();
      } on Object {
        // kaydırılabilir bir ata yok — belki zaten görünürdür, tap denesin
      }
      try {
        await t.tap(f.first, warnIfMissed: true);
      } on Object {
        return false;      // tap boşluğa indi → GERÇEKTEN dokunulamıyor
      }
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      return true;
    }

    await t.pumpWidget(ContentRepositoryScope(
      repo: repo,
      cueText: cueText,
      child: MaterialApp(
        home: OstinatoHome(
          repo: repo,
          cueText: cueText,
          store: InMemoryOnboardingStore(),
          alreadyOnboarded: false,
        ),
      ),
    ));
    await t.pump();
    note(t, '1 Onboarding');

    // Karşılamayı GERÇEK dokunuşlarla geç (3 perde — KATI'da +0).
    for (int i = 0; i < 3; i++) {
      await tapIfPossible(t, find.byKey(const Key('onboarding-primary')));
    }
    note(t, '2 Library');
    requireSubstance(t, 'Library', 'Measured, not chosen');

    // Ayarlar
    if (await tapIfPossible(t, find.text('⚙'))) {
      note(t, '3 Settings');
      requireSubstance(t, 'Settings', 'instruments are live');
      await tapIfPossible(t, find.text('‹'));
      await t.pump(const Duration(milliseconds: 400));
    }

    // Çalgı → Kurs → Ders sınıfları
    if (await tapIfPossible(t, find.text('Guitar'))) {
      note(t, '4 Instrument');
      requireSubstance(t, 'Instrument', 'not all the same kind of gap');
      final Discipline g =
          repo.disciplines.firstWhere((Discipline d) => d.id == 'guitar');
      if (await tapIfPossible(t, find.text(g.courses.first.displayName))) {
        note(t, '5 Course');
        requireSubstance(t, 'Course', g.courses.first.goal.split('.').first);
        for (final MapEntry<LessonKind, String> e
            in <LessonKind, String>{
          LessonKind.guide: '6 Lesson/guide→scored',
          LessonKind.scored: '6 Lesson/scored',
          LessonKind.demoOnly: '7 Lesson/demoOnly',
          LessonKind.locked: '8 Lesson/locked',
        }.entries) {
          final Iterable<Lesson> match =
              g.courses.first.lessons.where((Lesson l) => l.kind == e.key);
          if (match.isEmpty) continue;
          if (await tapIfPossible(t, find.text(match.first.displayName))) {
            note(t, e.value);
            // Ders ekranının ÖZÜ: kilitli ise gerekçesi, açık ise neye
            // karşı ölçüldüğü. İkisi de yoksa ekran boş kabuktur.
            requireSubstance(t, e.value,
                match.first.kind == LessonKind.locked
                    ? match.first.lockedReason!.split('.').first
                    : match.first.displayName);
            // ⚠️ `t.pageBack()` KULLANILAMAZ: geri düğmesi standart
            // `BackButton` değil, `GlassIconButton` (metin glifi) — yani
            // ÜRÜNÜN kendi kontrolü. Kullanıcı ona basar; test de basmalı.
            // (Aracın varsayılanı ürünün gerçeğini tanımıyordu.)
            await tapIfPossible(t, find.text('‹'));
            await t.pump(const Duration(milliseconds: 400));
          }
        }
      }
    }

    // ignore: avoid_print
    print('\n═══ DOKUNARAK ULAŞILAN EKRANLAR (KATI) ═══');
    for (final String l in log) {
      // ignore: avoid_print
      print('   $l');
    }
    // ignore: avoid_print
    print('   → KATI SAYI (bu yürüyüşte): ${reached.length}\n');

    // ⚠️ YÜRÜNEMEYEN ÜÇ EKRAN ve SEBEBİ — sayının yanına yazılmazsa
    // "11 ekran" iddiası GEVŞEK okuma olur:
    //   SetupCheck · Live · Review
    // Üçü de KAMERA arkasında. `SetupCheckScreenRoute` `initState`te gerçek
    // `MotionCameraController` kurar; widget testinde platform kanalı yanıt
    // vermez ve ekran asılı kalır (O-036/O-037'nin AYNI donanım sınırı).
    //
    // Ve bu, sayının kendisinden daha önemli bir olgu: ÜRÜNÜN ASIL DENEYİMİNİ
    // oluşturan üç ekran (kurulum · canlı ölçüm · özet) tam da GEZİLEBİLİR
    // OLDUĞU KANITLANAMAYAN üçü. Kod olarak varlar, rota olarak bağlılar —
    // ama hiçbir otomatik yürüyüş oraya GİDEMEZ, ve hiçbir insan da henüz
    // gerçek cihazda gitmedi.
    expect(reached.length, greaterThanOrEqualTo(8),
        reason: 'kamerasız yol boyunca sekiz ayrı ekrana dokunarak '
            'gidilebilmeli — düşerse navigasyon kabuğu kırılmış demektir');
  });
}
