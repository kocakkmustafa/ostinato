import 'package:flutter/material.dart';

import '../account_connection.dart';
import '../app_locale.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import '../guitar_journey.dart';
import '../guitar_journey_progress.dart';
import 'guitar_note_observation_screen.dart';

/// Self-guided learning path. No sensor result is converted into completion.
class GuitarJourneyScreen extends StatefulWidget {
  const GuitarJourneyScreen({
    super.key,
    this.progressStoreFactory,
    this.initialCourse,
    this.initialProgress,
  });

  final GuitarJourneyProgressStore Function(String? accountUserId)?
  progressStoreFactory;
  final GuitarJourneyCourse? initialCourse;
  final Map<String, GuitarLessonProgress>? initialProgress;

  @override
  State<GuitarJourneyScreen> createState() => _GuitarJourneyScreenState();
}

class _GuitarJourneyScreenState extends State<GuitarJourneyScreen> {
  late final Future<GuitarJourneyCourse> _course = widget.initialCourse == null
      ? GuitarJourneyCourse.load()
      : Future.value(widget.initialCourse);
  String? _accountId;
  GuitarJourneyProgressStore? _store;
  Future<Map<String, GuitarLessonProgress>>? _progress;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = AccountScope.maybeOf(context)?.currentUserId;
    if (_store == null || id != _accountId) {
      _accountId = id;
      _store =
          widget.progressStoreFactory?.call(id) ??
          GuitarJourneyProgressStore(accountUserId: id);
      _progress = widget.initialProgress == null
          ? _store!.load()
          : Future.value(widget.initialProgress);
    }
  }

  void _reload() {
    final progress = _store!.load();
    setState(() {
      _progress = progress;
    });
  }

  GuitarLessonProgress? _record(
    Map<String, GuitarLessonProgress> progress,
    GuitarJourneyCourse course,
    GuitarJourneyLesson lesson,
  ) => progress['${course.contentVersion}|${lesson.id}'];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: OstinatoColors.surface,
    body: SafeArea(
      child: FutureBuilder<GuitarJourneyCourse>(
        future: _course,
        builder: (context, courseSnapshot) {
          if (courseSnapshot.hasError) {
            return Center(
              child: Text(
                localized(
                  context,
                  'The course could not be loaded.',
                  'Kurs yüklenemedi.',
                ),
              ),
            );
          }
          if (!courseSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return FutureBuilder<Map<String, GuitarLessonProgress>>(
            future: _progress,
            builder: (context, progressSnapshot) {
              if (progressSnapshot.hasError) {
                return Center(
                  child: Text(
                    localized(
                      context,
                      'Your local progress could not be read. It has not been reset.',
                      'Yerel ilerlemen okunamadı. Kayıt sıfırlanmadı.',
                    ),
                  ),
                );
              }
              if (!progressSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _body(
                context,
                courseSnapshot.data!,
                progressSnapshot.data!,
              );
            },
          );
        },
      ),
    ),
  );

  Widget _body(
    BuildContext context,
    GuitarJourneyCourse course,
    Map<String, GuitarLessonProgress> progress,
  ) {
    final lessons = course.lessons;
    final completed = lessons
        .where(
          (l) => _record(progress, course, l)?.selfReportedCompletedAt != null,
        )
        .length;
    final next = lessons.cast<GuitarJourneyLesson?>().firstWhere(
      (l) =>
          l != null &&
          _record(progress, course, l)?.selfReportedCompletedAt == null,
      orElse: () => null,
    );
    final hue = InstrumentHues.guitar;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassIconButton(
            icon: '‹',
            semanticLabel: localized(context, 'Back', 'Geri'),
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 20),
          GlassCard(
            gradientColors: hue.grad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                kicker(
                  localized(
                    context,
                    'GUITAR · LEARNING PATH',
                    'GİTAR · ÖĞRENME YOLU',
                  ),
                  color: hue.ink,
                ),
                const SizedBox(height: 9),
                Text(
                  course.title.of(context),
                  style: hankenText(
                    size: 28,
                    weight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  course.summary.of(context),
                  style: hankenText(size: 13.5, height: 1.5),
                ),
                const SizedBox(height: 16),
                Text(
                  localized(
                    context,
                    '$completed of ${lessons.length} self-reported complete',
                    '$completed / ${lessons.length} öz beyanla tamamlandı',
                  ),
                  key: const Key('guitar-journey-progress'),
                  style: monoText(color: hue.ink),
                ),
                const SizedBox(height: 7),
                LinearProgressIndicator(
                  value: completed / lessons.length,
                  color: hue.ink,
                  backgroundColor: Colors.white.withValues(alpha: .65),
                  minHeight: 6,
                ),
              ],
            ),
          ),
          const SizedBox(height: 17),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localized(
                    context,
                    'Optional single-note practice',
                    'İsteğe bağlı tek nota pratiği',
                  ),
                  style: hankenText(size: 18, weight: FontWeight.w600),
                ),
                const SizedBox(height: 7),
                Text(
                  localized(
                    context,
                    'Observe an approximate note with microphone permission. This does not assess or complete a lesson.',
                    'Mikrofon izniyle yaklaşık bir nota gözle. Bu araç dersi değerlendirmez veya tamamlamaz.',
                  ),
                  style: hankenText(size: 12.5, height: 1.5),
                ),
                TextButton.icon(
                  key: const Key('guitar-note-observation-entry'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const GuitarNoteObservationScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.music_note_outlined),
                  label: Text(
                    localized(
                      context,
                      'Open note observation',
                      'Nota gözlemini aç',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 17),
          if (next != null)
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  kicker(
                    localized(context, 'Continue with', 'Sıradaki ders'),
                    color: hue.ink,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    next.title.of(context),
                    style: hankenText(size: 19, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    localized(
                      context,
                      'You can revisit any earlier lesson at any time.',
                      'Önceki derslere istediğin zaman dönebilirsin.',
                    ),
                    style: hankenText(
                      size: 12.5,
                      color: OstinatoColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 11),
                  TextButton.icon(
                    onPressed: () =>
                        _openLesson(context, course, next, progress),
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(localized(context, 'Open lesson', 'Dersi aç')),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          kicker(localized(context, 'The ten modules', 'On modül')),
          const SizedBox(height: 10),
          for (var index = 0; index < course.modules.length; index++) ...[
            _module(context, course, course.modules[index], index, progress),
            const SizedBox(height: 10),
          ],
          if (completed == lessons.length)
            GlassCard(
              child: Text(
                course.completionStatement.of(context),
                style: hankenText(size: 13.5, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _module(
    BuildContext context,
    GuitarJourneyCourse course,
    GuitarJourneyModule module,
    int index,
    Map<String, GuitarLessonProgress> progress,
  ) {
    final done = module.lessons
        .where(
          (l) => _record(progress, course, l)?.selfReportedCompletedAt != null,
        )
        .length;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        key: Key('guitar-module-${module.id}'),
        initiallyExpanded:
            index == 0 || (done > 0 && done < module.lessons.length),
        tilePadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 5),
        title: Text(
          '${index + 1}. ${module.title.of(context)}',
          style: hankenText(size: 16, weight: FontWeight.w600),
        ),
        subtitle: Text(
          localized(context, '$done / 6 self-reported', '$done / 6 öz beyan'),
          style: monoText(),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 0, 17, 9),
            child: Text(
              module.goal.of(context),
              style: hankenText(size: 12.5, color: OstinatoColors.textMuted),
            ),
          ),
          for (final lesson in module.lessons)
            ListTile(
              key: Key('guitar-lesson-${lesson.id}'),
              title: Text(
                lesson.title.of(context),
                style: hankenText(size: 14),
              ),
              subtitle: Text(
                _statusText(context, _record(progress, course, lesson)),
                style: monoText(),
              ),
              trailing: const Icon(Icons.chevron_right, size: 19),
              onTap: () => _openLesson(context, course, lesson, progress),
            ),
        ],
      ),
    );
  }

  String _statusText(BuildContext context, GuitarLessonProgress? record) {
    if (record?.selfReportedCompletedAt != null) {
      final date = record!.selfReportedCompletedAt!
          .toLocal()
          .toIso8601String()
          .split('T')
          .first;
      return localized(context, 'SELF-REPORTED · $date', 'ÖZ BEYAN · $date');
    }
    if ((record?.practiceCount ?? 0) > 0) {
      return localized(
        context,
        'PRACTISED ×${record?.practiceCount ?? 0}',
        'ÇALIŞILDI ×${record?.practiceCount ?? 0}',
      );
    }
    if (record?.seenAt != null) return localized(context, 'VIEWED', 'GÖRÜLDÜ');
    return localized(context, 'NOT STARTED', 'BAŞLANMADI');
  }

  Future<void> _openLesson(
    BuildContext context,
    GuitarJourneyCourse course,
    GuitarJourneyLesson lesson,
    Map<String, GuitarLessonProgress> progress,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GuitarJourneyLessonScreen(
          course: course,
          lesson: lesson,
          store: _store!,
          initial: _record(progress, course, lesson),
        ),
      ),
    );
    if (mounted) _reload();
  }
}

