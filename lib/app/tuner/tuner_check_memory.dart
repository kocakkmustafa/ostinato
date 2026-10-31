import 'package:flutter/foundation.dart';

/// The latest tuner result of today, kept only in RAM (no file, no network).
/// The session tuning gate reads it; a new day or an app restart forgets it.
final class TunerCheck {
  const TunerCheck({
    required this.presetId,
    required this.inTune,
    required this.total,
    required this.at,
  });

  final String presetId;
  final int inTune, total;
  final DateTime at;

  int get notInTune => total - inTune;
  bool get allInTune => inTune >= total;
}

final class TunerCheckMemory extends ChangeNotifier {
  TunerCheckMemory({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static final TunerCheckMemory instance = TunerCheckMemory();

  final DateTime Function() _now;
  TunerCheck? _last;
  DateTime? _continuedAt;

  /// Today's check, or null when there was none today.
  TunerCheck? get today {
    final last = _last;
    if (last == null || !_sameDay(last.at, _now())) return null;
    return last;
  }

  /// "Continue anyway" was chosen today at the gate.
  bool get continuedWithoutTuning {
    final at = _continuedAt;
    return at != null && today == null && _sameDay(at, _now());
  }

  void record({
    required String presetId,
    required int inTune,
    required int total,
  }) {
    _last = TunerCheck(
      presetId: presetId,
      inTune: inTune,
      total: total,
      at: _now(),
    );
    _continuedAt = null;
    notifyListeners();
  }

  void continueWithoutTuning() {
    _continuedAt = _now();
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    _last = null;
    _continuedAt = null;
    notifyListeners();
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final x = a.toLocal(), y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }
}
