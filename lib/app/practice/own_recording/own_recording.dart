import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:path_provider/path_provider.dart';

/// FK2 — "listen to my own recording" (founder, 2026-11-01): off by default.
/// When on, one practice run is kept in RAM and, once the run has a summary,
/// written as a WAV into the app's temporary directory so the result screen
/// can play it. The take is deleted when the next run starts, when the run
/// fails or is abandoned, and when the lesson screen closes; leftovers from a
/// crash are swept when a lesson opens. It is never uploaded and never handed
/// to analysis or training: this file imports no network API, and the judge
/// reads [CaptureBuffer], not this recorder.
final class OwnRecorder extends ChangeNotifier {
  OwnRecorder({
    Future<Directory> Function()? temporaryRoot,
    this.maxSeconds = 180,
  }) : _root = temporaryRoot ?? getTemporaryDirectory;

  final Future<Directory> Function() _root;

  /// RAM bound: a longer run keeps only its first [maxSeconds].
  final int maxSeconds;

  /// Follows the setting; while false [add] keeps nothing.
  bool enabled = false;

  final BytesBuilder _pcm = BytesBuilder(copy: false);
  int _sampleRate = 0;
  int _samples = 0;
  File? _take;
  int _generation = 0;
  bool _disposed = false;

  /// The sealed WAV of the last finished run, until it is deleted.
  File? get take => _take;
  bool get hasPendingAudio => _samples > 0;

  Future<Directory> _folder() async =>
      Directory('${(await _root()).path}/own_recording');

  /// Deletes every take left on disk (a crash skips [discard]). Call before
  /// the first run; a failure is retried at the next lesson.
  Future<void> sweep() async {
    try {
      final dir = await _folder();
      if (await dir.exists()) await dir.delete(recursive: true);
    } on Object {
      // No temporary directory (tests, OS refusal): nothing to sweep.
    }
  }

  /// A new run: drops the previous take and anything buffered.
  Future<void> reset() => discard();

  void add(AudioChunk c) {
    if (!enabled || _disposed) return;
    if (_sampleRate != 0 && c.sampleRate != _sampleRate) return;
    _sampleRate = c.sampleRate;
    final room = maxSeconds * _sampleRate - _samples;
    if (room <= 0) return;
    final n = c.samples.length < room ? c.samples.length : room;
    final out = Int16List(n);
    for (var i = 0; i < n; i++) {
      out[i] = (c.samples[i].clamp(-1.0, 1.0) * 32767).round();
    }
    _pcm.add(out.buffer.asUint8List());
    _samples += n;
  }

  /// The run finished: writes the buffered audio as the take.
  Future<File?> seal() async {
    final generation = ++_generation;
    if (_samples == 0 || _disposed) return null;
    final pcm = _pcm.takeBytes();
    final rate = _sampleRate;
    _samples = 0;
    _sampleRate = 0;
    final File file;
    try {
      final dir = await _folder();
      await dir.create(recursive: true);
      file = File('${dir.path}/take-$generation.wav');
      await file.writeAsBytes(encodeWav(pcm, rate), flush: true);
    } on Object {
      // No take this run; the result screen simply shows no player.
      return null;
    }
    if (generation != _generation || _disposed) {
      // A reset or dispose came while writing: this take is already stale.
      await _delete(file);
      return null;
    }
    _take = file;
    notifyListeners();
    return file;
  }

  /// Drops the RAM buffer and deletes the take.
  Future<void> discard() async {
    ++_generation;
    _pcm.clear();
    _samples = 0;
    _sampleRate = 0;
    final file = _take;
    _take = null;
    if (file != null) {
      if (!_disposed) notifyListeners();
      await _delete(file);
    }
  }

  static Future<void> _delete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } on FileSystemException {
      // The temporary directory is the OS's; sweep() retries next lesson.
    }
  }

  @override
  void dispose() {
    unawaited(discard());
    _disposed = true;
    super.dispose();
  }
}

/// 16-bit mono PCM (little endian) wrapped in a RIFF/WAVE header.
@visibleForTesting
Uint8List encodeWav(Uint8List pcm16, int sampleRate) {
  final header = ByteData(44);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      header.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  header.setUint32(4, 36 + pcm16.length, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  header.setUint32(40, pcm16.length, Endian.little);
  return (BytesBuilder(copy: false)
        ..add(header.buffer.asUint8List())
        ..add(pcm16))
      .takeBytes();
}
