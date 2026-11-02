import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale_preferences.dart';
import 'package:ostinato/app/app_translation_catalog.dart';
import 'package:ostinato/app/app_message_ids.dart';
import 'package:ostinato/app/guitar_journey_progress.dart';

void main() {
  test(
    'file preference round-trips an explicit tag and system selection',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ostinato-locale-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final preferences = FileAppLocalePreferences(directory: directory);
      expect(await preferences.read(), isNull);
      await preferences.write('pt-BR');
      expect(await preferences.read(), 'pt-BR');
      await preferences.write(null);
      expect(await preferences.read(), isNull);
      final value = jsonDecode(
        await File('${directory.path}/ostinato.locale.v1.json').readAsString(),
      );
      expect(value, {'schemaVersion': 1, 'languageTag': null});
      expect(
        await File('${directory.path}/ostinato.locale.v1.json.tmp').exists(),
        isFalse,
      );
    },
  );

  for (final raw in ['{broken', '{"schemaVersion":1,"languageTag":"xx"}']) {
    test('unreadable preference remains byte-identical: $raw', () async {
      final directory = await Directory.systemTemp.createTemp(
        'ostinato-locale-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/ostinato.locale.v1.json');
      await file.writeAsString(raw);
      final controller = AppLocaleController(
        preferences: FileAppLocalePreferences(directory: directory),
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.readFailed, isTrue);
      expect(controller.loading, isFalse);
      expect(controller.languageTag, isNull);
      expect(await file.readAsString(), raw);
      expect(await File('${file.path}.tmp').exists(), isFalse);
    });
  }

  testWidgets('a pending preference read falls back within its read budget', (
    tester,
  ) async {
    final preferences = _Preferences();
    final controller = AppLocaleController(preferences: preferences);
    addTearDown(controller.dispose);
    final loading = controller.load();
    await tester.pump(const Duration(seconds: 3));
    await loading;
    expect(controller.loading, isFalse);
    expect(controller.readFailed, isTrue);
    expect(controller.languageTag, isNull);
    expect(preferences.writes, isEmpty);
    preferences.reading.complete('fr');
    await tester.pump();
    expect(controller.languageTag, isNull);
    expect(controller.readFailed, isTrue);
    expect(preferences.writes, isEmpty);
  });

  test(
    'a late saved preference cannot replace an explicit selection',
    () async {
      final preferences = _Preferences();
      final controller = AppLocaleController(preferences: preferences);
      addTearDown(controller.dispose);
      final loading = controller.load();
      final selecting = controller.select('de');
      preferences.reading.complete('tr');
      await loading;
      await Future<void>.delayed(Duration.zero);
      expect(controller.languageTag, 'de');
      expect(controller.loading, isFalse);
      expect(preferences.writes.single.tag, 'de');
      preferences.writes.single.completion.complete();
      await selecting;
    },
  );

  test(
    'writes serialize and an old failure cannot publish into the new choice',
    () async {
      final preferences = _Preferences()..reading.complete(null);
      final controller = AppLocaleController(preferences: preferences);
      addTearDown(controller.dispose);
      await controller.load();
      final first = controller.select('fr');
      final second = controller.select('ar');
      await Future<void>.delayed(Duration.zero);
      expect(preferences.writes.map((w) => w.tag), ['fr']);
      preferences.writes.first.completion.completeError(
        const FileSystemException('fixture'),
      );
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(preferences.writes.map((w) => w.tag), ['fr', 'ar']);
      expect(controller.languageTag, 'ar');
      expect(controller.writeFailed, isFalse);
      preferences.writes.last.completion.complete();
      await second;
      expect(controller.writeFailed, isFalse);
    },
  );

  test(
    'a failed current write remains visible and the next explicit write recovers',
    () async {
      final preferences = _Preferences()..reading.complete(null);
      final controller = AppLocaleController(preferences: preferences);
      addTearDown(controller.dispose);
      await controller.load();
      final first = controller.select('ja');
      await Future<void>.delayed(Duration.zero);
      preferences.writes.first.completion.completeError(
        const FileSystemException('fixture'),
      );
      await first;
      expect(controller.languageTag, 'ja');
      expect(controller.writeFailed, isTrue);
      final retry = controller.select('ja');
      await Future<void>.delayed(Duration.zero);
      preferences.writes.last.completion.complete();
      await retry;
      expect(controller.writeFailed, isFalse);
      expect(() => controller.select('xx'), throwsArgumentError);
      expect(preferences.writes.length, 2);
    },
  );

  test('device preference order selects the approved regional catalogs', () {
    expect(
      resolveAppLocales([const Locale('ru'), const Locale('pt', 'PT')], []),
      const Locale('pt', 'BR'),
    );
    expect(
      resolveAppLocales([const Locale('es', 'ES')], []),
      const Locale('es', '419'),
    );
    expect(resolveAppLocales([const Locale('ru')], []), const Locale('en'));
    expect(resolveAppLocales(null, []), const Locale('en'));
    expect(supportedLanguageTags.toSet().length, 14);
    const chinese = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
    expect(localeForLanguageTag('zh-Hans'), chinese);
    expect(resolveAppLocales([const Locale('zh', 'CN')], []), chinese);
    expect(canonicalLanguageTag(chinese), 'zh-Hans');
    expect(intlLocaleName(chinese), 'zh');
    for (final unsupported in [
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Latn'),
      const Locale('zh', 'TW'),
      const Locale('zh', 'HK'),
      const Locale('zh', 'MO'),
    ]) {
      expect(canonicalLanguageTag(unsupported), 'en');
      expect(
        resolveAppLocales([unsupported, const Locale('fr')], []),
        const Locale('fr'),
      );
      expect(resolveAppLocales([unsupported], []), const Locale('en'));
      expect(const AppTranslationsDelegate().isSupported(unsupported), isFalse);
    }
    for (final tag in supportedLanguageTags) {
      expect(localeForLanguageTag(tag).toLanguageTag(), tag);
    }
  });

  test(
    'an explicit choice before load never reads an older saved choice',
    () async {
      final preferences = _Preferences()..reading.complete('tr');
      final controller = AppLocaleController(preferences: preferences);
      addTearDown(controller.dispose);
      final selection = controller.select('ar');
      await controller.load();
      expect(preferences.readCount, 0);
      expect(controller.languageTag, 'ar');
      await Future<void>.delayed(Duration.zero);
      preferences.writes.single.completion.complete();
      await selection;
    },
  );

  test(
    'a synchronous listener cannot reverse persistence order or the caller future',
    () async {
      final preferences = _Preferences()..reading.complete(null);
      final controller = AppLocaleController(preferences: preferences);
      addTearDown(controller.dispose);
      await controller.load();
      Future<void>? nested;
      controller.addListener(() {
        if (controller.languageTag == 'fr') nested = controller.select('ar');
      });
      final outer = controller.select('fr');
      expect(identical(outer, nested), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(preferences.writes.map((w) => w.tag), ['fr']);
      preferences.writes.first.completion.complete();
      await outer;
      await Future<void>.delayed(Duration.zero);
      expect(preferences.writes.map((w) => w.tag), ['fr', 'ar']);
      expect(controller.languageTag, 'ar');
      preferences.writes.last.completion.complete();
      await nested;
    },
  );

  test(
    'prepared delegate loads are synchronous and isolated by bundle',
    () async {
      final firstBundle = _DelayedLocaleBundle();
      final secondBundle = _DelayedLocaleBundle();
      final first = AppTranslationsDelegate(bundle: firstBundle);
      final loading = first.load(const Locale('fr'));
      expect(
        identical(
          loading,
          AppTranslationsDelegate(bundle: firstBundle).load(const Locale('fr')),
        ),
        isTrue,
      );
      expect(firstBundle.calls['fr'], 1);
      firstBundle.complete('fr');
      final prepared = await loading;
      var synchronous = false;
      first.load(const Locale('fr')).then((value) {
        synchronous = true;
        expect(value, same(prepared));
      });
      expect(synchronous, isTrue);
      expect(firstBundle.calls['fr'], 1);
      final independent = AppTranslationsDelegate(
        bundle: secondBundle,
      ).load(const Locale('fr'));
      expect(secondBundle.calls['fr'], 1);
      secondBundle.complete('fr');
      expect(await independent, isNot(same(prepared)));
    },
  );

  test(
    'failed preparation caches source fallback without an unhandled error',
    () async {
      final bundle = _DelayedLocaleBundle();
      final delegate = AppTranslationsDelegate(bundle: bundle);
      final loading = delegate.load(const Locale('ar'));
      bundle.fail('ar');
      final fallback = await loading;
      expect(fallback.locale, const Locale('ar'));
      expect(fallback.text('Language', 'Dil'), 'Language');
      var synchronous = false;
      delegate.load(const Locale('ar')).then((_) => synchronous = true);
      expect(synchronous, isTrue);
      expect(bundle.calls['ar'], 1);
    },
  );

  test('known plural IDs reject a string instead of their plural map', () {
    final id = appMessagePluralSources.keys.first;
    expect(
      () => AppTranslations.fromJson(const Locale('en'), {
        'schemaVersion': 1,
        'locale': 'en',
        // Even a string with the correct placeholder contract is not a plural map.
        'messages': {id: appMessagePluralSources[id]!['enOne']!},
      }),
      throwsFormatException,
    );
  });

  test('all seven plural IDs select categories and preserve source fallback', () {
    expect(appMessagePluralSources.length, 7);
    final countNames = <String, String>{
      'd1dd39c6c2708a07': 'v2',
      'bf71276795357a3e': 'v0',
      'd20233581ed29705': 'v0',
      '1e1a87f93ef87382': 'v0',
      'efc600bca7e1b87c': 'v0',
      'a0d2a51dd25b63d6': 'v2',
      '19d0a7a4844ffd1e': 'v2',
    };
    for (final id in appMessagePluralSources.keys) {
      final pair = appMessageIds.entries
          .singleWhere((entry) => entry.value == id)
          .key;
      final contract = appMessagePlaceholders[id]!;
      final variants = <String, String>{
        for (final category in ['zero', 'one', 'two', 'few', 'many', 'other'])
          category:
              '$category ${contract.entries.expand((entry) => List.filled(entry.value, '{${entry.key}}')).join(' ')}',
      };
      final arabic = AppTranslations.fromJson(const Locale('ar'), {
        'schemaVersion': 1,
        'locale': 'ar',
        'messages': {id: variants},
      });
      for (final item in [
        (0, 'zero'),
        (1, 'one'),
        (2, 'two'),
        (3, 'few'),
        (11, 'many'),
        (100, 'other'),
      ]) {
        final values = <String, Object?>{
          for (final name in contract.keys)
            name: name == countNames[id] ? item.$1 : 9,
        };
        final rendered = arabic.text(
          pair.$1,
          pair.$2,
          values: values,
          pluralCount: item.$1,
        );
        expect(rendered, startsWith('${item.$2} '), reason: '$id: ${item.$1}');
        expect(rendered, isNot(contains('{v')));
        expect(
          '\u2068'.allMatches(rendered).length,
          contract.values.fold<int>(0, (a, b) => a + b),
        );
        expect(
          '\u2069'.allMatches(rendered).length,
          contract.values.fold<int>(0, (a, b) => a + b),
        );
      }
      final japanese = AppTranslations(const Locale('ja'), {
        id: {'other': variants['other']!},
      });
      expect(
        japanese.text(pair.$1, pair.$2, pluralCount: 1),
        startsWith('other '),
      );
      final polish = AppTranslations(const Locale('pl'), {
        id: {
          for (final category in ['one', 'few', 'many', 'other'])
            category: variants[category]!,
        },
      });
      for (final item in [
        (1, 'one'),
        (2, 'few'),
        (5, 'many'),
        (12, 'many'),
        (22, 'few'),
        (101, 'many'),
      ]) {
        expect(
          polish.text(pair.$1, pair.$2, pluralCount: item.$1),
          startsWith('${item.$2} '),
        );
      }
      // Integer counts used by these UI messages. Italian has a many
      // category at a million; a translated other form remains its documented
      // grammatical fallback when the catalog intentionally shares that form.
      for (final entry in <String, List<(int, String)>>{
        'hi': [(0, 'one'), (1, 'one'), (2, 'other')],
        'it': [(1, 'one'), (1000000, 'many')],
        'ko': [(0, 'other'), (1, 'other'), (2, 'other')],
        'id': [(0, 'other'), (1, 'other'), (2, 'other')],
        'zh-Hans': [(0, 'other'), (1, 'other'), (2, 'other')],
      }.entries) {
        final locale = localeForLanguageTag(entry.key);
        final translated = AppTranslations(locale, {id: variants});
        for (final item in entry.value) {
          expect(
            translated.text(pair.$1, pair.$2, pluralCount: item.$1),
            startsWith('${item.$2} '),
            reason: '$id ${entry.key} ${item.$1}',
          );
        }
      }
      final italianFallback = AppTranslations(const Locale('it'), {
        id: {'one': variants['one']!, 'other': variants['other']!},
      });
      expect(
        italianFallback.text(pair.$1, pair.$2, pluralCount: 1000000),
        startsWith('other '),
      );
      for (final locale in [const Locale('en'), const Locale('tr')]) {
        final source = AppTranslations(locale, const {});
        final expected =
            appMessagePluralSources[id]![locale.languageCode == 'tr'
                ? 'trOne'
                : 'enOne'];
        expect(source.text(pair.$1, pair.$2, pluralCount: 1), expected);
      }
    }
  });

  test('all fourteen packaged catalogs retain every exact source contract', () {
    expect(ostinatoSupportedLocales, hasLength(14));
    expect(appMessageIds, hasLength(8396));
    final ids = appMessageIds.values.toSet();
    for (final locale in ostinatoSupportedLocales) {
      final tag = canonicalLanguageTag(locale);
      final raw = jsonDecode(File('assets/l10n/$tag.json').readAsStringSync());
      final translated = AppTranslations.fromJson(locale, raw);
      expect(translated.messages.keys.toSet(), ids, reason: tag);
      for (final pair in appMessageIds.entries) {
        final names =
            appMessagePlaceholders[pair.value]?.keys ?? const <String>[];
        final values = <String, Object?>{
          for (final key in names) key: 'fixture-$key',
        };
        final rendered = translated.text(
          pair.key.$1,
          pair.key.$2,
          values: values,
          pluralCount: appMessagePluralSources.containsKey(pair.value)
              ? 2
              : null,
        );
        expect(rendered.trim(), isNotEmpty, reason: '$tag ${pair.value}');
        expect(
          rendered,
          isNot(contains(RegExp(r'\{[A-Za-z][A-Za-z0-9_]*\}'))),
          reason: '$tag ${pair.value}',
        );
      }
    }
  });

  testWidgets('saved preference is read before the first child is published', (
    tester,
  ) async {
    final preferences = _Preferences();
    final bundle = _DelayedLocaleBundle();
    var builds = 0;
    await tester.pumpWidget(
      AppLocaleHost(
        preferences: preferences,
        translationBundle: bundle,
        child: Builder(
          builder: (context) {
            builds++;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(builds, 0);
    expect(bundle.calls, isEmpty);
    preferences.reading.complete('ar');
    await tester.pump();
    expect(builds, 0);
    expect(bundle.calls.keys, ['ar']);
    bundle.complete('ar');
    await tester.pumpAndSettle();
    expect(builds, greaterThan(0));
    expect(bundle.calls.keys, ['ar']);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing selected asset still publishes source copy and RTL', (
    tester,
  ) async {
    final preferences = _Preferences()..reading.complete('ar');
    final bundle = _DelayedLocaleBundle();
    await tester.pumpWidget(
      AppLocaleHost(
        preferences: preferences,
        translationBundle: bundle,
        child: Builder(
          builder: (context) => Text(
            AppTranslations.maybeOf(context)!.text('Language', 'Dil'),
            key: const Key('source-fallback-fixture'),
          ),
        ),
      ),
    );
    await tester.pump();
    bundle.fail('ar');
    await tester.pumpAndSettle();
    final element = tester.element(
      find.byKey(const Key('source-fallback-fixture')),
    );
    expect(find.text('Language'), findsOneWidget);
    expect(Localizations.localeOf(element), const Locale('ar'));
    expect(Directionality.of(element), TextDirection.rtl);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'disposing while a catalog is pending never publishes or throws',
    (tester) async {
      final preferences = _Preferences()..reading.complete('fr');
      final bundle = _DelayedLocaleBundle();
      var builds = 0;
      await tester.pumpWidget(
        AppLocaleHost(
          preferences: preferences,
          translationBundle: bundle,
          child: Builder(
            builder: (context) {
              builds++;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
      expect(bundle.calls['fr'], 1);
      await tester.pumpWidget(const SizedBox());
      bundle.complete('fr');
      await tester.pumpAndSettle();
      expect(builds, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'out-of-order FR then AR loads retain final AR route draft and progress',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'ostinato-locale-race-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final store = GuitarJourneyProgressStore(
        directoryProvider: () async => directory,
      );
      await tester.runAsync(() async {
        await store.record(
          lessonId: 'guitar.locale-race.fixture',
          contentVersion: 'locale-race.v1',
          action: GuitarProgressAction.practiced,
        );
        await store.record(
          lessonId: 'guitar.locale-race.fixture',
          contentVersion: 'locale-race.v1',
          action: GuitarProgressAction.selfReportedCompleted,
        );
      });
      final progressFile = File(
        '${directory.path}/guitar_journey_progress.v1.json',
      );
      final progressBefore = progressFile.readAsBytesSync();
      final preferences = _Preferences()..reading.complete('en');
      final bundle = _DelayedLocaleBundle();
      late AppLocaleController controller;
      final outerLocales = <Locale>[];
      await tester.pumpWidget(
        AppLocaleHost(
          preferences: preferences,
          translationBundle: bundle,
          child: Builder(
            builder: (context) {
              controller = AppLocaleScope.maybeOf(context)!;
              outerLocales.add(Localizations.localeOf(context));
              return MaterialApp(
                locale: Localizations.localeOf(context),
                supportedLocales: ostinatoSupportedLocales,
                localizationsDelegates: [
                  AppTranslationsDelegate(bundle: bundle),
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const _DraftPage(),
                        ),
                      ),
                      child: const Text('open-race-fixture'),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(bundle.calls['en'], 1);
      bundle.complete('en');
      await tester.pumpAndSettle();
      await tester.tap(find.text('open-race-fixture'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'retained race draft');
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      final page = tester.state(find.byType(_DraftPage));
      final frSave = controller.select('fr');
      await tester.pump();
      final arSave = controller.select('ar');
      await tester.pump();
      expect(bundle.calls.keys, containsAll(['en', 'fr', 'ar']));
      expect(outerLocales.last, const Locale('en'));
      preferences.writes.first.completion.complete();
      await frSave;
      await tester.pump();
      preferences.writes.last.completion.complete();
      await arSave;
      bundle.complete('ar');
      await tester.pumpAndSettle();
      expect(outerLocales.last, const Locale('ar'));
      bundle.complete('fr');
      await tester.pumpAndSettle();
      final field = tester.element(find.byType(TextField));
      expect(controller.languageTag, 'ar');
      expect(outerLocales, isNot(contains(const Locale('fr'))));
      expect(outerLocales.last, const Locale('ar'));
      expect(Localizations.localeOf(field), const Locale('ar'));
      expect(AppTranslations.maybeOf(field)?.locale, const Locale('ar'));
      expect(AppTranslations.maybeOf(field)?.text('Language', 'Dil'), 'اللغة');
      expect(Directionality.of(field), TextDirection.rtl);
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)),
        same(navigator),
      );
      expect(tester.state(find.byType(_DraftPage)), same(page));
      expect(find.text('retained race draft'), findsOneWidget);
      expect(find.text('open-race-fixture'), findsNothing);
      expect(progressFile.readAsBytesSync(), progressBefore);
      final records = await tester.runAsync(() => store.load());
      expect(records?.values.single.practiceCount, 1);
      expect(records?.values.single.selfReportedCompletedAt, isNotNull);
      expect(preferences.writes.map((write) => write.tag), ['fr', 'ar']);
      expect(bundle.calls, {'en': 1, 'fr': 1, 'ar': 1});
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('language updates retain the current route and typed draft', (
    tester,
  ) async {
    final preferences = _Preferences()..reading.complete('en');
    final bundle = _LocaleBundle();
    late AppLocaleController controller;
    await tester.pumpWidget(
      AppLocaleHost(
        preferences: preferences,
        translationBundle: bundle,
        child: Builder(
          builder: (context) {
            controller = AppLocaleScope.maybeOf(context)!;
            return MaterialApp(
              locale: Localizations.localeOf(context),
              supportedLocales: ostinatoSupportedLocales,
              localizationsDelegates: [
                AppTranslationsDelegate(bundle: bundle),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const _DraftPage(),
                      ),
                    ),
                    child: const Text('open-fixture'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open-fixture'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'retained user draft');
    final pageState = tester.state(find.byType(_DraftPage));
    final changing = controller.select('ar');
    await tester.pumpAndSettle();
    preferences.writes.single.completion.complete();
    await changing;
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(_DraftPage)), same(pageState));
    expect(find.text('retained user draft'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(TextField))),
      TextDirection.rtl,
    );
    expect(
      AppTranslations.maybeOf(
        tester.element(find.byType(TextField)),
      )?.text('Language', 'Dil'),
      'اللغة',
    );
    expect(find.text('open-fixture'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}

final class _Preferences implements AppLocalePreferences {
  final reading = Completer<String?>();
  final writes = <({String? tag, Completer<void> completion})>[];
  int readCount = 0;
  @override
  Future<String?> read() {
    readCount++;
    return reading.future;
  }

  @override
  Future<void> write(String? languageTag) {
    final completion = Completer<void>();
    writes.add((tag: languageTag, completion: completion));
    return completion.future;
  }
}

final class _LocaleBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final tag = key.split('/').last.split('.').first;
    final bytes = utf8.encode(
      jsonEncode({
        'schemaVersion': 1,
        'locale': tag,
        'messages': {
          appMessageIds[('Language', 'Dil')]!: tag == 'ar'
              ? 'اللغة'
              : 'Language',
        },
      }),
    );
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

final class _DraftPage extends StatefulWidget {
  const _DraftPage();
  @override
  State<_DraftPage> createState() => _DraftPageState();
}

final class _DraftPageState extends State<_DraftPage> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: TextField(controller: controller));
}

final class _DelayedLocaleBundle extends CachingAssetBundle {
  final pending = <String, Completer<String>>{};
  final calls = <String, int>{};

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    final tag = key.split('/').last.split('.').first;
    calls.update(tag, (count) => count + 1, ifAbsent: () => 1);
    return pending.putIfAbsent(tag, Completer<String>.new).future;
  }

  void complete(String tag) => pending[tag]!.complete(
    jsonEncode({
      'schemaVersion': 1,
      'locale': tag,
      'messages': {
        appMessageIds[('Language', 'Dil')]!: tag == 'ar'
            ? 'اللغة'
            : tag == 'fr'
            ? 'Langue'
            : 'Language',
      },
    }),
  );

  void fail(String tag) =>
      pending[tag]!.completeError(StateError('fixture missing catalog'));

  @override
  Future<ByteData> load(String key) =>
      throw UnimplementedError('loadString fixture only');
}
