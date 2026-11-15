import 'dart:typed_data';

import 'micro_etude_models.dart';

/// Standard MIDI File, format 0, çeyrek başına 480 tik, tek parça, kanal 0.
/// Parça: ad, tempo (her kademe başında), zaman imzası, program (naylon tel
/// gitar), nota on/off (running status KULLANILMAZ), end-of-track.
abstract final class MidiWriter {
  static const ticksPerQuarter = 480;
  static const ticksPerEighth = 240;
  static const velocity = 84;
  static const _program = 24;

  static Uint8List write(MicroEtude etude) {
    // (tik, öncelik, bayt dizisi): tempo < note-off < note-on aynı tikte.
    final events = <(int, int, List<int>)>[];
    var tick = 0;
    var lastBpm = -1;
    for (final (:bpm, :bar) in etude.timeline) {
      if (bpm != lastBpm) {
        final micros = (60000000 / bpm).round();
        events.add((
          tick,
          0,
          [
            0xFF,
            0x51,
            0x03,
            micros >> 16 & 0xFF,
            micros >> 8 & 0xFF,
            micros & 0xFF, //
          ],
        ));
        lastBpm = bpm;
      }
      for (final e in bar.events) {
        final len = e.eighths * ticksPerEighth;
        final midi = e.midi;
        if (midi != null) {
          events.add((tick, 2, [0x90, midi, velocity]));
          events.add((tick + len, 1, [0x80, midi, 0]));
        }
        tick += len;
      }
    }
    events.sort((x, y) {
      final c = x.$1.compareTo(y.$1);
      return c != 0 ? c : x.$2.compareTo(y.$2);
    });

    final name = 'micro-etude'.codeUnits;
    final body = <int>[
      0x00, 0xFF, 0x03, name.length, ...name, //
      0x00, 0xFF, 0x58, 0x04, etude.meter.beats,
      etude.meter.beatType == 8 ? 3 : 2,
      etude.meter.beatType == 8 ? 36 : 24, 8, //
      0x00, 0xC0, _program,
    ];
    var last = 0;
    for (final (t, _, bytes) in events) {
      body
        ..addAll(_vlq(t - last))
        ..addAll(bytes);
      last = t;
    }
    body.addAll([...(_vlq(tick - last)), 0xFF, 0x2F, 0x00]);

    return Uint8List.fromList([
      ...'MThd'.codeUnits, ..._u32(6), 0, 0, 0, 1, //
      ticksPerQuarter >> 8, ticksPerQuarter & 0xFF,
      ...'MTrk'.codeUnits, ..._u32(body.length), ...body,
    ]);
  }

  static List<int> _vlq(int v) {
    final groups = <int>[v & 0x7F];
    var rest = v >> 7;
    while (rest > 0) {
      groups.add((rest & 0x7F) | 0x80);
      rest >>= 7;
    }
    return groups.reversed.toList();
  }

  static List<int> _u32(int v) => [
    v >> 24 & 255,
    v >> 16 & 255,
    v >> 8 & 255,
    v & 255,
  ];
}
