// OST-UX-05g Faz D (reviewer tur 1): D1 tap action, D2 old panel absent,
// D3 neutral label, D5 surface in view, D6 14-language scan, D7 account
// switch guard.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/account_connection.dart';
import 'package:ostinato/app/app_message_ids.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/stage/ghost_level_copy.dart';
import 'package:ostinato/app/stage/ghost_policy.dart';
import 'package:ostinato/app/stage/ghost_store.dart';
import 'package:ostinato/app/stage/stage_home_screen.dart';

import 'support/practice_host.dart';
import 'support/ux_05g_rig.dart';

V1Lesson _lesson05h3() => V1Lesson.fromJson(
  jsonDecode(File('content/v1/gtr/gtr-s1-m02-02.json').readAsStringSync()),
);

void _tapSem(WidgetTester t, String label) => t.semantics.performAction(
  find.semantics.byLabel(label),
  SemanticsAction.tap,
);

Future<void> _help(WidgetTester t) async {
  await t.tap(find.byKey(const Key('stage-shelf-toggle')));
  await t.pump();
  await t.pump();
  await t.ensureVisible(find.byKey(const Key('stage-help-row')));
  await t.pump();
  await t.tap(find.byKey(const Key('stage-help-row')));
  await t.pump();
  await t.pump();
}

