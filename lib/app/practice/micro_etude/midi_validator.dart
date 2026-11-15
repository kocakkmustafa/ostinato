import 'dart:typed_data';

import 'micro_etude_validation.dart';

/// Standard MIDI File (format 0) doğrulayıcısı.
///
/// Denetler: MThd/MTrk başlıkları ve uzunlukları, delta-time VLQ (en çok 4
/// bayt), running status, her note-on'un note-off'u (velocity 0'lı note-on
/// note-off sayılır), end-of-track (tam bir kez, parçanın son olayı, uzunluk
/// 0), veri baytlarının 0–127 aralığı, tempo/zaman imzası meta uzunlukları ve
/// tempo haritasından süre.
ValidationReport validateMidi(Uint8List bytes) {
  final issues = <ValidationIssue>[];
  void err(String code, String message) =>
      issues.add(ValidationIssue(code, message));

  if (bytes.length < 14) {
    err('midi.too_short', 'Başlık için en az 14 bayt gerekir: ${bytes.length}');
    return ValidationReport(issues: issues);
  }
  if (!_tagIs(bytes, 0, 'MThd')) {
    err('midi.header_tag', 'MThd bekleniyordu');
    return ValidationReport(issues: issues);
  }
  final headerLength = _u32(bytes, 4);
  if (headerLength < 6) {
    err('midi.header_length', 'MThd uzunluğu 6 olmalı: $headerLength');
    return ValidationReport(issues: issues);
  }
  final format = _u16(bytes, 8);
  final trackCount = _u16(bytes, 10);
  final division = _u16(bytes, 12);
  if (format != 0) {
    err('midi.format', 'Format 0 bekleniyordu: $format');
  }
  if (division & 0x8000 != 0) {
    err('midi.division_smpte', 'SMPTE zaman tabanı desteklenmiyor');
  } else if (division == 0) {
    err('midi.division_zero', 'Çeyrek başına tik sıfır');
  }

  var pos = 8 + headerLength;
  var tracks = 0;
  var noteCount = 0;
  int? minNote, maxNote;
  double? duration;
  while (pos < bytes.length) {
    if (bytes.length - pos < 8) {
      err('midi.truncated_chunk_header', 'Parça başlığı kesik (konum $pos)');
      break;
    }
    final isTrack = _tagIs(bytes, pos, 'MTrk');
    final length = _u32(bytes, pos + 4);
    final start = pos + 8;
    if (!isTrack && !_isAsciiTag(bytes, pos)) {
      err('midi.chunk_tag', 'Tanınmayan parça etiketi (konum $pos)');
      break;
    }
    if (start + length > bytes.length) {
      err(
        'midi.truncated_track',
        'Parça uzunluğu $length ama yalnız ${bytes.length - start} bayt var',
      );
      break;
    }
    if (isTrack) {
      tracks++;
      final t = _parseTrack(bytes, start, start + length, err);
      noteCount += t.noteCount;
      if (t.minNote != null) {
        minNote = minNote == null || t.minNote! < minNote ? t.minNote : minNote;
        maxNote = maxNote == null || t.maxNote! > maxNote ? t.maxNote : maxNote;
      }
      if (division != 0 && division & 0x8000 == 0 && t.complete) {
        duration = _seconds(t.endTick, t.tempos, division);
      }
    }
    pos = start + length;
  }
  if (tracks != trackCount) {
    err('midi.track_count', 'Başlık $trackCount parça diyor, bulunan $tracks');
  }
  if (format == 0 && tracks != 1) {
    err('midi.format0_tracks', 'Format 0 tek parça ister: $tracks');
  }
  return ValidationReport(
    issues: issues,
    durationSeconds: issues.isEmpty ? duration : null,
    noteCount: noteCount,
    minNote: minNote,
    maxNote: maxNote,
  );
}

typedef _Err = void Function(String code, String message);

final class _TrackResult {
  _TrackResult(
    this.endTick,
    this.tempos,
    this.noteCount,
    this.minNote,
    this.maxNote,
    this.complete,
  );
  final int endTick;
  final List<(int tick, int microsPerQuarter)> tempos;
  final int noteCount;
  final int? minNote, maxNote;
  final bool complete;
}

