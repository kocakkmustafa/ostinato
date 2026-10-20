import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/app_locale_preferences.dart';
import 'package:ostinato/app/app_theme.dart';
import 'package:ostinato/app/app_theme_preferences.dart';
import 'package:ostinato/app/app_translation_catalog.dart';
import 'package:ostinato/app/ostinato_identity_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = '00000000-0000-4000-8000-000000000001';
const _realBudget = Duration(seconds: 2);

// HTTP/timers run in the real IO zone; widget frames remain under tester.
Future<T> _real<T>(WidgetTester tester, Future<T> Function() action) async {
  Object? failure;
  StackTrace? failureStack;
  late T value;
  await tester.runAsync(() async {
    try {
      value = await action().timeout(_realBudget);
    } catch (error, stack) {
      failure = error;
      failureStack = stack;
    }
  });
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  return value;
}

Future<void> _until(bool Function() ready) async {
  final limit = DateTime.now().add(const Duration(seconds: 1));
  while (!ready()) {
    if (DateTime.now().isAfter(limit)) {
      throw TimeoutException('Offline fixture did not reach its named stage');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

// No pumpAndSettle: a real verifying gate intentionally keeps its spinner alive.
Future<void> _framesUntil(
  WidgetTester tester,
  bool Function() ready, {
  required String stage,
}) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    await tester.pump();
    if (ready()) return;
    await _real(
      tester,
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
  }
  fail('Offline widget stage remained unready: $stage');
}

String _session(String token) => jsonEncode({
  'access_token': token,
  'refresh_token': 'synthetic-refresh',
  'token_type': 'bearer',
  'expires_at': 4102444800,
  'expires_in': 3600,
  'user': {
    'id': _userId,
    'aud': 'authenticated',
    'created_at': '2026-09-24T00:00:00Z',
    'app_metadata': <String, dynamic>{},
  },
});

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response _userReply() => _json({
  'id': _userId,
  'aud': 'authenticated',
  'created_at': '2026-09-24T00:00:00Z',
  'app_metadata': <String, dynamic>{},
});

http.Response _blockedReply() => _json({
  'code': 'synthetic_unavailable',
  'message': 'Offline fixture denial; not deletion evidence',
}, status: 403);

final class _MemoryLocalePreferences implements AppLocalePreferences {
  _MemoryLocalePreferences(this.value);
  String? value;
  var writes = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? languageTag) async {
    writes++;
    value = languageTag;
  }
}

final class _MemoryThemePreferences implements AppThemePreferences {
  _MemoryThemePreferences(this.value);
  AppThemePreference value;

  @override
  Future<AppThemePreference> read() async => value;

  @override
  Future<void> write(AppThemePreference preference) async {
    value = preference;
  }
}

// Valid empty app catalogs isolate the host/gate seam. Core still loads its
// real fourteen-language strings. This is not app catalog meaning acceptance.
final class _PresentationBundle extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    const prefix = 'assets/l10n/';
    if (!key.startsWith(prefix) || !key.endsWith('.json')) {
      throw StateError('Unexpected presentation fixture asset: $key');
    }
    final tag = key.substring(prefix.length, key.length - '.json'.length);
    if (!supportedLanguageTags.contains(tag)) {
      throw StateError('Unsupported presentation fixture language: $tag');
    }
    return jsonEncode({
      'schemaVersion': 1,
      'locale': tag,
      'messages': <String, Object>{},
    });
  }

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(
    Uint8List.fromList(utf8.encode(await loadString(key))),
  );
}

final class _AuthFixture {
  SupabaseClient? _client;
  MockClient? _transport;
  MotionAccountRuntime? _runtime;
  AppThemeController? theme;
  final heldUsers = <Completer<http.Response>>[];
  var holdUsers = true;
  var denyUsers = false;
  var userRequests = 0;
  var recoveryRequests = 0;
  var deletedCallbacks = 0;
  var inFlight = 0;
  var closed = false;

  SupabaseClient get client => _client!;
  MotionAccountRuntime get runtime => _runtime!;

