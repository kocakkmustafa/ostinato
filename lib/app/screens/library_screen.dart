import 'package:flutter/material.dart';
import 'package:ostinato_posture/ostinato_posture.dart';

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
                      // DÜZELTME (2026-08-07): önceki cümle "the microphone
                      // listens to what you play" diyordu. Bu build'de
                      // mikrofon GİRİŞİ YOK — `Info.plist`te
                      // `NSMicrophoneUsageDescription`, manifest'te
                      // `RECORD_AUDIO` yok, hiçbir kod yolu ses yakalamıyor.
                      // Kurulum Kontrolü bunu zaten doğru söylüyordu
                      // (`setup-room-gap-body`); giriş ekranı onu
                      // yalanlıyordu. Ürünün TEK CÜMLESİ (UI-BRIEF §0)
                      // mikrofonu içeriyor — o ÜRÜNÜN cümlesi; bu ekran
                      // BU BUILD'i anlatır.
                      Text(
                        'Put your phone where it can see you. The camera '
                        'reads nine upper-body points while you practise. '
                        'There is no live microphone input in this build — '
                        'the chord and note work described in the lessons '
                        'was measured on recordings, not in your room.',
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
                  _InstrumentCard(
                      discipline: d, contract: repo.contractOrNull(d.id)),
                  const SizedBox(height: 11),
                ],
                // 0-24° PAYLAŞILAN ölçek açıklaması (DESIGN-AHEAD §1.3).
                // Tasarımın taslak cümlesi piyanonun dar bandını "üç
                // eğitmen en ince kanıt" diye AÇIKLIYORDU — o cümle
                // yazılmadı: bant genişliği ölçülen ARALIKTAN gelir, kaynak
                // SAYISINDAN değil, ve ikisini nedensel bağlamak
                // ölçmediğimiz bir ilişkiyi iddia etmek olurdu. Sayılar
                // yan yana duruyor; bağı kuran cümle KURULMADI.
                const SizedBox(height: 6),
                Text(
                  'The bar on each card is the range those teachers actually '
                  'occupy, drawn on one shared 0–24° scale so the three can '
                  'be compared. It is a range, not a target: no point inside '
                  'it is more correct than another.',
                  key: const Key('library-band-scale-note'),
                  style: hankenText(
                      size: 12, height: 1.5, color: OstinatoColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// PAYLAŞILAN ölçeğin üst ucu (DESIGN-AHEAD §1.3). Bir EŞİK DEĞİL, bir
/// ÇİZİM ölçeği: hiçbir hüküm bu sayıdan türemiyor, yalnız üç çalgının
/// bandı AYNI eksende karşılaştırılabilsin diye sabit. Tasarımın verdiği
/// 24° korundu; bugünkü en geniş bant 6.4° ve gözlem eşiği 14° — ikisi de
/// ölçeğin içinde kalıyor, yani ölçek ölçümü kırpmıyor.
const double _sharedScaleMaxDeg = 24;

class _InstrumentCard extends StatelessWidget {
  const _InstrumentCard({required this.discipline, required this.contract});
  final Discipline discipline;

  /// Sözleşme YOKSA çubuk ÇİZİLMEZ. Boş bir ölçek çubuğu "bandı yok" değil
  /// "bandı sıfır" diye okunur — yokluğu yanlış anlatan bir görsel,
  /// yokluğu hiç göstermemekten kötüdür.
  final PostureContract? contract;

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
                  // Bugün "Guitar/Voice/Piano" (kısa) ama sabit genişlikli
                  // chevron'un yanında Expanded olmadan aynı taşma sınıfı
                  // bekliyor (bkz. live_screen.dart başlık düzeltmesi).
                  Expanded(
                    child: Text(discipline.displayName,
                        style: hankenText(
                            size: 22, weight: FontWeight.w600, color: hue.ink)),
                  ),
                  Icon(Icons.chevron_right, color: hue.ink.withValues(alpha: .6)),
                ],
              ),
              const SizedBox(height: 6),
              if (contract != null) ...<Widget>[
                const SizedBox(height: 10),
                HorizontalBandTrack(
                  key: Key('band-scale-${discipline.id}'),
                  lowDeg: contract!.bandLowDeg,
                  highDeg: contract!.bandHighDeg,
                  maxDeg: _sharedScaleMaxDeg,
                  color: hue.ink,
                  height: 8,
                ),
                const SizedBox(height: 6),
                Text(
                  '${contract!.teacherCount} ${contract!.sourceClass} · '
                  '${contract!.bandLowDeg.toStringAsFixed(1)}–'
                  '${contract!.bandHighDeg.toStringAsFixed(1)}° of '
                  '${_sharedScaleMaxDeg.toStringAsFixed(0)}°',
                  style: monoText(size: 8.5, color: hue.ink.withValues(alpha: .85)),
                ),
                const SizedBox(height: 10),
              ] else
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
