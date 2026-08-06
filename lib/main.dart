import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/content.dart';
import 'app/cue_text.dart';
import 'app/design/app_scope.dart';
import 'app/design/ostinato_theme.dart';
import 'app/onboarding_store.dart';
import 'app/screens/library_screen.dart';
import 'app/screens/onboarding_screen.dart';

/// Kabuk YALNIZ kablolama (Gravita G-100 deseni). Burada hüküm yok: eşik,
/// bant, bastırma, dürüst hâller — hepsi `packages/ostinato_posture`da ve
/// testte. Bir sayı buraya sızarsa test edilemez hâle gelir.
void main() => runApp(const OstinatoApp());

class OstinatoApp extends StatefulWidget {
  /// [store] enjekte edilebilir: widget testinde `path_provider` platform
  /// kanalı yok ve "ilk açılış" ile "ikinci açılış" AYRI ölçülebilir iki
  /// durum olmalı (bkz. `onboarding_store.dart` gerekçesi).
  const OstinatoApp({super.key, this.store = const FileOnboardingStore()});

  final OnboardingStore store;

  @override
  State<OstinatoApp> createState() => _OstinatoAppState();
}

typedef _Boot = (ContentRepository, CueTextResolver, bool onboarded);

class _OstinatoAppState extends State<OstinatoApp> {
  late final Future<_Boot> _load = (() async => (
        await ContentRepository.load(),
        await CueTextResolver.load(),
        await widget.store.isComplete(),
      ))();

  static final ThemeData _theme = ThemeData(
    colorSchemeSeed: const Color(0xFF5F4CA0),
    scaffoldBackgroundColor: OstinatoColors.shell,
    textTheme: GoogleFonts.hankenGroteskTextTheme(),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Boot>(
      future: _load,
      builder: (BuildContext ctx, AsyncSnapshot<_Boot> snap) {
        if (snap.hasError) {
          // Yükleme hatası GİZLENMEZ: üretilen bir varlık eksikse ekran onu
          // söyler, boş bir liste göstermez.
          return MaterialApp(
            theme: _theme,
            home: Scaffold(
                body: Center(child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Content did not load: ${snap.error}')))),
          );
        }
        if (!snap.hasData) {
          return MaterialApp(
            theme: _theme,
            home: const Scaffold(
                body: Center(child: CircularProgressIndicator())),
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
        return ContentRepositoryScope(
          repo: repo,
          cueText: cue,
          child: MaterialApp(
            title: 'Ostinato',
            theme: _theme,
            home: OstinatoHome(
              repo: repo,
              cueText: cue,
              store: widget.store,
              alreadyOnboarded: onboarded,
            ),
          ),
        );
      },
    );
  }
}

/// Karşılama mı kütüphane mi — kabuğun TEK dallanma noktası.
///
/// **Neden `_OstinatoAppState`ten ayrıldı:** bu dalın testi, uygulamanın
/// varlık yüklemesini beklemek ZORUNDA kalmamalı. `OstinatoApp`i pump eden
/// bir test `rootBundle`ın gerçek async'ini beklemek için `runAsync`
/// açmak zorunda kalıyor, `runAsync` da `google_fonts`un `flutter_test`
/// altındaki kaçınılmaz hatasını (aile dersi #9) testi DOĞRUDAN düşüren bir
/// bölgeye taşıyor — ölçüldü: aynı hata `pump()` içinde doğduğunda
/// `takeException()`a düşüyor, `runAsync` içinde doğduğunda düşmüyor.
/// Sonuç, dallanmanın kendisiyle ilgisi olmayan gezici bir kırmızıydı.
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
