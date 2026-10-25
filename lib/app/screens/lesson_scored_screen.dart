import '../app_theme.dart';
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
    final hue = OstinatoPalette.of(context).instrument(discipline.id);
    final PostureContract? contract = ContentRepositoryScope.of(
      context,
    ).contractOrNull(discipline.id);
    final bool isGuide = lesson.kind == LessonKind.guide;

    return Scaffold(
      backgroundColor: OstinatoPalette.of(context).surface,
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
                '${lessonMetadata(context, lesson.minutes, lesson.focus)} '
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
                              color: OstinatoPalette.of(context).ink,
                              markerColor: OstinatoPalette.of(
                                context,
                              ).textMuted,
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
                          "{v0} {v1} sit between {v2}° and {v3}° of trunk tilt — a band {v4}° wide. The dashed line marks {v5}°, the edge of what we will still call the same way of sitting. There is no point inside the band that is more correct than another.",
                          "{v0} {v1} için ölçülen gövde eğimi {v2}°–{v3}° arasındadır; aralık genişliği {v4}°. Kesikli çizgi, aynı oturuş biçimi saydığımız {v5}° sınırını gösterir. Aralığın içindeki bir nokta diğerinden daha doğru değildir.",
                          values: {
                            "v0": contract.teacherCount,
                            "v1": catalogSourceClass(
                              context,
                              contract.sourceClass,
                            ),
                            "v2": AppDecimal(contract.bandLowDeg, 1),
                            "v3": AppDecimal(contract.bandHighDeg, 1),
                            "v4": AppDecimal(
                              contract.bandHighDeg - contract.bandLowDeg,
                              1,
                            ),
                            "v5": AppDecimal(contract.cueThresholdDeg, 1),
                          },
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
                          color: OstinatoPalette.of(context).textMuted,
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
                          color: OstinatoPalette.of(context).textFaint,
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
                  color: OstinatoPalette.of(context).controlSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: OstinatoPalette.of(context).glassBorder,
                  ),
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
                  // Camera setup and measurement follow the camera gate, not
                  // the subscription gate: closed in this release for members
                  // too. Production always binds an account connection; only
                  // test shells run without one.
                  final guard = AccountScope.maybeOf(
                    context,
                  )?.connection?.requireCameraAccess;
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
