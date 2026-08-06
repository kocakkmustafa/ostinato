import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/content.dart';
import 'app/cue_text.dart';
import 'app/design/app_scope.dart';
import 'app/design/ostinato_theme.dart';
import 'app/screens/library_screen.dart';

/// Kabuk YALNIZ kablolama (Gravita G-100 deseni). Burada hüküm yok: eşik,
/// bant, bastırma, dürüst hâller — hepsi `packages/ostinato_posture`da ve
/// testte. Bir sayı buraya sızarsa test edilemez hâle gelir.
void main() => runApp(const OstinatoApp());

class OstinatoApp extends StatefulWidget {
  const OstinatoApp({super.key});

  @override
  State<OstinatoApp> createState() => _OstinatoAppState();
}

class _OstinatoAppState extends State<OstinatoApp> {
  late final Future<(ContentRepository, CueTextResolver)> _load =
      (() async => (await ContentRepository.load(), await CueTextResolver.load()))();

  static final ThemeData _theme = ThemeData(
    colorSchemeSeed: const Color(0xFF5F4CA0),
    scaffoldBackgroundColor: OstinatoColors.shell,
    textTheme: GoogleFonts.hankenGroteskTextTheme(),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(ContentRepository, CueTextResolver)>(
      future: _load,
      builder: (BuildContext ctx,
          AsyncSnapshot<(ContentRepository, CueTextResolver)> snap) {
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
        final (ContentRepository repo, CueTextResolver cue) = snap.data!;
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
            home: LibraryScreen(repo: repo, cueText: cue),
          ),
        );
      },
    );
  }
}
