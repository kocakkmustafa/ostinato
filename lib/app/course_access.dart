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
