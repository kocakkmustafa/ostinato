import 'package:flutter/material.dart';

import '../content.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import 'lesson_demo_screen.dart';
import 'lesson_locked_screen.dart';
import 'lesson_scored_screen.dart';

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
                semanticLabel: 'Back',
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 22),
              Text('${discipline.displayName.toUpperCase()} · FOUNDATIONS',
                  style: monoText(color: hue.ink)),
              const SizedBox(height: 9),
              Text(course.goal,
                  style: hankenText(
                      size: 28, weight: FontWeight.w600, height: 1.1)),
              const SizedBox(height: 12),
              Text(
                  '${course.level.toUpperCase()} · ${course.estimatedMinutes} '
                  'MIN · ${course.lessons.length} LESSONS',
                  style: monoText()),
              const SizedBox(height: 22),
              for (final Lesson l in course.lessons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LessonRow(discipline: discipline, lesson: l, hue: hue),
                ),
              const SizedBox(height: 8),
              Text(
                'A locked lesson is visible on purpose. The reason it is '
                'locked is the name of the measurement we are missing, not '
                'a threshold you failed.',
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
            'MEASURED · NOT MARKED',
            hue.chip,
            hue.ink,
            hue.soft.first,
          ),
        LessonKind.guide => ('GUIDE', const Color(0x0D2A2533),
            const Color(0xFF8B8497), Colors.white.withValues(alpha: .62)),
        LessonKind.scored => ('SCORED', const Color(0x0F2A2533),
            const Color(0xFF4E4759), Colors.white.withValues(alpha: .72)),
      };

  @override
  Widget build(BuildContext context) {
    final (String chip, Color chipBg, Color chipFg, Color bg) = _chip;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('lesson-${lesson.id}'),
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          final Widget screen = switch (lesson.kind) {
            LessonKind.locked => LessonLockedScreenRoute(
                discipline: discipline, lesson: lesson, hue: hue),
            LessonKind.demoOnly => LessonDemoScreenRoute(
                discipline: discipline, lesson: lesson, hue: hue),
            LessonKind.guide || LessonKind.scored => LessonScoredScreenRoute(
                discipline: discipline, lesson: lesson, hue: hue),
          };
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(lesson.displayName,
                            style: hankenText(size: 15.5, weight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        Text(
                            '${lesson.minutes} MIN'
                            '${lesson.focus.isEmpty ? '' : ' · ${lesson.focus.toUpperCase()}'}',
                            style: monoText()),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                        color: chipBg, borderRadius: BorderRadius.circular(7)),
                    child: Text(chip,
                        style: monoText(size: 9.5, color: chipFg, letterSpacing: .07)),
                  ),
                ],
              ),
              if (lesson.firstSentence.isNotEmpty) ...<Widget>[
                const SizedBox(height: 7),
                RichText(
                  text: TextSpan(
                    style: hankenText(
                        size: 12.5, color: OstinatoColors.textMuted),
                    children: <InlineSpan>[
                      TextSpan(text: '${lesson.firstSentence} '),
                      TextSpan(
                          text: 'Read why ›',
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
