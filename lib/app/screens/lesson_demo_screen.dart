import 'package:flutter/material.dart';

import '../content.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';

/// ⭐ Üçüncü görsel sınıf — "ölçülür ama puanlanmaz" (§4/⑧). "Bilgi" tonu,
/// "hata" tonu DEĞİL: aynı camsı kart dili, aynı bütünlük.
///
/// 📌 İSİMLİ SEÇİM (koordinatör hükmü, 2026-08-06): tasarımın iki paralel
/// "Explorations" çatalından (`demoTreatment` A/B) **Treatment A seçildi**
/// — rozet-başlık + TEK renkli kart + 3-bölümlü beyaz kart (WHY NO MARK /
/// WHAT WOULD CHANGE IT / IF IT NEVER DOES), Treatment B'nin "iki eşit kart"
/// simetrisi DENENMEDİ. Tek sadakatsizlik: A'nın 52px canlı-sayı öğesi
/// burada yok — bkz. aşağıdaki İSİMLİ SINIR.
///
/// ⚠️ İSİMLİ SINIR (giydirme turu, 2026-08-05): tasarımın canlı kol/önkol
/// açısı okuması (`armLive`) burada YOK. `CameraPostureAdapter` bugün yalnız
/// `trunk_tilt` hesaplıyor — dirsek açısı için motion_core'da
/// `StandardJoints.leftElbow/rightElbow` hazır ama Ostinato'nun canlı
/// zincirine hiç bağlanmadı. Sahte bir sayı GÖSTERMEK yerine bu ekran
/// gerçek statik dürüstlük metnini (demoOnlyReason + promotionPath) taşır
/// ve canlı ölçümün henüz yazılmadığını AÇIKÇA söyler — taklit etmez.
class LessonDemoScreenRoute extends StatelessWidget {
  const LessonDemoScreenRoute(
      {super.key, required this.discipline, required this.lesson, required this.hue});
  final Discipline discipline;
  final Lesson lesson;
  final InstrumentHue hue;

  @override
  Widget build(BuildContext context) {
    final ArmRangeHint? arm = ArmRangeHints.byDiscipline[discipline.id];
    return Scaffold(
      backgroundColor: OstinatoColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              GlassIconButton(
                  icon: '‹',
                  semanticLabel: 'Back',
                  onTap: () => Navigator.of(context).pop()),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: hue.chip, borderRadius: BorderRadius.circular(8)),
                child: Text('MEASURED · NOT MARKED',
                    key: const Key('state-lesson-demo'),
                    style: monoText(color: hue.ink)),
              ),
              const SizedBox(height: 13),
              Text(lesson.displayName,
                  style: hankenText(
                      size: 27, weight: FontWeight.w600, height: 1.15)),
              const SizedBox(height: 11),
              Text('${lesson.minutes} MIN · ${discipline.displayName.toUpperCase()}',
                  style: monoText()),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: hue.gradient,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withValues(alpha: .85)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    kicker('Your elbow angle, when this is live', color: hue.ink),
                    const SizedBox(height: 14),
                    if (arm != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            height: 34,
                            child: HorizontalBandTrack(
                              lowDeg: arm.lowDeg,
                              highDeg: arm.highDeg,
                              maxDeg: 120,
                              youDeg: (arm.lowDeg + arm.highDeg) / 2,
                              color: hue.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text('0°', style: monoText(size: 9)),
                              Text(
                                  '${arm.lowDeg.toStringAsFixed(0)}–'
                                  '${arm.highDeg.toStringAsFixed(0)}°',
                                  style: monoText(size: 9)),
                              Text('120°', style: monoText(size: 9)),
                            ],
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    Text(lesson.demoOnlyReason ?? '',
                        key: const Key('demo-reason'),
                        style: hankenText(size: 15, height: 1.6)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    kicker('Why there is no mark'),
                    const SizedBox(height: 8),
                    Text(lesson.blockedBy ?? '',
                        style: hankenText(size: 13.5, height: 1.55)),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    kicker('What would change it'),
                    const SizedBox(height: 8),
                    Text(lesson.unblockedBy ?? '',
                        style: hankenText(size: 13.5, height: 1.55)),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    kicker('If it never does'),
                    const SizedBox(height: 8),
                    Text(lesson.ifBlockedStaysBlocked ?? '',
                        style: hankenText(size: 13.5, height: 1.55)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0x0D2A2533),
                  borderRadius: BorderRadius.circular(16),
                ),
                // PLACEHOLDER(data): bu kart canlı dirsek/önkol açısı
                // GÖSTERMEZ, yalnız statik ArmRangeHint (öğretmen aralığı)
                // gösterir — unblocked by: motion_core'daki
                // StandardJoints.leftElbow/rightElbow CameraPostureAdapter'a
                // bağlanıp gerçek zamanlı bir açı üretilince (aynı sınır:
                // widgets.dart içindeki SkeletonFigurePainter dirsek/bilek
                // noktaları).
                  // closedPaths: none-known
                  // user-surface: demo-live-gap-note
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.info_outline,
                        size: 18, color: OstinatoColors.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      // DÜZELTME (koordinatör, 2026-08-06, M-F-186): "yet"
                      // çıkarıldı — bir zaman taahhüdüydü. Kalan cümle
                      // bugünün OLGUSUNU söylüyor, gelecek vaat etmiyor.
                      child: Text(
                        'Elbow tracking is not wired into this build — '
                        'only trunk posture measures live today. The text '
                        'above is real; the live number is not, so we are '
                        'not showing one.',
                        key: const Key('demo-live-gap-note'),
                        style: hankenText(
                            size: 12.5, color: OstinatoColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
