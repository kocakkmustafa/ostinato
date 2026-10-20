// DRAFT: copy into app/test only after the root locale APIs/catalogs and
// HOST-INTEGRATION.patch are integrated. SDK/runtime acceptance is UNRUN.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/account_connection.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/app_locale_preferences.dart';
import 'package:ostinato/app/app_translation_catalog.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_audio_root.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/guitar_journey.dart';
import 'package:ostinato/app/guitar_journey_progress.dart';
import 'package:ostinato/app/motion_account_bootstrap.dart';
import 'package:ostinato/app/onboarding_store.dart';
import 'package:ostinato/app/screens/guitar_journey_screen.dart';
import 'package:ostinato/app/screens/library_screen.dart';
import 'package:ostinato/app/screens/settings_screen.dart';
import 'package:ostinato/main.dart';

import 'support/fake_practice_audio_port.dart';

const _accountA = '11111111-1111-4111-8111-111111111111';
const _accountB = '22222222-2222-4222-8222-222222222222';

Future<void> _waitFor(
  WidgetTester tester,
  bool Function() ready,
  String reason,
) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (ready()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  expect(ready(), isTrue, reason: reason);
}

AppLocaleController _controller(WidgetTester tester, Finder finder) =>
    AppLocaleScope.maybeOf(tester.element(finder))!;

Future<void> _select(
  WidgetTester tester,
  Finder finder,
  String? tag, {
  String? effectiveTag,
}) async {
  final controller = _controller(tester, finder);
  final saving = controller.select(tag);
  await _waitFor(
    tester,
    () =>
        canonicalLanguageTag(Localizations.localeOf(tester.element(finder))) ==
        (effectiveTag ?? tag),
    'The existing route must adopt the selected presentation locale',
  );
  await saving;
}

Future<void> _choose(
  WidgetTester tester,
  String option,
  String effectiveTag,
) async {
  var stage = 'locate dropdown';
  try {
    final dropdown = find.byKey(const Key('app-language-select'));
    expect(
      dropdown,
      findsOneWidget,
      reason: 'Settings choice $option: the real dropdown must exist',
    );
    final button = tester.widget<DropdownButton<String>>(dropdown);
    final order = button.items!.map((item) => item.value).toList();
    final targetIndex = order.indexOf(option);
    final selectedIndex = order.indexOf(button.value);
    expect(
      targetIndex,
      greaterThanOrEqualTo(0),
      reason: 'Settings choice $option must be declared by the real dropdown',
    );
    expect(
      selectedIndex,
      greaterThanOrEqualTo(0),
      reason: 'Settings choice $option: the current value must be declared',
    );

    stage = 'open popup';
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
    final hitDropdown = dropdown.hitTestable();
    expect(
      hitDropdown,
      findsOneWidget,
      reason: 'Settings choice $option: the dropdown must receive the tap',
    );
    await tester.tap(hitDropdown);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );

    // Settings uses SingleChildScrollView; the opened Flutter dropdown owns
    // the ListView. Scope the target to that popup instead of relying on .last
    // across the selected button item and lazily mounted menu rows.
    stage = 'locate popup scrollable';
    final menu = find.byType(ListView);
    expect(
      menu,
      findsOneWidget,
      reason: 'Settings choice $option: one dropdown popup must be open',
    );
    final scrollable = find.descendant(
      of: menu,
      matching: find.byType(Scrollable),
    );
    expect(
      scrollable,
      findsOneWidget,
      reason: 'Settings choice $option: the popup must have one scrollable',
    );
    final item = find.descendant(
      of: menu,
      matching: find.byKey(ValueKey('app-language-option-$option')),
    );

    // A menu row outside the current viewport may have no element yet.
    // Use bounded real drags toward its declared index before asserting its
    // existence; ensureVisible alone cannot discover an unmounted row.
    stage = 'scroll popup to target';
    await tester.scrollUntilVisible(
      item,
      targetIndex < selectedIndex ? -160.0 : 160.0,
      scrollable: scrollable,
      maxScrolls: 24,
      duration: const Duration(milliseconds: 50),
    );
    expect(
      item,
      findsOneWidget,
      reason: 'Settings choice $option: target must exist after bounded scroll',
    );
    final optionText = find.descendant(of: item, matching: find.byType(Text));
    expect(
      optionText,
      findsOneWidget,
      reason: 'Settings choice $option: target must contain one label',
    );
    await tester.ensureVisible(optionText);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
    final hitText = optionText.hitTestable();
    expect(
      hitText,
      findsOneWidget,
      reason: 'The visible $option label must receive the real pointer hit',
    );

    stage = 'tap popup label';
    await tester.tap(hitText);
    stage = 'await selected locale';
    await _waitFor(
      tester,
      () =>
          canonicalLanguageTag(
            Localizations.localeOf(tester.element(find.byType(SettingsScreen))),
          ) ==
          effectiveTag,
      'The real Settings dropdown must apply $option as $effectiveTag immediately',
    );
    // Finish the popup transition without waiting on unrelated IO spinners.
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      tester.widget<DropdownButton<String>>(dropdown).value,
      option,
      reason: 'Settings choice $option must remain the selected value',
    );
  } catch (error, stack) {
    debugPrint(
      'Settings dropdown choice=$option effective=$effectiveTag stage=$stage',
    );
    Error.throwWithStackTrace(error, stack);
  }
}

