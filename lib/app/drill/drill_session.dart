import 'drill_generator.dart';

/// F2.6 — one pass through a drill (pure Dart). The score counts first tries
/// only. A question answered differently comes back once at the end (the
/// "mixed-up queue"); that second try teaches but never changes the score.
/// No time score (lesson guide §3).
final class DrillSession {
  DrillSession(List<DrillQuestion> questions, {this.passShare = 0.8})
    : _queue = List.of(questions),
      total = questions.length {
    if (questions.isEmpty) throw ArgumentError('A drill needs questions');
  }

  final double passShare;
  final int total;
  final List<DrillQuestion> _queue;
  int _position = 0;
  int _firstTries = 0;
  int matched = 0;

  /// The chosen option of the current question, once answered.
  int? chosen;

  DrillQuestion get current => _queue[_position];

  /// True while the current question is a second try from the queue.
  bool get isReview => _position >= total;

  /// 1-based number of the current question within the first pass.
  int get number => isReview ? total : _position + 1;

  bool get answered => chosen != null;
  bool get matchedCurrent => chosen == current.answer;
  bool get finished => _position >= _queue.length;

  /// The current question is the last one (a differing answer just now
  /// queues a second try, so ask after [choose]).
  bool get onLast => _position == _queue.length - 1;

  /// Questions needed to pass (80% of the first pass, rounded up).
  int get needed => (total * passShare - 1e-9).ceil();
  bool get passed => finished && matched >= needed;

  void choose(int option) {
    if (answered || finished) return;
    if (option < 0 || option >= current.options.length) {
      throw RangeError.index(option, current.options);
    }
    _answer(option);
  }

  /// What the learner wrote for a dictation question (null otherwise).
  List<String>? written;

  /// F2.6d: a written answer. It matches when its canonical key equals the
  /// expected one; otherwise it counts as a different answer (index −1).
  void submit(List<String> entered) {
    final entry = current.entry;
    if (answered || finished || entry == null) return;
    written = List.unmodifiable(entered);
    _answer(entry.keyOf(entered) == current.expected ? current.answer : -1);
  }

  void _answer(int option) {
    chosen = option;
    if (!isReview) {
      _firstTries++;
      if (option == current.answer) {
        matched++;
      } else {
        _queue.add(current);
      }
    }
  }

  void next() {
    if (!answered) return;
    chosen = null;
    written = null;
    _position++;
  }

  int get firstTries => _firstTries;
}
