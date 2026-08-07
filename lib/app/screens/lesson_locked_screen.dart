import 'package:flutter/material.dart';

import '../content.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';

/// Kilitli ders — sebep EKSİK ÖLÇÜMÜN ADIYLA, eşik değeriyle DEĞİL (§4/⑦).
/// `lockedReason` AYNEN gösterilir — yumuşatılmaz, kısaltılmaz.
class LessonLockedScreenRoute extends StatelessWidget {
  const LessonLockedScreenRoute(
      {super.key, required this.discipline, required this.lesson, required this.hue});
  final Discipline discipline;
  final Lesson lesson;
  final InstrumentHue hue;

  @override
  Widget build(BuildContext context) {
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
                    color: const Color(0x122A2533),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('LOCKED',
                    key: const Key('state-lesson-locked'),
                    style: monoText(color: const Color(0xFF6E6880))),
              ),
              const SizedBox(height: 13),
              Text(lesson.displayName,
                  style: hankenText(
                      size: 27, weight: FontWeight.w600, height: 1.15)),
              const SizedBox(height: 11),
              Text('${lesson.minutes} MIN'
                  '${lesson.focus.isEmpty ? '' : ' · ${lesson.focus.toUpperCase()}'} '
                  '· ${discipline.displayName.toUpperCase()}',
                  style: monoText()),
              const SizedBox(height: 20),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    kicker('Why it is locked'),
                    const SizedBox(height: 12),
                    Text(lesson.lockedReason ?? '',
                        key: const Key('locked-reason'),
                        style: hankenText(size: 16.5, height: 1.62)),
                  ],
                ),
              ),
              // BOŞ ETİKETLİ KART ÇİZİLMEZ (O-046, ekran kanıtı).
              // Ölçüldü: 10 kilitli dersin 10'unda da `promotionPath` YOKTU,
              // yani bu kart "WHAT WOULD OPEN IT" başlığıyla BOŞ bir gövde
              // çiziyordu — canlı bir boş kabuk, üstelik ürünün en içerikli
              // ekran sınıfında. Hiçbir test göremezdi: taşma yok, istisna
              // yok, metin "var" (boş string de bir string). Yalnız BAKINCA
              // görüldü. İçerik on derse de yazıldı; bu koruma ise
              // gerekçesiz bir kartın bir daha ÇİZİLEMEYECEĞİNİ garanti
              // ediyor — düzeltmek değil, imkânsız kılmak (aile dersi #7).
              if ((lesson.unblockedBy ?? '').trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: hue.softGradient,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: .75)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      kicker('What would open it', color: hue.ink),
                      const SizedBox(height: 9),
                      Text(lesson.unblockedBy!,
                          key: const Key('locked-what-would-open-it'),
                          style: hankenText(size: 14.5, height: 1.55)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'There is nothing to try here and no way to unlock it from '
                'your side. It opens when the measurement is confirmed, '
                'and you will see it change.',
                style: hankenText(size: 12.5, color: OstinatoColors.textFaint),
              ),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: Color(0x282A2533)),
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                ),
                child: Text('Back to ${discipline.courses.first.displayName}',
                    style: hankenText(size: 15, weight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
