import '../app_theme.dart';
import 'package:flutter/material.dart';

import '../account_connection.dart';
import '../app_locale.dart';
import '../course_access.dart';
import '../course/media/lesson_media_slot.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import '../guitar_journey.dart';
import '../guitar_journey_progress.dart';
import '../guitar_session_preparation.dart';
import '../guitar_staff_diagram.dart';
import '../retention/weekly_goal.dart';
import '../retention/weekly_goal_store.dart';
import '../ui_copy.dart';
import 'v1_home_copy.dart';
import 'guitar_note_observation_screen.dart';
import '../practice/loop/v1_practice_list_screen.dart';

/// Self-guided learning path. No sensor result is converted into completion.
class GuitarJourneyScreen extends StatefulWidget {
  const GuitarJourneyScreen({
    super.key,
    this.progressStoreFactory,
    this.initialCourse,
    this.initialProgress,
    this.preparation,
    this.bundle,
  });

  final GuitarJourneyProgressStore Function(String? accountUserId)?
  progressStoreFactory;
  final GuitarJourneyCourse? initialCourse;
  final Map<String, GuitarLessonProgress>? initialProgress;
  final GuitarSessionPreparation? preparation;
  final AssetBundle? bundle;

  @override
  State<GuitarJourneyScreen> createState() => _GuitarJourneyScreenState();
}

class _GuitarJourneyScreenState extends State<GuitarJourneyScreen> {
  late final GuitarSessionPreparation _preparation =
      widget.preparation ?? GuitarSessionPreparation();
  Future<GuitarJourneyCourse> _loadCourse() => widget.initialCourse == null
      ? GuitarJourneyCourse.load(bundle: widget.bundle)
      : Future.value(widget.initialCourse);
  late Future<GuitarJourneyCourse> _course = _loadCourse();
  String? _accountId;
  GuitarJourneyProgressStore? _store;
  Future<Map<String, GuitarLessonProgress>>? _progress;

