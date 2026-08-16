import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';
import 'package:ostinato/app/screens/course_screen.dart';
import 'package:ostinato/app/screens/instrument_screen.dart';
import 'package:ostinato/app/screens/lesson_demo_screen.dart';
import 'package:ostinato/app/screens/lesson_locked_screen.dart';
import 'package:ostinato/app/screens/lesson_scored_screen.dart';
import 'package:ostinato/app/screens/library_screen.dart';
import 'package:ostinato/app/screens/live_screen.dart';
import 'package:ostinato_posture/ostinato_posture.dart';

/// GERÇEK library.json metniyle taşma (RenderFlex overflow) taraması.
///
/// Aile dersi (Choreia, giydirme turu 2026-08-05): sentetik fixture metni
/// KISA olduğu için testler yeşil kalır, taşma ancak GERÇEK içerikle
/// görünür. Bu dosya kısaltılmış örnek KULLANMAZ — `ContentRepository.load()`
/// aynı gerçek `assets/content/library.json`ı okur; ekranlar en uzun gerçek
/// metinle pump edilir (şan `sustained_note` kilit gerekçesi ~480 karakter,
/// gitar "Holding the guitar — measured, never graded" 44 karakter başlık).
/// `tester.takeException()` her pump'tan sonra AÇIKÇA sınanır — sessiz
/// taşma (yalnız sarı/siyah şerit, testi kendiliğinden kırmayan durum) bu
/// açık kontrol olmadan kaçabilir.
///
/// NOT (yapısal): disiplin/kurs/ders döngüsü `repo` yüklenmeden ÖNCE, senkron
/// `main()` gövdesinde KURULAMAZ (`setUpAll` yalnız çalıştırma anında,
/// kayıttan SONRA dolar) — bu yüzden her disiplin TEK bir `testWidgets`
/// içinde, kendi kurs/ders döngüsünü test GÖVDESİNDE (repo hazırken) kurar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ContentRepository repo;
  late CueTextResolver cueText;
  setUpAll(() async {
    repo = await ContentRepository.load();
    cueText = await CueTextResolver.load();
  });

  // `flutter_test`in VARSAYILAN yüzeyi ~800 mantıksal piksel GENİŞ — gerçek
  // bir telefondan (375-440pt) NEREDEYSE İKİ KAT daha geniş. O genişlikte
  // taşan hiçbir şey görünmez; "yeşil" burada YANLIŞ GÜVEN üretir. En dar
  // yaygın hedefe (iPhone SE/13-mini sınıfı, 375pt) SABİTLİYORUZ — dar
  // uçta taşmayan, hiçbir yerde taşmaz.
  setUp(() {
    final TestWidgetsFlutterBinding binding =
        TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(375, 812);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);
  });

  Widget harness(Widget child) => ContentRepositoryScope(
        repo: repo,
        cueText: cueText,
        child: MaterialApp(home: child),
      );

  Future<void> pumpNoOverflow(
      WidgetTester t, Widget screen, String label) async {
    await t.pumpWidget(harness(screen));
    await t.pump();
    await t.pump();
    expect(t.takeException(), isNull,
        reason: '$label taştı (RenderFlex overflow) — gerçek metinle ölçüldü');
  }

  testWidgets('Library — gerçek 3 çalgı kartı taşmadan render olur',
      (WidgetTester t) async {
    await pumpNoOverflow(
        t, LibraryScreen(repo: repo, cueText: cueText), 'Library');
  });

  for (final String id in <String>['guitar', 'voice', 'piano']) {
    testWidgets(
        '$id — Instrument/Course/her-ders-sınıfı/Live-başlığı GERÇEK metinle taşmadan render olur',
        (WidgetTester t) async {
      final Discipline d =
          repo.disciplines.firstWhere((Discipline x) => x.id == id);
      final InstrumentHue hue = InstrumentHues.of(id);

      await pumpNoOverflow(
          t, InstrumentScreenRoute(discipline: d), '$id/Instrument');

      for (final Course c in d.courses) {
        await pumpNoOverflow(
            t, CourseScreenRoute(discipline: d, course: c), '$id/${c.id}');

        for (final Lesson l in c.lessons) {
          final Widget screen = switch (l.kind) {
            LessonKind.locked =>
              LessonLockedScreenRoute(discipline: d, lesson: l, hue: hue),
            LessonKind.demoOnly =>
              LessonDemoScreenRoute(discipline: d, lesson: l, hue: hue),
            LessonKind.guide ||
            LessonKind.scored =>
              LessonScoredScreenRoute(discipline: d, lesson: l, hue: hue),
          };
          await pumpNoOverflow(t, screen, '$id/${l.id} (${l.kind.name})');

          if (l.kind == LessonKind.guide || l.kind == LessonKind.scored) {
            final FakePoseSource src = FakePoseSource(<double?>[3.0]);
            await t.pumpWidget(harness(LiveScreenRoute(
              discipline: d,
              lesson: l,
              hue: hue,
              source: src,
              skipCountdown: true,
            )));
            await t.pump();
            await t.pump();
            expect(t.takeException(), isNull,
                reason: '$id/${l.id} Live başlığı taştı — '
                    '"${l.displayName}" (${l.displayName.length} karakter)');
            await src.dispose();
          }
        }
      }
    });
  }
}
