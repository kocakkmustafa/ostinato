import 'practice_marks.dart';
import 'practice_outcome.dart';

/// A3 onset timing for rhythm-only lines (`4/4: q q ee q | h h`), pure Dart.
///
/// Contract `00-ders-format-sozlesmesi` §5 and §6.2, applied to a line whose
/// events are attacks with no pitch:
/// - **correct** = an attack inside the level's "on time" window;
/// - **different** = an attack heard clearly but outside that window: early
///   or late (shown as "early or late", never "wrong");
/// - **couldn't hear** = no attack in the beat's search window (silence is
///   never correct), or app playback audible; outside the on-time ratio.
///
/// The gate's accuracy check becomes the on-time ratio (§6.2 "penceredeki
/// onset oranı"). All values `expertPending`.
abstract final class RhythmTiming {
  /// §6.2 "Zamanlama (A3): 'zamanında' penceresi", per level.
  static const Map<int, int> onTimeWindowMs = {1: 90, 2: 75, 3: 60, 4: 50};

  /// §6.2 "Zamanlama: penceredeki onset oranı", per level.
  static const Map<int, double> onTimeRatio = {1: .75, 2: .80, 3: .80, 4: .85};
}

/// Where "on time" is for one run.
///
/// With a latency calibration for the run's route the click grid is exact
/// and the reference is 0 ms. Without one, the grid is off by the unmeasured
/// part of the round trip; the run's own median offset stands in for it, so
/// the run is judged on keeping a steady pulse with the click (a constant
/// lag cannot be told apart from latency). Live marks use the median so far;
/// [remark] re-decides every onset with the whole run's median at the end.
final class OnsetTimingReference {
  OnsetTimingReference({required this.calibrated, required this.windowMs});

  final bool calibrated;
  final int windowMs;
  final List<double> _offsets = [];

  /// Offset that counts as exactly on time, in ms.
  double get referenceMs =>
      calibrated || _offsets.isEmpty ? 0 : medianOf(_offsets);

  /// Records one heard attack ([offsetMs] = attack − grid time, negative =
  /// early) and returns its mark and its timing against the reference.
  ({PracticeMark mark, double timingMs}) add(double offsetMs) {
    _offsets.add(offsetMs);
    return judge(offsetMs);
  }

  ({PracticeMark mark, double timingMs}) judge(double offsetMs) {
    final timing = offsetMs - referenceMs;
    return (
      mark: timing.abs() <= windowMs
          ? PracticeMark.correct
          : PracticeMark.differentNote,
      timingMs: timing,
    );
  }

  /// End of run: the same decision for every heard onset, against the
  /// reference of the whole run. Outcomes without an offset (could not hear,
  /// "Wait for me") are kept as they are.
  List<NoteOutcome> remark(List<NoteOutcome> outcomes) => [
    for (final o in outcomes)
      if (o.offsetMs == null)
        o
      else
        () {
          final j = judge(o.offsetMs!);
          return NoteOutcome(
            eventIndex: o.eventIndex,
            bar: o.bar,
            pass: o.pass,
            mark: j.mark,
            reason: o.reason,
            timingMs: j.timingMs,
            offsetMs: o.offsetMs,
          );
        }(),
  ];

  static double medianOf(List<double> values) {
    final s = List<double>.of(values)..sort();
    final n = s.length;
    return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
  }
}
