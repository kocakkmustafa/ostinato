// REPORT-ONLY CANDIDATE. Runtime/analyzer/formatter UNRUN.
// Applies only after the exact public d69 dependency graph resolves.
// This mounts Ostinato's actual production account factory, not main()/Auth init.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/account_connection.dart';
import 'package:ostinato/app/account_ownership_epoch.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/app_locale_preferences.dart';
import 'package:ostinato/app/app_theme.dart';
import 'package:ostinato/app/app_theme_preferences.dart';
import 'package:ostinato/app/app_translation_catalog.dart';
import 'package:ostinato/app/motion_account_bootstrap.dart';
import 'package:ostinato/app/ownership_guarded_account_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _id = '00000000-0000-4000-8000-000000000001';
const _token = 'synthetic-profile-test-token';
const _budget = Duration(seconds: 5);
const _paidButton = Key('consumer-closed-paid-action');

Future<T> _real<T>(WidgetTester tester, Future<T> Function() operation) async {
  Object? failure;
  StackTrace? trace;
  late T value;
  await tester.runAsync(() async {
    try {
      value = await operation().timeout(_budget);
    } catch (error, stack) {
      failure = error;
      trace = stack;
    }
  });
  if (failure != null) Error.throwWithStackTrace(failure!, trace!);
  return value;
}