class GuitarJourneyLessonScreen extends StatefulWidget {
  const GuitarJourneyLessonScreen({
    super.key,
    required this.course,
    required this.lesson,
    required this.store,
    this.initial,
  });
  final GuitarJourneyCourse course;
  final GuitarJourneyLesson lesson;
  final GuitarJourneyProgressStore store;
  final GuitarLessonProgress? initial;

  @override
  State<GuitarJourneyLessonScreen> createState() =>
      _GuitarJourneyLessonScreenState();
}

class _GuitarJourneyLessonScreenState extends State<GuitarJourneyLessonScreen> {
  late GuitarLessonProgress? _record = widget.initial;
  bool _saving = false;

  Future<void> _save(GuitarProgressAction action) async {
    if (AccountScope.maybeOf(context)?.currentUserId !=
        widget.store.accountUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localized(
              context,
              'The active account changed. Reopen this lesson to save progress.',
              'Etkin hesap değişti. İlerlemeyi kaydetmek için bu dersi yeniden aç.',
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final next = await widget.store.record(
        lessonId: widget.lesson.id,
        contentVersion: widget.course.contentVersion,
        action: action,
      );
      if (mounted) setState(() => _record = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localized(
                context,
                'Progress could not be saved.',
                'İlerleme kaydedilemedi.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final hue = InstrumentHues.guitar;
    return Scaffold(
      backgroundColor: OstinatoColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassIconButton(
                icon: '‹',
                semanticLabel: localized(
                  context,
                  'Back to course',
                  'Kursa dön',
                ),
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 20),
              kicker(
                localized(
                  context,
                  lesson.capstone ? 'ORIGINAL PERFORMANCE' : 'GUITAR LESSON',
                  lesson.capstone ? 'ÖZGÜN PERFORMANS' : 'GİTAR DERSİ',
                ),
                color: hue.ink,
              ),
              const SizedBox(height: 8),
              Text(
                lesson.title.of(context),
                key: Key('guitar-lesson-title-${lesson.id}'),
                style: hankenText(
                  size: 28,
                  weight: FontWeight.w600,
                  height: 1.13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                localized(
                  context,
                  '${lesson.minutes} MIN · SELF-GUIDED',
                  '${lesson.minutes} DK · KENDİ ÇALIŞMAN',
                ),
                style: monoText(),
              ),
              const SizedBox(height: 17),
              if (lesson.prerequisiteIds.isNotEmpty)
                _section(
                  context,
                  'Before this lesson',
                  'Bu dersten önce',
                  localized(
                    context,
                    'Practise ${widget.course.lessons.firstWhere((l) => l.id == lesson.prerequisiteIds.single).title.en} and use its self-check before continuing. Return to the course to revisit it.',
                    '${widget.course.lessons.firstWhere((l) => l.id == lesson.prerequisiteIds.single).title.tr} dersini çalış ve devam etmeden öz denetimini yap. Yeniden açmak için kursa dön.',
                  ),
                ),
              _section(context, 'Goal', 'Hedef', lesson.objective.of(context)),
              _section(
                context,
                'Learn',
                'Öğren',
                lesson.teachingSteps
                    .asMap()
                    .entries
                    .map((e) => '${e.key + 1}. ${e.value.of(context)}')
                    .join('\n\n'),
              ),
              if (lesson.id.endsWith('.tuning')) _tuningCard(context),
              if (lesson.shapeIds.isNotEmpty) _shapeCard(context),
              _section(
                context,
                'Practise',
                'Çalış',
                lesson.practice.of(context),
              ),
              _section(
                context,
                'Check yourself',
                'Kendini denetle',
                lesson.selfCheck.of(context),
              ),
              _section(
                context,
                'Common mistake',
                'Yaygın hata',
                lesson.commonError.of(context),
              ),
              _section(
                context,
                'Make it easier',
                'Kolaylaştır',
                lesson.adaptation.of(context),
              ),
              _section(
                context,
                'When to pause',
                'Ne zaman ara vermeli',
                lesson.stopSignal.of(context),
              ),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    kicker(
                      localized(context, 'Progress record', 'İlerleme kaydı'),
                      color: hue.ink,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localized(
                        context,
                        'Viewing, practice and completion are separate. Completion is your own report; no note, chord or hand position is graded here.',
                        'Görme, çalışma ve tamamlama ayrıdır. Tamamlama kendi beyanındır; burada nota, akor veya el konumu puanlanmaz.',
                      ),
                      style: hankenText(size: 12.5, height: 1.5),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      localized(
                        context,
                        'Practice entries: ${_record?.practiceCount ?? 0}',
                        'Çalışma kaydı: ${_record?.practiceCount ?? 0}',
                      ),
                      style: monoText(),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _saving || _record?.seenAt != null
                              ? null
                              : () => _save(GuitarProgressAction.viewed),
                          child: Text(
                            localized(context, 'Mark viewed', 'Okudum'),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => _save(GuitarProgressAction.practiced),
                          child: Text(
                            localized(
                              context,
                              'Record practice',
                              'Çalışmayı kaydet',
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed:
                              _saving ||
                                  (_record?.practiceCount ?? 0) == 0 ||
                                  _record?.selfReportedCompletedAt != null
                              ? null
                              : () => _save(
                                  GuitarProgressAction.selfReportedCompleted,
                                ),
                          child: Text(
                            localized(
                              context,
                              'I completed this practice',
                              'Bu çalışmayı tamamladım',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ExpansionTile(
                title: Text(
                  localized(
                    context,
                    'Sources for this lesson',
                    'Bu dersin kaynakları',
                  ),
                  style: hankenText(size: 13.5),
                ),
                children: [
                  for (final id in lesson.sourceIds)
                    if (widget.course.sources[id] case final source?)
                      ListTile(
                        title: Text(
                          source.title,
                          style: hankenText(size: 12.5),
                        ),
                        subtitle: SelectableText(
                          source.url,
                          style: monoText(size: 9),
                        ),
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String en, String tr, String body) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              kicker(
                localized(context, en, tr),
                color: InstrumentHues.guitar.ink,
              ),
              const SizedBox(height: 9),
              Text(body, style: hankenText(size: 13.5, height: 1.55)),
            ],
          ),
        ),
      );

  Widget _tuningCard(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kicker(
            localized(
              context,
              'Standard tuning reference',
              'Standart akort referansı',
            ),
            color: InstrumentHues.guitar.ink,
          ),
          const SizedBox(height: 9),
          for (final string in widget.course.tuning)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                localized(
                  context,
                  'String ${string.number} · ${string.note} · ${string.hz.toStringAsFixed(2)} Hz',
                  '${string.number}. tel · ${string.note} · ${string.hz.toStringAsFixed(2)} Hz',
                ),
                style: monoText(size: 10.5, color: OstinatoColors.textBody),
              ),
            ),
          const SizedBox(height: 7),
          Text(
            localized(
              context,
              'These are standard-tuning reference frequencies, not live readings or sound-level measurements.',
              'Bunlar standart akort referans frekanslarıdır; canlı okuma veya ses düzeyi ölçümü değildir.',
            ),
            style: hankenText(size: 12, color: OstinatoColors.textMuted),
          ),
        ],
      ),
    ),
  );

  Widget _shapeCard(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kicker(
            localized(context, 'Example chord shapes', 'Örnek akor şekilleri'),
            color: InstrumentHues.guitar.ink,
          ),
          const SizedBox(height: 6),
          Text(
            localized(
              context,
              'Strings run thick to thin (6→1). × = do not play; 0 = open. Finger numbers are examples, not a required grip.',
              'Teller kalından inceye (6→1) gider. × = çalma; 0 = açık. Parmak sayıları zorunlu tutuş değil, örnektir.',
            ),
            style: hankenText(size: 12, color: OstinatoColors.textMuted),
          ),
          const SizedBox(height: 12),
          for (final id in widget.lesson.shapeIds)
            if (widget.course.chordShapes[id] case final shape?) ...[
              Text(
                shape.label.of(context),
                style: hankenText(size: 14, weight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < 6; i++)
                      Container(
                        width: 43,
                        margin: const EdgeInsets.only(right: 3),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: InstrumentHues.guitar.chip,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${6 - i}',
                              style: monoText(
                                size: 9,
                                color: InstrumentHues.guitar.ink,
                              ),
                            ),
                            Text(
                              shape.frets6to1[i]?.toString() ?? '×',
                              style: hankenText(
                                size: 17,
                                weight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              shape.exampleFingers6to1[i]?.toString() ?? '×',
                              style: monoText(size: 9),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                localized(
                  context,
                  'Top row: string · middle: fret · bottom: example finger',
                  'Üst: tel · orta: perde · alt: örnek parmak',
                ),
                style: hankenText(size: 10.5, color: OstinatoColors.textFaint),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    ),
  );
}
