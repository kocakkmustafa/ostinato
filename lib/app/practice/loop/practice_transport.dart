import 'dart:math' as math;

import 'practice_score.dart';

/// F2.3 — where the lesson is, given where the metronome is (pure Dart).
///
/// Lesson beat `L = m − countIn − shift`, with `m` the metronome beat on the
/// capture clock. `shift` (whole beats) grows when a loop wraps or when
/// "Wait for me" releases a held note, so every note still lands on a click.
final class PracticeTransport {
  PracticeTransport({
    required this.score,
    required this.countInBeats,
    this.loop,
    this.waitMode = false,
  }) {
    final l = loop;
    if (l != null &&
        (l.start < 0 || l.end > score.totalBeats || l.end <= l.start)) {
      throw ArgumentError('Loop outside the score');
    }
  }

  final PracticeScore score;
  final int countInBeats;

  /// Lesson-beat range repeated until stopped; null = play once.
  final ({double start, double end})? loop;

  /// "Wait for me": the line stops at each note until it is heard (or skipped).
  final bool waitMode;

  double _shift = 0;
  bool _started = false;
  double _floor = double.negativeInfinity;
  int _pass = 0;
  int _nextEvent = 0;
  int? _held;
  int? _heldPass;
  double? _heldMetronomeBeat;
  bool _finished = false;

  int get pass => _pass;
  bool get finished => _finished;
  int? get heldEvent => _held;

  /// Metronome beat at which the held note was reached.
  double? get heldSinceMetronomeBeat => _heldMetronomeBeat;

  double get _startBeat => loop?.start ?? 0;
  double get _endBeat => loop?.end ?? score.totalBeats;

  /// Metronome beat at which lesson beat [lessonBeat] sounds now.
  double metronomeBeatFor(double lessonBeat) =>
      countInBeats + _shift + lessonBeat;

  /// Advances to metronome beat [m]; returns the display beat and every note
  /// whose start was crossed (each loop pass reports its notes again).
  TransportStep advance(double m) {
    final reached = <ReachedEvent>[];
    if (_finished) {
      return TransportStep(_endBeat, reached, finished: true);
    }
    if (!_started) {
      // A loop starts right after the count-in at its own first beat.
      _started = true;
      _shift = -_startBeat;
      _nextEvent = _firstIndexAtOrAfter(_startBeat);
    }
    if (_held != null) {
      return TransportStep(score.events[_held!].startBeat, reached);
    }
    var lesson = m - countInBeats - _shift;
    var guard = 0;
    while (guard++ < 1000) {
      // Report notes whose start lies in (last, lesson].
      while (_nextEvent < score.events.length) {
        final e = score.events[_nextEvent];
        if (e.startBeat >= _endBeat || e.startBeat > lesson) break;
        if (e.startBeat >= _startBeat) {
          reached.add(
            ReachedEvent(
              event: e,
              pass: _pass,
              metronomeBeat: metronomeBeatFor(e.startBeat),
            ),
          );
          if (waitMode) {
            _held = _nextEvent;
            _heldPass = _pass;
            _heldMetronomeBeat = m;
            _nextEvent++;
            return TransportStep(e.startBeat, reached);
          }
        }
        _nextEvent++;
      }
      if (lesson < _endBeat) break;
      if (loop == null) {
        _finished = true;
        return TransportStep(_endBeat, reached, finished: true);
      }
      // Wrap the loop.
      _shift += _endBeat - _startBeat;
      _pass++;
      _floor = double.negativeInfinity;
      _nextEvent = _firstIndexAtOrAfter(_startBeat);
      lesson = m - countInBeats - _shift;
    }
    return TransportStep(math.max(lesson, _floor), reached);
  }

  /// Releases the held note at metronome beat [m]: the next note keeps its
  /// written distance and lands on a later click.
  void releaseHeld(double m) {
    final held = _held;
    if (held == null) return;
    final s = score.events[held].startBeat;
    final needed = (m - countInBeats - s).ceilToDouble();
    _shift = math.max(_shift, needed);
    _floor = s;
    _held = null;
    _heldPass = null;
    _heldMetronomeBeat = null;
  }

  int? get heldPass => _heldPass;

  int _firstIndexAtOrAfter(double beat) {
    for (var i = 0; i < score.events.length; i++) {
      if (score.events[i].startBeat >= beat) return i;
    }
    return score.events.length;
  }
}

final class ReachedEvent {
  const ReachedEvent({
    required this.event,
    required this.pass,
    required this.metronomeBeat,
  });
  final PracticeEvent event;
  final int pass;

  /// Metronome beat at which this note is expected (capture-clock grid).
  final double metronomeBeat;
}

final class TransportStep {
  const TransportStep(this.displayBeat, this.reached, {this.finished = false});

  /// Lesson beat under the NOW line.
  final double displayBeat;
  final List<ReachedEvent> reached;
  final bool finished;
}

/// Tempo choice: 40–120 % of the lesson's target (contract §6.3), default
/// the opening tempo. Free-tempo lessons (null) have no metronome.
final class PracticeTempo {
  PracticeTempo({required this.openBpm, required this.targetBpm, int? bpm})
    : bpm = (bpm ?? openBpm).clamp(minBpm(targetBpm), maxBpm(targetBpm)) {
    if (openBpm > targetBpm) throw ArgumentError('open > target');
  }

  final int openBpm;
  final int targetBpm;
  final int bpm;

  static int minBpm(int target) => math.max(20, (target * .4).round());
  static int maxBpm(int target) => math.min(300, (target * 1.2).round());

  int get percent => (bpm * 100 / targetBpm).round();
  bool get atTarget => bpm >= targetBpm;
  bool get atOpening => bpm >= openBpm;

  PracticeTempo withBpm(int next) =>
      PracticeTempo(openBpm: openBpm, targetBpm: targetBpm, bpm: next);

  /// Tempo ladder (FK6): +5 BPM, never above 120 %.
  PracticeTempo stepped(int delta) => withBpm(bpm + delta);
}