  static Future<_AuthFixture> open(WidgetTester tester) async {
    final fixture = _AuthFixture();
    addTearDown(() => fixture.close(tester));
    await _real(tester, () async {
      fixture._transport = MockClient(fixture._respond);
      fixture._client = SupabaseClient(
        'https://motion.example.invalid',
        'public-test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: fixture._transport,
      );
      fixture._runtime = MotionAccountRuntime.forTesting(
        client: fixture.client,
        app: MotionApp.ostinato,
        onDeletedAccount: (_) async {
          fixture.deletedCallbacks++;
        },
      );
      await fixture.client.auth.setInitialSession(
        _session('synthetic-restored'),
      );
      await _until(() => fixture.heldUsers.isNotEmpty);
    });
    return fixture;
  }

  Future<http.Response> _respond(http.Request request) async {
    inFlight++;
    try {
      if (request.url.path.endsWith('/user')) {
        userRequests++;
        if (holdUsers) {
          final reply = Completer<http.Response>();
          heldUsers.add(reply);
          return await reply.future;
        }
        return denyUsers ? _blockedReply() : _userReply();
      }
      if (request.url.path.endsWith('/verify')) {
        recoveryRequests++;
        return _json(
          jsonDecode(_session('synthetic-recovery-$recoveryRequests')),
        );
      }
      throw StateError(
        'Unexpected offline fixture request: ${request.url.path}',
      );
    } finally {
      inFlight--;
    }
  }

  void releaseUsers({required bool success}) {
    holdUsers = false;
    denyUsers = !success;
    for (final reply in heldUsers) {
      if (!reply.isCompleted) {
        reply.complete(success ? _userReply() : _blockedReply());
      }
    }
  }

  Future<void> close(WidgetTester tester) async {
    if (closed) return;
    closed = true;
    try {
      // Unmount removes gate/host subscriptions and both real host observers.
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      _runtime?.dispose();
      try {
        await _real(tester, () async {
          // dispose does not cancel in-flight getUser().timeout Futures.
          releaseUsers(success: true);
          await _until(() => inFlight == 0);
          await Future<void>.delayed(Duration.zero);
          await _client?.dispose();
        });
      } finally {
        _transport?.close();
        theme?.dispose();
      }
    }
    expect(heldUsers.every((reply) => reply.isCompleted), isTrue);
    expect(inFlight, 0);
    expect(_runtime?.isDisposed, isTrue);
    expect(deletedCallbacks, 0);
  }
}

final class _StateProbe extends StatefulWidget {
  const _StateProbe({super.key, required this.runtime});
  final MotionAccountRuntime runtime;

  @override
  State<_StateProbe> createState() => _StateProbeState();
}

final class _StateProbeState extends State<_StateProbe> {
  var draft = 0;
  late final bool recoveryAtAdmission;

  @override
  void initState() {
    super.initState();
    recoveryAtAdmission = widget.runtime.isPasswordRecovery;
  }

  void changeDraft(int value) => setState(() => draft = value);

  @override
  Widget build(BuildContext context) => Text('retained draft $draft');
}

Future<void> _mount(
  WidgetTester tester,
  _AuthFixture fixture, {
  required String? languageTag,
  required AppThemePreference preference,
  required Widget child,
  _MemoryLocalePreferences? localePreferences,
}) async {
  final controller = AppThemeController(
    preferences: _MemoryThemePreferences(preference),
  );
  fixture.theme = controller;
  await _real(tester, controller.load);
  await tester.pumpWidget(
    AppThemeHost(
      controller: controller,
      disposeController: false,
      child: AppLocaleHost(
        preferences: localePreferences ?? _MemoryLocalePreferences(languageTag),
        translationBundle: _PresentationBundle(),
        child: OstinatoIdentityGate(runtime: fixture.runtime, child: child),
      ),
    ),
  );
  await _framesUntil(
    tester,
    () => find.byType(OstinatoIdentityGate).evaluate().isNotEmpty,
    stage: 'real AppLocaleHost publication',
  );
}

