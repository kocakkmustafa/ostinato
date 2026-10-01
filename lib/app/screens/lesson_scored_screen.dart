import 'package:flutter/material.dart';
import 'package:ostinato_posture/ostinato_posture.dart';

import '../content.dart';
import '../account_connection.dart';
import '../app_locale.dart';
import '../design/app_scope.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import 'setup_check_screen.dart';

/// Skorlu/guide ders — ölçüm oturumundan ÖNCEKİ bilgi ekranı. Guide sınıfı
/// (`focus == 'setup'`) ölçüm iddiası TAŞIMAZ; bant kartı yalnız skorlu
/// derslerde gösterilir.
class LessonScoredScreenRoute extends StatelessWidget {
  const LessonScoredScreenRoute({
    super.key,
    required this.discipline,
    required this.lesson,
    required this.hue,
  });
  final Discipline discipline;
  final Lesson lesson;
  final InstrumentHue hue;

  @override
  Widget build(BuildContext context) {
    final PostureContract? contract = ContentRepositoryScope.of(
      context,
    ).contractOrNull(discipline.id);
    final bool isGuide = lesson.kind == LessonKind.guide;

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
                semanticLabel: localized(context, 'Back', 'Geri'),
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 22),
              Text(
                catalogName(context, lesson.id, lesson.displayName),
                key: const Key('state-lesson-scored'),
                style: hankenText(
                  size: 27,
                  weight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 11),
              Text(
                '${lesson.minutes} ${localized(context, 'MIN', 'DK')}'
                '${lesson.focus.isEmpty ? '' : ' · ${catalogTag(context, lesson.focus)}'} '
                '· ${catalogUpperName(context, discipline.id, discipline.displayName)}',
                style: monoText(),
              ),
              const SizedBox(height: 20),
              if (!isGuide && contract != null) ...<Widget>[
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      kicker(
                        localized(
                          context,
                          'What you’re measured against',
                          'Ölçümün dayandığı aralık',
                        ),
                        color: hue.ink,
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: SizedBox(
                          width: 200,
                          height: 200,
                          child: CustomPaint(
                            painter: SkeletonFigurePainter(
                              bandLowDeg: contract.bandLowDeg,
                              bandHighDeg: contract.bandHighDeg,
                              bandColor: hue.band,
                              markerDeg: contract.cueThresholdDeg,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        localized(
                          context,
                          '${contract.teacherCount} ${contract.sourceClass} sit '
                              'between ${contract.bandLowDeg.toStringAsFixed(1)}° and '
                              '${contract.bandHighDeg.toStringAsFixed(1)}° of trunk '
                              'tilt — a band '
                              '${(contract.bandHighDeg - contract.bandLowDeg).toStringAsFixed(1)}° '
                              'wide. The dashed line marks '
                              '${contract.cueThresholdDeg.toStringAsFixed(1)}°, the '
                              'edge of what we will still call the same way of '
                              'sitting. There is no point inside the band that is '
                              'more correct than another.',
                          '${contract.teacherCount} ${catalogSourceClass(context, contract.sourceClass)} '
                              'için ölçülen gövde eğimi '
                              '${contract.bandLowDeg.toStringAsFixed(1)}°–'
                              '${contract.bandHighDeg.toStringAsFixed(1)}° arasındadır; '
                              'aralık genişliği '
                              '${(contract.bandHighDeg - contract.bandLowDeg).toStringAsFixed(1)}°.'
                              ' Kesikli çizgi, aynı oturuş biçimi saydığımız '
                              '${contract.cueThresholdDeg.toStringAsFixed(1)}° sınırını gösterir. '
                              'Aralığın içindeki bir nokta diğerinden daha doğru değildir.',
                        ),
                        style: hankenText(size: 13.5, height: 1.55),
                      ),
                      const SizedBox(height: 8),
                      // DÜZELTME-2 (O-099, koordinatör hükmü 2026-08-12):
                      // "Nine upper-body landmarks" OKUMA iddiasıydı ve
                      // ölçüme uymuyordu — kamera DÖRT landmark okur (iki
                      // omuz + iki kalça), TEK açı ölçer. Dokuz, BU
                      // FİGÜRÜN düğüm sayısı; bu yüzden sayı yalnız burada
                      // kalıyor ve fiili "çizer". Her sayı saydığı şeyin
                      // yanında durur (08-06 netleştirmesi figürü tarif
                      // ederken doğruydu, okunan veriye sızması yanlıştı).
                      Text(
                        localized(
                          context,
                          'Your two shoulders and your two hips are what the '
                              'camera reads; this figure draws nine points. No '
                              'head node — our reference does not carry one, so '
                              'nothing about your chin or jaw is read.',
                          'Kamera iki omzunuzu ve iki kalçanızı okur; bu çizim '
                              'dokuz nokta gösterir. Referansta baş noktası '
                              'olmadığı için çene konumunuz okunmaz.',
                        ),
                        style: hankenText(
                          size: 12.5,
                          color: OstinatoColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // İSİMLİ NETLEŞTİRME (koordinatör, 2026-08-06, M-F-287
                      // ikizi): "dokuz" sayısı figürün SOLID (canlı, kalça+
                      // omuz+boyun) beş noktasıyla YAN YANA okununca dar
                      // görünebilirdi — dört tanesi (dirsek/bilek) neden
                      // KESİKLİ olduğunu bu cümle olmadan açıklamıyordu.
                      //
                      // DÜZELTME (koordinatör, 2026-08-06): ilk metin "not
                      // tracked YET" diyordu — M-F-186 vaat dili ihlali
                      // ("yet" bir zaman taahhüdü) VE yanlış: kollar
                      // ÖLÇÜLÜYOR (demoOnly ders gösteriyor), izlenmeyen
                      // ölçüm değil bu FİGÜR. "Şu an" olguyu söylüyor,
                      // gelecek zaman kipi yok.
                      Text(
                        localized(
                          context,
                          'The solid points are what this figure tracks; the '
                              'dashed arms are shown for shape — this figure '
                              'follows your trunk.',
                          'Düz çizgili noktalar çizimin izlediği kısımlardır. '
                              'Kesikli kollar yalnız biçimi gösterir; bu çizim '
                              'gövdenizi izler.',
                        ),
                        style: hankenText(
                          size: 11.5,
                          color: OstinatoColors.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: .7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    kicker(
                      localized(context, 'Before you start', 'Başlamadan önce'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isGuide
                          ? localized(
                              context,
                              'This lesson is instruction only — it makes no measurement claim.',
                              'Bu ders yalnız yönlendirme sunar; ölçüm iddiası taşımaz.',
                            )
                          : localized(
                              context,
                              'A setup check runs first: your frame and the light. Measuring does not begin until both pass.',
                              'Önce kadraj ve ışık denetlenir. İkisi de uygun olmadan ölçüm başlamaz.',
                            ),
                      style: hankenText(size: 13.5, height: 1.55),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: isGuide
                    ? localized(context, 'Continue', 'Devam et')
                    : localized(
                        context,
                        'Begin the setup check',
                        'Kurulum denetimini başlat',
                      ),
                onPressed: () async {
                  final guard = AccountScope.maybeOf(
                    context,
                  )?.connection?.requirePaidAccess;
                  if (guard != null && !await guard(context)) return;
                  if (!context.mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SetupCheckScreenRoute(
                        discipline: discipline,
                        lesson: lesson,
                        hue: hue,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
