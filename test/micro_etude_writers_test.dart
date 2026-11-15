import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/practice/micro_etude/micro_etude_generator.dart';
import 'package:ostinato/app/practice/micro_etude/micro_etude_models.dart';
import 'package:ostinato/app/practice/micro_etude/midi_validator.dart';
import 'package:ostinato/app/practice/micro_etude/midi_writer.dart';
import 'package:ostinato/app/practice/micro_etude/musicxml_validator.dart';
import 'package:ostinato/app/practice/micro_etude/musicxml_writer.dart';

List<MicroEtudeRequest> requests() {
  const pairs = [(40, 41), (52, 55), (45, 57), (76, 40), (64, 67), (71, 59)];
  return [
    for (var bpm = 50; bpm <= 120; bpm += 1)
      for (final m in EtudeMeter.values) ...[
        for (var s = 0; s < m.eighthsPerBar; s++)
          for (final d in RhythmDeviation.values)
            MicroEtudeRequest(
              miss: RhythmMiss(slot: s, deviation: d),
              bpm: bpm,
              meter: m,
              seed: bpm,
            ),
        for (final (a, b) in pairs)
          MicroEtudeRequest(
            miss: NoteTransitionMiss(fromMidi: a, toMidi: b),
            bpm: bpm,
            meter: m,
          ),
      ],
  ];
}

void main() {
  final all = requests();

  test('üretilen MIDI doğrulayıcıdan geçer, süre 15–30 sn ve plana eşit', () {
    for (final r in all) {
      final e = MicroEtudeGenerator.generate(r);
      final report = validateMidi(MidiWriter.write(e));
      final why = '${r.meter} ${r.bpm} ${r.miss.runtimeType}: $report';
      expect(report.isValid, isTrue, reason: why);
      expect(report.durationSeconds, inInclusiveRange(15.0, 30.0), reason: why);
      expect(report.durationSeconds, closeTo(e.durationSeconds, 0.02));
      expect(report.minNote!, greaterThanOrEqualTo(40));
      expect(report.maxNote!, lessThanOrEqualTo(76));
      expect(report.noteCount, greaterThan(0));
    }
  });

  test(
    'üretilen MusicXML doğrulayıcıdan geçer, süre 15–30 sn ve plana eşit',
    () {
      for (final r in all) {
        final e = MicroEtudeGenerator.generate(r);
        final report = validateMusicXml(MusicXmlWriter.write(e));
        final why = '${r.meter} ${r.bpm} ${r.miss.runtimeType}: $report';
        expect(report.isValid, isTrue, reason: why);
        expect(
          report.durationSeconds,
          inInclusiveRange(15.0, 30.0),
          reason: why,
        );
        expect(report.durationSeconds, closeTo(e.durationSeconds, 1e-9));
      }
    },
  );

  test('MIDI ve MusicXML aynı nota sayısı ve aralık', () {
    for (final r in all.where((r) => r.bpm % 7 == 0)) {
      final e = MicroEtudeGenerator.generate(r);
      final m = validateMidi(MidiWriter.write(e));
      final x = validateMusicXml(MusicXmlWriter.write(e));
      expect(x.noteCount, m.noteCount);
      expect(x.minNote, m.minNote);
      expect(x.maxNote, m.maxNote);
    }
  });

  test('determinizm: aynı girdi → aynı bayt ve aynı XML', () {
    for (final r in all.where((r) => r.bpm % 5 == 0)) {
      final a = MicroEtudeGenerator.generate(r);
      final b = MicroEtudeGenerator.generate(r);
      expect(MidiWriter.write(a), orderedEquals(MidiWriter.write(b)));
      expect(MusicXmlWriter.write(a), MusicXmlWriter.write(b));
    }
  });

  test('MIDI başlık ayrıntıları: format 0, 480 tik, zaman imzası, tempo', () {
    final e = MicroEtudeGenerator.generate(
      const MicroEtudeRequest(
        miss: RhythmMiss(slot: 2, deviation: RhythmDeviation.late),
        bpm: 100,
        meter: EtudeMeter.sixEight,
      ),
    );
    final b = MidiWriter.write(e);
    expect(String.fromCharCodes(b.sublist(0, 4)), 'MThd');
    expect((b[8] << 8) | b[9], 0); // format
    expect((b[12] << 8) | b[13], 480);
    // 6/8 zaman imzası meta: FF 58 04 06 03 24 08
    final s = b.join(',');
    expect(s, contains('255,88,4,6,3,36,8'));
    expect(s, contains('255,47,0')); // end-of-track
  });

  test('MusicXML sürüm 4.0, divisions 2, backup yok', () {
    final e = MicroEtudeGenerator.generate(
      const MicroEtudeRequest(
        miss: NoteTransitionMiss(fromMidi: 52, toMidi: 55),
        bpm: 90,
        meter: EtudeMeter.fourFour,
      ),
    );
    final x = MusicXmlWriter.write(e);
    expect(x, contains('<score-partwise version="4.0">'));
    expect(x, contains('<divisions>2</divisions>'));
    expect(x, isNot(contains('<backup')));
  });

  test('yazılan çıktı bozulunca doğrulayıcı yakalar (uçtan uca)', () {
    final e = MicroEtudeGenerator.generate(
      const MicroEtudeRequest(
        miss: NoteTransitionMiss(fromMidi: 52, toMidi: 55),
        bpm: 90,
        meter: EtudeMeter.fourFour,
      ),
    );
    final bytes = MidiWriter.write(e);
    expect(validateMidi(bytes.sublist(0, bytes.length - 12)).isValid, isFalse);
    final x = MusicXmlWriter.write(e);
    expect(
      validateMusicXml(
        x.replaceFirst('<duration>2</duration>', '<duration>3</duration>'),
      ).isValid,
      isFalse,
    );
    expect(
      validateMusicXml(x.replaceFirst('<step>', '<step>Z')).isValid,
      isFalse,
    );
  });

  test(
    'örnek dosyaları kanıt klasörüne yaz (yalnız ortam değişkeni varsa)',
    () {
      final dir = Platform.environment['OST_P101_SAMPLE_DIR'];
      if (dir == null) return;
      final samples = <String, MicroEtudeRequest>{
        'ritim-gec-4-4-bpm80': const MicroEtudeRequest(
          miss: RhythmMiss(slot: 3, deviation: RhythmDeviation.late),
          bpm: 80,
          meter: EtudeMeter.fourFour,
        ),
        'gecis-A2-C3-3-4-bpm100': const MicroEtudeRequest(
          miss: NoteTransitionMiss(fromMidi: 45, toMidi: 48),
          bpm: 100,
          meter: EtudeMeter.threeFour,
        ),
        'ritim-erken-6-8-bpm60': const MicroEtudeRequest(
          miss: RhythmMiss(slot: 4, deviation: RhythmDeviation.early),
          bpm: 60,
          meter: EtudeMeter.sixEight,
        ),
      };
      samples.forEach((name, r) {
        final e = MicroEtudeGenerator.generate(r);
        File('$dir/$name.mid').writeAsBytesSync(MidiWriter.write(e));
        File('$dir/$name.musicxml').writeAsStringSync(MusicXmlWriter.write(e));
      });
    },
  );
}
