import 'package:flutter/material.dart';
import 'package:ostinato_posture/ostinato_posture.dart';

import '../content.dart';
import '../design/app_scope.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import 'setup_check_screen.dart';

/// Skorlu/guide ders — ölçüm oturumundan ÖNCEKİ bilgi ekranı. Guide sınıfı
/// (`focus == 'setup'`) ölçüm iddiası TAŞIMAZ; bant kartı yalnız skorlu
/// derslerde gösterilir.
class LessonScoredScreenRoute extends StatelessWidget {
  const LessonScoredScreenRoute(
      {super.key, required this.discipline, required this.lesson, required this.hue});
  final Discipline discipline;
  final Lesson lesson;
  final InstrumentHue hue;

  @override
  Widget build(BuildContext context) {
    final PostureContract? contract =
        ContentRepositoryScope.of(context).contractOrNull(discipline.id);
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
                  semanticLabel: 'Back',
                  onTap: () => Navigator.of(context).pop()),
              const SizedBox(height: 22),
              Text(lesson.displayName,
                  key: const Key('state-lesson-scored'),
                  style: hankenText(
                      size: 27, weight: FontWeight.w600, height: 1.15)),
              const SizedBox(height: 11),
              Text('${lesson.minutes} MIN'
                  '${lesson.focus.isEmpty ? '' : ' · ${lesson.focus.toUpperCase()}'} '
                  '· ${discipline.displayName.toUpperCase()}',
                  style: monoText()),
              const SizedBox(height: 20),
              if (!isGuide && contract != null) ...<Widget>[
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      kicker('What you’re measured against', color: hue.ink),
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
                        style: hankenText(size: 13.5, height: 1.55),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nine upper-body landmarks. No head node — our '
                        'reference does not carry one, so nothing about '
                        'your chin or jaw is read.',
                        style: hankenText(
                            size: 12.5, color: OstinatoColors.textMuted),
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
                        'The solid points are what this figure tracks; the '
                        'dashed arms are shown for shape — this figure '
                        'follows your trunk.',
                        style: hankenText(
                            size: 11.5, color: OstinatoColors.textFaint),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: .7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    kicker('Before you start'),
                    const SizedBox(height: 8),
                    Text(
                      isGuide
                          ? 'This lesson is instruction only — it makes no '
                              'measurement claim.'
                          : 'A setup check runs first: your frame and the '
                              'light. Measuring does not begin until both pass.',
                      style: hankenText(size: 13.5, height: 1.55),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: isGuide ? 'Continue' : 'Begin the setup check',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => SetupCheckScreenRoute(
                        discipline: discipline, lesson: lesson, hue: hue))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
