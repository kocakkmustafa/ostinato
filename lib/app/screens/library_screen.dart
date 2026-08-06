import 'package:flutter/material.dart';

import '../content.dart';
import '../cue_text.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import 'instrument_screen.dart';
import 'settings_screen.dart';

/// Kütüphane — kabuğun giriş ekranı. Üç canlı çalgı, her biri kendi gradyan
/// kimliğinde bir kart. Zemin NÖTR kalır (§13); renk yalnız kartlarda.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, required this.repo, required this.cueText});

  final ContentRepository repo;
  final CueTextResolver cueText;

  @override
  Widget build(BuildContext context) {
    final List<Discipline> live =
        repo.disciplines.where((Discipline d) => d.status == 'live').toList();
    return Scaffold(
      backgroundColor: OstinatoColors.shell,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.7, -1),
            radius: 1.2,
            colors: <Color>[Color(0x8CDACDF6), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(children: <Widget>[
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              Color(0xFFFFD9BE),
                              Color(0xFFDACDF6),
                              Color(0xFFC4EADB)
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text('Ostinato',
                          style: hankenText(
                              size: 21,
                              weight: FontWeight.w600,
                              color: OstinatoColors.ink)),
                    ]),
                    GlassIconButton(
                      icon: '⚙',
                      semanticLabel: 'Settings',
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const SettingsScreen())),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Measured, not chosen. Correct posture is a band, '
                        'not a point.',
                        style: hankenText(
                            size: 16.5,
                            weight: FontWeight.w500,
                            height: 1.35),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Put your phone where it can see you. The camera '
                        'watches how you sit; the microphone listens to '
                        'what you play.',
                        style: hankenText(
                            size: 13, color: OstinatoColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                kicker('Your instruments'),
                const SizedBox(height: 11),
                for (final Discipline d in live) ...<Widget>[
                  _InstrumentCard(discipline: d),
                  const SizedBox(height: 11),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InstrumentCard extends StatelessWidget {
  const _InstrumentCard({required this.discipline});
  final Discipline discipline;

  @override
  Widget build(BuildContext context) {
    final InstrumentHue hue = InstrumentHues.of(discipline.id);
    // Eğitmen sayısı+anlaşma derecesini göstermek için kartın kendi kapsam
    // sözcüğü — gerçek sayılar contract'tan gelir, burada yalnız etiket için
    // discipline metninden türetilen kaba bir konum çizilir (hüküm taşımaz).
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => InstrumentScreenRoute(discipline: discipline))),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: hue.gradient,
            border: Border.all(color: Colors.white.withValues(alpha: .8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(discipline.displayName,
                      style: hankenText(
                          size: 22, weight: FontWeight.w600, color: hue.ink)),
                  Icon(Icons.chevron_right, color: hue.ink.withValues(alpha: .6)),
                ],
              ),
              const SizedBox(height: 6),
              Text(discipline.blurb,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: hankenText(size: 12.5, color: hue.ink.withValues(alpha: .8))),
            ],
          ),
        ),
      ),
    );
  }
}
