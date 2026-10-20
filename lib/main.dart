import 'package:flutter/material.dart';
import 'package:motion_account/motion_account.dart';
import 'package:motion_content/motion_content.dart';

import 'app/content.dart';
import 'app/cue_text.dart';
import 'app/app_locale.dart';
import 'app/app_locale_preferences.dart';
import 'app/account_connection.dart';
import 'app/camera_session.dart';
import 'app/audio/practice_audio_root.dart';
import 'app/design/app_scope.dart';
import 'app/app_theme.dart';
import 'app/app_theme_preferences.dart';
import 'app/guitar_journey.dart';
import 'app/onboarding_store.dart';
import 'app/motion_account_bootstrap.dart';
import 'app/screens/library_screen.dart';
import 'app/screens/onboarding_screen.dart';

/// Kabuk YALNIZ kablolama (Gravita G-100 deseni). Burada hüküm yok: eşik,
/// bant, bastırma, dürüst hâller — hepsi `packages/ostinato_posture`da ve
/// testte. Bir sayı buraya sızarsa test edilemez hâle gelir.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final theme = AppThemeController();
  final themeReady = theme.load();
  try {
    final (runtime, accountConnection) = await initializeMotionAccount();
    bindCameraResourceAdmission(accountConnection.resourceAdmission);
    await themeReady;
    runApp(AppThemeHost(
      controller: theme,
      child: AppLocaleHost(
        child: OstinatoAudioRoot(
          userId: runtime.userId,
          phase: runtime.phase,
          passwordRecovery: accountConnection.passwordRecovery,
          identityBoundary: accountConnection.identityBoundary,
          resourceAdmission: accountConnection.resourceAdmission,
          disposeAccountBinding: accountConnection.disposeBinding,
          builder: (audioNavigatorHost) => MotionIdentityGate(
            runtime: runtime,
            child: OstinatoApp(
              accountConnection: accountConnection,
              audioNavigatorHost: audioNavigatorHost,
            ),
          ),
        ),
      ),
    ));
  } on Object {
    await themeReady;
    runApp(AppThemeHost(controller: theme,
      child: const AppLocaleHost(child: AccountStartupFailure())));
  }
}

class OstinatoApp extends StatefulWidget {
  /// [store] enjekte edilebilir: widget testinde `path_provider` platform
  /// kanalı yok ve "ilk açılış" ile "ikinci açılış" AYRI ölçülebilir iki
  /// durum olmalı (bkz. `onboarding_store.dart` gerekçesi).
  const OstinatoApp({
    super.key,
    this.store = const FileOnboardingStore(),
    this.accountConnection,
    this.guitarCourseBundle,
    PracticeAudioNavigatorHost? audioNavigatorHost,
  }) : _audioNavigatorHost = audioNavigatorHost;

  final OnboardingStore store;
  final AccountConnection? accountConnection;

  /// Allows the packaged guitar-course gate to be probed without mutating
  /// Flutter's global rootBundle. Production uses the bundled asset bytes.
  final AssetBundle? guitarCourseBundle;
  // Route widgets cannot read the root authority through an inherited scope.
  final PracticeAudioNavigatorHost? _audioNavigatorHost;

  @override
  State<OstinatoApp> createState() => _OstinatoAppState();
}

typedef _Boot = (ContentRepository, CueTextResolver, bool onboarded);

class _OstinatoAppState extends State<OstinatoApp> {
  late ({String? userId, bool recovery}) _accountNavigationState;
  int _navigationEpoch = 0;

  @override
  void initState() {
    super.initState();
    _observeAccount();
  }

  void _observeAccount() {
    final account = widget.accountConnection;
    bindCameraResourceAdmission(account?.resourceAdmission);
    _accountNavigationState = (
      userId: account?.userId.value,
      recovery: account?.passwordRecovery?.value ?? false,
    );
    account?.userId.addListener(_onAccountBoundaryChanged);
    account?.passwordRecovery?.addListener(_onAccountBoundaryChanged);
    account?.identityBoundary?.addListener(_onIdentityBoundaryChanged);
    if (!identical(account?.identityBoundary, account?.resourceAdmission)) {
      account?.resourceAdmission?.addListener(_onIdentityBoundaryChanged);
    }
  }

  void _stopObservingAccount(AccountConnection? account) {
    account?.userId.removeListener(_onAccountBoundaryChanged);
    account?.passwordRecovery?.removeListener(_onAccountBoundaryChanged);
    account?.identityBoundary?.removeListener(_onIdentityBoundaryChanged);
    if (!identical(account?.identityBoundary, account?.resourceAdmission)) {
      account?.resourceAdmission?.removeListener(_onIdentityBoundaryChanged);
    }
  }

