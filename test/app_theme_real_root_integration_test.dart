// DRAFT ONLY. Proposed target: app/test/app_theme_real_root_integration_test.dart.
// Requires the reviewed theme integration-draft and locale catalogs in app/lib.
// Source freeze remains active. No SDK/analyzer/formatter execution: UNRUN.
// This file imports the production OstinatoApp + AudioRoot + progress store.
// It does not invoke main(), initialize live Auth, or open physical audio.
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
import 'package:ostinato/app/app_theme.dart';
import 'package:ostinato/app/app_theme_preferences.dart';
import 'package:ostinato/app/audio/native_audio_state.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_audio_root.dart';
import 'package:ostinato/app/guitar_journey.dart';
import 'package:ostinato/app/guitar_journey_progress.dart';
import 'package:ostinato/app/onboarding_store.dart';
import 'package:ostinato/app/screens/guitar_journey_screen.dart';
import 'package:ostinato/app/screens/library_screen.dart';
import 'package:ostinato/main.dart';

import 'support/fake_practice_audio_port.dart';

const _accountA = '11111111-1111-4111-8111-111111111111';
const _accountB = '22222222-2222-4222-8222-222222222222';
const _ioBound = Duration(seconds: 5);

// Fixed, short fake-clock steps plus bounded real IO turns. Never settle a
// whole app tree: unrelated spinners, caret timers and pending boot can persist.
Future<void> _waitFor(
  WidgetTester tester,
  bool Function() ready,
  String reason,
) async {
  for (var attempt = 0; attempt < 250; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (ready()) return;
    await tester.runAsync(() => Future<void>.delayed(
      const Duration(milliseconds: 5),
    ).timeout(const Duration(seconds: 1)));
  }
  expect(ready(), isTrue, reason: reason);
}

Future<T> _complete<T>(
  WidgetTester tester,
  Future<T> operation,
  String reason,
) async {
  var finished = false;
  Object? failure;
  StackTrace? trace;
  unawaited(operation.then<void>(
    (_) { finished = true; },
    onError: (Object error, StackTrace stack) {
      failure = error;
      trace = stack;
      finished = true;
    },
  ));
  await _waitFor(tester, () => finished, reason);
  if (failure != null) Error.throwWithStackTrace(failure!, trace!);
  return await operation; // Already completed; cannot wait indefinitely here.
}

Future<Directory> _temporary(WidgetTester tester, String prefix) async {
  final directory = await tester.runAsync(() => Directory.systemTemp
      .createTemp(prefix).timeout(_ioBound));
  expect(directory, isNotNull);
  final root = directory!;
  addTearDown(() async {
    await tester.runAsync(() async {
      if (await root.exists().timeout(_ioBound)) {
        await root.delete(recursive: true).timeout(_ioBound);
      }
    });
  });
  return root;
}

final class _LocalePreferences implements AppLocalePreferences {
  final writes = <String?>[];
  @override
  Future<String?> read() async => 'ar';
  @override
  Future<void> write(String? value) async { writes.add(value); }
}

final class _MemoryThemePreferences implements AppThemePreferences {
  final writes = <AppThemePreference>[];
  @override
  Future<AppThemePreference> read() async => AppThemePreference.system;
  @override
  Future<void> write(AppThemePreference value) async { writes.add(value); }
}

// Only reads are held. Explicit writes still use the real atomic file writer.
final class _HeldThemePreferences implements AppThemePreferences {
  _HeldThemePreferences(this.files);
  final FileAppThemePreferences files;
  final reading = Completer<AppThemePreference>();
  final writes = <AppThemePreference>[];
  @override
  Future<AppThemePreference> read() => reading.future;
  @override
  Future<void> write(AppThemePreference value) {
    writes.add(value);
    return files.write(value);
  }
}

final class _AccountDraftPage extends StatefulWidget {
  const _AccountDraftPage({required this.onDisposed});
  final VoidCallback onDisposed;
  @override
  State<_AccountDraftPage> createState() => _AccountDraftPageState();
}