void _expectPresentation(
  WidgetTester tester, {
  required Locale locale,
  required Brightness brightness,
  required MotionAccountString message,
}) {
  final strings = MotionAccountLocalizations(locale);
  final text = find.text(strings.text(message));
  expect(text, findsOneWidget, reason: '$locale/$brightness/$message');
  final context = tester.element(text);
  expect(Localizations.localeOf(context), locale);
  expect(Directionality.of(context), strings.textDirection);
  expect(Theme.of(context).brightness, brightness);
  expect(
    Theme.of(context).colorScheme.primary,
    OstinatoThemes.forBrightness(brightness).colorScheme.primary,
  );
  final gate = tester.widget<MotionIdentityGate>(
    find.byType(MotionIdentityGate),
  );
  expect(gate.theme, same(OstinatoThemes.light));
  expect(gate.darkTheme, same(OstinatoThemes.dark));
  expect(gate.locale, locale);
}

void main() {
  testWidgets(
    'selected 14 locales and three cold-start modes reach loading and blocked',
    (tester) async {
      final dispatcher = tester.binding.platformDispatcher;
      addTearDown(dispatcher.clearLocalesTestValue);
      addTearDown(dispatcher.clearPlatformBrightnessTestValue);
      // One body; 14 x 3 = 42 cold starts, each observing two real gate stages.
      for (var index = 0; index < supportedLanguageTags.length; index++) {
        final tag = supportedLanguageTags[index];
        final locale = localeForLanguageTag(tag);
        for (final preference in AppThemePreference.values) {
          final platform = preference == AppThemePreference.system
              ? (index.isEven ? Brightness.light : Brightness.dark)
              : (preference == AppThemePreference.light
                    ? Brightness.dark
                    : Brightness.light);
          final expected = switch (preference) {
            AppThemePreference.system => platform,
            AppThemePreference.light => Brightness.light,
            AppThemePreference.dark => Brightness.dark,
          };
          dispatcher.localesTestValue = const [Locale('xx'), Locale('en')];
          dispatcher.platformBrightnessTestValue = platform;
          final fixture = await _AuthFixture.open(tester);
          try {
            final child = _StateProbe(runtime: fixture.runtime);
            await _mount(
              tester,
              fixture,
              languageTag: tag,
              preference: preference,
              child: child,
            );
            await _framesUntil(
              tester,
              () =>
                  find.byType(CircularProgressIndicator).evaluate().isNotEmpty,
              stage: '$tag/$preference checking',
            );
            _expectPresentation(
              tester,
              locale: locale,
              brightness: expected,
              message: MotionAccountString.checkingAccount,
            );
            expect(find.byType(_StateProbe), findsNothing);
            final gate = tester.widget<MotionIdentityGate>(
              find.byType(MotionIdentityGate),
            );
            expect(gate.runtime, same(fixture.runtime));
            expect(gate.child, same(child));
            expect(gate.themeMode, fixture.theme!.themeMode);
            await _real(tester, () async {
              fixture.releaseUsers(success: false);
              await _until(
                () =>
                    fixture.runtime.phase.value ==
                    MotionIdentityPhase.unavailable,
              );
            });
            await _framesUntil(
              tester,
              () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
              stage: '$tag/$preference blocked',
            );
            _expectPresentation(
              tester,
              locale: locale,
              brightness: expected,
              message: MotionAccountString.accountVerificationFailed,
            );
            final strings = MotionAccountLocalizations(locale);
            expect(
              find.text(strings.text(MotionAccountString.retry)),
              findsOneWidget,
            );
            expect(
              find.text(strings.text(MotionAccountString.continueAsGuest)),
              findsOneWidget,
            );
            expect(fixture.runtime.userId.value, isNull);
            expect(find.byType(_StateProbe), findsNothing);
          } finally {
            await fixture.close(tester);
          }
        }
      }
    },
  );

  testWidgets(
    'public recovery stays localized while pending and admits only matching proof',
    (tester) async {
      final fixture = await _AuthFixture.open(tester);
      try {
        final probeKey = GlobalKey<_StateProbeState>();
        final child = _StateProbe(key: probeKey, runtime: fixture.runtime);
        await _mount(
          tester,
          fixture,
          languageTag: 'ar',
          preference: AppThemePreference.dark,
          child: child,
        );
        await _real(tester, () async {
          await fixture.client.auth.verifyOTP(
            type: OtpType.recovery,
            tokenHash: 'synthetic-recovery-hash',
          );
          await _until(
            () =>
                fixture.runtime.isPasswordRecovery &&
                fixture.heldUsers.length >= 2,
          );
        });
        await _framesUntil(
          tester,
          () => find
              .text(
                MotionAccountLocalizations(
                  const Locale('ar'),
                ).text(MotionAccountString.checkingAccount),
              )
              .evaluate()
              .isNotEmpty,
          stage: 'recovery checking AR',
        );
        _expectPresentation(
          tester,
          locale: const Locale('ar'),
          brightness: Brightness.dark,
          message: MotionAccountString.checkingAccount,
        );
        expect(probeKey.currentState, isNull);
        expect(fixture.runtime.isCurrentSessionVerified, isFalse);
        expect(fixture.recoveryRequests, 1);
        await _real(tester, () async {
          fixture.releaseUsers(success: true);
          await _until(() => fixture.runtime.isCurrentSessionVerified);
        });
        await _framesUntil(
          tester,
          () => probeKey.currentState != null,
          stage: 'verified recovery admission',
        );
        expect(fixture.runtime.isPasswordRecovery, isTrue);
        expect(probeKey.currentState!.recoveryAtAdmission, isTrue);
        expect(
          Localizations.localeOf(probeKey.currentContext!),
          const Locale('ar'),
        );
        expect(Directionality.of(probeKey.currentContext!), TextDirection.rtl);
        expect(Theme.of(probeKey.currentContext!).brightness, Brightness.dark);
        // Admission only: actual OstinatoApp/AccountPage recovery form is a
        // separate acceptance surface; this probe does not simulate that form.
      } finally {
        await fixture.close(tester);
      }
    },
  );

  testWidgets(
    'authorized runtime gate and child draft survive actual host presentation changes',
    (tester) async {
      final dispatcher = tester.binding.platformDispatcher;
      addTearDown(dispatcher.clearPlatformBrightnessTestValue);
      final fixture = await _AuthFixture.open(tester);
      try {
        await _real(tester, () async {
          fixture.releaseUsers(success: true);
          await _until(() => fixture.runtime.isCurrentSessionVerified);
        });
        final probeKey = GlobalKey<_StateProbeState>();
        final child = _StateProbe(key: probeKey, runtime: fixture.runtime);
        await _mount(
          tester,
          fixture,
          languageTag: 'en',
          preference: AppThemePreference.light,
          child: child,
        );
        await _framesUntil(
          tester,
          () => probeKey.currentState != null,
          stage: 'verified child',
        );
        final state = probeKey.currentState!;
        final wrapperElement = tester.element(
          find.byType(OstinatoIdentityGate),
        );
        final gateElement = tester.element(find.byType(MotionIdentityGate));
        final session = fixture.client.auth.currentSession;
        final requests = fixture.userRequests;
        state.changeDraft(7);
        await tester.pump();
        final localeController = AppLocaleScope.maybeOf(wrapperElement)!;
        await _real(
          tester,
          () => fixture.theme!.select(AppThemePreference.dark),
        );
        await _real(tester, () => localeController.select('ar'));
        await _framesUntil(
          tester,
          () =>
              Localizations.localeOf(state.context) == const Locale('ar') &&
              Theme.of(state.context).brightness == Brightness.dark,
          stage: 'selected AR/dark',
        );
        await _real(
          tester,
          () => fixture.theme!.select(AppThemePreference.system),
        );
        for (final brightness in [Brightness.light, Brightness.dark]) {
          dispatcher.platformBrightnessTestValue = brightness;
          await _framesUntil(
            tester,
            () => Theme.of(state.context).brightness == brightness,
            stage: 'real host system brightness $brightness',
          );
          expect(probeKey.currentState, same(state));
          expect(state.draft, 7);
          expect(
            tester.element(find.byType(OstinatoIdentityGate)),
            same(wrapperElement),
          );
          expect(
            tester.element(find.byType(MotionIdentityGate)),
            same(gateElement),
          );
          final gate = tester.widget<MotionIdentityGate>(
            find.byType(MotionIdentityGate),
          );
          expect(gate.runtime, same(fixture.runtime));
          expect(gate.child, same(child));
          expect(gate.locale, const Locale('ar'));
          expect(gate.themeMode, ThemeMode.system);
        }
        expect(Directionality.of(state.context), TextDirection.rtl);
        expect(fixture.client.auth.currentSession, same(session));
        expect(fixture.runtime.isCurrentSessionVerified, isTrue);
        expect(fixture.runtime.userId.value, _userId);
        expect(
          fixture.userRequests,
          requests,
          reason: 'Presentation must not reverify identity',
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
      } finally {
        await fixture.close(tester);
      }
    },
  );

  testWidgets(
    'real AppLocaleHost observer follows unsupported then FR and AR OS preferences',
    (tester) async {
      final dispatcher = tester.binding.platformDispatcher;
      addTearDown(dispatcher.clearLocalesTestValue);
      dispatcher.localesTestValue = const [Locale('xx'), Locale('fr')];
      final fixture = await _AuthFixture.open(tester);
      try {
        final prefs = _MemoryLocalePreferences(null);
        final child = _StateProbe(runtime: fixture.runtime);
        await _mount(
          tester,
          fixture,
          languageTag: null,
          preference: AppThemePreference.light,
          localePreferences: prefs,
          child: child,
        );
        await _framesUntil(
          tester,
          () => find
              .text(
                MotionAccountLocalizations(
                  const Locale('fr'),
                ).text(MotionAccountString.checkingAccount),
              )
              .evaluate()
              .isNotEmpty,
          stage: 'OS second choice FR',
        );
        _expectPresentation(
          tester,
          locale: const Locale('fr'),
          brightness: Brightness.light,
          message: MotionAccountString.checkingAccount,
        );
        final wrapperElement = tester.element(
          find.byType(OstinatoIdentityGate),
        );
        final gateElement = tester.element(find.byType(MotionIdentityGate));
        final requests = fixture.userRequests;
        // This setter invokes onLocaleChanged and the binding's real observer
        // dispatch. Never call resolveAppLocales/didChangeLocales directly.
        dispatcher.localesTestValue = const [Locale('xx'), Locale('ar')];
        await _framesUntil(
          tester,
          () => find
              .text(
                MotionAccountLocalizations(
                  const Locale('ar'),
                ).text(MotionAccountString.checkingAccount),
              )
              .evaluate()
              .isNotEmpty,
          stage: 'OS second choice AR',
        );
        _expectPresentation(
          tester,
          locale: const Locale('ar'),
          brightness: Brightness.light,
          message: MotionAccountString.checkingAccount,
        );
        expect(
          tester.element(find.byType(OstinatoIdentityGate)),
          same(wrapperElement),
        );
        expect(
          tester.element(find.byType(MotionIdentityGate)),
          same(gateElement),
        );
        final gate = tester.widget<MotionIdentityGate>(
          find.byType(MotionIdentityGate),
        );
        expect(gate.runtime, same(fixture.runtime));
        expect(gate.child, same(child));
        expect(AppLocaleScope.maybeOf(wrapperElement)!.languageTag, isNull);
        expect(prefs.value, isNull);
        expect(prefs.writes, 0);
        expect(fixture.runtime.phase.value, MotionIdentityPhase.verifying);
        expect(fixture.userRequests, requests);
        expect(find.byType(_StateProbe), findsNothing);
      } finally {
        await fixture.close(tester);
      }
    },
  );
}