// The UI starts this Future in the widget fake zone. Awaiting it inside
// runAsync can leave its fake-zone continuations unpumped. Observe completion
// across bounded fake pumps and real event turns, then rethrow any IO failure
// with its original stack; disk bytes are still checked by the caller.
Future<void> _finishUiWrite(WidgetTester tester, Future<void> writing) async {
  var finished = false;
  Object? failure;
  StackTrace? failureStack;
  unawaited(
    writing.then<void>(
      (_) {
        finished = true;
      },
      onError: (Object error, StackTrace stack) {
        failure = error;
        failureStack = stack;
        finished = true;
      },
    ),
  );
  await _waitFor(
    tester,
    () => finished,
    'The explicit UI preference write must finish within 200 IO turns',
  );
  if (failure != null) {
    Error.throwWithStackTrace(failure!, failureStack!);
  }
}

final class _Preferences implements AppLocalePreferences {
  _Preferences({String? initial = 'en', bool holdRead = false}) {
    if (!holdRead) reading.complete(initial);
  }
  final reading = Completer<String?>();
  final writes = <String?>[];
  bool failNextWrite = false;

  @override
  Future<String?> read() => reading.future;

  @override
  Future<void> write(String? languageTag) async {
    writes.add(languageTag);
    if (failNextWrite) {
      failNextWrite = false;
      throw const FileSystemException('fixture preference write failure');
    }
  }
}

// Only the preference read future is held by this fixture. Writes and the
// on-disk reader use the production FileAppLocalePreferences implementation.
final class _HeldFilePreferences implements AppLocalePreferences {
  _HeldFilePreferences(this.files);

  final FileAppLocalePreferences files;
  final reading = Completer<String?>();
  final writes = <String?>[];
  Future<void>? lastWrite;

  @override
  Future<String?> read() => reading.future;

  @override
  Future<void> write(String? languageTag) {
    writes.add(languageTag);
    return lastWrite = files.write(languageTag);
  }
}

final class _FormFixture extends StatefulWidget {
  const _FormFixture();
  @override
  State<_FormFixture> createState() => _FormFixtureState();
}

final class _FormFixtureState extends State<_FormFixture> {
  final draft = TextEditingController();
  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TextField(key: const Key('fixture-account-draft'), controller: draft),
  );
}

final class _HeldGuitarBundle extends CachingAssetBundle {
  final pending = Completer<ByteData>();
  int calls = 0;
  @override
  Future<ByteData> load(String key) {
    calls++;
    return pending.future;
  }
}

