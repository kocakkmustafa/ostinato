import 'package:flutter/material.dart';
import 'package:motion_entitlements/motion_entitlements.dart'
    show isLessonUnlocked;

import 'account_connection.dart';
import 'app_locale.dart';
import 'ostinato_release_policy.dart';

/// Paywall A (founder decision 2026-10-23, shared by the five Motion apps):
/// the first module or about a third of each course is free. Later lessons,
/// including guitar's independent-practice module, need an Ostinato or
/// Motion+ subscription. Only opening a paid lesson is gated: course lists,
/// titles and progress records always stay readable.
const Map<String, int> ostinatoFreeLessonCounts = {
  'guitar': 12,
  'piano': 8,
  'ukulele': 8,
  'bass': 8,
  'voice': 8,
};

/// Course shapes passed to Core's lesson lock. Guitar has ten six-lesson
/// modules; the other courses have no module structure, so their first-module
/// count is 0 and only the approved free count above applies.
/// `test/course_access_test.dart` checks the totals against the bundled
/// course files.
const Map<String, ({int totalLessons, int firstModuleLessonCount})>
ostinatoCourseShapes = {
  'guitar': (totalLessons: 60, firstModuleLessonCount: 6),
  'piano': (totalLessons: 25, firstModuleLessonCount: 0),
  'ukulele': (totalLessons: 24, firstModuleLessonCount: 0),
  'bass': (totalLessons: 24, firstModuleLessonCount: 0),
  'voice': (totalLessons: 22, firstModuleLessonCount: 0),
};

/// Core `isLessonUnlocked` for a non-member, with the app's approved free
/// counts as the override (OST-K2, founder decision 2026-10-25). An unknown
/// course or an index outside the course has no free lessons (closed by
/// default). With sales closed nothing is gated, as before the paywall.
bool isFreeLesson(
  String instrumentId,
  int index, {
  bool paidFeaturesAvailable = ostinatoPaidFeaturesAvailable,
}) {
  if (!paidFeaturesAvailable) return true;
  final shape = ostinatoCourseShapes[instrumentId];
  if (shape == null || index < 0 || index >= shape.totalLessons) return false;
  return isLessonUnlocked(
    lessonIndex: index,
    totalLessons: shape.totalLessons,
    firstModuleLessonCount: shape.firstModuleLessonCount,
    entitled: false,
    freeLessonLimit: ostinatoFreeLessonCounts[instrumentId],
  );
}

/// Admits a lesson open. A paid lesson goes through the account's paid-access
/// guard (Core: sign-in, server membership check, then the membership page).
/// Without an account service the paid lesson stays closed and says why.
Future<bool> admitLesson(
  BuildContext context,
  String instrumentId,
  int index, {
  bool paidFeaturesAvailable = ostinatoPaidFeaturesAvailable,
}) async {
  if (isFreeLesson(
    instrumentId,
    index,
    paidFeaturesAvailable: paidFeaturesAvailable,
  )) {
    return true;
  }
  return _requirePaidAccess(context);
}

/// v1 paywall (founder decision 2026-11-02): every lesson of the listed
/// stages is free, for each v1 course (`gtr`, `ear`); later stages need a
/// membership. Guitar S1 = modules 1–4 plus `gtr-s1-test` (40 lessons); ear
/// S1 = 25 lessons. This map is the single place the free scope lives: add or
/// remove a stage id here and the gate, the list marks and the tests follow.
/// A course missing from the map has no free lessons (closed by default).
const Map<String, Set<String>> ostinatoV1FreeStages = {
  'gtr': {'s1'},
  'ear': {'s1'},
};

final RegExp _v1LessonId = RegExp(r'^([a-z]+)-(s\d+)-');

/// Whether a v1 lesson (`gtr-s1-m01-03`, `gtr-s1-test`, `ear-s2-m05-01`)
/// opens without a membership. An id that is not a v1 lesson id is paid.
/// With sales closed nothing is gated.
bool isFreeV1Lesson(
  String lessonId, {
  bool paidFeaturesAvailable = ostinatoPaidFeaturesAvailable,
  Map<String, Set<String>> freeStages = ostinatoV1FreeStages,
}) {
  if (!paidFeaturesAvailable) return true;
  final m = _v1LessonId.firstMatch(lessonId);
  if (m == null) return false;
  return freeStages[m.group(1)]?.contains(m.group(2)) ?? false;
}

/// The single free level number shown in the v1 free-scope notice (`s1` → 1),
/// or null when the course's free scope is not exactly one stage.
int? v1FreeLevel(String course) {
  final stages = ostinatoV1FreeStages[course];
  if (stages == null || stages.length != 1) return null;
  return int.tryParse(stages.single.substring(1));
}

/// Admits opening a v1 lesson: free lessons open at once (no account
/// needed); a paid one goes through the same paid-access guard as
/// [admitLesson]. Independent of the course's module gate, which the caller
/// checks as before.
Future<bool> admitV1Lesson(
  BuildContext context,
  String lessonId, {
  bool paidFeaturesAvailable = ostinatoPaidFeaturesAvailable,
}) async {
  if (isFreeV1Lesson(lessonId, paidFeaturesAvailable: paidFeaturesAvailable)) {
    return true;
  }
  return _requirePaidAccess(context);
}

Future<bool> _requirePaidAccess(BuildContext context) async {
  final guard = AccountScope.maybeOf(context)?.connection?.requirePaidAccess;
  if (guard == null) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          localized(
            context,
            'This lesson needs a subscription, and the account service is unavailable right now.',
            'Bu ders abonelik gerektirir; hesap hizmeti şu anda kullanılamıyor.',
          ),
        ),
      ),
    );
    return false;
  }
  return guard(context);
}

/// Course-level statement of the free range, shown above every lesson list.
class FreeLessonsNotice extends StatelessWidget {
  const FreeLessonsNotice({super.key, required this.instrumentId});

  final String instrumentId;

  @override
  Widget build(BuildContext context) {
    if (!ostinatoPaidFeaturesAvailable) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        localized(
          context,
          'Lessons 1–{v0} are free. Later lessons need an Ostinato or Motion+ subscription; your progress records always stay visible.',
          '1–{v0}. dersler ücretsizdir. Sonraki dersler Ostinato veya Motion+ aboneliği gerektirir; ilerleme kayıtların her zaman görünür kalır.',
          values: {'v0': ostinatoFreeLessonCounts[instrumentId] ?? 0},
        ),
        key: Key('free-lessons-$instrumentId'),
      ),
    );
  }
}

/// Trailing mark for a lesson that needs a subscription; null when free.
Widget? subscriptionLessonMark(
  BuildContext context,
  String instrumentId,
  int index,
) {
  if (isFreeLesson(instrumentId, index)) return null;
  return Icon(
    Icons.lock_outline,
    size: 19,
    semanticLabel: localized(context, 'Subscription lesson', 'Abonelik dersi'),
  );
}
