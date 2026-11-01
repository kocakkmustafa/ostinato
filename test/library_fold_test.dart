// İLK DERS ŞERİDİ KATLAMANIN NE KADAR ALTINDA — ÖLÇÜLÜR ve GÖRÜNÜR olur.
//
// ## Neden bu test var (O-139)
//
// `O-117` şeridi kurdu ve `library_starters_test.dart` onun **çalıştığını**
// kanıtlıyor — ama o test hedefe `ensureVisible` ile **kaydırarak** gidiyor.
// Kaydırmak testin hilesi değil, kullanıcının gerçeği; ne var ki o test
// *"kullanıcı bunu GÖRÜYOR mu"* sorusunu hiç sormuyor. Bu dosya tam o soruyu
// bir SAYIYA çeviriyor.
//
// **Ölçüm (2026-08-14, 375×812):** katlama `812`, şeridin başlığı `1302` ⇒
// şerit katlamadan **~490pt** aşağıda; kalemlerin kendisi 515–684pt aşağıda.
// Yani "biraz altta" değil, **yarım ekrandan fazla** altta.
//
// > ***BİR YÖNLENDİRME ŞERİDİ, YÖNLENDİRDİĞİ SEÇİMİN ALTINDAYSA, KULLANICI
// > ONU ANCAK YARDIM ETMESİ GEREKEN KARARI VERDİKTEN SONRA GÖRÜR.***
//
// ## ⛔ BU TEST YERLEŞİMİ DEĞİŞTİRMEZ
//
// Şeridi yukarı taşımak sayfanın bilgi sırasını değiştirir — bu bir **TASARIM
// YÖNÜ** kararıdır ve hattın yetkisinde değildir (M-F-77). Testin işi tek şey:
// mesafeyi **ölçmek** ve **beyan edilmiş** değerle karşılaştırmak. Böylece
// ⑴ yerleşim sessizce KÖTÜLEŞEMEZ, ⑵ biri düzeltirse test **öter** ve
// düzeltme beyanı tazelemeye zorlar — yani iyileşme de görünür olur.
//
// (Desen `validate_runtime_fetch.py`/`validate_persistence.py` ile aynı:
// *kapı bu kararı VERMEZ, görünür tutar.*)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/screens/library_screen.dart';

/// Görünür yükseklik — testin kurduğu yüzeyle AYNI olmalı.
const double kFold = 812.0;

/// BEYAN: şeridin İLK kaleminin katlamadan aşağıdaki mesafesi (pt).
/// ⚠️ Muafiyet değil KARAR NOKTASI — ölçümle ayrışırsa test öter.
///
/// D16 (2026-08-16, O-152): 515.0 → -240.0. Şerit `library_screen.dart`da
/// "Your instruments"tan ÖNCEYE taşındı (koordinatör kararı, O-139/O-140
/// ölçümü üstüne). Negatif değer katlamanın ÜSTÜNDE demek — üç kalemin
/// EN UZAĞI bile artık -71pt (hâlâ üstte). 2026-09-25 ilk sürüm kapsam
/// metni kısalınca ilk kalem -373pt'ye yükseldi; ölçüm tekrarlandı. Bu,
/// testin kendi disiplininin
/// ikinci yönünün uygulanışı: "sayı küçülürse düzeltme inmiş demektir ve
/// test öter — beyanı tazele, iyileşme de bir olaydır." 2026-11-01 v1
/// metni (ana sayfa girişi kısaldı) ilk kalemi -464pt'ye yükseltti.
const double kDeclaredFirstItemBelowFold = -464.0;

/// Yazı metrikleri sürüm/platformla birkaç pt oynayabilir; tolerans o kadar.
/// **Yerleşim değişikliğini gizleyecek kadar geniş DEĞİL** (ölçülen fark
/// yüzlerce pt; 40pt bunu asla yutmaz).
const double kTolerance = 40.0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ContentRepository repo;
  late CueTextResolver cueText;
  setUpAll(() async {
    repo = await ContentRepository.load();
    cueText = await CueTextResolver.load();
  });

  setUp(() {
    final TestWidgetsFlutterBinding binding =
        TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize =
        const Size(375, kFold);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);
  });

  Widget harness() => ContentRepositoryScope(
        repo: repo,
        cueText: cueText,
        child: MaterialApp(home: LibraryScreen(repo: repo, cueText: cueText)),
      );

  testWidgets('ilk ders şeridinin katlama mesafesi BEYANLA uyuşuyor',
      (WidgetTester t) async {
    await t.pumpWidget(harness());
    await t.pump();
    await t.pump();

    final List<Discipline> withStarter = repo.disciplines
        .where((Discipline d) => d.starterLesson != null)
        .toList();
    // VAKUM: hiç starter yoksa bu testin ölçtüğü şey YOKTUR — sessizce
    // yeşil geçemez. (`starters` boşken ekran şeridi hiç çizmez.)
    expect(withStarter, isNotEmpty,
        reason: 'VAKUM: hiçbir disiplinin starter dersi yok — bu test '
            'ölçecek bir şey bulamadı, "geçti" demesi YANILTICI olurdu');

    final List<double> belowFold = <double>[];
    for (final Discipline d in withStarter) {
      final Finder f = find.byKey(Key('starter-${d.id}'));
      expect(f, findsOneWidget,
          reason: '${d.id}: starter kalemi ağaçta yok — şerit türetimi '
              'kırılmış olabilir (bkz. library_starters_test.dart)');
      belowFold.add(t.getRect(f).top - kFold);
    }
    belowFold.sort();
    final double first = belowFold.first;

    // ignore: avoid_print
    print('\n📏 KATLAMA: şeridin ilk kalemi katlamadan '
        '${first.toStringAsFixed(0)}pt AŞAĞIDA '
        '(beyan ${kDeclaredFirstItemBelowFold.toStringAsFixed(0)}pt · '
        '${withStarter.length} kalem · en uzağı '
        '${belowFold.last.toStringAsFixed(0)}pt).');
    if (first > 0) {
      // ignore: avoid_print
      print('   ⏳ TASARIM YÖNÜ KURUCUDA: yönlendirme şeridi, yönlendirdiği '
          'seçimin ALTINDA. Test bu kararı VERMEZ, görünür tutar.\n');
    }

    expect((first - kDeclaredFirstItemBelowFold).abs() <= kTolerance, isTrue,
        reason: 'KATLAMA MESAFESİ BEYANDAN SAPTI: ölçüm '
            '${first.toStringAsFixed(1)}pt, beyan '
            '${kDeclaredFirstItemBelowFold.toStringAsFixed(1)}pt '
            '(tolerans ${kTolerance.toStringAsFixed(0)}pt).\n'
            'Yerleşim değişmiş olabilir — İKİ YÖNDE de anlamlı:\n'
            '  · sayı BÜYÜDÜYSE şerit daha da gömüldü (kötüleşme, sessiz kalamaz)\n'
            '  · sayı KÜÇÜLDÜYSE düzeltme inmiş demektir — beyanı tazele ve '
            'DEFTER\'e yaz (iyileşme de bir olaydır).');
  });
}
