import '../../ui_copy.dart';
import 'listen_try_fix_copy.dart';
import 'practice_marks.dart';

/// OST-UX-05e copy: why a note landed in "could not hear" on the stage
/// result layer. Neutral, never a verdict: no "wrong", no promise words.
/// `unclear` and `notMeasured` reuse pairs that already carry ids. Message ids
/// are in `lib/app/app_message_ids.dart`; the 14 catalogs hold the
/// translations; `test/ux_05e_result_layer_test.dart` scans them.
abstract final class ResultLayerCopy {
  static const UiCopy noAttack = (
    "I didn't hear a note start here.",
    'Burada bir notanın başladığını duymadım.',
  );
  static const UiCopy tooQuiet = (
    'This was too quiet for me to hear.',
    'Bu, duymam için fazla kısıktı.',
  );
  static const UiCopy tooLoud = (
    'This was loud enough to distort the sound.',
    'Bu, sesi bozacak kadar yüksekti.',
  );
  static const UiCopy appPlayback = (
    "The app's own sound was audible here, so I made no call on this note.",
    'Burada uygulamanın kendi sesi duyuldu; bu nota için karar vermedim.',
  );
  static const UiCopy skipped = (
    'You skipped this note in "Wait for me".',
    '"Beni bekle"de bu notayı atladın.',
  );

  /// Shared with the path layer (same pair, same id).
  static const UiCopy notMeasured = ('Not measured', 'Ölçülmedi');

  /// The neutral reason line for [reason].
  static UiCopy forReason(HearingReason reason) => switch (reason) {
    HearingReason.noAttack => noAttack,
    HearingReason.tooQuiet => tooQuiet,
    HearingReason.tooLoud => tooLoud,
    HearingReason.unclear => ListenTryFixCopy.couldNotMeasure,
    HearingReason.appPlayback => appPlayback,
    HearingReason.skipped => skipped,
  };

  /// The pairs this ticket adds (the rest are shared).
  static const List<UiCopy> newPairs = [
    noAttack,
    tooQuiet,
    tooLoud,
    appPlayback,
    skipped,
  ];
}
