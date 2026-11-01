import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// The latest tuner result of today. The session tuning gate reads it; a new
/// day forgets it. The app's memory keeps it in a small device file
/// (`tuner_check.v1.json`: preset id, string counts, time; no audio, no
/// network) so a restart the same day still shows "tuned today".
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

  Map<String, Object?> toJson() => {
    'presetId': presetId,
    'inTune': inTune,
    'total': total,
    'at': at.toUtc().toIso8601String(),
  };

  factory TunerCheck.fromJson(Map<String, dynamic> json) => TunerCheck(
    presetId: json['presetId'] as String,
    inTune: json['inTune'] as int,
    total: json['total'] as int,
    at: DateTime.parse(json['at'] as String),
  );
}

final class TunerCheckMemory extends ChangeNotifier {
  /// Without [file] the memory lives only in RAM (tests, previews).
  TunerCheckMemory({DateTime Function()? now, this.file})
    : _now = now ?? DateTime.now;

  static final TunerCheckMemory instance = TunerCheckMemory(
    file: () async =>
        File('${(await getApplicationSupportDirectory()).path}/$fileName'),
  )..restore().ignore();

  static const String fileName = 'tuner_check.v1.json';
  static const int schemaVersion = 1;

  final Future<File> Function()? file;
  final DateTime Function() _now;
  TunerCheck? _last;
  DateTime? _continuedAt;
  Future<void> _writing = Future<void>.value();

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
    _save();
  }

  void continueWithoutTuning() {
    _continuedAt = _now();
    notifyListeners();
    _save();
  }

  /// Reads the file once at start. A check recorded in the meantime is newer
  /// and wins; a missing or damaged file reads as "no check".
  Future<void> restore() async {
    final provider = file;
    if (provider == null) return;
    try {
      final f = await provider();
      if (!await f.exists()) return;
      final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      if (json['schemaVersion'] != schemaVersion) return;
      if (_last != null || _continuedAt != null) return;
      final last = json['last'];
      final continued = json['continuedAt'];
      _last = last == null
          ? null
          : TunerCheck.fromJson(last as Map<String, dynamic>);
      _continuedAt = continued == null
          ? null
          : DateTime.parse(continued as String);
      notifyListeners();
    } on Object {
      // Unreadable: behave as if nothing was checked today.
    }
  }

  /// Writes are queued so a quick second check never lands under the first.
  Future<void> get saved => _writing;

  void _save() {
    final provider = file;
    if (provider == null) return;
    final json = {
      'schemaVersion': schemaVersion,
      'last': _last?.toJson(),
      'continuedAt': _continuedAt?.toUtc().toIso8601String(),
    };
    _writing = _writing.then((_) async {
      try {
        final f = await provider();
        await f.parent.create(recursive: true);
        final temp = File('${f.path}.tmp');
        await temp.writeAsString('${jsonEncode(json)}\n', flush: true);
        await temp.rename(f.path);
      } on Object {
        // Best effort: today's state is still in RAM.
      }
    });
  }

  @visibleForTesting
  void reset() {
    _last = null;
    _continuedAt = null;
    notifyListeners();
    _save();
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final x = a.toLocal(), y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }
}
