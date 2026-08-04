import 'package:flutter/material.dart';
import 'package:ostinato_posture/ostinato_posture.dart';

import 'app/content.dart';
import 'app/cue_text.dart';
import 'app/posture_screen.dart';

/// Kabuk YALNIZ kablolama (Gravita G-100 deseni). Burada hüküm yok: eşik,
/// bant, bastırma, dürüst hâller — hepsi `packages/ostinato_posture`da ve
/// testte. Bir sayı buraya sızarsa test edilemez hâle gelir.
void main() => runApp(const OstinatoApp());

class OstinatoApp extends StatelessWidget {
  const OstinatoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Ostinato',
        theme: ThemeData(colorSchemeSeed: const Color(0xFF3B5BA5)),
        home: const _Boot(),
      );
}

class _Boot extends StatefulWidget {
  const _Boot();
  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  late final Future<(ContentRepository, CueTextResolver)> _load =
      (() async => (await ContentRepository.load(), await CueTextResolver.load()))();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(ContentRepository, CueTextResolver)>(
      future: _load,
      builder: (BuildContext ctx,
          AsyncSnapshot<(ContentRepository, CueTextResolver)> snap) {
        if (snap.hasError) {
          // Yükleme hatası GİZLENMEZ: üretilen bir varlık eksikse ekran onu
          // söyler, boş bir liste göstermez.
          return Scaffold(
              body: Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Content did not load: ${snap.error}'))));
        }
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final (ContentRepository repo, CueTextResolver cue) = snap.data!;
        return _LibraryScreen(repo: repo, cueText: cue);
      },
    );
  }
}

class _LibraryScreen extends StatelessWidget {
  const _LibraryScreen({required this.repo, required this.cueText});
  final ContentRepository repo;
  final CueTextResolver cueText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ostinato')),
      body: ListView(
        key: const Key('library-list'),
        children: <Widget>[
          for (final Discipline d in repo.disciplines)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                key: Key('discipline-${d.id}'),
                title: Text(d.displayName),
                subtitle: Text(d.blurb, maxLines: 3,
                    overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: d.status != 'live'
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PostureScreen(
                              discipline: d,
                              contract: repo.contractFor(d.id),
                              cueText: cueText,
                              // TUR-1: kaynak SAHTE ve ekranda öyle yazıyor.
                              // Gerçek kamera tur-2'de bağlanır; şimdi canlı
                              // YOLU kanıtlıyoruz, kamerayı değil.
                              source: FakePoseSource(_demoScript, stepUs: 180000),
                              sourceLabel: 'DEMO SOURCE — synthetic pose data, '
                                  'not a camera. The live path is real; the '
                                  'camera is not connected yet.',
                            ),
                          ),
                        ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sahte akış: bant içinde başla → kadraj dışına çık → belirgin eğil.
/// Adım 180 ms: her hâl gözle görülecek kadar durur (tasarım turu ve
/// ekran-kanıtı için; 33 ms'te üç hâl tek göz kırpmasına sığıyordu).
/// Üç hâlin de ekranda GÖRÜLEBİLMESİ için; sayılar sözleşmeden bağımsız
/// bir "senaryo"dur, hüküm üretmez.
const List<double?> _demoScript = <double?>[
  2.0, 2.4, 3.1, 2.8, 3.4, 2.2, 2.9, 3.3, 2.5, 3.0,
  null, null, null,
  16.0, 18.0, 19.5, 21.0, 22.0, 20.5, 19.0,
  6.0, 4.5, 3.2, 2.6,
];
