import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/screens/library_screen.dart';

/// Başlangıç şeridi — TÜRETİLDİĞİNİN testi (DESIGN-AHEAD §1.2, O-117).
///
/// ⚠️ Bu dosyanın kendi tuzağı: beklenen üç dersi BURAYA yazmak, kimliği
/// ekrandan çıkarıp teste taşımak olurdu — aynı sertlikte ikinci bir gömülü
/// liste, üstelik "test var" diye korunuyor sanılan. Bu yüzden hiçbir ders
/// kimliği ya da başlığı elle yazılmadı: beklenen değerlerin HEPSİ
/// `repo`dan, yani ekranın okuduğu AYNI kaynaktan türetiliyor.
///
/// Bunun bedeli dürüstçe: bu test şeridin `library.json` ile UYUMLU
/// olduğunu kanıtlar, `library.json`ın DOĞRU dersi seçtiğini kanıtlamaz —
/// o seçimin kapısı `tools/validate_starters.py` (kilitli/demoOnly starter
/// reddi) ve kaynağı `_why_starter` alanı.
/// İtilen rotaları kaydeden tanık. Gezinmeyi ekranın YOKLUĞUNDAN çıkarmak
/// yerine, olayın kendisini kaydeder.
class _PushWitness extends NavigatorObserver {
  final List<Route<dynamic>> pushes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes.add(route);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ContentRepository repo;
  late CueTextResolver cueText;
  setUpAll(() async {
    repo = await ContentRepository.load();
    cueText = await CueTextResolver.load();
  });

  // Gerçek telefon genişliği (375pt) — real_content_overflow_test.dart ile
  // aynı gerekçe: varsayılan ~800pt yüzey taşmayı gizler.
  setUp(() {
    final TestWidgetsFlutterBinding binding =
        TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(375, 812);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);
  });

  /// [appKey] neden var: `pumpWidget` aynı tipte bir ağaç verildiğinde
  /// element ağacını YENİDEN KURMAZ, günceller — ve `Navigator` rota
  /// yığınını korur. Döngülü testte ikinci tur, birincinin ittiği ders
  /// ekranı hâlâ üstteyken koşar ve Library offstage kalır (ölçüldü: ikinci
  /// iterasyonda `find.byKey` 0 eleman). Farklı anahtar = taze yığın.
  Widget harness({
    List<NavigatorObserver> observers = const <NavigatorObserver>[],
    Key? appKey,
  }) => ContentRepositoryScope(
    repo: repo,
    cueText: cueText,
    child: MaterialApp(
      key: appKey,
      locale: const Locale('en'),
      supportedLocales: const <Locale>[Locale('en'), Locale('tr')],
      navigatorObservers: observers,
      home: LibraryScreen(repo: repo, cueText: cueText),
    ),
  );

  List<Discipline> liveWithStarter() => repo.disciplines
      .where((Discipline d) => d.status == 'live' && d.starterLesson != null)
      .toList();

  testWidgets('şerit başlığı ve kalem SAYISI canlı disiplinlerden türer', (
    WidgetTester t,
  ) async {
    await t.pumpWidget(harness());
    await t.pump();

    final List<Discipline> expected = liveWithStarter();
    // Ölçümün kendisi boşsa test HİÇBİR ŞEY kanıtlamaz — "0 kalem bulundu,
    // 0 bekleniyordu" yeşil yanar. Tabanı adıyla sınıyoruz.
    expect(
      expected,
      isNotEmpty,
      reason:
          'canlı disiplinlerin hiçbiri starter çözemedi — şerit boş '
          'olurdu ve bu testin geri kalanı boşlukta yeşil yanardı',
    );

    expect(
      find.text('EXPLORE LESSONS'),
      findsOneWidget,
      reason:
          'ilk sürümde ücretli seanslar kapalı; keşif şeridi '
          'başlama veya ödeme vaadi vermemeli',
    );
    expect(
      find.byWidgetPredicate(
        (Widget w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('starter-'),
      ),
      findsNWidgets(expected.length),
      reason:
          'şerit kalem sayısı canlı disiplin sayısından SAPTI — fazlası '
          'elle eklenmiş, eksiği çözülememiş kimlik demektir',
    );
  });

  testWidgets('her kalem KENDİ disiplininin çözülmüş dersini gösterir', (
    WidgetTester t,
  ) async {
    await t.pumpWidget(harness());
    await t.pump();

    for (final Discipline d in liveWithStarter()) {
      final Finder row = find.byKey(Key('starter-${d.id}'));
      expect(row, findsOneWidget, reason: '${d.id} için şerit kalemi yok');
      expect(
        find.descendant(
          of: row,
          matching: find.text(d.starterLesson!.displayName),
        ),
        findsOneWidget,
        reason:
            '${d.id} kalemi kendi starterLessonId\'sinin başlığını '
            'göstermiyor — şerit veriden KOPMUŞ',
      );
    }
  });

  testWidgets(
    'HER kalem kendi dersinin ekranını AÇAR (tanık: NavigatorObserver)',
    (WidgetTester t) async {
      // İlk yazımda "şerit kayboldu mu" diye sormuştum ve test HAKLI OLARAK
      // düştü: `Navigator.push` önceki rotayı ağaçtan SİLMEZ, üstünü örter.
      // Kaybolma, gezinmenin YANLIŞ VEKİLİ. Tanık artık itilen rotanın
      // kendisi — O-112'nin `NavigatorObserver` deseni.
      for (final Discipline d in liveWithStarter()) {
        final _PushWitness witness = _PushWitness();
        await t.pumpWidget(
          harness(
            observers: <NavigatorObserver>[witness],
            appKey: ValueKey<String>('app-${d.id}'),
          ),
        );
        await t.pump();
        witness.pushes.clear(); // ana rotanın kendi push'u sayılmaz

        // ŞERİT KATLAMANIN ALTINDA (375×812'de ölçüldü: ilk yazımda tap 0 rota
        // itti çünkü kalem görünür alanın dışındaydı). Kaydırmak testin
        // hilesi değil kullanıcının gerçeği — ama bu gerçek DEFTER'e de
        // yazıldı (O-117): tasarım şeridi kartların hemen altına koyuyor ve
        // en dar yaygın telefonda oraya scroll'suz ulaşılmıyor.
        await t.ensureVisible(find.byKey(Key('starter-${d.id}')));
        await t.pumpAndSettle();

        await t.tap(find.byKey(Key('starter-${d.id}')));
        await t.pumpAndSettle();

        expect(
          witness.pushes.length,
          1,
          reason: '${d.id}: dokunma TAM BİR rota itmeliydi',
        );
        expect(
          find.text(d.starterLesson!.displayName),
          findsWidgets,
          reason: '${d.id}: açılan ekran o dersin başlığını taşımıyor',
        );
      }
    },
  );

  testWidgets('şerit gerçek metinle taşmaz', (WidgetTester t) async {
    await t.pumpWidget(harness());
    await t.pump();
    await t.pump();
    expect(
      t.takeException(),
      isNull,
      reason: 'START HERE şeridi gerçek başlıklarla taştı (375pt)',
    );
  });
}