Future<void> _ready(
  WidgetTester tester,
  bool Function() predicate,
  String stage,
) async {
  for (var attempt = 0; attempt < 250; attempt++) {
    await tester.pump();
    if (predicate()) return;
    await _real(
      tester,
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail('Bounded offline consumer stage not reached: $stage');
}

Future<void> _complete(
  WidgetTester tester,
  Future<void> operation,
  String stage,
) async {
  var finished = false;
  Object? failure;
  StackTrace? trace;
  unawaited(
    operation.then<void>(
      (_) {
        finished = true;
      },
      onError: (Object error, StackTrace stack) {
        failure = error;
        trace = stack;
        finished = true;
      },
    ),
  );
  await _ready(tester, () => finished, stage);
  if (failure != null) Error.throwWithStackTrace(failure!, trace!);
}

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object> _user() => {
  'id': _id,
  'aud': 'authenticated',
  'email': 'local-account@example.invalid',
  'created_at': '2026-09-24T00:00:00Z',
  'app_metadata': <String, Object>{},
};

String _session() => jsonEncode({
  'access_token': _token,
  'refresh_token': 'synthetic-refresh',
  'token_type': 'bearer',
  'expires_at': 4102444800,
  'expires_in': 3600,
  'user': _user(),
});

final class _LocalePreferences implements AppLocalePreferences {
  _LocalePreferences(this.tag);
  String? tag;
  @override
  Future<String?> read() async => tag;
  @override
  Future<void> write(String? value) async {
    tag = value;
  }
}

final class _ThemePreferences implements AppThemePreferences {
  @override
  Future<AppThemePreference> read() async => AppThemePreference.light;
  @override
  Future<void> write(AppThemePreference value) async {}
}

// Only HTTP transport is synthetic. Account/runtime and page binding are real.
final class _Fixture {
  SupabaseClient? client;
  MotionAccountRuntime? runtime;
  AccountConnection? connection;
  MockClient? transport;
  Directory? directory;
  AppThemeController? theme;
  final paidResult = ValueNotifier<bool?>(null);
  final requests = <http.Request>[];
  final profileReads = <http.Request>[];
  // Core 5832031 reads the signed-in owner's age declaration and consent on
  // the account page. The fixture answers as a declared adult (no consent
  // row), so these reads are owner-scoped GETs, never writes.
  final ageReads = <http.Request>[];
  final profileWrites = <http.Request>[];
  final unexpected = <String>[];
  final held = <Completer<http.Response>>[];
  bool holdProfile = false;
  bool profileUnavailable = false;
  bool closed = false;
  int inFlight = 0;
  int deletedCallbacks = 0;
  int clearCallbacks = 0;

  int get userReads =>
      requests.where((r) => r.url.path == '/auth/v1/user').length;
  int get membershipRequests => requests
      .where(
        (r) =>
            r.url.path.contains('membership') ||
            r.url.path.contains('purchase'),
      )
      .length;
  int get deleteRequests => requests
      .where((r) => r.url.path.contains('motion-delete-account'))
      .length;

  static Future<_Fixture> open(WidgetTester tester) async {
    final f = _Fixture();
    addTearDown(() => f.close(tester));
    await _real(tester, () async {
      f.directory = await Directory.systemTemp.createTemp(
        'ostinato-profile-ui-',
      );
      f.transport = MockClient(f.respond);
      f.client = SupabaseClient(
        'https://motion.example.invalid',
        'public-test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: f.transport,
      );
      await f.client!.auth.setInitialSession(_session());
      f.runtime = MotionAccountRuntime.forTesting(
        client: f.client!,
        app: MotionApp.ostinato,
        onDeletedAccount: (_) async {
          f.deletedCallbacks++;
        },
        localAccountIds: () async => const <String>[],
        wasAccountDeleted: (_) async => false,
      );
      await f.runtime!.refreshIdentity();
      await f.runtime!.reconcileDeletedLocalAccounts();
      await Future<void>.delayed(Duration.zero);
      f.connection = bindMotionAccountRuntime(
        f.runtime!,
        deletionCoordinator: AccountDeletionCoordinator.forRoot(f.directory!),
        clearLocalData: (_) async {
          f.clearCallbacks++;
        },
      );
      f.theme = AppThemeController(preferences: _ThemePreferences());
      await f.theme!.load();
    });
    expect(f.runtime!.isCurrentSessionVerified, isTrue);
    expect(f.connection!.userId.value, _id);
    return f;
  }

  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    inFlight++;
    try {
      final response = await _responseFor(request);
      return http.Response.bytes(
        response.bodyBytes,
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    } finally {
      inFlight--;
    }
  }

  Future<http.Response> _responseFor(http.Request request) async {
    if (request.url.host != 'motion.example.invalid') {
      unexpected.add(
        '${request.method} ${request.url.host}${request.url.path}',
      );
      throw StateError('Unexpected offline fixture origin');
    }
    if (request.method == 'GET' && request.url.path == '/auth/v1/user') {
      return _json(_user());
    }
    if (request.method == 'GET' &&
        request.url.path == '/rest/v1/motion_age_declarations') {
      ageReads.add(request);
      return _json([
        {
          'birth_year_month': '1990-01',
          'country': 'TR',
          'policy_version': '2026-10-21.1',
        },
      ]);
    }
    if (request.method == 'GET' &&
        request.url.path == '/rest/v1/motion_parental_consents') {
      ageReads.add(request);
      return _json(<Object>[]);
    }
    if (request.url.path == '/rest/v1/motion_profiles') {
      if (request.method == 'GET') {
        profileReads.add(request);
        if (holdProfile) {
          final response = Completer<http.Response>();
          held.add(response);
          return await response.future;
        }
        return profileUnavailable ? _profileFailure() : _profileReply();
      }
      if (request.method == 'POST') {
        profileWrites.add(request);
        return http.Response('', 201);
      }
    }
    unexpected.add('${request.method} ${request.url.path}');
    throw StateError('Unexpected offline fixture HTTP request');
  }

  http.Response _profileReply() => _json([
    {
      'user_id': _id,
      'display_name': 'Existing server name',
      'created_at': '2026-09-24T00:00:00Z',
      'updated_at': '2026-09-24T00:00:00Z',
    },
  ]);

  http.Response _profileFailure() => _json({
    'code': 'XX001',
    'message': 'Synthetic profile read failure',
    'details': '',
    'hint': '',
  }, status: 400);

  void failHeldReads() {
    holdProfile = false;
    profileUnavailable = true; // Stays failed until the actual Retry tap below.
    for (final response in held) {
      if (!response.isCompleted) response.complete(_profileFailure());
    }
  }

  void expectClosedBoundaries() {
    expect(membershipRequests, 0);
    expect(deleteRequests, 0);
    expect(deletedCallbacks, 0);
    expect(clearCallbacks, 0);
    expect(unexpected, isEmpty);
    for (final read in ageReads) {
      expect(read.url.queryParameters['user_id'], 'eq.$_id');
    }
  }

  Future<void> close(WidgetTester tester) async {
    if (closed) return;
    closed = true;
    try {
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      connection?.disposeBinding?.call();
      if (connection == null) runtime?.dispose();
      try {
        holdProfile = false;
        profileUnavailable = false;
        for (final response in held) {
          if (!response.isCompleted) response.complete(_profileReply());
        }
        // Profile HTTP starts in the widget zone: pump that same zone to drain it.
        await _ready(
          tester,
          () => inFlight == 0,
          'profile transport teardown drain',
        );
        await _real(tester, () async {
          await client?.dispose();
          if (directory case final dir?) {
            if (await dir.exists()) await dir.delete(recursive: true);
          }
        });
      } finally {
        transport?.close();
        theme?.dispose();
        paidResult.dispose();
      }
    }
    expect(inFlight, 0);
    expect(held.every((response) => response.isCompleted), isTrue);
    expect(runtime?.isDisposed, isTrue);
    expectClosedBoundaries();
  }
}

// Fixture Navigator supplies the same app-owned host locale/theme/delegates;
// the page itself is always the real production connection.pageBuilder output.
// This is an account consumer probe, not a full main/AudioRoot/Gate acceptance.
Future<void> _mount(WidgetTester tester, _Fixture f, String tag) async {
  await tester.pumpWidget(
    AppThemeHost(
      controller: f.theme!,
      disposeController: false,
      child: AppLocaleHost(
        preferences: _LocalePreferences(tag),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: OstinatoThemes.light,
            darkTheme: OstinatoThemes.dark,
            themeMode: AppThemeScope.modeOf(context),
            themeAnimationDuration: Duration.zero,
            locale: Localizations.localeOf(context),
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            localeListResolutionCallback: resolveAppLocales,
            home: Builder(
              builder: (context) => Column(
                children: [
                  Expanded(child: Builder(builder: f.connection!.pageBuilder)),
                  FilledButton(
                    key: _paidButton,
                    onPressed: () async {
                      f.paidResult.value =
                          await f.connection!.requirePaidAccess!(context);
                    },
                    child: const Text('TEST_CLOSED_PAID_ACTION'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await _ready(
    tester,
    () =>
        find.byType(MotionAccountPage).evaluate().isNotEmpty &&
        f.profileReads.isNotEmpty,
    'production page factory and actual profile GET',
  );
  final page = tester.widget<MotionAccountPage>(find.byType(MotionAccountPage));
  expect(page.account, isA<OwnershipGuardedAccountClient>());
  expect(page.account.app, MotionApp.ostinato);
  expect(page.account.currentUser?.id, _id);
  expect(page.paidFeaturesAvailable, isFalse);
}

Finder _name(MotionAccountLocalizations strings) => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      widget.decoration?.labelText ==
          strings.text(MotionAccountString.displayName),
);

Finder _button(
  Type type,
  MotionAccountLocalizations strings,
  MotionAccountString key,
) => find.widgetWithText(type, strings.text(key));

Future<void> _tap(WidgetTester tester, Finder button) async {
  expect(button, findsOneWidget);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Real packaged app catalogs; no synthetic empty translation bundle.
    for (final locale in appSupportedLocales) {
      await const AppTranslationsDelegate().load(locale).timeout(_budget);
    }
  });

  testWidgets(
    'production account factory retains its real page across fourteen locales with paid access closed',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = await _Fixture.open(tester);
      await _mount(tester, f, 'en');
      var strings = MotionAccountLocalizations(const Locale('en'));
      await _ready(
        tester,
        () =>
            tester.widget<TextField>(_name(strings)).controller!.text ==
            'Existing server name',
        'actual profile payload published',
      );
      final page = find.byType(MotionAccountPage);
      final pageState = tester.state(page);
      final pageKey = tester.widget<MotionAccountPage>(page).key;
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      final controller = tester.widget<TextField>(_name(strings)).controller!;
      final localeController = AppLocaleScope.maybeOf(tester.element(page))!;
      final profileReadCount = f.profileReads.length;
      final authReadCount = f.userReads;
      await tester.enterText(_name(strings), 'Retained موسيقى draft');
      expect(appSupportedLocales, MotionAccountLocalizations.supportedLocales);
      expect(appSupportedLocales, hasLength(14));

      for (final locale in appSupportedLocales) {
        final tag = canonicalLanguageTag(locale);
        await _complete(
          tester,
          localeController.select(tag),
          'preference write $tag',
        );
        await _ready(
          tester,
          () =>
              canonicalLanguageTag(
                Localizations.localeOf(tester.element(page)),
              ) ==
              tag,
          'published actual account locale $tag',
        );
        await tester.pump(const Duration(milliseconds: 250));
        strings = MotionAccountLocalizations(locale);
        expect(tester.state(page), same(pageState), reason: tag);
        expect(
          tester.widget<MotionAccountPage>(page).key,
          pageKey,
          reason: tag,
        );
        expect(
          tester.state<NavigatorState>(find.byType(Navigator)),
          same(navigator),
        );
        expect(
          tester.widget<TextField>(_name(strings)).controller,
          same(controller),
        );
        expect(controller.text, 'Retained موسيقى draft', reason: tag);
        expect(
          find.text(strings.text(MotionAccountString.accountTitle)),
          findsOneWidget,
        );
        expect(Directionality.of(tester.element(page)), strings.textDirection);
        expect(Theme.of(tester.element(page)).brightness, Brightness.light);
        expect(
          _button(FilledButton, strings, MotionAccountString.membershipOptions),
          findsNothing,
        );
        expect(find.byType(MotionMembershipPage), findsNothing);

        f.paidResult.value = null;
        await _tap(tester, find.byKey(_paidButton));
        await _ready(
          tester,
          () => f.paidResult.value != null,
          'closed paid callback $tag',
        );
        expect(f.paidResult.value, isFalse);
        expect(
          find.text(strings.text(MotionAccountString.futureSession)),
          findsOneWidget,
        );
        ScaffoldMessenger.of(tester.element(page)).removeCurrentSnackBar();
        await tester.pump();

        await _tap(
          tester,
          _button(TextButton, strings, MotionAccountString.deleteMotionAccount),
        );
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.text(strings.text(MotionAccountString.deleteExplanation)),
          findsOneWidget,
        );
        expect(
          Directionality.of(tester.element(find.byType(AlertDialog))),
          strings.textDirection,
        );
        await _tap(
          tester,
          _button(TextButton, strings, MotionAccountString.cancel),
        );
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.state(page), same(pageState));
        expect(f.profileReads, hasLength(profileReadCount));
        expect(f.profileWrites, isEmpty);
        expect(f.userReads, authReadCount);
        f.expectClosedBoundaries();
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'production profile read failure cannot save an untouched blank and actual retry writes only intentional owner data',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = await _Fixture.open(tester);
      f.holdProfile = true;
      await _mount(tester, f, 'fr');
      final strings = MotionAccountLocalizations(const Locale('fr'));
      final save = _button(
        FilledButton,
        strings,
        MotionAccountString.saveProfile,
      );
      expect(f.held, isNotEmpty);
      expect(
        find.text(strings.text(MotionAccountString.profileLoading)),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(_name(strings)).controller!.text,
        isEmpty,
      );
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await _tap(tester, save);
      expect(f.profileWrites, isEmpty);

      f.failHeldReads();
      await _ready(
        tester,
        () => find
            .text(strings.text(MotionAccountString.profileReadFailed))
            .evaluate()
            .isNotEmpty,
        'actual failed profile GET renders safe retry',
      );
      expect(
        tester.widget<TextField>(_name(strings)).controller!.text,
        isEmpty,
      );
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await _tap(tester, save);
      expect(f.profileWrites, isEmpty);
      final readsBeforeRetry = f.profileReads.length;
      final authBeforeRetry = f.userReads;
      f.profileUnavailable = false;
      await _tap(
        tester,
        _button(TextButton, strings, MotionAccountString.retryProfile),
      );
      await _ready(
        tester,
        () =>
            tester.widget<TextField>(_name(strings)).controller!.text ==
            'Existing server name',
        'actual Retry profile GET returns the original server name',
      );
      expect(f.profileReads.length, greaterThan(readsBeforeRetry));
      expect(
        f.userReads,
        authBeforeRetry,
      ); // Retry profile is not Refresh identity.
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      expect(f.profileWrites, isEmpty);
      for (final request in f.profileReads) {
        expect(request.url.queryParameters['user_id'], 'eq.$_id');
        expect(
          request.url.queryParameters['select'],
          'user_id,display_name,created_at,updated_at',
        );
        expect(request.headers['Authorization'], 'Bearer $_token');
      }
      await tester.enterText(_name(strings), '  Intentional Ostinato draft  ');
      await _tap(tester, save);
      await _ready(
        tester,
        () => find
            .text(strings.text(MotionAccountString.profileSaved))
            .evaluate()
            .isNotEmpty,
        'actual profile POST success is published',
      );
      expect(f.profileWrites, hasLength(1));
      final request = f.profileWrites.single;
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      expect(payload.keys.toSet(), {'user_id', 'display_name', 'updated_at'});
      expect(payload['user_id'], _id);
      expect(payload['display_name'], 'Intentional Ostinato draft');
      expect(DateTime.parse(payload['updated_at'] as String).isUtc, isTrue);
      expect(request.headers['Authorization'], 'Bearer $_token');
      expect(f.connection!.userId.value, _id);
      expect(f.runtime!.isCurrentSessionVerified, isTrue);
      f.expectClosedBoundaries();
      expect(tester.takeException(), isNull);
    },
  );
}