  @override
  void dispose() {
    if (widget.preparation == null) _preparation.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = AccountScope.maybeOf(context)?.currentUserId;
    if (_store == null || id != _accountId) {
      if (_store != null && id != _accountId) _preparation.afterBreak();
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

  void _reloadCourse() {
    final course = _loadCourse();
    setState(() {
      _course = course;
    });
  }

  Widget _loadError(BuildContext context, String message, VoidCallback retry) =>
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: retry,
                child: Text(localized(context, 'Retry', 'Yeniden dene')),
              ),
              if (Navigator.of(context).canPop())
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(localized(context, 'Back', 'Geri')),
                ),
            ],
          ),
        ),
      );

  GuitarLessonProgress? _record(
    Map<String, GuitarLessonProgress>? progress,
    GuitarJourneyCourse course,
    GuitarJourneyLesson lesson,
  ) =>
      progress?['${lesson.progressVersionFor(course.contentVersion)}|${lesson.id}'];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: OstinatoPalette.of(context).surface,
    body: SafeArea(
      child: FutureBuilder<GuitarJourneyCourse>(
        future: _course,
        builder: (context, courseSnapshot) {
          if (courseSnapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (courseSnapshot.hasError) {
            return _loadError(
              context,
              localized(
                context,
                'The course could not be loaded.',
                'Kurs yüklenemedi.',
              ),
              _reloadCourse,
            );
          }
          if (!courseSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return FutureBuilder<Map<String, GuitarLessonProgress>>(
            future: _progress,
            builder: (context, progressSnapshot) {
              // A new account or retry may retain the old snapshot's data.
              // Do not pair it with the newly selected store while loading.
              if (progressSnapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (progressSnapshot.hasError) {
                return _body(context, courseSnapshot.data!, null);
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
    Map<String, GuitarLessonProgress>? progress,
  ) {
    final lessons = course.lessons;
    final completed = progress == null
        ? null
        : lessons
              .where(
                (l) =>
                    _record(progress, course, l)?.selfReportedCompletedAt !=
                    null,
              )
              .length;
    final next = progress == null
        ? null
        : lessons.cast<GuitarJourneyLesson?>().firstWhere(
            (l) =>
                l != null &&
                _record(progress, course, l)?.selfReportedCompletedAt == null,
            orElse: () => null,
          );
    final hue = OstinatoPalette.of(context).guitar;
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
                  uiText(context, V1HomeCopy.heroBody),
                  style: hankenText(size: 13.5, height: 1.5),
                ),
                const SizedBox(height: 16),
                Text(
                  completed == null
                      ? localized(
                          context,
                          'Progress unknown',
                          'İlerleme bilinmiyor',
                        )
                      : localized(
                          context,
                          "{v0} of {v1} self-reported complete",
                          "{v0} / {v1} öz beyanla tamamlandı",
                          values: {"v0": completed, "v1": lessons.length},
                        ),
                  key: const Key('guitar-journey-progress'),
                  style: monoText(color: hue.ink),
                ),
                if (completed != null) ...[
                  const SizedBox(height: 7),
                  LinearProgressIndicator(
                    value: completed / lessons.length,
                    color: hue.ink,
                    backgroundColor: OstinatoPalette.of(context).controlSurface,
                    minHeight: 6,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 17),
          const MeasuredPracticeCard(),
          if (progress == null) ...[
            const SizedBox(height: 17),
            GlassCard(
              key: const Key('guitar-progress-unavailable'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localized(
                      context,
                      'Your local progress could not be read. It has not been reset.',
                      'Yerel ilerlemen okunamadı. Kayıt sıfırlanmadı.',
                    ),
                    style: hankenText(size: 13.5, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localized(
                      context,
                      'You can read every lesson. Progress is unknown and recording is disabled until the saved record can be read.',
                      'Bütün dersleri okuyabilirsin. Kayıt okunana dek ilerleme bilinmiyor ve ilerleme kaydı kapalıdır.',
                    ),
                    style: hankenText(size: 12.5, height: 1.5),
                  ),
                  OutlinedButton(
                    onPressed: _reload,
                    child: Text(localized(context, 'Retry', 'Yeniden dene')),
                  ),
                ],
              ),
            ),
          ],
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
                  uiText(context, V1HomeCopy.noteToolBody),
                  style: hankenText(size: 12.5, height: 1.5),
                ),
                TextButton.icon(
                  key: const Key('guitar-note-observation-entry'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GuitarNoteObservationScreen(
                        preparation: _preparation,
                      ),
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
              key: const Key('guitar-journey-next'),
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
                      color: OstinatoPalette.of(context).textMuted,
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
          const FreeLessonsNotice(instrumentId: 'guitar'),
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
    Map<String, GuitarLessonProgress>? progress,
  ) {
    final done = progress == null
        ? null
        : module.lessons
              .where(
                (l) =>
                    _record(progress, course, l)?.selfReportedCompletedAt !=
                    null,
              )
              .length;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        key: Key('guitar-module-${module.id}'),
        initiallyExpanded:
            index == 0 ||
            (done != null && done > 0 && done < module.lessons.length),
        tilePadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 5),
        title: Text(
          '${index + 1}. ${module.title.of(context)}',
          style: hankenText(size: 16, weight: FontWeight.w600),
        ),
        subtitle: Text(
          done == null
              ? localized(context, 'Progress unknown', 'İlerleme bilinmiyor')
              : localized(
                  context,
                  "{v0} / 6 self-reported",
                  "{v0} / 6 öz beyan",
                  values: {"v0": done},
                ),
          style: monoText(),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 0, 17, 9),
            child: Text(
              module.goal.of(context),
              style: hankenText(
                size: 12.5,
                color: OstinatoPalette.of(context).textMuted,
              ),
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
                progress == null
                    ? localized(
                        context,
                        'PROGRESS UNKNOWN',
                        'İLERLEME BİLİNMİYOR',
                      )
                    : _statusText(context, _record(progress, course, lesson)),
                style: monoText(),
              ),
              trailing:
                  subscriptionLessonMark(
                    context,
                    'guitar',
                    course.lessons.indexOf(lesson),
                  ) ??
                  const Icon(Icons.chevron_right, size: 19),
              onTap: () => _openLesson(context, course, lesson, progress),
            ),
        ],
      ),
    );
  }

  String _statusText(BuildContext context, GuitarLessonProgress? record) {
    if (record?.selfReportedCompletedAt != null) {
      final date = MaterialLocalizations.of(
        context,
      ).formatMediumDate(record!.selfReportedCompletedAt!.toLocal());
      return localized(
        context,
        "SELF-REPORTED · {v0}",
        "ÖZ BEYAN · {v0}",
        values: {"v0": date},
      );
    }
    if ((record?.practiceCount ?? 0) > 0) {
      return localized(
        context,
        "PRACTISED ×{v0}",
        "ÇALIŞILDI ×{v0}",
        values: {"v0": record?.practiceCount ?? 0},
      );
    }
    if (record?.seenAt != null) return localized(context, 'VIEWED', 'GÖRÜLDÜ');
    return localized(context, 'NOT STARTED', 'BAŞLANMADI');
  }

  Future<void> _openLesson(
    BuildContext context,
    GuitarJourneyCourse course,
    GuitarJourneyLesson lesson,
    Map<String, GuitarLessonProgress>? progress,
  ) async {
    final store = _store!;
    // Paywall A: opening a paid lesson needs membership; its progress record
    // above stays readable either way.
    if (!await admitLesson(context, 'guitar', course.lessons.indexOf(lesson)) ||
        !context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GuitarJourneyLessonScreen(
          course: course,
          lesson: lesson,
          store: store,
          progressReadOnly: progress == null,
          initial: _record(progress, course, lesson),
          previousVersion: lesson.progressRevision == null
              ? null
              : progress?['${course.contentVersion}|${lesson.id}'],
          preparation: _preparation,
        ),
      ),
    );
    if (mounted && identical(_store, store)) _reload();
  }
}

class GuitarJourneyLessonScreen extends StatefulWidget {
  const GuitarJourneyLessonScreen({
    super.key,
    required this.course,
    required this.lesson,
    required this.store,
    this.initial,
    this.previousVersion,
    this.preparation,
    this.progressReadOnly = false,
  });
  final GuitarJourneyCourse course;
  final GuitarJourneyLesson lesson;
  final GuitarJourneyProgressStore store;
  final GuitarLessonProgress? initial;
  final GuitarLessonProgress? previousVersion;
  final GuitarSessionPreparation? preparation;
  // Unknown history must not become an empty writable progress record.
  final bool progressReadOnly;

  @override
  State<GuitarJourneyLessonScreen> createState() =>
      _GuitarJourneyLessonScreenState();
}

class _GuitarJourneyLessonScreenState extends State<GuitarJourneyLessonScreen> {
  late GuitarLessonProgress? _record = widget.initial;
  late final GuitarSessionPreparation _preparation =
      widget.preparation ?? GuitarSessionPreparation();
  bool _saving = false;
  bool _observationOnly = false;
  bool _firstReadScoreRevealed = false;

  bool get _needsPreparation => !const {
    'guitar.journey.start.parts',
    'guitar.journey.start.setup',
    'guitar.journey.start.tuning',
  }.contains(widget.lesson.id);

  bool get _mayRecordPractice =>
      !widget.progressReadOnly &&
      (!_needsPreparation || _preparation.isAcknowledged);

  @override
  void initState() {
    super.initState();
    _preparation.addListener(_onPreparationChanged);
  }

  void _onPreparationChanged() {
    if (mounted) setState(() {});
  }

  Widget _previousCompletionCard(BuildContext context) {
    final completed = widget.previousVersion!.selfReportedCompletedAt!;
    final date = MaterialLocalizations.of(
      context,
    ).formatShortDate(completed.toLocal());
    return GlassCard(
      key: const Key('guitar-previous-version-completion'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kicker(
            localized(context, 'EARLIER PRACTICE', 'ÖNCEKİ ÇALIŞMA'),
            color: OstinatoPalette.of(context).guitar.ink,
          ),
          const SizedBox(height: 6),
          Text(
            localized(
              context,
              "You self-reported completing an earlier version on {v0}. That record remains saved; new required material has its own practice record.",
              "Önceki sürümü {v0} tarihinde tamamladığını beyan ettin. O kayıt korunuyor; yeni zorunlu içeriğin ayrı bir çalışma kaydı var.",
              values: {"v0": date},
            ),
            style: hankenText(size: 12.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _preparation.removeListener(_onPreparationChanged);
    if (widget.preparation == null) _preparation.dispose();
    super.dispose();
  }

  Future<void> _save(GuitarProgressAction action) async {
    // Also guard stale callbacks; disabling the three controls is not enough.
    if (widget.progressReadOnly || _saving) return;
    if (action != GuitarProgressAction.viewed && !_mayRecordPractice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localized(
              context,
              'Check this session\'s setup before recording practice.',
              'Çalışmayı kaydetmeden önce bu oturumun hazırlığını denetle.',
            ),
          ),
        ),
      );
      return;
    }
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
        contentVersion: widget.lesson.progressVersionFor(
          widget.course.contentVersion,
        ),
        action: action,
      );
      if (action == GuitarProgressAction.practiced) {
        // F5.2: an existing lesson event counts toward the weekly goal.
        recordLessonPracticeInBackground(
          WeeklyGoalStore(
            accountUserId: widget.store.accountUserId,
            directoryProvider: widget.store.directoryProvider,
          ),
          PracticeCourse.guitar,
        );
      }
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
    final hue = OstinatoPalette.of(context).guitar;
    return Scaffold(
      backgroundColor: OstinatoPalette.of(context).surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassIconButton(
                key: const Key('guitar-lesson-back'),
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
                lesson.capstone
                    ? localized(
                        context,
                        'ORIGINAL PERFORMANCE',
                        'ÖZGÜN PERFORMANS',
                      )
                    : localized(context, 'GUITAR LESSON', 'GİTAR DERSİ'),
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
                  "{v0} MIN · SELF-GUIDED",
                  "{v0} DK · KENDİ ÇALIŞMAN",
                  values: {"v0": lesson.minutes},
                ),
                style: monoText(),
              ),
              LessonMediaSlot.empty(
                lessonId: lesson.id,
                locale: Localizations.localeOf(context).languageCode,
              ),
              const SizedBox(height: 17),
              if (widget.progressReadOnly) ...[
                GlassCard(
                  key: const Key('guitar-lesson-progress-unavailable'),
                  child: Text(
                    localized(
                      context,
                      'Progress is unknown. You can read this lesson, but progress recording is disabled. Return to the course to retry reading the saved record.',
                      'İlerleme bilinmiyor. Bu dersi okuyabilirsin; ilerleme kaydı kapalıdır. Kaydı okumayı yeniden denemek için kursa dön.',
                    ),
                    style: hankenText(size: 12.5, height: 1.5),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (!widget.progressReadOnly &&
                  widget.previousVersion?.selfReportedCompletedAt != null) ...[
                _previousCompletionCard(context),
                const SizedBox(height: 12),
              ],
              if (_needsPreparation && !_preparation.isAcknowledged)
                _preparationCard(context),
              if (_needsPreparation && _preparation.isAcknowledged)
                _preparedCard(context),
              if (widget.progressReadOnly ||
                  !_needsPreparation ||
                  _preparation.isAcknowledged ||
                  _observationOnly) ...[
                if (lesson.prerequisiteIds.isNotEmpty)
                  _section(
                    context,
                    'Before this lesson',
                    'Bu dersten önce',
                    localized(
                      context,
                      'Practise {v0} and use its self-check before continuing. Return to the course to revisit it.',
                      '{v0} dersini çalış ve devam etmeden öz denetimini yap. Yeniden açmak için kursa dön.',
                      values: {
                        'v0': widget.course.lessons
                            .firstWhere(
                              (l) => l.id == lesson.prerequisiteIds.single,
                            )
                            .title
                            .of(context),
                      },
                    ),
                  ),
                _section(
                  context,
                  'Goal',
                  'Hedef',
                  lesson.objective.of(context),
                ),
                if (lesson.id == 'guitar.journey.reading.staff')
                  const GuitarStaffDiagram(),
                if (lesson.learningLab == null)
                  _section(
                    context,
                    'Learn',
                    'Öğren',
                    lesson.teachingSteps
                        .asMap()
                        .entries
                        .map(
                          (e) =>
                              '${appInteger(context, e.key + 1)}. ${e.value.of(context)}',
                        )
                        .join('\n\n'),
                  ),
                if (lesson.id.endsWith('.tuning')) _tuningCard(context),
                if (lesson.shapeIds.isNotEmpty) _shapeCard(context),
                if (lesson.learningLab case final lab?)
                  _practiceLab(context, lab)
                else
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
                if (lesson.learningLab != null)
                  ExpansionTile(
                    key: Key('guitar-lab-microphone-${lesson.id}'),
                    title: Text(
                      localized(
                        context,
                        'About microphone feedback',
                        'Mikrofon geri bildirimi hakkında',
                      ),
                      style: hankenText(size: 13.5),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    children: [
                      Text(
                        localized(
                          context,
                          'With your permission, the microphone shows approximate single-note observations. It does not verify these exercises or change your progress.',
                          'İzin verirsen mikrofon yaklaşık tek nota gözlemi gösterir. Bu alıştırmaları doğrulamaz ve ilerleme kaydını değiştirmez.',
                        ),
                        style: hankenText(size: 12.5, height: 1.5),
                      ),
                    ],
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
                      if (widget.course.progressSemantics
                          case final explanation?) ...[
                        Text(
                          explanation.of(context),
                          style: hankenText(
                            size: 12,
                            color: OstinatoPalette.of(context).textMuted,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Text(
                        widget.progressReadOnly
                            ? localized(
                                context,
                                'Practice entries: unknown',
                                'Çalışma kaydı: bilinmiyor',
                              )
                            : localized(
                                context,
                                "Practice entries: {v0}",
                                "Çalışma kaydı: {v0}",
                                values: {"v0": _record?.practiceCount ?? 0},
                              ),
                        style: monoText(),
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            key: const Key('guitar-progress-viewed'),
                            onPressed:
                                widget.progressReadOnly ||
                                    _saving ||
                                    _record?.seenAt != null
                                ? null
                                : () => _save(GuitarProgressAction.viewed),
                            child: Text(
                              localized(context, 'Mark viewed', 'Okudum'),
                            ),
                          ),
                          OutlinedButton(
                            key: const Key('guitar-progress-practiced'),
                            onPressed: _saving || !_mayRecordPractice
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
                            key: const Key('guitar-progress-completed'),
                            onPressed:
                                widget.progressReadOnly ||
                                    _saving ||
                                    !_mayRecordPractice ||
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _preparationCard(BuildContext context) => GlassCard(
    key: const Key('guitar-session-preparation'),
    gradientColors: OstinatoPalette.of(context).guitar.grad,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        kicker(
          localized(context, 'BEFORE PLAYING TODAY', 'BUGÜN ÇALMADAN ÖNCE'),
          color: OstinatoPalette.of(context).guitar.ink,
        ),
        const SizedBox(height: 9),
        Text(
          localized(
            context,
            'Support the guitar with a stable seat, strap or other support so both hands can release. If useful, check string letters and octaves with an external tuner; do not force a peg when unsure. Begin with a few easy open-string plucks and full hand release.',
            'Gitarı sabit koltuk, askı veya destekle taşı; iki elini de gevşetebil. Gerekirse tel adlarını ve oktavları harici akort cihazıyla denetle; emin değilsen burguyu zorlama. Birkaç kolay açık tel sesi ve tam el gevşetmesiyle başla.',
          ),
          style: hankenText(size: 13.5, height: 1.55),
        ),
        const SizedBox(height: 9),
        Text(
          localized(
            context,
            'Pause for hand, neck, shoulder or hearing discomfort or tingling. Read without playing, or stop and seek individual advice if symptoms persist. This check is your choice; the app makes no tuning, posture or safety verdict.',
            'El, boyun, omuz veya işitme rahatsızlığı ya da karıncalanmada ara ver. Çalmadan oku; belirtiler sürerse durup kişisel görüş al. Bu denetim senin seçimin; uygulama akort, duruş veya güvenlik hükmü vermez.',
          ),
          style: hankenText(size: 12.5, height: 1.5),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              key: const Key('guitar-session-acknowledge'),
              onPressed: () {
                setState(() => _observationOnly = false);
                _preparation.acknowledge();
              },
              child: Text(
                localized(
                  context,
                  'I checked this and will practise',
                  'Denetledim, çalışacağım',
                ),
              ),
            ),
            OutlinedButton(
              key: const Key('guitar-session-observe'),
              onPressed: () => setState(() => _observationOnly = true),
              child: Text(localized(context, 'Read only', 'Yalnız oku')),
            ),
          ],
        ),
        if (_observationOnly) ...[
          const SizedBox(height: 9),
          Text(
            localized(
              context,
              'Reading only: practice and completion recording are unavailable until you check this session\'s setup.',
              'Yalnız okuma: bu oturumun hazırlığını denetleyene dek çalışma ve tamamlama kaydı kapalıdır.',
            ),
            style: hankenText(size: 12.5, height: 1.5),
          ),
        ],
      ],
    ),
  );

  Widget _preparedCard(BuildContext context) => GlassCard(
    key: const Key('guitar-session-prepared'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localized(
            context,
            'You reported preparing for this session. This is not an app safety or tuning check.',
            'Bu oturuma hazırlandığını bildirdin. Bu, uygulamanın güvenlik veya akort denetimi değildir.',
          ),
          style: hankenText(size: 12.5, height: 1.5),
        ),
        TextButton(
          key: const Key('guitar-session-after-break'),
          onPressed: () {
            setState(() => _observationOnly = false);
            _preparation.afterBreak();
          },
          child: Text(
            localized(
              context,
              'After a break: prepare again',
              'Aradan sonra: yeniden hazırlan',
            ),
          ),
        ),
      ],
    ),
  );

  Widget _practiceLab(
    BuildContext context,
    GuitarJourneyLearningLab lab,
  ) => Column(
    key: Key('guitar-learning-lab-${widget.lesson.id}'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        localized(
          context,
          'Work in short sessions. The time and rounds below are flexible suggestions; pause or use the easier version when needed.',
          'Kısa oturumlarda çalış. Aşağıdaki süre ve turlar esnek önerilerdir; gerektiğinde ara ver veya kolay sürümü kullan.',
        ),
        style: hankenText(size: 12.5, height: 1.5),
      ),
      const SizedBox(height: 10),
      for (final drill in lab.drills)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            key: Key('guitar-drill-${drill.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                kicker(switch (drill.stage) {
                  'foundation' => localized(
                    context,
                    'Foundation',
                    'Temel çalışma',
                  ),
                  'connected' => localized(
                    context,
                    'Put it together',
                    'Birleştir',
                  ),
                  _ => localized(
                    context,
                    'Try another context',
                    'Farklı durumda dene',
                  ),
                }, color: OstinatoPalette.of(context).guitar.ink),
                const SizedBox(height: 8),
                if (drill.firstReadScore case final score?) ...[
                  if (!_firstReadScoreRevealed)
                    OutlinedButton(
                      key: const Key('guitar-first-read-reveal'),
                      onPressed: () =>
                          setState(() => _firstReadScoreRevealed = true),
                      child: Text(
                        localized(
                          context,
                          'Reveal the original score when ready',
                          'Hazır olduğunda özgün porteyi göster',
                        ),
                      ),
                    )
                  else ...[
                    Text(
                      localized(
                        context,
                        'Use the four staff bars or their accessible note-and-duration text to count each beat, then play once. Make your own attempt before viewing a demonstration.',
                        'Dört porteli ölçüyü veya erişilebilir nota ve süre metnini kullanarak her vuruşu say, ardından bir kez çal. Bir gösterimi izlemeden önce kendi denemeni yap.',
                      ),
                      style: hankenText(size: 13.5, height: 1.55),
                    ),
                    const SizedBox(height: 8),
                    GuitarFirstReadScore(score: score),
                    const SizedBox(height: 8),
                    Text(
                      drill.task.of(context),
                      style: hankenText(size: 13.5, height: 1.55),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localized(
                        context,
                        'This fixed card can be a first read only once. Later visits are familiar reading, and the app does not grade it.',
                        'Bu sabit kart yalnız bir kez ilk okuma olabilir. Sonraki ziyaretler tanıdık okumadır; uygulama bunu puanlamaz.',
                      ),
                      style: hankenText(size: 12.5, height: 1.5),
                    ),
                  ],
                ] else
                  Text(
                    drill.task.of(context),
                    style: hankenText(size: 13.5, height: 1.55),
                  ),
                const SizedBox(height: 8),
                Text(
                  localized(
                    context,
                    'About {v0}–{v1} min · {v2} short rounds',
                    'Yaklaşık {v0}–{v1} dk · {v2} kısa tur',
                    values: {
                      'v0': drill.minutesRange.first,
                      'v1': drill.minutesRange.last,
                      'v2': drill.rounds,
                    },
                    pluralCount: drill.rounds,
                  ),
                  style: hankenText(
                    size: 11.5,
                    color: OstinatoPalette.of(context).textMuted,
                  ),
                ),
                if (drill.optionalExtension) ...[
                  const SizedBox(height: 6),
                  Text(
                    localized(
                      context,
                      'An optional next step for later sessions.',
                      'Sonraki oturumlar için isteğe bağlı bir adım.',
                    ),
                    style: hankenText(
                      size: 11.5,
                      color: OstinatoPalette.of(context).textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      _section(
        context,
        'Listen and notice',
        'Dinle ve fark et',
        lab.earTraining.of(context),
      ),
      _section(
        context,
        'Return to it later',
        'Sonra yeniden dene',
        '${lab.retentionTask.of(context)}\n\n${localized(context, 'You can try again after 1, 3 or 7 days. This is a flexible reminder, not a proven timetable for learning guitar.', '1, 3 veya 7 gün sonra yeniden deneyebilirsin. Bu esnek bir hatırlatmadır; gitar öğrenmek için kanıtlanmış takvim değildir.')}',
      ),
    ],
  );

  Widget _section(BuildContext context, String en, String tr, String body) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              kicker(
                localized(context, en, tr),
                color: OstinatoPalette.of(context).guitar.ink,
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
            color: OstinatoPalette.of(context).guitar.ink,
          ),
          const SizedBox(height: 9),
          for (final string in widget.course.tuning)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                localized(
                  context,
                  "String {v0} · {v1} · {v2} Hz",
                  "{v0}. tel · {v1} · {v2} Hz",
                  values: {
                    "v0": string.number,
                    "v1": string.note,
                    "v2": AppDecimal(string.hz, 2),
                  },
                ),
                style: monoText(
                  size: 10.5,
                  color: OstinatoPalette.of(context).textBody,
                ),
              ),
            ),
          const SizedBox(height: 7),
          Text(
            localized(
              context,
              'These are standard-tuning reference frequencies, not live readings or sound-level measurements.',
              'Bunlar standart akort referans frekanslarıdır; canlı okuma veya ses düzeyi ölçümü değildir.',
            ),
            style: hankenText(
              size: 12,
              color: OstinatoPalette.of(context).textMuted,
            ),
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
            color: OstinatoPalette.of(context).guitar.ink,
          ),
          const SizedBox(height: 6),
          Text(
            localized(
              context,
              'Strings run thick to thin (6→1). × = do not play; 0 = open. Finger numbers are examples, not a required grip.',
              'Teller kalından inceye (6→1) gider. × = çalma; 0 = açık. Parmak sayıları zorunlu tutuş değil, örnektir.',
            ),
            style: hankenText(
              size: 12,
              color: OstinatoPalette.of(context).textMuted,
            ),
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
                          color: OstinatoPalette.of(context).guitar.chip,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${6 - i}',
                              style: monoText(
                                size: 9,
                                color: OstinatoPalette.of(context).guitar.ink,
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
                style: hankenText(
                  size: 10.5,
                  color: OstinatoPalette.of(context).textFaint,
                ),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    ),
  );
}

/// Ölçülü pratik kartı (v1 metni C1, kurucu 2026-11-01): gitar sayfasının
/// birincil kartı. Düğme ilk geçilmemiş açık dersi doğrudan açar.
class MeasuredPracticeCard extends StatelessWidget {
  const MeasuredPracticeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final accountId = AccountScope.maybeOf(context)?.currentUserId;
    return GlassCard(
      key: const Key('measured-practice-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            uiText(context, V1HomeCopy.measuredTitle),
            style: hankenText(size: 18, weight: FontWeight.w600),
          ),
          const SizedBox(height: 7),
          Text(
            uiText(context, V1HomeCopy.measuredBody),
            style: hankenText(size: 12.5, height: 1.5),
          ),
          TextButton.icon(
            key: const Key('guitar-measured-practice-entry'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => V1PracticeListScreen(
                  startNext: true,
                  // F5.2: a measured run counts toward the weekly goal
                  // (≥60 s listening, ≥1 heard note). A failed write must
                  // not interrupt the result screen.
                  onSessionFinished: (e) =>
                      WeeklyGoalStore(accountUserId: accountId)
                          .recordPracticeSession(
                            MeasuredPracticeSession(
                              course: PracticeCourse.guitar,
                              activeDuration: e.activeDuration,
                              heardEvents: e.heardEvents,
                              lessonId: e.lessonId,
                            ),
                          )
                          .then<void>((_) {}, onError: (_) {}),
                ),
              ),
            ),
            icon: const Icon(Icons.graphic_eq),
            label: Text(uiText(context, V1HomeCopy.startNext)),
          ),
        ],
      ),
    );
  }
}