  void _onIdentityBoundaryChanged() {
    retireAllCameraOwners();
    setState(() => ++_navigationEpoch);
  }

  void _onAccountBoundaryChanged() {
    final account = widget.accountConnection;
    final next = (
      userId: account?.userId.value,
      recovery: account?.passwordRecovery?.value ?? false,
    );
    if (next == _accountNavigationState) return;
    retireAllCameraOwners();
    // Preserve every boundary event, including A → null → A or recovery
    // enter/exit before a frame. A final-value key alone misses those events.
    setState(() {
      _accountNavigationState = next;
      ++_navigationEpoch;
    });
  }

  @override
  void didUpdateWidget(OstinatoApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.accountConnection, widget.accountConnection)) {
      final oldState = _accountNavigationState;
      final boundaryChanged =
          !identical(
            oldWidget.accountConnection?.userId,
            widget.accountConnection?.userId,
          ) ||
          !identical(
            oldWidget.accountConnection?.passwordRecovery,
            widget.accountConnection?.passwordRecovery,
          ) ||
          !identical(
            oldWidget.accountConnection?.identityBoundary,
            widget.accountConnection?.identityBoundary,
          ) ||
          !identical(
            oldWidget.accountConnection?.resourceAdmission,
            widget.accountConnection?.resourceAdmission,
          );
      _stopObservingAccount(oldWidget.accountConnection);
      _observeAccount();
      if (boundaryChanged || oldState != _accountNavigationState) {
        retireAllCameraOwners();
        ++_navigationEpoch;
      }
    }
  }

  @override
  void dispose() {
    retireAllCameraOwners();
    _stopObservingAccount(widget.accountConnection);
    super.dispose();
  }

  late final Future<_Boot> _load = (() async {
    await GuitarJourneyCourse.load(bundle: widget.guitarCourseBundle);
    return (
      await ContentRepository.load(),
      await CueTextResolver.load(),
      await widget.store.isComplete(),
    );
  })();


  @override
  Widget build(BuildContext context) {
    // Tests which embed the shell without the app preference host retain
    // MaterialApp's device-locale behavior. Locale changes never own a key.
    final locale = AppLocaleScope.maybeOf(context) == null
        ? null
        : Localizations.localeOf(context);
    return FutureBuilder<_Boot>(
      future: _load,
      builder: (BuildContext ctx, AsyncSnapshot<_Boot> snap) {
        if (snap.hasError) {
          // The library stays closed. Show a useful localized message and a
          // stable support code without exposing raw parser/asset diagnostics.
          final Object? error = snap.error;
          final String supportCode = error is ContentException
              ? 'CONTENT_${error.error.code.name.toUpperCase()}'
              : 'CONTENT_LOAD';
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: OstinatoThemes.light,
            darkTheme: OstinatoThemes.dark,
            themeMode: AppThemeScope.modeOf(context),
            themeAnimationDuration: Duration.zero,
            locale: locale,
            localeListResolutionCallback: resolveAppLocales,
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            home: Builder(
              builder: (errorContext) => Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          localized(
                            errorContext,
                            'Course content could not be loaded. Close and reopen the app. If the problem continues, contact support with the code below.',
                            'Kurs içeriği yüklenemedi. Uygulamayı kapatıp yeniden aç. Sorun sürerse aşağıdaki kodla destek ekibine ulaş.',
                          ),
                          key: const Key('ostinato-content-load-failure'),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          localized(errorContext, "Support code: {v0}", "Destek kodu: {v0}", values: {"v0": supportCode}),
                          key: const Key('ostinato-content-support-code'),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: OstinatoThemes.light,
            darkTheme: OstinatoThemes.dark,
            themeMode: AppThemeScope.modeOf(context),
            themeAnimationDuration: Duration.zero,
            locale: locale,
            localeListResolutionCallback: resolveAppLocales,
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final (ContentRepository repo, CueTextResolver cue, bool onboarded) =
            snap.data!;
        // ContentRepositoryScope MaterialApp'in DIŞINDA: Navigator'ın
        // Overlay'i MaterialApp içinde kurulur, push edilen HER route yeni
        // bir OverlayEntry olarak KARDEŞ eklenir (home'un ALTINA değil).
        // Scope MaterialApp.home'u sarsaydı, push edilen hiçbir ekran onu
        // GÖREMEZDİ — route_path_test.dart bunu ölçtü, main.dart'ta AYNI
        // hata olurdu (LibraryScreen'den herhangi bir dokunuş çökerdi).
        final AccountConnection? account = widget.accountConnection;
        Widget accountApp(String? userId) {
          Widget materialApp(NavigatorObserver? observer) => MaterialApp(
            key: ValueKey<String>('ostinato-account-${userId ?? 'signed-out'}'),
            title: 'Ostinato',
            debugShowCheckedModeBanner: false,
            theme: OstinatoThemes.light,
            darkTheme: OstinatoThemes.dark,
            themeMode: AppThemeScope.modeOf(context),
            themeAnimationDuration: Duration.zero,
            locale: locale,
            localeListResolutionCallback: resolveAppLocales,
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            navigatorObservers: observer == null
                ? const <NavigatorObserver>[]
                : <NavigatorObserver>[observer],
            home: _accountNavigationState.recovery && account != null
                ? Builder(builder: account.pageBuilder)
                : OstinatoHome(
                    repo: repo,
                    cueText: cue,
                    store: widget.store,
                    alreadyOnboarded: onboarded,
                  ),
          );
          final navigator = widget._audioNavigatorHost == null
              ? materialApp(null)
              : widget._audioNavigatorHost!.wrap(
                  key: ValueKey<String>(
                    'ostinato-audio-navigator-${userId ?? 'signed-out'}',
                  ),
                  builder: materialApp,
                );
          return ContentRepositoryScope(
            repo: repo,
            cueText: cue,
            child: AccountScope(
              connection: account,
              currentUserId: userId,
              child: KeyedSubtree(
                key: ValueKey<int>(_navigationEpoch),
                child: navigator,
              ),
            ),
          );
        }

        return accountApp(_accountNavigationState.userId);
      },
    );
  }
}

/// Karşılama mı kütüphane mi — kabuğun TEK dallanma noktası.
///
/// **Neden `_OstinatoAppState`ten ayrıldı:** bu dalın testi, uygulamanın
/// varlık yüklemesini beklemek ZORUNDA kalmamalı. `OstinatoApp`i pump eden
/// bir test `rootBundle`ın gerçek async'ini beklemek için `runAsync`
/// açmak zorunda kalıyor. **D1 NOTU (2026-08-16):** eski gerekçenin bir
/// yarısı (`runAsync`ın `google_fonts`un `flutter_test` altındaki
/// kaçınılmaz hatasını testi düşüren bir bölgeye taşıması) fontlar
/// paketlenince ORTADAN KALKTI — ama `rootBundle` async'i hâlâ gerçek,
/// ayrım o yüzden BOZULMADI.
///
/// Bu ayrım o kırmızıyı düzeltmiyor, İMKÂNSIZ kılıyor (aile dersi #7):
/// dallanma artık yüklenmiş bağımlılıkları alan saf bir widget, ve bu kod
/// tabanının geri kalanıyla AYNI şekilde — hazır `repo` ile pump edilerek —
/// sınanıyor.
class OstinatoHome extends StatefulWidget {
  const OstinatoHome({
    super.key,
    required this.repo,
    required this.cueText,
    required this.store,
    required this.alreadyOnboarded,
  });

  final ContentRepository repo;
  final CueTextResolver cueText;
  final OnboardingStore store;
  final bool alreadyOnboarded;

  @override
  State<OstinatoHome> createState() => _OstinatoHomeState();
}

class _OstinatoHomeState extends State<OstinatoHome> {
  /// Karşılama bitince kurulan bayrak. Depodan okunan değeri EZER — depo
  /// yazamamış olabilir (`markComplete` sessizce başarısız olabiliyor,
  /// bilerek), ve o durumda bile kullanıcı bu oturumda karşılamayı iki kez
  /// görmemeli.
  bool _finishedThisSession = false;

  @override
  Widget build(BuildContext context) {
    // Karşılama `home` İÇİNDE değiştirilir, push edilmez: geri yığınında
    // bırakılan bir onboarding'e kullanıcı geri düğmesiyle DÖNEBİLİR, ve
    // bitirdiği bir akışa dönmek "bitmedi mi?" der.
    if (widget.alreadyOnboarded || _finishedThisSession) {
      return LibraryScreen(repo: widget.repo, cueText: widget.cueText);
    }
    return OnboardingScreen(
      repo: widget.repo,
      store: widget.store,
      onFinished: () => setState(() => _finishedThisSession = true),
    );
  }
}
