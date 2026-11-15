import 'micro_etude_models.dart';

/// MusicXML 4.0 score-partwise: tek part (P1), `divisions` = 2 (sekizlik = 1),
/// her kademenin ilk ölçüsünde tempo yönergesi, `backup`/`forward` yok,
/// bağlı nota (tie) yok. Gitar yazımı: sol anahtarı oktav aşağı notalı.
abstract final class MusicXmlWriter {
  static const divisions = 2;

  static const _stepsSharp = [
    ('C', 0), ('C', 1), ('D', 0), ('D', 1), ('E', 0), ('F', 0), //
    ('F', 1), ('G', 0), ('G', 1), ('A', 0), ('A', 1), ('B', 0),
  ];

  static String write(MicroEtude etude) {
    final b = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<score-partwise version="4.0">')
      ..writeln('  <work><work-title>Micro etude</work-title></work>')
      ..writeln(
        '  <identification><encoding><software>Ostinato micro-etude</software>'
        '</encoding></identification>',
      )
      ..writeln(
        '  <part-list><score-part id="P1"><part-name>Guitar</part-name>'
        '</score-part></part-list>',
      )
      ..writeln('  <part id="P1">');
    var number = 0;
    var lastBpm = -1;
    for (final (:bpm, :bar) in etude.timeline) {
      number++;
      b.writeln('    <measure number="$number">');
      if (number == 1) {
        b.writeln(
          '      <attributes><divisions>$divisions</divisions>'
          '<key><fifths>0</fifths></key>'
          '<time><beats>${etude.meter.beats}</beats>'
          '<beat-type>${etude.meter.beatType}</beat-type></time>'
          '<clef><sign>G</sign><line>2</line>'
          '<clef-octave-change>-1</clef-octave-change></clef></attributes>',
        );
      }
      if (bpm != lastBpm) {
        b.writeln(
          '      <direction placement="above"><direction-type><metronome>'
          '<beat-unit>quarter</beat-unit><per-minute>$bpm</per-minute>'
          '</metronome></direction-type><sound tempo="$bpm"/></direction>',
        );
        lastBpm = bpm;
      }
      for (final e in bar.events) {
        b.writeln('      ${_note(e)}');
      }
      b.writeln('    </measure>');
    }
    b
      ..writeln('  </part>')
      ..writeln('</score-partwise>');
    return b.toString();
  }

  static String _note(EtudeEvent e) {
    final (type, dotted) = switch (e.eighths) {
      1 => ('eighth', false),
      2 => ('quarter', false),
      3 => ('quarter', true),
      4 => ('half', false),
      6 => ('half', true),
      8 => ('whole', false),
      final n => throw StateError('Yazılamayan uzunluk: $n sekizlik'),
    };
    final tail =
        '<duration>${e.eighths}</duration><type>$type</type>${dotted ? '<dot/>' : ''}';
    final midi = e.midi;
    if (midi == null) return '<note><rest/>$tail</note>';
    final (step, alter) = _stepsSharp[midi % 12];
    final octave = midi ~/ 12 - 1;
    return '<note><pitch><step>$step</step>'
        '${alter != 0 ? '<alter>$alter</alter>' : ''}'
        '<octave>$octave</octave></pitch>$tail</note>';
  }
}
