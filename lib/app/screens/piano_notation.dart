import 'package:flutter/material.dart';
import '../app_locale.dart';

/// Original vector examples. Pitch is a diatonic staff position, not a sensor.
class PianoWrittenNote {
  const PianoWrittenNote(this.pitch, this.beats);
  final String? pitch; // null = rest
  final double beats;
}

const pianoReadingRight = [
  [
    PianoWrittenNote('E4', 1),
    PianoWrittenNote('F4', 1),
    PianoWrittenNote('G4', 2),
  ],
  [
    PianoWrittenNote('G4', 1),
    PianoWrittenNote('E4', 1),
    PianoWrittenNote('D4', 2),
  ],
];
const pianoReadingLeft = [
  [PianoWrittenNote('C3', 4)],
  [PianoWrittenNote('G3', 4)],
];
const pianoStudyRight = [
  [
    PianoWrittenNote('C4', 1),
    PianoWrittenNote('D4', 1),
    PianoWrittenNote('E4', 1),
    PianoWrittenNote('G4', 1),
  ],
  [
    PianoWrittenNote('G4', 1),
    PianoWrittenNote('E4', 1),
    PianoWrittenNote('D4', 1),
    PianoWrittenNote('C4', 1),
  ],
  [
    PianoWrittenNote('E4', 1),
    PianoWrittenNote('F4', 1),
    PianoWrittenNote('G4', 2),
  ],
  [
    PianoWrittenNote('E4', 1),
    PianoWrittenNote('D4', 1),
    PianoWrittenNote('C4', 2),
  ],
];
const pianoStudyLeft = [
  [PianoWrittenNote('C3', 4)],
  [PianoWrittenNote('G3', 4)],
  [PianoWrittenNote('C3', 2), PianoWrittenNote('G3', 2)],
  [PianoWrittenNote('C3', 4)],
];

