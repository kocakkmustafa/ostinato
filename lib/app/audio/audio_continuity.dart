/// Timestamp continuity is an input hygiene check, never AV synchronization or
/// a physical timing tolerance. Android currently estimates chunk start from
/// read completion; allow 20 ms scheduling jitter, then discard prior context.
enum AudioContinuityResult { continuous, recalibrate, invalid }

final class AudioContinuity {
  static const schedulingJitterUs = 20000;
  int? _lastStartUs, _expectedStartUs, _rate;

  void reset() {
    _lastStartUs = _expectedStartUs = _rate = null;
  }

  AudioContinuityResult observe({
    required int startUs,
    required int sampleRate,
    required int sampleCount,
  }) {
    if (startUs < 0 ||
        sampleRate <= 0 ||
        sampleCount <= 0 ||
        (_lastStartUs != null && startUs <= _lastStartUs!)) {
      return AudioContinuityResult.invalid;
    }
    final changed = _rate != null && _rate != sampleRate;
    final gap =
        _expectedStartUs != null &&
        (startUs - _expectedStartUs!).abs() > schedulingJitterUs;
    _lastStartUs = startUs;
    _expectedStartUs = startUs + (sampleCount * 1000000 / sampleRate).round();
    _rate = sampleRate;
    return changed || gap
        ? AudioContinuityResult.recalibrate
        : AudioContinuityResult.continuous;
  }
}
