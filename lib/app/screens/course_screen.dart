import 'package:flutter/material.dart';

import '../content.dart';
import '../app_locale.dart';
import '../catalog_copy_tr.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import 'lesson_demo_screen.dart';
import 'lesson_locked_screen.dart';
import 'lesson_scored_screen.dart';

/// Bir dersin AÇILACAĞI ekran — [LessonKind]'ın tek karşılığı.
///
/// Top-level, çünkü iki çağıranı var (kurs listesi ve Kütüphane'nin "START
/// HERE" şeridi) ve switch'in İKİ kopyası olsaydı biri sessizce eskirdi:
/// yeni bir [LessonKind] eklendiğinde derleyici yalnız güncellenen kopyayı
/// bilir. Tek yer = tek gerçek.
Widget lessonScreenFor({
  required Discipline discipline,
  required Lesson lesson,
  required InstrumentHue hue,
}) =>
    switch (lesson.kind) {
      LessonKind.locked =>
        LessonLockedScreenRoute(discipline: discipline, lesson: lesson, hue: hue),
      LessonKind.demoOnly =>
        LessonDemoScreenRoute(discipline: discipline, lesson: lesson, hue: hue),
      LessonKind.guide || LessonKind.scored =>
        LessonScoredScreenRoute(discipline: discipline, lesson: lesson, hue: hue),
    };

/// Kurs — ders listesi. Üç görsel sınıf burada AYRI çip taşır; kilitli
/// dersin gerekçesinin İLK CÜMLESİ satır-içi görünür (§4/⑭ — bilgi tonu,
/// merak-tuzağı DEĞİL).
class CourseScreenRoute extends StatelessWidget {
  const CourseScreenRoute(
      {super.key, required this.discipline, required this.course});
  final Discipline discipline;
  final Course course;

  @override
  Widget build(BuildContext context) {
    final InstrumentHue hue = InstrumentHues.of(discipline.id);
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
              Text('${catalogUpperName(context, discipline.id, discipline.displayName)} · ${localized(context, 'FOUNDATIONS', 'TEMELLER')}',
                  style: monoText(color: hue.ink)),
              const SizedBox(height: 9),
              Text(catalogGoal(context, course.id, course.goal),
                  style: hankenText(
                      size: 28, weight: FontWeight.w600, height: 1.1)),
              const SizedBox(height: 12),
              Text(
                  courseMetadata(context, course.level, course.estimatedMinutes, course.lessons.length),
                  style: monoText()),
              const SizedBox(height: 22),
              for (final Lesson l in course.lessons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LessonRow(discipline: discipline, lesson: l, hue: hue),
                ),
              const SizedBox(height: 8),
              Text(
                localized(context,
                  'A locked lesson is visible on purpose. The reason it is locked is the name of the measurement we are missing, not a threshold you failed.',
                  'Kilitli dersler bilerek gösterilir. Kilidin nedeni geçemediğin bir eşik değil, eksik olan ölçümün adıdır.'),
                style: hankenText(size: 12, color: OstinatoColors.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow(
      {required this.discipline, required this.lesson, required this.hue});
  final Discipline discipline;
  final Lesson lesson;
  final InstrumentHue hue;

  (String, Color, Color, Color) get _chip => switch (lesson.kind) {
        LessonKind.locked => ('LOCKED', const Color(0x122A2533),
            const Color(0xFF6E6880), Colors.white.withValues(alpha: .5)),
        LessonKind.demoOnly => (
            'REFERENCE · NO SCORING',
            hue.chip,
            hue.ink,
            hue.soft.first,
          ),
        LessonKind.guide => ('GUIDE', const Color(0x0D2A2533),
            const Color(0xFF8B8497), Colors.white.withValues(alpha: .62)),
        LessonKind.scored => ('REFERENCE', const Color(0x0F2A2533),
            const Color(0xFF4E4759), Colors.white.withValues(alpha: .72)),
      };

  @override
  Widget build(BuildContext context) {
    final (_, chipBg, chipFg, bg) = _chip;
    final String? sourceReason = lesson.lockedReason ?? lesson.demoOnlyReason;
    final String firstSentence = sourceReason == null
        ? ''
        : catalogFirstSentence(
            context,
            '${lesson.id}.${lesson.lockedReason != null ? 'lockedReason' : 'demoOnlyReason'}',
            sourceReason,
          );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('lesson-${lesson.id}'),
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          final Widget screen = lessonScreenFor(
              discipline: discipline, lesson: lesson, hue: hue);
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => screen));
        },
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: bg,
            border: Border.all(color: Colors.white.withValues(alpha: .8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Give the title and status their own bounded lines. A long
              // status chip must wrap at large text sizes, not squeeze the
              // title or overflow the lesson card.
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    catalogName(context, lesson.id, lesson.displayName),
                    style: hankenText(size: 15.5, weight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lessonMetadata(context, lesson.minutes, lesson.focus),
                    style: monoText(),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                        color: chipBg, borderRadius: BorderRadius.circular(7)),
                    child: Text(
                      switch (lesson.kind) {
                        LessonKind.locked => localized(context, 'LOCKED', 'KİLİTLİ'),
                        LessonKind.demoOnly => localized(context, 'REFERENCE · NO SCORING', 'REFERANS · PUAN YOK'),
                        LessonKind.guide => localized(context, 'GUIDE', 'REHBER'),
                        LessonKind.scored => localized(context, 'REFERENCE', 'REFERANS'),
                      },
                      style: monoText(
                        size: 9.5,
                        color: chipFg,
                        letterSpacing: .07,
                      ),
                    ),
                  ),
                ],
              ),
              if (firstSentence.isNotEmpty) ...<Widget>[
                const SizedBox(height: 7),
                RichText(
                  text: TextSpan(
                    style: hankenText(
                        size: 12.5, color: OstinatoColors.textMuted),
                    children: <InlineSpan>[
                      TextSpan(text: '$firstSentence '),
                      TextSpan(
                          text: localized(context, 'Read why ›', 'Nedenini oku ›'),
                          style: hankenText(size: 12.5, color: hue.ink)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