final class _AccountDraftPageState extends State<_AccountDraftPage> {
  final text = TextEditingController();
  final focus = FocusNode();
  final scroll = ScrollController();
  @override
  void dispose() {
    text.dispose();
    focus.dispose();
    scroll.dispose();
    widget.onDisposed();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      controller: scroll,
      children: [
        const SizedBox(height: 300),
        TextField(
          key: const Key('theme-account-draft'),
          controller: text,
          focusNode: focus,
        ),
        const SizedBox(height: 1200),
      ],
    ),
  );
}

final class _RetainedDialog extends StatefulWidget {
  const _RetainedDialog();
  @override
  State<_RetainedDialog> createState() => _RetainedDialogState();
}

final class _RetainedDialogState extends State<_RetainedDialog> {
  final focus = FocusNode();
  @override
  void dispose() { focus.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('theme-retained-dialog'),
    content: const Text('Retained dialog العربية'),
    actions: [FilledButton(
      autofocus: true,
      focusNode: focus,
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Close fixture dialog'),
    )],
  );
}

final class _HeldCourseBundle extends CachingAssetBundle {
  final reading = Completer<ByteData>();
  int calls = 0;
  @override
  Future<ByteData> load(String key) { calls++; return reading.future; }
}

typedef _Counters = ({int opens, int closes, int fences});
_Counters _counts(FakePracticeAudioPort port) => (
  opens: port.opens.length,
  closes: port.closeCalls,
  fences: port.fences.length,
);

// This is a fixture for the real app's injected seams, not a replacement
// MaterialApp. The production OstinatoApp builds and owns the Navigator.
final class _RealApp {
  _RealApp(this.theme, {WidgetBuilder? pageBuilder, this.bundle}) {
    account = AccountConnection(
      userId: user,
      pageBuilder: pageBuilder ?? (_) => const Scaffold(body: Text('account')),
    );
  }
  final AppThemeController theme;
  final AssetBundle? bundle;
  final user = ValueNotifier<String?>(_accountA);
  final phase = ValueNotifier(MotionIdentityPhase.verified);
  final locale = _LocalePreferences();
  final port = FakePracticeAudioPort();
  final onboarding = InMemoryOnboardingStore(complete: true);
  final owners = <PracticeAudioRootOwner>[];
  late final AccountConnection account;
  int bindingDisposals = 0;
  int captureCalls = 0;
  PracticeAudioRootOwner get owner => owners.single;

