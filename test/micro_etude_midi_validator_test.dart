import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/practice/micro_etude/midi_validator.dart';

// Doğrulayıcıdan bağımsız, elle kurulan SMF yapı taşları.
List<int> vlq(int v) {
  final out = <int>[v & 0x7F];
  var rest = v >> 7;
  while (rest > 0) {
    out.insert(0, (rest & 0x7F) | 0x80);
    rest >>= 7;
  }
  return out;
}

List<int> u32(int v) => [v >> 24 & 255, v >> 16 & 255, v >> 8 & 255, v & 255];

Uint8List smf(
  List<int> trackBody, {
  int format = 0,
  int ntrks = 1,
  int division = 480,
  int? lengthOverride,
}) {
  return Uint8List.fromList([
    ...'MThd'.codeUnits, ...u32(6), 0, format, 0, ntrks,
    division >> 8, division & 255, //
    ...'MTrk'.codeUnits, ...u32(lengthOverride ?? trackBody.length),
    ...trackBody,
  ]);
}

const eot = [0, 0xFF, 0x2F, 0];
const tempo120 = [0, 0xFF, 0x51, 3, 0x07, 0xA1, 0x20]; // 500000
// 4 çeyrek nota (C4), 480 tik her biri.
List<int> fourQuarters() => [
  ...tempo120,
  for (var k = 0; k < 4; k++) ...[0, 0x90, 60, 80, ...vlq(480), 0x80, 60, 0],
  ...eot,
];

void main() {
  group('validateMidi pozitif', () {
    test('4 çeyrek nota 120 bpm = 2.0 sn', () {
      final r = validateMidi(smf(fourQuarters()));
      expect(r.isValid, isTrue, reason: '$r');
      expect(r.noteCount, 4);
      expect(r.durationSeconds, closeTo(2.0, 1e-9));
      expect(r.minNote, 60);
      expect(r.maxNote, 60);
    });

    test('running status ve velocity 0 note-on kabul edilir', () {
      final body = [
        ...tempo120,
        0, 0x90, 60, 80, //
        ...vlq(240), 62, 80, // running status: ikinci note-on
        ...vlq(240), 60, 0, // velocity 0 = note-off (running)
        0, 62, 0,
        ...eot,
      ];
      final r = validateMidi(smf(body));
      expect(r.isValid, isTrue, reason: '$r');
      expect(r.noteCount, 2);
      expect(r.durationSeconds, closeTo(0.5, 1e-9));
    });

    test('tempo değişimi süreye işler', () {
      final body = [
        ...tempo120,
        0, 0x90, 60, 80, ...vlq(480), 0x80, 60, 0, // 0.5 sn
        0, 0xFF, 0x51, 3, 0x0F, 0x42, 0x40, // 1_000_000 us = 60 bpm
        0, 0x90, 60, 80, ...vlq(480), 0x80, 60, 0, // 1.0 sn
        ...eot,
      ];
      final r = validateMidi(smf(body));
      expect(r.isValid, isTrue, reason: '$r');
      expect(r.durationSeconds, closeTo(1.5, 1e-9));
    });

    test('çok baytlı VLQ delta okunur', () {
      final body = [
        ...tempo120,
        0,
        0x90,
        60,
        80,
        ...vlq(100000),
        0x80,
        60,
        0,
        ...eot,
      ];
      final r = validateMidi(smf(body));
      expect(r.isValid, isTrue, reason: '$r');
      expect(r.durationSeconds, closeTo(100000 / 480 * 0.5, 1e-6));
    });
  });

  group('validateMidi negatif (gerçekten reddeder)', () {
    String code(Uint8List b) {
      final r = validateMidi(b);
      expect(r.isValid, isFalse);
      return r.issues.first.code;
    }

    test('kesik MTrk: uzunluk gerçek bayttan büyük', () {
      final full = fourQuarters();
      final bytes = smf(
        full.sublist(0, full.length - 10),
        lengthOverride: full.length,
      );
      expect(code(bytes), 'midi.truncated_track');
    });

    test('dosya ortadan kesilmiş', () {
      final bytes = smf(fourQuarters());
      expect(code(bytes.sublist(0, bytes.length - 6)), 'midi.truncated_track');
    });

    test('eşleşmeyen note-off (başka nota)', () {
      final body = [...tempo120, 0, 0x90, 60, 80, 10, 0x80, 61, 0, ...eot];
      final r = validateMidi(smf(body));
      expect(r.hasCode('midi.orphan_note_off'), isTrue);
      expect(r.hasCode('midi.unterminated_note'), isTrue);
    });

    test('note-off yok', () {
      final body = [...tempo120, 0, 0x90, 60, 80, ...eot];
      expect(code(smf(body)), 'midi.unterminated_note');
    });

    test('önce note-off', () {
      final body = [...tempo120, 0, 0x80, 60, 0, ...eot];
      expect(code(smf(body)), 'midi.orphan_note_off');
    });

    test('end-of-track yok', () {
      final body = [...tempo120, 0, 0x90, 60, 80, 10, 0x80, 60, 0];
      expect(code(smf(body)), 'midi.missing_end_of_track');
    });

    test('end-of-track sonrası olay', () {
      final body = [...tempo120, ...eot, 0, 0x90, 60, 80];
      expect(code(smf(body)), 'midi.event_after_end');
    });

    test('bozuk başlık etiketi', () {
      final b = smf(fourQuarters());
      b[0] = 0x58;
      expect(code(b), 'midi.header_tag');
    });

    test('parça sayısı başlıkla uyuşmuyor', () {
      expect(code(smf(fourQuarters(), ntrks: 2)), 'midi.track_count');
    });

    test('VLQ 4 bayttan uzun', () {
      final body = [
        ...tempo120,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0x7F,
        0x90,
        60,
        80,
        ...eot,
      ];
      expect(code(smf(body)), 'midi.vlq_too_long');
    });

    test('VLQ parça sonunda kesik', () {
      final body = [...tempo120, 0x81];
      expect(code(smf(body)), 'midi.vlq_truncated');
    });

    test('önceki durum yokken running status', () {
      final body = [0, 60, 80, ...eot];
      expect(code(smf(body)), 'midi.running_status_missing');
    });

    test('veri baytı 127 üstü (nota 128+)', () {
      final body = [...tempo120, 0, 0x90, 60, 200, ...eot];
      expect(code(smf(body)), 'midi.data_byte_high');
    });

    test('tempo meta uzunluğu yanlış', () {
      final body = [0, 0xFF, 0x51, 2, 7, 161, ...eot];
      expect(code(smf(body)), 'midi.tempo_length');
    });

    test('parçadan sonra artık bayt', () {
      final b = Uint8List.fromList([...smf(fourQuarters()), 1, 2, 3]);
      expect(code(b), 'midi.truncated_chunk_header');
    });

    test('format 1 reddedilir', () {
      expect(code(smf(fourQuarters(), format: 1)), 'midi.format');
    });
  });
}
