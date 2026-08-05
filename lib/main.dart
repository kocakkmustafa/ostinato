import 'package:flutter/material.dart';

import 'app/camera_pose_source.dart';
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
                              // TUR-2: gerçek kamera bağlandı. Yüzey
                              // DEĞİŞMEDİ — kaynak yalnız status/frames
                              // akışlarını doldurur. Sim'de kamera donanımı
                              // yok: dürüst hâller (izin/kurulum) beklenir,
                              // "cihazda kanıtlı" iddiası YOK (M-F-263).
                              source: CameraPoseSource(),
                              sourceLabel: 'LIVE CAMERA — measuring your '
                                  'posture in real time. Video stays on '
                                  'this device and is never uploaded.',
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