  Future<void> mount(WidgetTester tester, {bool waitForLibrary = true}) async {
    expect(theme.loading, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    const channel = MethodChannel('com.yulalab.ostinato/audio_capture');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
      (call) async {
        captureCalls++;
        throw StateError('Theme fixture must not invoke native capture');
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(AppThemeHost(
      controller: theme,
      child: AppLocaleHost(
        preferences: locale,
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
            guitarCourseBundle: bundle,
          ),
        ),
      ),
    ));
    await _waitFor(tester,
      () => owners.length == 1 &&
          find.byType(OstinatoApp).evaluate().isNotEmpty &&
          find.byType(MaterialApp).evaluate().isNotEmpty,
      'Locale/catalog boot must publish the actual app and AudioRoot first');
    if (waitForLibrary) {
      await _waitFor(tester,
        () => find.byType(LibraryScreen).evaluate().isNotEmpty,
        'The actual OstinatoApp must finish its packaged-content boot');
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final close = owner.lastFenceForTest;
    if (close != null) await _complete(tester, close, 'Fake root disposal must finish');
    expect(bindingDisposals, 1);
    expect(captureCalls, 0);
    user.dispose();
    phase.dispose();
    expect(tester.takeException(), isNull);
  }
}

Future<AppThemeController> _memoryController(WidgetTester tester) async {
  final controller = AppThemeController(preferences: _MemoryThemePreferences());
  await tester.runAsync(() => controller.load().timeout(_ioBound));
  return controller;
}

Future<void> _selectTheme(
  WidgetTester tester,
  AppThemeController controller,
  AppThemePreference preference,
) async {
  await _complete(tester, controller.select(preference),
      'Theme selection persistence must finish within the fixture budget');
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _platform(WidgetTester tester, Brightness brightness) async {
  tester.binding.platformDispatcher.platformBrightnessTestValue = brightness;
  await tester.pump(const Duration(milliseconds: 250));
}

void _presentation(BuildContext context, Brightness brightness) {
  expect(Theme.of(context).brightness, brightness);
  expect(OstinatoPalette.of(context).shell,
      (brightness == Brightness.dark ? OstinatoPalette.dark : OstinatoPalette.light).shell);
  expect(canonicalLanguageTag(Localizations.localeOf(context)), 'ar');
  expect(Directionality.of(context), TextDirection.rtl);
}

Future<void> _acquire(
  WidgetTester tester,
  _RealApp app,
  Route<dynamic> route,
) async {
  await _waitFor(tester, () => app.owner.grantFor(route) != null,
      'The original observed route must have an explicit test-only fake grant');
  final acquired = await _complete(tester,
      app.owner.acquire(app.owner.grantFor(route)!, PracticeAudioSide.input),
      'The in-memory input lease must acquire');
  expect(acquired.status, AudioRouteAcquireStatus.acquired);
  expect(app.owner.leasePhase, PracticeAudioLeasePhase.inputActive);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GuitarJourneyCourse course;
  setUpAll(() async {
    course = await GuitarJourneyCourse.load().timeout(const Duration(seconds: 10));
  });
  setUp(() {
    addTearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearPlatformBrightnessTestValue());
  });

  testWidgets('real root theme preserves active input account draft focus scroll locale and dialog', (tester) async {
    await _platform(tester, Brightness.light);
    var draftDisposals = 0;
    final theme = await _memoryController(tester);
    final app = _RealApp(theme, pageBuilder: (_) => _AccountDraftPage(
      onDisposed: () => draftDisposals++,
    ));
    await app.mount(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final appState = tester.state(find.byType(OstinatoApp));
    final audioState = tester.state(find.byType(OstinatoAudioRoot));
    final owner = app.owner;
    final route = MaterialPageRoute<void>(builder: app.account.pageBuilder);
    unawaited(navigator.push(route));
    await _waitFor(tester, () => find.byType(_AccountDraftPage).evaluate().isNotEmpty,
        'The actual account page-builder seam must open in the app Navigator');
    await tester.pump(const Duration(milliseconds: 400));
    final finder = find.byType(_AccountDraftPage);
    final state = tester.state<_AccountDraftPageState>(finder);
    await tester.enterText(find.byKey(const Key('theme-account-draft')), 'Retained العربية draft 123');
    state.text.selection = const TextSelection(baseOffset: 3, extentOffset: 12);
    state.focus.requestFocus();
    await tester.pump();
    state.scroll.jumpTo(100);
    await tester.pump();
    final text = state.text.value;
    final offset = state.scroll.offset;
    final locale = AppLocaleScope.maybeOf(state.context);
    expect(locale?.languageTag, 'ar');
    await _acquire(tester, app, route);
    var before = _counts(app.port);
    void retained(Brightness brightness) {
      expect(tester.state<NavigatorState>(find.byType(Navigator)), same(navigator));
      expect(tester.state(find.byType(OstinatoApp)), same(appState));
      expect(tester.state(find.byType(OstinatoAudioRoot)), same(audioState));
      expect(app.owner, same(owner));
      expect(app.owners, hasLength(1));
      expect(tester.state(finder), same(state));
      expect(ModalRoute.of(state.context), same(route));
      expect(state.text.value, text);
      expect(state.scroll.offset, closeTo(offset, .01));
      expect(AppLocaleScope.maybeOf(state.context), same(locale));
      expect(AppThemeScope.maybeOf(state.context), same(theme));
      expect(AccountScope.maybeOf(state.context)?.currentUserId, _accountA);
      expect(app.locale.writes, isEmpty);
      expect(app.bindingDisposals, 0);
      expect(draftDisposals, 0);
      expect(app.onboarding.markCalls, 0);
      expect(app.captureCalls, 0);
      _presentation(state.context, brightness);
    }
    for (final (preference, brightness) in [
      (AppThemePreference.dark, Brightness.dark),
      (AppThemePreference.light, Brightness.light),
      (AppThemePreference.system, Brightness.light),
    ]) {
      await _selectTheme(tester, theme, preference);
      retained(brightness);
      expect(state.focus.hasFocus, isTrue);
      expect(owner.topRoute, same(route));
      expect(owner.leasePhase, PracticeAudioLeasePhase.inputActive);
      expect(_counts(app.port), before);
    }
    await _platform(tester, Brightness.dark);
    retained(Brightness.dark);
    expect(state.focus.hasFocus, isTrue);
    expect(owner.leasePhase, PracticeAudioLeasePhase.inputActive);
    expect(_counts(app.port), before);

    // Dialog push is a real route boundary and MUST fence. Establish the next
    // theme baseline only after that intended navigation event has completed.
    final dialogClosed = showDialog<void>(context: state.context,
        builder: (_) => const _RetainedDialog());
    await _waitFor(tester, () => find.byType(_RetainedDialog).evaluate().isNotEmpty,
        'The real Navigator overlay dialog must open');
    await tester.pump(const Duration(milliseconds: 400));
    final dialog = tester.state<_RetainedDialogState>(find.byType(_RetainedDialog));
    final dialogRoute = ModalRoute.of(dialog.context)!;
    expect(app.port.fences.length, greaterThan(before.fences));
    await _acquire(tester, app, dialogRoute);
    dialog.focus.requestFocus();
    await tester.pump();
    final dialogFocus = FocusManager.instance.primaryFocus;
    before = _counts(app.port);
    for (final (preference, brightness) in [
      (AppThemePreference.light, Brightness.light),
      (AppThemePreference.dark, Brightness.dark),
    ]) {
      await _selectTheme(tester, theme, preference);
      retained(brightness);
      expect(tester.state(find.byType(_RetainedDialog)), same(dialog));
      expect(ModalRoute.of(dialog.context), same(dialogRoute));
      expect(FocusManager.instance.primaryFocus, same(dialogFocus));
      expect(owner.topRoute, same(dialogRoute));
      expect(owner.leasePhase, PracticeAudioLeasePhase.inputActive);
      expect(_counts(app.port), before);
      _presentation(dialog.context, brightness);
    }
    navigator.pop();
    await _complete(tester, dialogClosed, 'The explicit dialog pop must finish');
    await tester.pump(const Duration(milliseconds: 400));
    state.focus.requestFocus();
    await tester.pump();
    retained(Brightness.dark);
    await _acquire(tester, app, route);
    before = _counts(app.port);
    // Appearance retention must not disable real identity-boundary teardown.
    app.user.value = _accountB;
    await _waitFor(tester, () => !navigator.mounted && draftDisposals == 1,
        'Actual account change must dispose old Navigator and draft route');
    await _complete(tester, owner.lastFenceForTest!, 'Account fence must complete');
    expect(app.port.fences.length, greaterThan(before.fences));
    expect(app.port.fences.skip(before.fences), contains(NativeAudioContextReason.accountChange));
    expect(app.port.closeCalls, greaterThan(before.closes));
    expect(owner.leasePhase, isNot(PracticeAudioLeasePhase.inputActive));
    expect(app.owner, same(owner));
    expect(app.bindingDisposals, 0); // Binding belongs to root lifetime.
    await app.unmount(tester);
  });

  testWidgets('real root theme keeps progress account namespace and exact disk bytes', (tester) async {
    await _platform(tester, Brightness.light);
    final directory = await _temporary(tester, 'ostinato-theme-progress-');
    final store = GuitarJourneyProgressStore(
      directoryProvider: () async => directory, accountUserId: _accountA,
    );
    final initial = await tester.runAsync(() async {
      await store.record(lessonId: course.lessons.first.id,
        contentVersion: course.contentVersion, action: GuitarProgressAction.practiced).timeout(_ioBound);
      await store.record(lessonId: course.lessons.first.id,
        contentVersion: course.contentVersion, action: GuitarProgressAction.selfReportedCompleted).timeout(_ioBound);
      return store.load().timeout(_ioBound);
    });
    final file = File('${directory.path}/accounts/$_accountA/guitar_journey_progress.v1.json');
    final bytes = await tester.runAsync(() => file.readAsBytes().timeout(_ioBound));
    final selectedAccounts = <String?>[];
    final theme = await _memoryController(tester);
    final app = _RealApp(theme, pageBuilder: (_) => GuitarJourneyScreen(
      initialCourse: course, initialProgress: initial!,
      progressStoreFactory: (id) { selectedAccounts.add(id); return store; },
    ));
    await app.mount(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final route = MaterialPageRoute<void>(builder: app.account.pageBuilder);
    unawaited(navigator.push(route));
    await _waitFor(tester,
        () => find.byKey(const Key('guitar-journey-progress')).evaluate().isNotEmpty,
        'Real progress route must render the seeded account record');
    await tester.pump(const Duration(milliseconds: 400));
    final finder = find.byType(GuitarJourneyScreen);
    final state = tester.state(finder);
    final owner = app.owner;
    await _acquire(tester, app, route);
    final before = _counts(app.port);
    for (final (preference, brightness) in [
      (AppThemePreference.dark, Brightness.dark),
      (AppThemePreference.light, Brightness.light),
      (AppThemePreference.system, Brightness.light),
    ]) {
      await _selectTheme(tester, theme, preference);
      expect(tester.state(finder), same(state));
      expect(tester.state<NavigatorState>(find.byType(Navigator)), same(navigator));
      expect(ModalRoute.of(tester.element(finder)), same(route));
      expect(selectedAccounts, [_accountA]);
      expect(AccountScope.maybeOf(tester.element(finder))?.currentUserId, _accountA);
      expect(await tester.runAsync(() => file.readAsBytes().timeout(_ioBound)), bytes);
      final records = await tester.runAsync(() => store.load().timeout(_ioBound));
      expect(records?.values.single.practiceCount, 1);
      expect(records?.values.single.selfReportedCompletedAt, isNotNull);
      expect(_counts(app.port), before);
      expect(app.owner, same(owner));
      expect(owner.leasePhase, PracticeAudioLeasePhase.inputActive);
      _presentation(tester.element(finder), brightness);
    }
    await _platform(tester, Brightness.dark);
    expect(tester.state(finder), same(state));
    expect(selectedAccounts, [_accountA]);
    expect(_counts(app.port), before);
    _presentation(tester.element(finder), Brightness.dark);
    expect(await tester.runAsync(() => file.readAsBytes().timeout(_ioBound)), bytes);
    app.user.value = _accountB;
    await _waitFor(tester, () => !navigator.mounted,
        'Account switch must retire the old real progress Navigator');
    expect(find.byType(GuitarJourneyScreen), findsNothing);
    expect(state.mounted, isFalse);
    expect(app.port.fences.length, greaterThan(before.fences));
    expect(app.port.fences.skip(before.fences), contains(NativeAudioContextReason.accountChange));
    expect(await tester.runAsync(() => file.readAsBytes().timeout(_ioBound)), bytes);
    expect(await tester.runAsync(() => File(
        '${directory.path}/accounts/$_accountB/guitar_journey_progress.v1.json'
      ).exists().timeout(_ioBound)), isFalse);
    await app.unmount(tester);
  });

  // Separate named cases keep expanded definition count explicit: seven tests.
  testWidgets('real root cold start uses saved light despite dark platform', (tester) async {
    await _savedStartup(tester, AppThemePreference.light, Brightness.dark, Brightness.light);
  });
  testWidgets('real root cold start uses saved dark despite light platform', (tester) async {
    await _savedStartup(tester, AppThemePreference.dark, Brightness.light, Brightness.dark);
  });
  testWidgets('real root cold start system follows platform without writing preference', (tester) async {
    await _savedStartup(tester, AppThemePreference.system, Brightness.dark, Brightness.dark);
  });

  testWidgets('real root read timeout preserves saved bytes and rejects late theme repaint', (tester) async {
    await _platform(tester, Brightness.light);
    final directory = await _temporary(tester, 'ostinato-theme-read-timeout-');
    final files = FileAppThemePreferences(directory: directory);
    await tester.runAsync(() => files.write(AppThemePreference.light).timeout(_ioBound));
    final file = File('${directory.path}/ostinato.theme.v1.json');
    final original = await tester.runAsync(() => file.readAsBytes().timeout(_ioBound));
    final preferences = _HeldThemePreferences(files);
    final theme = AppThemeController(preferences: preferences,
        readDeadline: const Duration(milliseconds: 100));
    // Real-time bounded load, awaited before first AppThemeHost as main requires.
    await tester.runAsync(() => theme.load().timeout(_ioBound));
    expect(theme.loading, isFalse);
    expect(theme.readFailed, isTrue);
    expect(theme.preference, AppThemePreference.system);
    expect(preferences.writes, isEmpty);
    expect(await tester.runAsync(() => file.readAsBytes().timeout(_ioBound)), original);
    final app = _RealApp(theme);
    await app.mount(tester);
    final library = find.byType(LibraryScreen);
    final state = tester.state(library);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final owner = app.owner;
    final before = _counts(app.port);
    _presentation(tester.element(library), Brightness.light);
    await _selectTheme(tester, theme, AppThemePreference.dark);
    final selected = await tester.runAsync(() => file.readAsBytes().timeout(_ioBound));
    expect(selected, isNot(original));
    preferences.reading.complete(AppThemePreference.light);
    await tester.pump(const Duration(milliseconds: 250));
    expect(theme.preference, AppThemePreference.dark);
    expect(theme.readFailed, isFalse);
    expect(tester.state(library), same(state));
    expect(tester.state<NavigatorState>(find.byType(Navigator)), same(navigator));
    expect(app.owner, same(owner));
    expect(app.owners, hasLength(1));
    expect(_counts(app.port), before);
    expect(preferences.writes, [AppThemePreference.dark]);
    expect(await tester.runAsync(() => files.read().timeout(_ioBound)), AppThemePreference.dark);
    expect(await tester.runAsync(() => file.readAsBytes().timeout(_ioBound)), selected);
    _presentation(tester.element(library), Brightness.dark);
    await app.unmount(tester);
  });

  testWidgets('real root pending boot and typed error theme change do not restart content load', (tester) async {
    await _platform(tester, Brightness.light);
    final theme = await _memoryController(tester);
    final bundle = _HeldCourseBundle();
    final app = _RealApp(theme, bundle: bundle);
    await app.mount(tester, waitForLibrary: false);
    await _waitFor(tester, () => find.byType(CircularProgressIndicator).evaluate().isNotEmpty,
        'The actual OstinatoApp loading branch must remain pending');
    final appState = tester.state(find.byType(OstinatoApp));
    final audioState = tester.state(find.byType(OstinatoAudioRoot));
    final owner = app.owner;
    final spinner = find.byType(CircularProgressIndicator);
    final loadingNavigator = tester.state<NavigatorState>(find.byType(Navigator));
    final before = _counts(app.port);
    await _selectTheme(tester, theme, AppThemePreference.dark);
    expect(bundle.calls, 1);
    expect(tester.state(find.byType(OstinatoApp)), same(appState));
    expect(tester.state(find.byType(OstinatoAudioRoot)), same(audioState));
    expect(tester.state<NavigatorState>(find.byType(Navigator)), same(loadingNavigator));
    expect(app.owner, same(owner));
    expect(_counts(app.port), before);
    _presentation(tester.element(spinner), Brightness.dark);
    bundle.reading.completeError(StateError('fixture missing asset diagnostic'));
    final support = find.byKey(const Key('ostinato-content-support-code'));
    await _waitFor(tester, () => support.evaluate().isNotEmpty,
        'The same pending content load must reach its typed error surface');
    final supportCode = tester.widget<Text>(support).data;
    final errorNavigator = tester.state<NavigatorState>(find.byType(Navigator));
    final errorRoute = ModalRoute.of(tester.element(support));
    final errorCounts = _counts(app.port);
    await _selectTheme(tester, theme, AppThemePreference.light);
    expect(tester.widget<Text>(support).data, supportCode);
    expect(tester.state<NavigatorState>(find.byType(Navigator)), same(errorNavigator));
    expect(ModalRoute.of(tester.element(support)), same(errorRoute));
    expect(tester.state(find.byType(OstinatoApp)), same(appState));
    expect(bundle.calls, 1);
    expect(_counts(app.port), errorCounts);
    expect(find.byType(LibraryScreen), findsNothing);
    expect(find.textContaining('fixture missing asset diagnostic'), findsNothing);
    _presentation(tester.element(support), Brightness.light);
    await app.unmount(tester);
  });
}

Future<void> _savedStartup(
  WidgetTester tester,
  AppThemePreference saved,
  Brightness platform,
  Brightness expected,
) async {
  await _platform(tester, platform);
  final directory = await _temporary(tester, 'ostinato-theme-cold-start-');
  final preferences = FileAppThemePreferences(directory: directory);
  await tester.runAsync(() => preferences.write(saved).timeout(_ioBound));
  final file = File('${directory.path}/ostinato.theme.v1.json');
  final bytes = await tester.runAsync(() => file.readAsBytes().timeout(_ioBound));
  final theme = AppThemeController(preferences: preferences);
  await tester.runAsync(() => theme.load().timeout(_ioBound));
  expect(theme.preference, saved);
  expect(theme.loading, isFalse);
  final app = _RealApp(theme, bundle: _HeldCourseBundle());
  await app.mount(tester, waitForLibrary: false);
  await _waitFor(tester, () => find.byType(CircularProgressIndicator).evaluate().isNotEmpty,
      'First actual MaterialApp must use loaded preference while boot is pending');
  final spinner = find.byType(CircularProgressIndicator);
  final appState = tester.state(find.byType(OstinatoApp));
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  final owner = app.owner;
  final before = _counts(app.port);
  _presentation(tester.element(spinner), expected);
  expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, theme.themeMode);
  final opposite = platform == Brightness.dark ? Brightness.light : Brightness.dark;
  await _platform(tester, opposite);
  _presentation(tester.element(spinner), saved == AppThemePreference.system ? opposite : expected);
  expect(tester.state(find.byType(OstinatoApp)), same(appState));
  expect(tester.state<NavigatorState>(find.byType(Navigator)), same(navigator));
  expect(app.owner, same(owner));
  expect(_counts(app.port), before);
  expect(await tester.runAsync(() => file.readAsBytes().timeout(_ioBound)), bytes);
  // Resolve the finite fixture before teardown, with a handled consumer error.
  (app.bundle! as _HeldCourseBundle).reading.completeError(StateError('cold-start fixture ends'));
  await _waitFor(tester,
      () => find.byKey(const Key('ostinato-content-load-failure')).evaluate().isNotEmpty,
      'Pending course future must be resolved before fixture teardown');
  await app.unmount(tester);
}