final class _MissingGuitarBundle extends CachingAssetBundle {
  int calls = 0;
  @override
  Future<ByteData> load(String key) async {
    calls++;
    throw StateError('fixture missing asset; do not expose this diagnostic');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentRepository repo;
  late CueTextResolver cues;
  late GuitarJourneyCourse course;

  setUpAll(() async {
    // Production readers run outside the widget fake clock, with real bounds.
    repo = await ContentRepository.load().timeout(const Duration(seconds: 10));
    cues = await CueTextResolver.load().timeout(const Duration(seconds: 10));
    course = await GuitarJourneyCourse.load().timeout(
      const Duration(seconds: 10),
    );
  });

  Future<void> mountSettings(
    WidgetTester tester,
    AppLocalePreferences preferences, {
    bool waitUntilReady = true,
  }) async {
    await tester.pumpWidget(
      AppLocaleHost(
        preferences: preferences,
        child: ContentRepositoryScope(
          repo: repo,
          cueText: cues,
          child: Builder(
            builder: (context) => MaterialApp(
              locale: Localizations.localeOf(context),
              localeListResolutionCallback: resolveAppLocales,
              supportedLocales: appSupportedLocales,
              localizationsDelegates: appLocalizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const SettingsScreen(),
            ),
          ),
        ),
      ),
    );
    if (waitUntilReady) {
      await _waitFor(
        tester,
        () =>
            find.byKey(const Key('app-language-select')).evaluate().isNotEmpty,
        'Settings and the inherited app locale controller must be mounted',
      );
    }
  }

  testWidgets(
    'real app locale keeps Navigator form and active fake input owner',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final user = ValueNotifier<String?>(_accountA);
      final phase = ValueNotifier(MotionIdentityPhase.verified);
      final preferences = _Preferences();
      final port = FakePracticeAudioPort();
      final onboarding = InMemoryOnboardingStore(complete: true);
      final owners = <PracticeAudioRootOwner>[];
      var bindingDisposals = 0;
      var captureChannelCalls = 0;
      const capture = MethodChannel('com.yulalab.ostinato/audio_capture');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(capture, (
        call,
      ) async {
        captureChannelCalls++;
        throw StateError('Locale selection must not invoke capture');
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          capture,
          null,
        ),
      );
      final account = AccountConnection(
        userId: user,
        pageBuilder: (_) => const _FormFixture(),
      );
      await tester.pumpWidget(
        AppLocaleHost(
          preferences: preferences,
          child: OstinatoAudioRoot(
            userId: user,
            phase: phase,
            testLease: PracticeAudioLease(port: port),
            allowTestAcquisition: true,
            onTestOwnerCreated: owners.add,
            disposeAccountBinding: () => bindingDisposals++,
            builder: (host) => OstinatoApp(
              audioNavigatorHost: host,
              store: onboarding,
              accountConnection: account,
            ),
          ),
        ),
      );
      await _waitFor(
        tester,
        () => find.byType(LibraryScreen).evaluate().isNotEmpty,
        'The actual app must finish its packaged-content boot',
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      final route = MaterialPageRoute<void>(builder: account.pageBuilder);
      unawaited(navigator.push(route));
      await _waitFor(
        tester,
        () => find.byType(_FormFixture).evaluate().isNotEmpty,
        'The account page-builder route must open',
      );
      await tester.pump(const Duration(milliseconds: 350));
      final form = find.byType(_FormFixture);
      final formState = tester.state<_FormFixtureState>(form);
      await tester.enterText(
        find.byKey(const Key('fixture-account-draft')),
        'retained draft 123',
      );
      final owner = owners.single;
      await _waitFor(
        tester,
        () => owner.grantFor(route) != null,
        'The same observed route must receive a test-only fake lease grant',
      );
      final acquiring = owner.acquire(
        owner.grantFor(route)!,
        PracticeAudioSide.input,
      );
      await tester.pump();
      final acquired = await acquiring;
      expect(acquired.status, AudioRouteAcquireStatus.acquired);
      expect(owner.leasePhase, PracticeAudioLeasePhase.inputActive);
      final before = (
        opens: port.opens.length,
        closes: port.closeCalls,
        fences: port.fences.length,
      );
      for (final tag in supportedLanguageTags) {
        await _select(tester, form, tag);
        expect(
          tester.state<NavigatorState>(find.byType(Navigator)),
          same(navigator),
        );
        expect(tester.state(form), same(formState));
        expect(ModalRoute.of(tester.element(form)), same(route));
        expect(formState.draft.text, 'retained draft 123');
        expect(
          AccountScope.maybeOf(tester.element(form))?.currentUserId,
          _accountA,
        );
        expect(owner.topRoute, same(route));
        expect(owner.leasePhase, PracticeAudioLeasePhase.inputActive);
        expect((
          opens: port.opens.length,
          closes: port.closeCalls,
          fences: port.fences.length,
        ), before);
        expect(owners.length, 1);
        expect(bindingDisposals, 0);
        expect(captureChannelCalls, 0);
        expect(onboarding.markCalls, 0);
      }
      // Locale preservation must not suppress the real identity-boundary reset.
      user.value = _accountB;
      await _waitFor(
        tester,
        () => !navigator.mounted,
        'An actual account change must still retire the old Navigator',
      );
      expect(find.byType(_FormFixture), findsNothing);
      expect(port.fences.length, greaterThan(before.fences));
      await tester.pumpWidget(const SizedBox());
      expect(bindingDisposals, 1);
      user.dispose();
      phase.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'locale switch preserves the real progress namespace and disk bytes',
    (tester) async {
      final root = Directory.systemTemp.createTempSync(
        'ostinato-locale-progress-',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final preferences = _Preferences();
      final store = GuitarJourneyProgressStore(
        directoryProvider: () async => root,
        accountUserId: _accountA,
      );
      final initial = await tester.runAsync(() async {
        await store.record(
          lessonId: course.lessons.first.id,
          contentVersion: course.contentVersion,
          action: GuitarProgressAction.practiced,
        );
        await store.record(
          lessonId: course.lessons.first.id,
          contentVersion: course.contentVersion,
          action: GuitarProgressAction.selfReportedCompleted,
        );
        return store.load().timeout(const Duration(seconds: 5));
      });
      expect(initial, isNotNull);
      final file = File(
        '${root.path}/accounts/$_accountA/guitar_journey_progress.v1.json',
      );
      final bytesBefore = file.readAsBytesSync();
      final selectedOwners = <String?>[];
      await tester.pumpWidget(
        AppLocaleHost(
          preferences: preferences,
          child: Builder(
            builder: (context) => MaterialApp(
              locale: Localizations.localeOf(context),
              localeListResolutionCallback: resolveAppLocales,
              supportedLocales: appSupportedLocales,
              localizationsDelegates: appLocalizationsDelegates,
              home: AccountScope(
                connection: null,
                currentUserId: _accountA,
                child: GuitarJourneyScreen(
                  initialCourse: course,
                  initialProgress: initial!,
                  progressStoreFactory: (id) {
                    selectedOwners.add(id);
                    return store;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      final screen = find.byType(GuitarJourneyScreen);
      await _waitFor(
        tester,
        () => find
            .byKey(const Key('guitar-journey-progress'))
            .evaluate()
            .isNotEmpty,
        'The real progress page must render its existing account record',
      );
      final state = tester.state(screen);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      for (final tag in ['ja', 'ar', 'tr', 'en']) {
        await _select(tester, screen, tag);
        expect(tester.state(screen), same(state));
        expect(
          tester.state<NavigatorState>(find.byType(Navigator)),
          same(navigator),
        );
        expect(selectedOwners, [_accountA]);
        expect(
          AccountScope.maybeOf(tester.element(screen))?.currentUserId,
          _accountA,
        );
        expect(file.readAsBytesSync(), bytesBefore);
        final records = await tester.runAsync(
          () => store.load().timeout(const Duration(seconds: 5)),
        );
        expect(records?.values.single.practiceCount, 1);
        expect(records?.values.single.selfReportedCompletedAt, isNotNull);
      }
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Settings exposes fourteen self names and a serialized system choice',
    (tester) async {
      tester.view.physicalSize = const Size(320, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final preferences = _Preferences();
      await mountSettings(tester, preferences);
      final screen = find.byType(SettingsScreen);
      final route = ModalRoute.of(tester.element(screen));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      final dropdown = tester.widget<DropdownButton<String>>(
        find.byKey(const Key('app-language-select')),
      );
      const selfNames = <String, String>{
        'tr': 'Türkçe',
        'en': 'English',
        'es-419': 'Español (Latinoamérica)',
        'pt-BR': 'Português (Brasil)',
        'de': 'Deutsch',
        'fr': 'Français',
        'ja': '日本語',
        'ar': 'العربية',
        'it': 'Italiano',
        'ko': '한국어',
        'id': 'Bahasa Indonesia',
        'pl': 'Polski',
        'hi': 'हिन्दी',
        'zh-Hans': '简体中文',
      };
      expect(supportedLanguageTags, hasLength(14));
      expect(supportedLanguageTags.toSet(), selfNames.keys.toSet());
      expect(dropdown.items?.map((item) => item.value), [
        'system',
        ...supportedLanguageTags,
      ]);
      expect(
        dropdown.items?.skip(1).map((item) => (item.child as Text).data),
        supportedLanguageTags.map((tag) => selfNames[tag]),
      );
      for (final tag in supportedLanguageTags) {
        await _choose(tester, tag, tag);
        expect(_controller(tester, screen).languageTag, tag);
        expect(ModalRoute.of(tester.element(screen)), same(route));
        expect(
          tester.state<NavigatorState>(find.byType(Navigator)),
          same(navigator),
        );
        expect(tester.takeException(), isNull);
      }
      tester.binding.platformDispatcher.localesTestValue = [
        const Locale('pt', 'PT'),
      ];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      await _choose(tester, 'system', 'pt-BR');
      expect(_controller(tester, screen).languageTag, isNull);
      expect(preferences.writes, [...supportedLanguageTags, null]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Settings waits for read timeout then preserves disk until an explicit choice',
    (tester) async {
      tester.binding.platformDispatcher.localesTestValue = [const Locale('en')];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      final directory = Directory.systemTemp.createTempSync(
        'ostinato-locale-read-timeout-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final files = FileAppLocalePreferences(directory: directory);
      final file = File('${directory.path}/ostinato.locale.v1.json');
      final temporary = File('${file.path}.tmp');
      final saved = await tester.runAsync(() async {
        await files.write('tr').timeout(const Duration(seconds: 5));
        return files.read().timeout(const Duration(seconds: 5));
      });
      expect(saved, 'tr');
      final originalBytes = file.readAsBytesSync();
      final preferences = _HeldFilePreferences(files);
      await mountSettings(tester, preferences, waitUntilReady: false);

      // AppLocaleHost must not publish its child in a temporary system locale
      // while the saved preference is still within its three-second budget.
      expect(find.byType(MaterialApp), findsNothing);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byKey(const Key('app-language-select')), findsNothing);
      await tester.pump(const Duration(milliseconds: 2999));
      expect(find.byType(MaterialApp), findsNothing);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(preferences.writes, isEmpty);
      expect(file.readAsBytesSync(), originalBytes);
      expect(temporary.existsSync(), isFalse);

      await tester.pump(const Duration(milliseconds: 1));
      await _waitFor(
        tester,
        () => find
            .byKey(const Key('app-language-read-failure'))
            .evaluate()
            .isNotEmpty,
        'After the bounded read failure, Settings must publish system fallback',
      );
      final screen = find.byType(SettingsScreen);
      final controller = _controller(tester, screen);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      final route = ModalRoute.of(tester.element(screen));
      expect(screen, findsOneWidget);
      expect(controller.loading, isFalse);
      expect(controller.readFailed, isTrue);
      expect(controller.languageTag, isNull);
      expect(
        canonicalLanguageTag(Localizations.localeOf(tester.element(screen))),
        'en',
      );
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byKey(const Key('app-language-select')),
            )
            .value,
        'system',
      );
      expect(find.byKey(const Key('app-language-loading')), findsNothing);
      expect(preferences.writes, isEmpty);
      expect(file.readAsBytesSync(), originalBytes);
      expect(temporary.existsSync(), isFalse);

      // An explicit UI choice may replace those bytes. Its write starts
      // in the fake widget zone: interleave real IO turns with fake pumps,
      // then independently read disk outside the fake zone. A locale repaint
      // alone is not persistence evidence.
      await _choose(tester, 'ar', 'ar');
      expect(preferences.writes, ['ar']);
      expect(preferences.lastWrite, isNotNull);
      await _finishUiWrite(tester, preferences.lastWrite!);
      final persisted = await tester.runAsync(
        () => files.read().timeout(const Duration(seconds: 5)),
      );
      expect(persisted, 'ar');
      final selectedBytes = file.readAsBytesSync();
      expect(selectedBytes, isNot(originalBytes));
      expect(temporary.existsSync(), isFalse);
      expect(controller.readFailed, isFalse);
      expect(find.byKey(const Key('app-language-read-failure')), findsNothing);

      // The old read's completion must not repaint, rewrite, or replace the
      // current route/controller after timeout and a newer explicit choice.
      preferences.reading.complete(saved);
      await tester.pump();
      expect(_controller(tester, screen), same(controller));
      expect(controller.languageTag, 'ar');
      expect(controller.loading, isFalse);
      expect(controller.readFailed, isFalse);
      expect(
        canonicalLanguageTag(Localizations.localeOf(tester.element(screen))),
        'ar',
      );
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)),
        same(navigator),
      );
      expect(ModalRoute.of(tester.element(screen)), same(route));
      expect(preferences.writes, ['ar']);
      expect(file.readAsBytesSync(), selectedBytes);
      expect(temporary.existsSync(), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Settings shows read failure without writing a default', (
    tester,
  ) async {
    final preferences = _Preferences(holdRead: true);
    await mountSettings(tester, preferences, waitUntilReady: false);
    expect(find.byType(MaterialApp), findsNothing);
    expect(find.byType(SettingsScreen), findsNothing);
    preferences.reading.completeError(
      const FileSystemException('fixture read failure'),
    );
    await _waitFor(
      tester,
      () => find
          .byKey(const Key('app-language-read-failure'))
          .evaluate()
          .isNotEmpty,
      'The existing translated read-failure copy must be visible',
    );
    final screen = find.byType(SettingsScreen);
    expect(screen, findsOneWidget);
    expect(_controller(tester, screen).loading, isFalse);
    expect(_controller(tester, screen).readFailed, isTrue);
    expect(_controller(tester, screen).languageTag, isNull);
    expect(find.byKey(const Key('app-language-loading')), findsNothing);
    expect(preferences.writes, isEmpty);
    await _choose(tester, 'de', 'de');
    expect(preferences.writes, ['de']);
    expect(_controller(tester, screen).languageTag, 'de');
    expect(_controller(tester, screen).readFailed, isFalse);
    expect(find.byKey(const Key('app-language-read-failure')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Settings write failure stays visible until an explicit retry', (
    tester,
  ) async {
    final preferences = _Preferences()..failNextWrite = true;
    await mountSettings(tester, preferences);
    await _choose(tester, 'fr', 'fr');
    await _waitFor(
      tester,
      () => find
          .byKey(const Key('app-language-write-failure'))
          .evaluate()
          .isNotEmpty,
      'A failed preference write must not roll back the session language',
    );
    expect(_controller(tester, find.byType(SettingsScreen)).languageTag, 'fr');
    await _choose(tester, 'fr', 'fr');
    await _waitFor(
      tester,
      () => find
          .byKey(const Key('app-language-write-failure'))
          .evaluate()
          .isEmpty,
      'Choosing the same language again must recover persistence',
    );
    expect(preferences.writes, ['fr', 'fr']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'main loading MaterialApp inherits locale without restarting boot',
    (tester) async {
      final preferences = _Preferences();
      final bundle = _HeldGuitarBundle();
      await tester.pumpWidget(
        AppLocaleHost(
          preferences: preferences,
          child: OstinatoApp(guitarCourseBundle: bundle),
        ),
      );
      await _waitFor(
        tester,
        () => find.byType(CircularProgressIndicator).evaluate().isNotEmpty,
        'The real startup loading surface must remain pending',
      );
      final appState = tester.state(find.byType(OstinatoApp));
      final spinner = find.byType(CircularProgressIndicator);
      await _select(tester, spinner, 'tr');
      await _select(tester, spinner, 'ar');
      expect(tester.state(find.byType(OstinatoApp)), same(appState));
      expect(bundle.calls, 1);
      bundle.pending.completeError(StateError('fixture missing manifest'));
      await _waitFor(
        tester,
        () => find
            .byKey(const Key('ostinato-content-load-failure'))
            .evaluate()
            .isNotEmpty,
        'The original pending boot must reach its error surface',
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'main content error changes locale but preserves its support code',
    (tester) async {
      final preferences = _Preferences();
      final bundle = _MissingGuitarBundle();
      await tester.pumpWidget(
        AppLocaleHost(
          preferences: preferences,
          child: OstinatoApp(guitarCourseBundle: bundle),
        ),
      );
      final support = find.byKey(const Key('ostinato-content-support-code'));
      await _waitFor(
        tester,
        () => support.evaluate().isNotEmpty,
        'The real typed content failure must provide its stable support code',
      );
      final calls = bundle.calls;
      for (final tag in ['tr', 'ar', 'en']) {
        await _select(tester, support, tag);
        final context = tester.element(support);
        final expected = localized(
          context,
          'Support code: {v0}',
          'Destek kodu: {v0}',
          values: {'v0': 'CONTENT_MISSINGASSET'},
        );
        expect(tester.widget<Text>(support).data, expected);
        expect(expected, contains('CONTENT_MISSINGASSET'));
        expect(bundle.calls, calls);
        expect(find.byType(LibraryScreen), findsNothing);
        expect(find.textContaining('fixture missing asset'), findsNothing);
      }
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'startup failure inherits host choice and standalone fallback remains',
    (tester) async {
      await tester.pumpWidget(
        AppLocaleHost(
          preferences: _Preferences(),
          child: const AccountStartupFailure(),
        ),
      );
      final page = find.byType(Scaffold);
      await _waitFor(
        tester,
        () => page.evaluate().isNotEmpty,
        'Startup failure must render',
      );
      await _select(tester, page, 'ar');
      expect(Directionality.of(tester.element(page)), TextDirection.rtl);
      tester.binding.platformDispatcher.localesTestValue = [const Locale('tr')];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(const AccountStartupFailure());
      await _waitFor(
        tester,
        () => find
            .textContaining('Bu sürümde giriş kullanılamıyor')
            .evaluate()
            .isNotEmpty,
        'A standalone embed without AppLocaleScope must still use device locale',
      );
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Settings embedded without a locale scope keeps existing behavior',
    (tester) async {
      await tester.pumpWidget(
        ContentRepositoryScope(
          repo: repo,
          cueText: cues,
          child: MaterialApp(
            locale: const Locale('tr'),
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            home: const SettingsScreen(),
          ),
        ),
      );
      await _waitFor(
        tester,
        () => find.byType(SettingsScreen).evaluate().isNotEmpty,
        'Legacy embedded Settings must remain available',
      );
      expect(find.byKey(const Key('app-language-settings')), findsNothing);
      expect(find.text('Ayarlar'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
