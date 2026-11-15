import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/practice/micro_etude/micro_etude_validation.dart';
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

  group('validateMidi ek dallar', () {
    ValidationReport run(
      List<int> body, {
      int division = 480,
      int format = 0,
      int ntrks = 1,
    }) => validateMidi(
      smf(body, division: division, format: format, ntrks: ntrks),
    );

    test('SMPTE zaman tabanı', () {
      expect(
        run(fourQuarters(), division: 0xE728).hasCode('midi.division_smpte'),
        isTrue,
      );
    });

    test('division sıfır', () {
      expect(
        run(fourQuarters(), division: 0).hasCode('midi.division_zero'),
        isTrue,
      );
    });

    test('tempo sıfır', () {
      final body = [0, 0xFF, 0x51, 3, 0, 0, 0, ...eot];
      expect(run(body).hasCode('midi.tempo_zero'), isTrue);
    });

    test('sysex: geçerli kabul, kesik ret', () {
      final ok = [...tempo120, 0, 0xF0, 3, 1, 2, 0xF7, ...eot];
      expect(run(ok).isValid, isTrue, reason: '${run(ok)}');
      final cut = [...tempo120, 0, 0xF0, 9, 1, 2];
      final r = run(cut);
      expect(r.isValid, isFalse);
      expect(r.hasCode('midi.truncated_event'), isTrue);
    });

    test('meta olay kesik', () {
      final r = run([...tempo120, 0, 0xFF, 0x03, 9, 65, 66]);
      expect(r.hasCode('midi.truncated_event'), isTrue);
      expect(
        run([...tempo120, 0, 0xFF]).hasCode('midi.truncated_event'),
        isTrue,
      );
    });

    test('delta-time sonrası olay yok', () {
      expect(run([...tempo120, 5]).hasCode('midi.truncated_event'), isTrue);
    });

    test('kanal olayı kesik', () {
      expect(
        run([...tempo120, 0, 0x90, 60]).hasCode('midi.truncated_event'),
        isTrue,
      );
    });

    test('end-of-track uzunluğu sıfır değil', () {
      final r = run([...tempo120, 0, 0xFF, 0x2F, 1, 0]);
      expect(r.hasCode('midi.end_of_track_length'), isTrue);
    });

    test('zaman imzası uzunluğu ve değeri', () {
      expect(
        run([
          0,
          0xFF,
          0x58,
          3,
          4,
          2,
          24,
          ...eot,
        ]).hasCode('midi.time_signature_length'),
        isTrue,
      );
      expect(
        run([
          0,
          0xFF,
          0x58,
          4,
          0,
          2,
          24,
          8,
          ...eot,
        ]).hasCode('midi.time_signature_value'),
        isTrue,
      );
      expect(
        run([
          0,
          0xFF,
          0x58,
          4,
          4,
          9,
          24,
          8,
          ...eot,
        ]).hasCode('midi.time_signature_value'),
        isTrue,
      );
      expect(run([0, 0xFF, 0x58, 4, 4, 2, 24, 8, ...eot]).isValid, isTrue);
    });

    test(
      'tanınmayan parça etiketi reddedilir, ASCII yabancı parça atlanır',
      () {
        final good = smf(fourQuarters());
        final bad = Uint8List.fromList([...good, 1, 2, 3, 4, 0, 0, 0, 0]);
        expect(validateMidi(bad).hasCode('midi.chunk_tag'), isTrue);
        final foreign = Uint8List.fromList([
          ...good,
          ...'XFIH'.codeUnits,
          0,
          0,
          0,
          1,
          7,
        ]);
        expect(
          validateMidi(foreign).isValid,
          isTrue,
          reason: '${validateMidi(foreign)}',
        );
      },
    );

    test('format 0 ama iki parça', () {
      final one = fourQuarters();
      final two = Uint8List.fromList([
        ...smf(one, ntrks: 2),
        ...'MTrk'.codeUnits,
        ...u32(one.length),
        ...one,
      ]);
      expect(validateMidi(two).hasCode('midi.format0_tracks'), isTrue);
    });
  });
}
