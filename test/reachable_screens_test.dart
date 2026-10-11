import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
/// (b) YÜRÜYÜŞ TANIĞI — sözleşme maddesi (O-112).
///
/// Bir ekrana "gidildi" demenin kanıtı, o ekranın metnini GÖRMEK değil
/// `Navigator`ın oraya GÖTÜRDÜĞÜNÜ görmektir. Metin kontrolü aynı sayfada
/// da geçebilir; rota olayı geçemez.
class _RouteWitness extends NavigatorObserver {
  final List<String> pushed = <String>[];
  /// ⚠️ `settings.name` bu uygulamada BOŞ: rotalar `MaterialPageRoute` ile
  /// ADSIZ push ediliyor. Tanık bu yüzden ADI değil OLAYI sayar — kaç kez
  /// gerçek bir navigasyon sınırı geçildiğini. Ad beklemek, tanığı sessizce
  /// boş bırakırdı (ölçüldü, varsayılmadı).
  void _note(Route<dynamic>? r) {
    if (r is PageRoute) pushed.add(r.settings.name ?? '(adsız)');
  }
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previous) => _note(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _note(newRoute);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    /// ⚖️ SAYAÇ ROTA-KİMLİĞİNE BAĞLI (O-106, koordinatör hükmü 2026-08-12).
    ///
    /// **Kusur neydi:** küme `where` ETİKET DİZGESİNİ topluyordu, rota
    /// kimliğini değil. `guide` ve `scored` ders türleri AYNI rotaya gidiyor
    /// (`course_screen.dart:100-104` → `LessonKind.guide || LessonKind.scored
    /// => LessonScoredScreenRoute`) ve yazar bunu BİLİYORDU — iki etiketi de
    /// `'6'` ile numaralamış. Ama küme iki ayrı DİZGE gördüğü için **9**
    /// sayıyordu; yazılı KATI kural ise *"ayrı ROTAYA gidiş sayılır"* diyor.
    ///
    /// > ***Sayı doğru sayıyordu ama SAYDIĞI ŞEY kuralın konusu değildi:
    /// > ETİKET ≠ ROTA.***
    ///
    /// Kimlik ELLE veriliyor (türetilmiyor) — bu, bu yürüyüşün zaten isimli
    /// kör noktasıdır (`docs/gates/GEZILEBILIRLIK-SAYMA-KURALI.md` §②): elle
    /// yürüyüşün göremediği şey yazarın denemeyi akıl etmediği kontroldür.
    /// Desen-türetimi (ör. `*ScreenRoute` adı) o kör noktayı KAPATMAZ, yalnız
    /// BAŞKASIYLA değiştirirdi (Gravita'nın vakası: desenin tanımadığı ad).
    // ⚖️ (b) TANIK ÜYELİK BAŞINA (O-115). Eski hâl `witness.pushed.length
    // >= 1` idi — bir TOPLAM, ve *bir toplam hiçbir üyenin kanıtı değildir.*
    // `reached` `note()` çağrılarıyla doluyordu, yani üyelik testin KENDİ
    // İDDİASIYLA kuruluyordu: (d)'de Lissom'un düştüğü "iki tarafı aynı
    // kaynaktan okuma" biçiminin (b) yüzü.
    //
    // Artık her varış BİR TANIK OLAYINA eşlenir. ⚠️ Ve ÖLÇÜLDÜ: iki varış
    // rota push'u DEĞİL — `OnboardingScreen` `home:` olarak doğar,
    // `LibraryScreen` `OstinatoHome` içinde `setState` ile yer değiştirir
    // (`pushReplacement` bile değil). Onlar için üçüncü bir sessiz hâl
    // BIRAKILMAZ: `arrival` türü ADIYLA beyan edilir (`push` | `root`).
    final Map<String, String> arrivalKind = <String, String>{};
    final List<String> arrivals = <String>[];  // her VARIŞ (üye değil)
    void note(WidgetTester t, String where, String routeId,
        {String arrival = 'push'}) {
      arrivalKind[routeId] = arrival;
      arrivals.add(arrival);
      final String name = t
          .widget<Scaffold>(find.byType(Scaffold).first)
          .key
          ?.toString() ??
          '';
      reached.add(routeId);
      log.add('$where → $routeId ($arrival)'
          '${name.isEmpty ? '' : ' [$name]'}');
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

    final _RouteWitness witness = _RouteWitness();
    await t.pumpWidget(ContentRepositoryScope(
      repo: repo,
      cueText: cueText,
      child: MaterialApp(
        navigatorObservers: <NavigatorObserver>[witness],
        home: OstinatoHome(
          repo: repo,
          cueText: cueText,
          store: InMemoryOnboardingStore(),
          alreadyOnboarded: false,
        ),
      ),
    ));
    await t.pump();
    note(t, '1 Onboarding', 'OnboardingScreen', arrival: 'root');

    // Karşılamayı GERÇEK dokunuşlarla geç (3 perde — KATI'da +0).
    for (int i = 0; i < 3; i++) {
      await tapIfPossible(t, find.byKey(const Key('onboarding-primary')));
    }
    note(t, '2 Library', 'LibraryScreen', arrival: 'root');
    requireSubstance(t, 'Library', 'Written lessons. Posture references.');

    // Ayarlar
    if (await tapIfPossible(t, find.text('⚙'))) {
      // ⚠️ 'SettingsScreenRoute' YAZMIŞTIM — gerçek sınıf `SettingsScreen`.
      // TÜRETİLMİŞ aday kümesi (sözleşme (a)) bunu ilk koşumda
      // yakaladı: elle yazılan kimlik, koddan türetilenle ayrıştı.
      note(t, '3 Settings', 'SettingsScreen');
      requireSubstance(t, 'Settings', 'instrument previews in the posture catalogue');
      await tapIfPossible(t, find.text('‹'));
      await t.pump(const Duration(milliseconds: 400));
    }

    // ⭐ Kurulum kontrolüne YALNIZ BİR KEZ girilir: aynı ekrana ikinci varış
    // sayıyı değiştirmez (küme), yalnız yürüyüşü uzatır.
    bool setupVisited = false;

    // Çalgı → Kurs → Ders sınıfları
    if (await tapIfPossible(t, find.text('Guitar'))) {
      note(t, '4 Instrument', 'InstrumentScreenRoute');
      requireSubstance(t, 'Instrument', 'not all the same kind of gap');
      final Discipline g =
          repo.disciplines.firstWhere((Discipline d) => d.id == 'guitar');
      if (await tapIfPossible(t, find.text(g.courses.first.displayName))) {
        note(t, '5 Course', 'CourseScreenRoute');
        requireSubstance(t, 'Course',
            'Set up your space, read the guitar posture references, and learn which eight open chords the notes describe.');
        for (final MapEntry<LessonKind, (String, String)> e
            in <LessonKind, (String, String)>{
          // ⚠️ KİMLİKLER `course_screen.dart:100-104`ten ÖLÇÜLDÜ:
          //   locked → LessonLockedScreenRoute · demoOnly → LessonDemoScreenRoute
          //   guide VEYA scored → LessonScoredScreenRoute  (AYNI ROTA)
          LessonKind.guide: ('6 Lesson/guide', 'LessonScoredScreenRoute'),
          LessonKind.scored: ('6 Lesson/scored', 'LessonScoredScreenRoute'),
          LessonKind.demoOnly: ('7 Lesson/demoOnly', 'LessonDemoScreenRoute'),
          LessonKind.locked: ('8 Lesson/locked', 'LessonLockedScreenRoute'),
        }.entries) {
          final Iterable<Lesson> match =
              g.courses.first.lessons.where((Lesson l) => l.kind == e.key);
          if (match.isEmpty) continue;
          final String lessonTitle = match.first.id == 'guitar.foundations.arms'
              ? 'Holding the guitar — posture reference'
              : match.first.displayName;
          if (await tapIfPossible(t, find.text(lessonTitle))) {
            note(t, e.value.$1, e.value.$2);
            // Ders ekranının ÖZÜ: kilitli ise gerekçesi, açık ise neye
            // karşı ölçüldüğü. İkisi de yoksa ekran boş kabuktur.
            requireSubstance(t, e.value.$1,
                match.first.kind == LessonKind.locked
                    ? match.first.lockedReason!.split('.').first
                    : lessonTitle);
            // ⭐ KURULUM KONTROLÜ — 2026-08-13'te ÖLÇÜLDÜ, VARILIYOR (O-121).
            //
            // 🔴 Burada YILLARCA duracak bir yanlış vardı: aşağıdaki (c)
            // bloğu `SetupCheckScreenRoute`u *"kamera kurar, widget testinde
            // ekran ASILI KALIR"* diye dışlıyordu. Bir prob bunu çürüttü —
            // `camera_session.dart:109` `on Object catch` eksik platform
            // kanalını `CameraStartFailed`e çevirir; ekran asılmaz, ilk
            // perdesini çizer ve tanık push'u GÖRÜR.
            //
            // ⚠️ Ve asıl ders yürüyüşteydi, yüklemde değil: bu düğmeye HİÇ
            // BASILMIYORDU. İki taraf (yürüyüş ↔ kaynak beklentisi) ölçümle
            // değil İHMALLE uzlaşıyordu.
            // > ***BİR DENETİMİN İKİ TARAFI DA AYNI ŞEYİ DENEMİYORSA,
            // > UZLAŞMALARI BİR ÖLÇÜM DEĞİL BİR SESSİZLİKTİR.***
            if (!setupVisited &&
                (match.first.kind == LessonKind.guide ||
                    match.first.kind == LessonKind.scored)) {
              final Finder go =
                  find.text('Begin the setup check').evaluate().isNotEmpty
                      ? find.text('Begin the setup check')
                      : find.text('Continue');
              if (await tapIfPossible(t, go)) {
                setupVisited = true;
                note(t, '9 SetupCheck (dersten)', 'SetupCheckScreenRoute');
                requireSubstance(t, 'SetupCheck', 'Find your frame');
                // Ürünün KENDİ kapatma kontrolü — '✕', `BackButton` değil.
                await tapIfPossible(t, find.text('✕'));
                await t.pump(const Duration(milliseconds: 400));
              }
            }
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
    print('   → KATI SAYI (bu yürüyüşte): ${reached.length}'
        '  [${log.length} varış / ${reached.length} AYRI ROTA]');
    // ⚖️ SAYININ YANINDA SEBEBİ (koordinatör hükmü O-106): sayı 9→8'e
    // DÜŞMEDİ; 9 hiç DOĞRU DEĞİLDİ. Eski sayaç ETİKET DİZGESİ topluyordu,
    // yazılı KATI kural ise AYRI ROTA sayar — `guide` ve `scored` aynı
    // rotaya gider (`LessonScoredScreenRoute`). Birim değişti, yön değil.
    // ignore: avoid_print
    print('   ⚠️ eşik >= 9 · bugünkü sayı ${reached.length} → KAPI TAM '
        'TABANDA, SIFIR PAY: tek bir rota kaybı kırmızıya düşürür. Bu bir '
        'kusur değil, DÜRÜST HÂL — payı olmayan bir eşiği "geçti" diye '
        'okumak yanıltıcı olurdu.\n');

    // ⚠️ YÜRÜNEMEYEN İKİ EKRAN ve SEBEBİ — sayının yanına yazılmazsa
    // "11 ekran" iddiası GEVŞEK okuma olur:
    //   Live · Review
    //
    // 🔻 ÜÇTEN İKİYE DÜŞTÜ (O-121, 2026-08-13) ve sebebi bir ÖLÇÜM:
    // `SetupCheckScreenRoute` bu listedeydi, çünkü yüklem *"kamerayı kendisi
    // kullanıyor"*du. Yürüyüş artık ona GERÇEKTEN dokunuyor (yukarıda) ve
    // varıyor. Kalan ikisi kamerayı kullandıkları için değil, kamera
    // KAPISININ ARKASINDA oldukları için varılamaz: `LiveScreenRoute`a ancak
    // kurulum kontrolü GEÇİNCE gidilir ve o geçiş GERÇEK KARE ister.
    //
    // Ve bu, sayının kendisinden daha önemli bir olgu: ÜRÜNÜN ASIL ÖLÇÜM
    // DENEYİMİNİ oluşturan iki ekran (canlı ölçüm · özet) tam da dokunarak
    // GEZİLEBİLİR OLDUĞU KANITLANAMAYAN ikisi. Kod olarak varlar, rota olarak
    // bağlılar; `test/full_flow_test.dart` onları ZERK EDİLMİŞ bir kaynakla
    // yürür — ama bu bir DOKUNMA kanıtı değildir ve orada adıyla yazılıdır.
    // Gerçek cihazda hiçbir insan henüz gitmedi (A12).
    // ── (a)(c)(d) SÖZLEŞME: aday = varılan ⊎ VARILAMAYAN ──────────────
    // Aday küme TÜRETİLMİŞ (tools/gen_screen_candidates.py), elle YAZILMAZ.
    final Map<String, dynamic> gen = jsonDecode(
        File('test/generated/screen_candidates.json').readAsStringSync())
        as Map<String, dynamic>;
    final Set<String> candidates =
        (gen['candidates'] as List<dynamic>).cast<String>().toSet();
    final Map<String, dynamic> reasons =
        (gen['behindCameraGate'] as Map<String, dynamic>);
    // ⚖️ (d) BEKLENTİ KAYNAKTAN TÜRETİLİR — FARKTAN DEĞİL (O-115).
    //
    // 🔴 Eski hâl: `unreached = candidates.difference(reached)` → sonra
    // `reached ∪ unreached == candidates` assert'i. Bu denklem TANIM GEREĞİ
    // doğruydu; sözleşmenin kendi cümlesiyle: *bir bölme denetimi, iki
    // tarafı AYNI KAYNAKTAN okuyorsa denetim değil TANIMDIR.*
    //
    // Yeni hâl: beklenti KAYNAKTAN gelir — `behindCameraGate` taşıyan aday
    // widget testinde varılamaz (ona giden her kapı gerçek kare ister),
    // taşımayan varılabilir OLMALI. Böylece iki taraf BAĞIMSIZ: biri
    // YÜRÜYÜŞ, öteki KAYNAK TÜRETİMİ. Artık iki yönde de gerçek bulgu mümkün:
    //   · kapı arkasında sanılan bir ekrana VARILDIYSA → beklenti yanlış
    //   · kapısız bir ekrana VARILAMADIYSA → NAVİGASYON REGRESYONU
    //
    // ⚠️ Ve bu denetim 2026-08-13'te İLK KEZ gerçekten yanlış çıkabildi:
    // yüklem `cameraDependency`den `behindCameraGate`e taşındığında
    // `SetupCheckScreenRoute` beklenen-varılamaz kümesinden ÇIKTI ve
    // yürüyüş onu bulmak ZORUNDA kaldı. Öncesinde ikisi de o düğmeye
    // dokunmadığı için assert TANIM gibi davranıyordu.
    final Set<String> expectedUnreachable = candidates
        .where((String c) => reasons.containsKey(c)).toSet();
    final Set<String> expectedReachable =
        candidates.difference(expectedUnreachable);
    final Set<String> unreached = candidates.difference(reached);
    // (e) ELLE KÜME SİLİNMEZ — türetimin POZİTİF KONTROLÜ.
    // Türetim, zaten BİLDİĞİMİZİ kapsamalı; kapsamıyorsa desen kördür.
    // ⚠️ ŞERH 1: bu küme bir ALT SINIRDIR — **TAM ENVANTER DEĞİLDİR.**
    //    (Eksik yarım O-115'te eklendi: "alt sınır" tek başına okunduğunda
    //     "şu an tam" diye anlaşılabiliyordu. Bir sınırın adı, onun TAM
    //     OLMADIĞINI söylemiyorsa yarım bir uyarıdır.)
    // ⚠️ ŞERH 2: buraya ekleme yapmak envanter güncellemesi DEĞİL,
    //    KONTROLÜN TABANINI yükseltmektir.
    const Set<String> handWritten = <String>{
      'OnboardingScreen', 'LibraryScreen', 'SettingsScreen',
      'InstrumentScreenRoute', 'CourseScreenRoute',
      'LessonScoredScreenRoute', 'LessonDemoScreenRoute',
      'LessonLockedScreenRoute',
      // ⬆ TABAN YÜKSELTİLDİ (O-121): dokunarak varıldığı ÖLÇÜLDÜ.
      'SetupCheckScreenRoute',
    };
    expect(handWritten.difference(candidates), isEmpty,
        reason: '(e) TÜRETİM, elle bilinen kümeyi KAPSAMIYOR — desen kör: '
            'elle liste bir ALT SINIRDIR ve türetim onun altına düşemez');
    // ignore: avoid_print
    print('\n═══ (c) ADAY OLUP VARILAMAYAN — KATI\'ya girmez, KAYBOLMAZ ═══');
    for (final String u in unreached.toList()..sort()) {
      // ignore: avoid_print
      print('   ⛔ $u\n        sebep: ${reasons[u] ?? '🔴 SEBEP YOK'}');
    }
    // Choreia kuralı: SEBEPSİZ dışlama, denetimi yeniden TANIMA çevirir.
    for (final String u in unreached) {
      expect(reasons.containsKey(u), isTrue,
          reason: '$u varılamıyor ama SEBEBİ türetilemedi — sebepsiz bir '
              'dışlama, denetimi "tanım" hâline getirir (varılamayanı '
              'varılamaz diye tanımlamak)');
    }
    // ignore: avoid_print
    print('   → aday ${candidates.length} = varılan ${reached.length}'
        ' ⊎ varılamayan ${unreached.length}');
    // ignore: avoid_print
    print('   (e) elle küme ${handWritten.length} ⊆ türetim '
        '${candidates.length} — ALT SINIR, taban yükseltilebilir\n');
    // (d) BÖLME ASSERT'İ — Lissom'un vakası: eksik yürünen bir yürüyüş
    // "0 kusur" diye DOĞRU sonucu YANLIŞ sebeple basar.
    // GERÇEK DENETİM: yürüyüş (taraf 1) ↔ kaynak beklentisi (taraf 2)
    expect(reached, expectedReachable,
        reason: 'YÜRÜYÜŞ ile KAYNAK BEKLENTİSİ ayrıştı. Fazladan varılan = '
            'kamera bağımlısı sanılan bir ekrana varıldı (beklenti yanlış); '
            'eksik = kamerasız bir ekrana VARILAMADI → NAVİGASYON '
            'REGRESYONU. İki taraf AYRI kaynaktan okunuyor, bu yüzden bu '
            'assert tanım değil DENETİMDİR.');
    expect(unreached, expectedUnreachable,
        reason: 'varılamayanlar, kaynaktan türetilen beklentiyle eşleşmiyor');
    expect(reached.difference(candidates), isEmpty,
        reason: 'yürüyüş aday kümesinde OLMAYAN bir ekrana vardı — aday '
            'kümesi bayat, `gen_screen_candidates.py` yeniden koşmalı');
    // (b) YÜRÜYÜŞ TANIĞI — ölçüm, iddia değil.
    // ignore: avoid_print
    print('   (b) tanık: ${witness.pushed.length} gerçek rota push\'u '
        '(navigasyon SINIRI geçildi; sayfa-içi durum değişimi buraya '
        'düşmez)\n');
    // ⚠️ ÜYE değil VARIŞ sayılır: `LessonScoredScreenRoute`a İKİ kez varılır
    // (guide + scored) ve her varış ayrı bir push olayıdır. Üye sayısıyla
    // karşılaştırmak, tanık gereksinimini SESSİZCE düşürürdü.
    final int pushArrivals =
        arrivals.where((String k) => k == 'push').length;
    final int rootArrivals =
        arrivals.where((String k) => k == 'root').length;
    final int pushMembers =
        arrivalKind.values.where((String k) => k == 'push').length;
    final int rootMembers =
        arrivalKind.values.where((String k) => k == 'root').length;
    // 🔴 KÖK VARIŞ SINIRI — sabotajla ölçüldü (O-115): bir üyeyi `root`
    // beyan etmek tanık gereksinimini DÜŞÜRÜYORDU, yani yanlış bir beyan
    // sessizce geçiyordu.
    //
    // ⚠️ O-116 DÜZELTMESİ: burada `expect(rootMembers, 2)` yazılıydı ve
    // gerekçesi *"kök varış YAPISAL olarak ikidir"* diyordu. ÖLÇÜM bunu
    // ÇÜRÜTTÜ: iki oluşu `main.dart`ın BUGÜNKÜ dallanmasının sonucu, yapının
    // zorunluluğu değil — üçüncü bir dal MEŞRU bir değişikliktir ve o gün bu
    // satır DOĞRU bir değişikliği kırmızı basardı.
    //
    // > ***'YAPISAL' DEMEK, 'BUGÜN BÖYLE' DEMEKTEN FARKLIDIR — VE ARADAKİ
    // > FARK ANCAK ÖLÇÜLEREK BİLİNİR.***
    //
    // Yapısal olan SAYI değil KURAL: *kök varış, `OstinatoHome`un rota
    // kurmadan döndürebildiği yüzeydir.* Kural `gen_screen_candidates.py`de
    // kodlu; buraya KÜME olarak iner — sayı değil, KİMLİK bağlanır. Beyanı
    // `root` olup kaynakta kök OLMAYAN bir varış, tanık gereksiniminden
    // kaçmış demektir ve kapı öter.
    final Set<String> rootSurfaces =
        (gen['rootSurfaces'] as List<dynamic>).cast<String>().toSet();
    final Set<String> declaredRoot = arrivalKind.entries
        .where((MapEntry<String, String> e) => e.value == 'root')
        .map((MapEntry<String, String> e) => e.key)
        .toSet();
    expect(declaredRoot, rootSurfaces,
        reason: '(b) `root` BEYAN edilen varışlar ($declaredRoot), kaynaktan '
            'türetilen kök yüzeylerle ($rootSurfaces) eşleşmiyor. FAZLA = bir '
            'üyelik `root` beyan edilerek TANIK GEREKSİNİMİNDEN kaçtı; EKSİK '
            '= kaynakta kök olan bir yüzeye bu yürüyüşte VARILMADI. Sayı '
            'değil KİMLİK bağlıdır: üçüncü bir kök dal eklemek kaynağı '
            'değiştirir ve beklenti onu KENDİLİĞİNDEN izler');
    // ignore: avoid_print
    print('   (b) üyelik başına tanık: $pushArrivals push VARIŞI ↔ '
        '${witness.pushed.length} tanık olayı · $pushMembers push-üyesi · '
        '$rootArrivals kök varış / $rootMembers kök üye '
        '(KAYNAKTAN türetildi: ${rootSurfaces.toList()..sort()})\n');
    expect(witness.pushed.length, greaterThanOrEqualTo(pushArrivals),
        reason: '(b) `push` beyan eden $pushArrivals VARIŞ var ama tanık '
            'yalnız ${witness.pushed.length} olay gördü — bir varış TANIKSIZ '
            'kuruldu. Bir TOPLAM hiçbir üyenin kanıtı değildir; üyelik testin '
            'kendi iddiasıyla değil TANIKLA kurulur');
    expect(arrivalKind.keys.toSet(), reached,
        reason: '(b) her varışın türü (push|root) beyan edilmeli — beyansız '
            'bir varış ÜÇÜNCÜ SESSİZ HÂLdir');
    // ⚖️ SAYI EŞİĞİ NEDEN HÂLÂ VAR — küme eşitliği varken gereksiz DEĞİL.
    // `expect(reached, expectedReachable)` iki tarafı karşılaştırır; ama bir
    // ekran KAYNAKTAN silinirse aday küme de, beklenti de, yürüyüş de birlikte
    // küçülür ve küme eşitliği YİNE GEÇER. Bu taban, üzerinde ANLAŞILMIŞ bir
    // küçülmeyi yakalayan tek şeydir.
    // > ***İKİ TARAFI DA AYNI KAYNAKTAN BESLENEN BİR DENETİM, O KAYNAK
    // > KÜÇÜLDÜĞÜNDE SESSİZDİR — MUTLAK BİR TABAN O SESSİZLİĞİ BOZAR.***
    // 8 → 9 (O-121): `SetupCheckScreenRoute` ölçülerek eklendi, mandal yükseldi.
    expect(reached.length, greaterThanOrEqualTo(9),
        reason: 'kamera KAPISI ÖNCESİNDEKİ yol boyunca dokuz ayrı ekrana '
            'dokunarak gidilebilmeli — düşerse ya navigasyon kabuğu kırıldı '
            'ya bir ekran ürüne sessizce veda etti');
  });
}