_TrackResult _parseTrack(Uint8List b, int start, int end, _Err err) {
  var p = start;
  var tick = 0;
  int? running;
  var ended = false;
  var ok = true;
  var noteCount = 0;
  int? minNote, maxNote;
  final tempos = <(int, int)>[];
  final open = <int, int>{}; // kanal*128+nota -> açık sayısı

  // VLQ okur; hata olursa null döner ve hatayı bildirir.
  int? vlq() {
    var value = 0;
    for (var i = 0; i < 4; i++) {
      if (p >= end) {
        err('midi.vlq_truncated', 'VLQ parça sonunda kesildi');
        return null;
      }
      final byte = b[p++];
      value = (value << 7) | (byte & 0x7F);
      if (byte & 0x80 == 0) return value;
    }
    err('midi.vlq_too_long', 'VLQ 4 bayttan uzun');
    return null;
  }

  while (p < end && ok) {
    if (ended) {
      err('midi.event_after_end', 'end-of-track sonrası olay var (konum $p)');
      ok = false;
      break;
    }
    final delta = vlq();
    if (delta == null) {
      ok = false;
      break;
    }
    tick += delta;
    if (p >= end) {
      err('midi.truncated_event', 'Delta-time sonrası olay yok');
      ok = false;
      break;
    }
    final first = b[p];
    if (first == 0xFF) {
      p++;
      if (p >= end) {
        err('midi.truncated_event', 'Meta türü eksik');
        ok = false;
        break;
      }
      final type = b[p++];
      final len = vlq();
      if (len == null) {
        ok = false;
        break;
      }
      if (p + len > end) {
        err('midi.truncated_event', 'Meta $type verisi kesik');
        ok = false;
        break;
      }
      switch (type) {
        case 0x2F:
          if (len != 0) {
            err('midi.end_of_track_length', 'end-of-track uzunluğu 0 olmalı');
          }
          ended = true;
        case 0x51:
          if (len != 3) {
            err('midi.tempo_length', 'Tempo meta uzunluğu 3 olmalı: $len');
          } else {
            final micros = (b[p] << 16) | (b[p + 1] << 8) | b[p + 2];
            if (micros == 0) {
              err('midi.tempo_zero', 'Tempo sıfır');
            } else {
              tempos.add((tick, micros));
            }
          }
        case 0x58:
          if (len != 4) {
            err('midi.time_signature_length', 'Zaman imzası 4 bayt ister');
          } else if (b[p] == 0 || b[p + 1] > 6) {
            err('midi.time_signature_value', 'Zaman imzası değeri geçersiz');
          }
      }
      p += len;
      running = null;
    } else if (first == 0xF0 || first == 0xF7) {
      p++;
      final len = vlq();
      if (len == null || p + len > end) {
        if (len != null) err('midi.truncated_event', 'Sysex verisi kesik');
        ok = false;
        break;
      }
      p += len;
      running = null;
    } else {
      int status;
      if (first >= 0x80) {
        if (first >= 0xF0) {
          err('midi.unsupported_status', 'Desteklenmeyen durum baytı $first');
          ok = false;
          break;
        }
        status = first;
        p++;
        running = status;
      } else {
        if (running == null) {
          err('midi.running_status_missing', 'Önceki durum yokken veri baytı');
          ok = false;
          break;
        }
        status = running;
      }
      final kind = status & 0xF0;
      final channel = status & 0x0F;
      final need = (kind == 0xC0 || kind == 0xD0) ? 1 : 2;
      if (p + need > end) {
        err('midi.truncated_event', 'Kanal olayı kesik');
        ok = false;
        break;
      }
      final d1 = b[p];
      final d2 = need == 2 ? b[p + 1] : 0;
      if (d1 > 0x7F || d2 > 0x7F) {
        err('midi.data_byte_high', 'Veri baytı 0–127 dışında (konum $p)');
        ok = false;
        break;
      }
      p += need;
      final key = channel * 128 + d1;
      if (kind == 0x90 && d2 > 0) {
        open[key] = (open[key] ?? 0) + 1;
        noteCount++;
        minNote = minNote == null || d1 < minNote ? d1 : minNote;
        maxNote = maxNote == null || d1 > maxNote ? d1 : maxNote;
      } else if (kind == 0x80 || kind == 0x90) {
        final n = open[key] ?? 0;
        if (n == 0) {
          err('midi.orphan_note_off', 'Eşi olmayan note-off: nota $d1');
        } else if (n == 1) {
          open.remove(key);
        } else {
          open[key] = n - 1;
        }
      }
    }
  }
  if (ok && !ended) {
    err('midi.missing_end_of_track', 'Parça end-of-track ile bitmiyor');
  }
  if (ok && open.isNotEmpty) {
    err('midi.unterminated_note', '${open.length} nota kapanmadı');
  }
  return _TrackResult(tick, tempos, noteCount, minNote, maxNote, ok && ended);
}

double _seconds(
  int endTick,
  List<(int tick, int microsPerQuarter)> tempos,
  int division,
) {
  var micros = 500000; // MIDI varsayılanı: 120 bpm
  var lastTick = 0;
  var seconds = 0.0;
  for (final (tick, value) in tempos) {
    if (tick > endTick) break;
    seconds += (tick - lastTick) * micros / division / 1e6;
    lastTick = tick;
    micros = value;
  }
  seconds += (endTick - lastTick) * micros / division / 1e6;
  return seconds;
}

bool _tagIs(Uint8List b, int at, String tag) {
  for (var i = 0; i < 4; i++) {
    if (b[at + i] != tag.codeUnitAt(i)) return false;
  }
  return true;
}

bool _isAsciiTag(Uint8List b, int at) {
  for (var i = 0; i < 4; i++) {
    final c = b[at + i];
    if (c < 0x20 || c > 0x7E) return false;
  }
  return true;
}

int _u16(Uint8List b, int at) => (b[at] << 8) | b[at + 1];

int _u32(Uint8List b, int at) =>
    (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3];