void main() {
  late final V1CourseCatalog catalog = catalog05f();
  setUp(resetAudioCaptureCoordinatorForTest);

  group('D1 semantics tap action', () {
    testWidgets('D1: Yardim satiri ve basamak secenekleri SemanticsAction.tap '
        'tasir ve tetiklenince calisir', (t) async {
      final sem = t.ensureSemantics();
      final rig = Rig05f();
      final store = MemoryGhostStore();
      await boot05f(t, stage05g(rig, catalog, ghostStore: store));
      await t.tap(find.byKey(const Key('stage-shelf-toggle')));
      await t.pump();
      await t.pump();
      final row = find.byKey(const Key('stage-help-row'));
      await t.ensureVisible(row);
      await t.pump();
      expect(
        t.getSemantics(row).getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'stage-help-row tap eylemi',
      );
      _tapSem(t, 'Yardım');
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('ghost-help-surface')), findsOneWidget);
      for (final l in GhostLevel.values) {
        final f = find.byKey(Key('ghost-level-${l.name}'));
        expect(f, findsOneWidget, reason: l.name);
        expect(
          t.getSemantics(f).getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
          reason: 'ghost-level-${l.name} tap eylemi',
        );
      }
      _tapSem(t, 'Pekiştirme');
      await t.pump();
      await t.pump();
      expect(store.state.level, GhostLevel.reinforce);
      sem.dispose();
      await dispose05f(t, rig);
    });
  });

  group('D2 eski panel sahnede yok', () {
    // NOT: `ostinatoGhostScreenOpen` bir `const` oldugundan testte acilamaz ve
    // sahne `ghostScreen: false` degerini sabit verir; o deger tek basina
    // kirmizi uretmez. Bu yuzden eski panelin VARLIGI ayri kontrolle gosterilir
    // (asagidaki "kontrol": ayni ekran `ghostScreen: true` ile `ghost-toggle`
    // cizer) ve sahnede ARANAN sey bu gercek, cizilen anahtardir.
    testWidgets('D2 kontrol: ghostScreen:true ile eski panel (ghost-toggle) '
        'cizilir; yani bulucu kirmizi olabilir', (t) async {
      final rig = Rig05f();
      await boot05f(
        t,
        practiceHost(
          PracticeLoopScreen(
            lesson: _lesson05h3(),
            progress: Mem05f(),
            seed: 1,
            ghostScreen: true,
            controllerFactory: rig.factory,
          ),
        ),
        size: const Size(420, 2400),
      );
      expect(find.byKey(const Key('ghost-toggle')), findsOneWidget);
      await dispose05f(t, rig);
    });

    testWidgets('D2: bayrak ACIK sahnede ghostScreen=false, eski panel yok, '
        'yeni Yardim var', (t) async {
      final rig = Rig05f();
      await boot05f(t, stage05g(rig, catalog, ghost: true));
      final screen = t.widget<PracticeLoopScreen>(
        find.byType(PracticeLoopScreen),
      );
      expect(screen.ghostScreen, isFalse);
      expect(find.byKey(const Key('ghost-toggle')), findsNothing);
      await _help(t);
      expect(find.byKey(const Key('ghost-help-surface')), findsOneWidget);
      expect(find.byKey(const Key('ghost-toggle')), findsNothing);
      await dispose05f(t, rig);
    });
  });

  group('D3 notr etiket', () {
    testWidgets('D3: "Bu basamagin yardimlari"; "gorunenler" vaadi yok', (
      t,
    ) async {
      final rig = Rig05f();
      await boot05f(t, stage05g(rig, catalog));
      await _help(t);
      expect(find.text('Bu basamağın yardımları'), findsOneWidget);
      expect(find.text('Bu basamakta görünenler'), findsNothing);
      await dispose05f(t, rig);
    });
  });

  group('D5 yuzey ekranda', () {
    for (final size in <Size>[const Size(360, 640), const Size(390, 844)]) {
      testWidgets('D5: acinca yuzey ekran icinde (ensureVisible yok), '
          '${size.width.toInt()}x${size.height.toInt()}', (t) async {
        final rig = Rig05f();
        await boot05f(t, stage05g(rig, catalog), size: size);
        await t.tap(find.byKey(const Key('stage-shelf-toggle')));
        await t.pump();
        await t.pump();
        final row = find.byKey(const Key('stage-help-row'));
        await t.ensureVisible(row);
        await t.pump();
        await t.tap(row);
        await t.pump();
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        final surface = find.byKey(const Key('ghost-help-surface'));
        expect(surface, findsOneWidget);
        final screen = Offset.zero & size;
        final top = t.getRect(surface).top;
        expect(top >= 0 && top < size.height - 96, isTrue, reason: 'ust=$top');
        final first = t.getRect(find.byKey(const Key('ghost-level-learn')));
        expect(
          screen.contains(first.center),
          isTrue,
          reason: 'ilk secenek ekranda: $first',
        );
        await dispose05f(t, rig);
      });
    }
  });

  group('D6 14 dil taramasi', () {
    // Bekcinin PROMISE_PATTERNS listesi (tools/validate_surface_honesty.py)
    // dosyadan okunur; bekci DEGISTIRILMEDI.
    List<RegExp> promise() {
      final src = File('tools/validate_surface_honesty.py').readAsStringSync();
      final block = RegExp(
        r'PROMISE_PATTERNS = \[(.*?)\n\]',
        dotAll: true,
      ).firstMatch(src)!.group(1)!;
      return [
        for (final m in RegExp(r'\(r"(.*?)", ".*?"\)').allMatches(block))
          RegExp(m.group(1)!, caseSensitive: false),
      ];
    }

    const stems = <String, List<String>>{
      'en': [
        'mastered',
        'competent',
        'proficient',
        'successful',
        'correct',
        'wrong',
        'right',
      ],
      'tr': ['yetkin', 'ustalaş', 'başarılı', 'doğru', 'yanlış', 'kazanıl'],
      'de': ['gemeistert', 'kompetent', 'erfolgreich', 'richtig', 'falsch'],
      'es-419': ['dominad', 'competente', 'exitos', 'correcto', 'incorrecto'],
      'fr': ['maîtris', 'compétent', 'réussi', 'correct', 'faux', 'erreur'],
      'it': ['padroneggi', 'competent', 'riuscit', 'corretto', 'sbagliat'],
      'pt-BR': ['dominad', 'competente', 'sucesso', 'correto', 'errad'],
      'pl': ['opanowa', 'kompetent', 'udan', 'poprawn', 'błęd', 'błąd'],
      'id': ['menguasai', 'kompeten', 'berhasil', 'benar', 'salah'],
      'ja': ['習得', '上手', '成功', '正解', '間違'],
      'ko': ['숙달', '능숙', '성공', '정답', '틀렸', '오답'],
      'zh-Hans': ['掌握', '精通', '成功', '正确', '错误', '失败'],
      'ar': ['إتقان', 'متقن', 'ناجح', 'صحيح', 'خاطئ', 'خطأ'],
      'hi': ['महारत', 'कुशल', 'सफल', 'सही', 'गलत', 'त्रुटि'],
    };

    test('D6: tarayici calisiyor (kontrol): 22 vaat deseni, bilinen kotu '
        'ornekleri yakalar', () {
      final p = promise();
      expect(p, hasLength(22));
      expect(p.any((r) => r.hasMatch('we do not grade this yet')), isTrue);
      expect(p.any((r) => r.hasMatch('henüz değerlendirmiyoruz')), isTrue);
      expect(stems.keys, hasLength(14));
    });

    test('D6: tum Hayalet cumleleri 14 dilde vaat/yetkinlik/dogru-yanlis '
        'kokunden temiz', () {
      final p = promise();
      expect(GhostLevelCopy.all, hasLength(14));
      for (final c in GhostLevelCopy.all) {
        final id = appMessageIds[c];
        expect(id, isNotNull, reason: c.$1);
        for (final loc in stems.keys) {
          final cat =
              (jsonDecode(File('assets/l10n/$loc.json').readAsStringSync())
                      as Map<String, dynamic>)['messages']
                  as Map<String, dynamic>;
          final text = cat[id] as String?;
          expect(text, isNotNull, reason: '$loc ${c.$1}');
          final lower = text!.toLowerCase();
          for (final r in p) {
            expect(r.hasMatch(text), isFalse, reason: '$loc "$text" $r');
          }
          for (final s in stems[loc]!) {
            expect(lower.contains(s), isFalse, reason: '$loc "$text" kok $s');
          }
        }
      }
    });
  });

  group('D7 hesap degisimi', () {
    Widget scoped(
      String id,
      GhostStore Function(String?) factory,
      Rig05f rig,
    ) => practiceHost(
      locale: 'tr',
      AccountScope(
        currentUserId: id,
        connection: AccountConnection(
          userId: ValueNotifier<String?>(id),
          pageBuilder: (_) => const SizedBox(),
          hasPaidAccess: () async => true,
        ),
        child: StageHomeScreen(
          catalog: catalog,
          progressFactory: (_) => Mem05f(),
          checksFactory: (_) => Checks05f(),
          controllerFactory: rig.factory,
          seed: 1,
          ghostOpen: true,
          ghostStoreFactory: factory,
          tunerOpener: (_) async {},
        ),
      ),
    );

    testWidgets('D7: eski hesabin gec biten okumasi yeni hesabi EZMEZ; '
        'hesap degisince durum sifirlanir', (t) async {
      final slow = Completer<GhostState>();
      final u1 = _SlowStore(slow.future);
      final u2 = MemoryGhostStore(
        const GhostState(level: GhostLevel.recall, validRuns: 2),
      );
      GhostStore factory(String? id) => id == 'u1' ? u1 : u2;
      final rig = Rig05f();
      await boot05f(t, scoped('u1', factory, rig));
      await t.pumpWidget(scoped('u2', factory, rig));
      for (var i = 0; i < 4; i++) {
        await t.pump();
      }
      // u1'in okumasi simdi biter (gec).
      slow.complete(const GhostState(level: GhostLevel.independent));
      for (var i = 0; i < 4; i++) {
        await t.pump();
      }
      await _help(t);
      // u2: Hatirlama secili ve ogeleri (preStartPreview, beat) gorunur
      expect(
        find.byKey(const Key('ghost-item-preStartPreview')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ghost-item-none')), findsNothing);
      await dispose05f(t, rig);
    });
  });
}

final class _SlowStore implements GhostStore {
  _SlowStore(this._load);
  final Future<GhostState> _load;
  @override
  Future<GhostState> load() => _load;
  @override
  Future<void> save(GhostState state) async {}
}