class PianoNotation extends StatelessWidget {
  const PianoNotation({super.key, required this.lesson});
  final int lesson;
  @override
  Widget build(BuildContext context) {
    if (lesson == 3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localized(
              context,
              'One octave around middle C (C4)',
              'Orta Do (Do4) çevresinde bir oktav',
            ),
          ),
          _Vector(
            kind: 'keyboard',
            description: localized(
              context,
              'C4 D4 E4 F4 G4 A4 B4 C5; black keys in groups of two and three',
              'C4 D4 E4 F4 G4 A4 B4 C5; siyah tuşlar ikili ve üçlü gruplar halinde. C4 orta Do, MIDI 60.',
            ),
          ),
          Text(
            localized(
              context,
              '88 keys: A0 … C1 … C2 … C3 … [C4 = middle C] … C5 … C6 … C7 … C8. The local diagram does not locate the centre of every shorter keyboard.',
              '88 tuş: La0 … Do1 … Do2 … Do3 … [Do4 = orta Do] … Do5 … Do6 … Do7 … Do8. Yerel çizim her kısa klavyenin merkezini belirlemez.',
            ),
          ),
        ],
      );
    }
    if (lesson == 7) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localized(
              context,
              'Treble: E4 bottom line, F4 bottom space, G4 second line; C4 ledger below. Bass: F3 second line from top, G3 top space; C4 ledger above.',
              'Sol: alt çizgi Mi4, alt aralık Fa4, ikinci çizgi Sol4; altta ek çizgi Do4. Fa: üstten ikinci çizgi Fa3, en üst aralık Sol3; üstte ek çizgi Do4.',
            ),
          ),
          _Vector(
            kind: 'anchors',
            description: localized(
              context,
              'Treble E4 F4 G4 C4; bass F3 G3 C4. Each labeled note is a quarter.',
              'Sol anahtarı Mi4 Fa4 Sol4 Do4; fa anahtarı Fa3 Sol3 Do4. Etiketli her nota dörtlük.',
            ),
          ),
        ],
      );
    }
    if (lesson == 8) {
      return Column(
        children: [
          Text(
            localized(
              context,
              'Symbol key in 4/4: quarter 1; half 2; whole 4; two beamed eighths ½ + ½. Rests: quarter 1, half 2, whole bar 4.',
              '4/4 simgeleri: dörtlük 1; ikilik 2; birlik 4; kirişle birleştirilmiş iki sekizlik ½ + ½. Suslar: dörtlük 1, ikilik 2, birlik ölçü 4.',
            ),
          ),
          _Vector(
            kind: 'symbols',
            description: localized(
              context,
              'Filled stem note quarter; hollow stem half; hollow no stem whole; beamed eighth pair. Quarter zigzag rest; half rectangle above line; whole rectangle below line.',
              'Saplı dolu dörtlük; saplı boş ikilik; sapsız boş birlik; kirişle birleştirilmiş iki sekizlik. Dörtlük zikzak sus; ikilik çizgi üstü, birlik çizgi altı dikdörtgen sus.',
            ),
          ),
          Text(
            localized(
              context,
              'Rest example: C4 quarter on beat 1, quarter rest on 2, D4 half on 3–4.',
              'Sus örneği: 1’de Do4 dörtlük, 2’de dörtlük sus, 3–4’te Re4 ikilik.',
            ),
          ),
          _Vector(
            kind: 'rest',
            description: localized(
              context,
              'Treble C4 quarter, quarter rest, D4 half; 4 beats.',
              'Sol anahtarı Do4 dörtlük, dörtlük sus, Re4 ikilik; dört vuruş.',
            ),
          ),
        ],
      );
    }
    if (lesson != 14 && lesson != 15) return const SizedBox.shrink();
    final right = lesson == 14 ? pianoReadingRight : pianoStudyRight;
    final left = lesson == 14 ? pianoReadingLeft : pianoStudyLeft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localized(
            context,
            '4/4 · no pedal · each bar has four beats. Two staves share each vertical beat position.',
            '4/4 · pedal yok · her ölçü dört vuruş. İki dizek dikey vuruş konumlarını paylaşır.',
          ),
        ),
        for (var bar = 0; bar < right.length; bar++) ...[
          Text(
            localized(
              context,
              'Bar {v0}',
              'Ölçü {v0}',
              values: {'v0': bar + 1},
            ),
          ),
          _Vector(
            kind: 'score',
            right: right[bar],
            left: left[bar],
            description: lesson == 14
                ? localized(
                    context,
                    'Grand staff reading task. Treble staff above bass; decode the positions and durations before opening answers.',
                    'Büyük dizek okuma görevi. Sol anahtarlı dizek fa anahtarlı dizeğin üstündedir; yanıtları açmadan konumları ve süreleri çözün.',
                  )
                : localized(
                    context,
                    'Original study bar {v0}; see the written notes in the practice text.',
                    'Özgün etüt ölçüsü {v0}; pratik metnindeki yazılı notalara bakın.',
                    values: {'v0': bar + 1},
                  ),
          ),
        ],
        ExpansionTile(
          key: Key('piano-answers-$lesson'),
          title: Text(
            localized(
              context,
              'Show answers after your attempt',
              'Denemenden sonra cevapları göster',
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var bar = 0; bar < right.length; bar++)
                    Text(
                      '${localized(context, 'Bar', 'Ölçü')} ${appInteger(context, bar + 1)}: ${localized(context, 'right', 'sağ')} ${_answer(right[bar], context)}; ${localized(context, 'left', 'sol')} ${_answer(left[bar], context)}',
                    ),
                  Text(
                    localized(
                      context,
                      'Compare written answers yourself. This panel does not hear, observe or grade your playing.',
                      'Yazdığın cevapları kendin karşılaştır. Bu panel çalmanı duymaz, gözlemlemez veya puanlamaz.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _answer(List<PianoWrittenNote> notes, BuildContext context) {
  var beat = 1.0;
  return notes
      .map((n) {
        final pitch = n.pitch == null
            ? localized(context, 'rest', 'sus')
            : musicPitch(context, n.pitch!);
        final duration = n.beats == 4
            ? localized(context, 'whole', 'birlik')
            : n.beats == 2
            ? localized(context, 'half', 'ikilik')
            : localized(context, 'quarter', 'dörtlük');
        final result = n.beats > 1
            ? localized(
                context,
                '{v0} {v1} (beats {v2}–{v3})',
                '{v0} {v1} (vuruş {v2}–{v3})',
                values: {
                  'v0': pitch,
                  'v1': duration,
                  'v2': beat.toInt(),
                  'v3': (beat + n.beats - 1).toInt(),
                },
              )
            : localized(
                context,
                '{v0} {v1} (beat {v2})',
                '{v0} {v1} (vuruş {v2})',
                values: {'v0': pitch, 'v1': duration, 'v2': beat.toInt()},
              );
        beat += n.beats;
        return result;
      })
      .join(', ');
}

class _Vector extends StatelessWidget {
  const _Vector({
    required this.kind,
    required this.description,
    this.right = const [],
    this.left = const [],
  });
  final String kind, description;
  final List<PianoWrittenNote> right, left;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Semantics(
      label: kind == 'score'
          ? '$description ${localized(context, 'Staff positions: bottom line is 0, each space or line above adds 1; negative positions lie below. Even positions are lines; 10 or -2 is a ledger line. ', 'Dizek konumları: alt çizgi 0, üstte her aralık veya çizgi 1 ekler; negatif konumlar alttadır. Çift konumlar çizgidir; 10 veya -2 ek çizgidir. ')}${_positions(right, true, context)} ${_positions(left, false, context)}'
          : description,
      image: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Never shrink note geometry. Narrow screens can pan the vector horizontally.
          final width = constraints.maxWidth < 340
              ? 340.0
              : constraints.maxWidth;
          return Directionality(
            textDirection: TextDirection.ltr,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                height: kind == 'keyboard'
                    ? 150
                    : kind == 'symbols'
                    ? 155
                    : kind == 'rest'
                    ? 140
                    : 255,
                child: CustomPaint(
                  key: Key('piano-vector-$kind'),
                  painter: _PianoPainter(
                    kind,
                    right,
                    left,
                    middleCLabel: localized(
                      context,
                      'C4 = middle C / MIDI 60',
                      'C4 = orta Do / MIDI 60',
                    ),
                    proseDirection: Directionality.of(context),
                    localeTag: Localizations.localeOf(context).toLanguageTag(),
                    pitchLabels: {
                      for (final pitch in const [
                        'C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4', 'C5',
                        'F3', 'G3',
                      ])
                        pitch: musicPitch(context, pitch),
                    },
                    countLabels: [
                      for (var count = 1; count <= 4; count++)
                        appInteger(context, count),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

int pianoStaffPosition(String pitch, {required bool treble}) =>
    'CDEFGAB'.indexOf(pitch[0]) +
    int.parse(pitch.substring(1)) * 7 -
    (treble ? 30 : 18);
String _positions(
  List<PianoWrittenNote> notes,
  bool treble,
  BuildContext context,
) {
  var start = 1.0;
  final prefix = treble
      ? localized(context, 'Treble', 'Sol')
      : localized(context, 'Bass', 'Fa');
  final details = notes
      .map((note) {
        final pos = note.pitch == null
            ? null
            : 'CDEFGAB'.indexOf(note.pitch![0]) +
                  int.parse(note.pitch!.substring(1)) * 7 -
                  (treble ? 30 : 18);
        final result = localized(
          context,
          'beat {v0}, position {v1}, {v2} beats',
          'vuruş {v0}, konum {v1}, {v2} vuruş',
          values: {
            'v0': start.toInt(),
            'v1': pos ?? localized(context, 'rest', 'sus'),
            'v2': note.beats,
          },
          pluralCount: note.beats,
        );
        start += note.beats;
        return result;
      })
      .join('; ');
  return '$prefix: $details';
}

class _PianoPainter extends CustomPainter {
  _PianoPainter(
    this.kind,
    this.right,
    this.left, {
    required this.middleCLabel,
    required this.proseDirection,
    required this.localeTag,
    required this.pitchLabels,
    required this.countLabels,
  });
  final String middleCLabel, localeTag;
  final TextDirection proseDirection;
  final Map<String, String> pitchLabels;
  final List<String> countLabels;
  final String kind;
  final List<PianoWrittenNote> right, left;
  final ink = Paint()
    ..color = Colors.black
    ..strokeWidth = 1.4;
  void label(
    Canvas c,
    String s,
    double x,
    double y, {
    double size = 14,
    TextDirection direction = TextDirection.ltr,
  }) {
    final t = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: Colors.black,
          fontSize: size,
          fontFamily: 'Hanken Grotesk',
        ),
      ),
      textDirection: direction,
    )..layout();
    t.paint(c, Offset(x, y));
  }

  void staff(Canvas c, double bottom, bool treble, double width) {
    for (var i = 0; i < 5; i++) {
      c.drawLine(
        Offset(12, bottom - i * 10),
        Offset(width - 10, bottom - i * 10),
        ink,
      );
    }
    // Hand-drawn G clef: loop surrounds the second line, stem passes through it.
    if (treble) {
      final y = bottom - 10;
      final path = Path()
        ..moveTo(31, y + 28)
        ..cubicTo(47, y + 39, 48, y + 17, 38, y - 8)
        ..cubicTo(19, y - 44, 31, y - 61, 38, y - 43)
        ..cubicTo(48, y - 25, 12, y - 17, 20, y + 2)
        ..cubicTo(25, y + 16, 49, y + 13, 48, y - 1)
        ..cubicTo(46, y - 16, 27, y - 12, 29, y - 2)
        ..cubicTo(30, y + 4, 37, y + 4, 39, y);
      c.drawPath(
        path,
        Paint()
          ..color = Colors.black
          ..strokeWidth = 2.2
          ..style = PaintingStyle.stroke,
      );
    } else {
      final y = bottom - 30;
      final path = Path()
        ..moveTo(22, y + 1)
        ..cubicTo(18, y - 12, 43, y - 13, 41, y + 2)
        ..cubicTo(39, y + 14, 26, y + 21, 20, y + 23);
      c.drawPath(
        path,
        Paint()
          ..color = Colors.black
          ..strokeWidth = 2.3
          ..style = PaintingStyle.stroke,
      );
      c.drawCircle(Offset(24, y), 3, ink);
      c.drawCircle(Offset(48, y - 5), 2, ink);
      c.drawCircle(Offset(48, y + 5), 2, ink);
    }
  }

  int pos(String pitch, bool treble) =>
      pianoStaffPosition(pitch, treble: treble);

  void note(
    Canvas c,
    double x,
    double bottom,
    bool treble,
    PianoWrittenNote n,
  ) {
    if (n.pitch == null) {
      rest(c, x, bottom - 20, n.beats);
      return;
    }
    final position = pos(n.pitch!, treble), y = bottom - position * 5.0;
    for (var step = -2; step >= position; step -= 2) {
      c.drawLine(
        Offset(x - 12, bottom - step * 5),
        Offset(x + 12, bottom - step * 5),
        ink,
      );
    }
    for (var step = 10; step <= position; step += 2) {
      c.drawLine(
        Offset(x - 12, bottom - step * 5),
        Offset(x + 12, bottom - step * 5),
        ink,
      );
    }
    final head = Rect.fromCenter(
      center: Offset(x, y),
      width: n.beats == 4 ? 16 : 13,
      height: 8,
    );
    c.drawOval(
      head,
      Paint()
        ..color = Colors.black
        ..strokeWidth = 2
        ..style = n.beats < 2 ? PaintingStyle.fill : PaintingStyle.stroke,
    );
    if (n.beats < 4) c.drawLine(Offset(x + 6, y), Offset(x + 6, y - 30), ink);
  }

  void rest(Canvas c, double x, double y, double beats) {
    if (beats >= 2) {
      c.drawLine(Offset(x - 15, y), Offset(x + 15, y), ink);
      c.drawRect(Rect.fromLTWH(x - 6, beats == 2 ? y - 5 : y, 12, 5), ink);
    } else {
      final p = Path()
        ..moveTo(x - 3, y - 13)
        ..lineTo(x + 4, y - 6)
        ..lineTo(x - 3, y + 1)
        ..lineTo(x + 5, y + 7)
        ..quadraticBezierTo(x - 6, y + 5, x - 1, y + 14);
      c.drawPath(
        p,
        Paint()
          ..color = Colors.black
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = Colors.white);
    if (kind == 'keyboard') {
      final w = (s.width - 16) / 8;
      for (var i = 0; i < 8; i++) {
        final r = Rect.fromLTWH(8 + i * w, 8, w, 105);
        c.drawRect(
          r,
          Paint()..color = i == 0 ? const Color(0xffffecb3) : Colors.white,
        );
        c.drawRect(
          r,
          Paint()
            ..color = Colors.black
            ..style = PaintingStyle.stroke,
        );
        label(
          c,
          pitchLabels[['C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4', 'C5'][i]]!
              .replaceFirst(' (', '\n('),
          12 + i * w,
          87,
          size: 10,
        );
      }
      for (final i in [0, 1, 3, 4, 5]) {
        c.drawRect(
          Rect.fromLTWH(8 + (i + 1) * w - w * .28, 8, w * .56, 60),
          ink,
        );
      }
      label(
        c,
        middleCLabel,
        8,
        123,
        direction: proseDirection,
      );
      return;
    }
    if (kind == 'symbols') {
      for (var i = 0; i < 3; i++) {
        note(
          c,
          30 + i * 80.0,
          55,
          true,
          PianoWrittenNote('E4', [1.0, 2.0, 4.0][i]),
        );
        label(c, ['1', '2', '4'][i], 25 + i * 80.0, 68);
      }
      note(c, 270, 55, true, const PianoWrittenNote('E4', .5));
      note(c, 305, 55, true, const PianoWrittenNote('E4', .5));
      c.drawLine(
        const Offset(276, 25),
        const Offset(311, 25),
        Paint()
          ..color = Colors.black
          ..strokeWidth = 4,
      );
      label(c, '½ + ½', 265, 68);
      for (var i = 0; i < 3; i++) {
        rest(c, 30 + i * 80.0, 117, [1.0, 2.0, 4.0][i]);
        label(c, ['1', '2', '4'][i], 25 + i * 80.0, 137);
      }
      return;
    }
    final topBottom = 90.0, bassBottom = 205.0;
    staff(c, topBottom, true, s.width);
    if (kind == 'rest') {
      note(c, 95, topBottom, true, const PianoWrittenNote('C4', 1));
      note(c, 155, topBottom, true, const PianoWrittenNote(null, 1));
      note(c, 215, topBottom, true, const PianoWrittenNote('D4', 2));
      return;
    }
    staff(c, bassBottom, false, s.width);
    c.drawLine(const Offset(12, 50), const Offset(12, 205), ink);
    if (kind == 'anchors') {
      for (var i = 0; i < 4; i++) {
        final pitch = ['E4', 'F4', 'G4', 'C4'][i];
        note(c, 90 + i * 62.0, topBottom, true, PianoWrittenNote(pitch, 1));
        label(c, pitchLabels[pitch]!, 80 + i * 62.0, 110, size: 11);
      }
      for (var i = 0; i < 3; i++) {
        final pitch = ['F3', 'G3', 'C4'][i];
        note(c, 105 + i * 80.0, bassBottom, false, PianoWrittenNote(pitch, 1));
        label(c, pitchLabels[pitch]!, 95 + i * 80.0, 225, size: 11);
      }
      return;
    }
    label(c, '4', 57, 52, size: 16);
    label(c, '4', 57, 71, size: 16);
    label(c, '4', 57, 167, size: 16);
    label(c, '4', 57, 186, size: 16);
    final unit = (s.width - 100) / 4;
    for (var beat = 0; beat < 4; beat++) {
      label(c, countLabels[beat], 83 + beat * unit, 235, size: 12);
    }
    for (final pair in [(right, topBottom, true), (left, bassBottom, false)]) {
      var time = 0.0;
      for (final n in pair.$1) {
        note(c, 88 + time * unit, pair.$2, pair.$3, n);
        time += n.beats;
      }
    }
    c.drawLine(Offset(s.width - 12, 50), Offset(s.width - 12, 205), ink);
  }

  @override
  bool shouldRepaint(covariant _PianoPainter old) =>
      old.localeTag != localeTag ||
      old.middleCLabel != middleCLabel ||
      old.proseDirection != proseDirection ||
      old.pitchLabels.length != pitchLabels.length ||
      old.pitchLabels.entries.any(
        (entry) => pitchLabels[entry.key] != entry.value,
      ) ||
      old.countLabels.length != countLabels.length ||
      old.countLabels.indexed.any(
        (entry) => countLabels[entry.$1] != entry.$2,
      ) ||
      old.kind != kind ||
      old.right != right ||
      old.left != left;
}
