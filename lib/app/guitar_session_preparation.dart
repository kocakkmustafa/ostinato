import 'dart:async';

import 'package:flutter/widgets.dart';

/// A learner's current-session preparation acknowledgement, kept only in RAM.
/// It is not a tuning, posture, health, or skill verdict.
final class GuitarSessionPreparation extends ChangeNotifier
    with WidgetsBindingObserver {
  GuitarSessionPreparation({DateTime Function()? now}) : _now = now ?? DateTime.now {
    WidgetsBinding.instance.addObserver(this);
  }

  final DateTime Function() _now;
  DateTime? _acknowledgedDate;
  Timer? _dateBoundary;

  bool get isAcknowledged {
    final date = _acknowledgedDate;
    if (date == null) return false;
    final today = _now().toLocal();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  void acknowledge() {
    _acknowledgedDate = _now().toLocal();
    _scheduleDateBoundary();
    notifyListeners();
  }

  void afterBreak() => _clear();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _clear();
    } else if (state == AppLifecycleState.resumed) {
      if (!isAcknowledged) {
        _clear();
      } else {
        _scheduleDateBoundary();
      }
    }
  }

  void _scheduleDateBoundary() {
    _dateBoundary?.cancel();
    final now = _now().toLocal();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    final untilNextDay = nextDay.difference(now);
    _dateBoundary = Timer(
      untilNextDay > Duration.zero
          ? untilNextDay
          : const Duration(seconds: 1),
      () {
        if (isAcknowledged) {
          _scheduleDateBoundary();
        } else {
          _clear();
        }
      },
    );
  }

  void _clear() {
    _dateBoundary?.cancel();
    _dateBoundary = null;
    if (_acknowledgedDate == null) return;
    _acknowledgedDate = null;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dateBoundary?.cancel();
    super.dispose();
  }
}
