import 'package:flutter/material.dart';
import '../app_locale.dart';
import '../ukulele_beginner.dart';

/// Original repo-native diagrams. They display instructions, never observed sound.
class UkuleleDiagrams extends StatelessWidget {
  const UkuleleDiagrams({
    super.key,
    required this.course,
    required this.lesson,
  });
  final UkuleleCourse course;
  final UkuleleLesson lesson;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final id in lesson.diagrams)
        if (id == 'strings') ...[
          Text(
            localized(
              context,
              'Held neck map: top is nearest your face, bottom nearest the floor. Nut at left, body toward right; numbered spaces are frets. D travels 4→1; U returns 1→4.',
              'Tutulan sap haritası: üst yüzüne, alt zemine yakındır. Üst eşik solda, gövde sağa doğrudur; numaralı boşluklar perdelerdir. D yönü 4→1; U dönüşü 1→4.',
            ),
          ),
          _Vector(
            kind: 'strings',
            description: localized(
              context,
              'Strings top to bottom: 4 G4, 3 C4, 2 E4, 1 A4. Fret 0 is open; nut left, frets 1 2 3 toward the body.',
              'Üstten alta teller: 4 Sol4, 3 Do4, 2 Mi4, 1 La4. Perde 0 açık; eşik solda, perdeler 1 2 3 gövdeye doğru.',
            ),
          ),
        ] else if (course.chords.containsKey(id)) ...[
          Text(
            course.chords[id]!.title.of(context),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            localized(
              context,
              'Grid left→right: 4 G, 3 C, 2 E, 1 A. Thick top line = nut. O = open. Dot number = left-hand finger; fret spaces count down from 1.',
              'Izgara soldan sağa: 4 Sol, 3 Do, 2 Mi, 1 La. Kalın üst çizgi = üst eşik. O = açık. Noktadaki sayı = sol el parmağı; perde boşlukları aşağı 1’den sayılır.',
            ),
          ),
          _Vector(
            kind: 'chord',
            chord: course.chords[id],
            description: _chordDescription(course.chords[id]!, context),
          ),
          Text(_chordDescription(course.chords[id]!, context)),
        ] else if (id == 'tab') ...[
          Text(
            localized(
              context,
              'New reading task · all columns are quarter beats',
              'Yeni okuma görevi · tüm sütunlar dörtlük vuruş',
            ),
          ),
          for (var bar = 0; bar < 2; bar++) ...[
            Text(localized(context, 'Bar ${bar + 1}', 'Ölçü ${bar + 1}')),
            _Vector(
              kind: 'tab',
              notes: course.tab.sublist(bar * 4, bar * 4 + 4),
              description: _tabDescription(
                course.tab.sublist(bar * 4, bar * 4 + 4),
                context,
              ),
            ),
          ],
          ExpansionTile(
            key: const Key('ukulele-tab-answers'),
            title: Text(
              localized(
                context,
                'Show string/fret answers after decoding',
                'Çözdükten sonra tel/perde cevaplarını göster',
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var bar = 0; bar < 2; bar++)
                      Text(
                        '${localized(context, 'Bar', 'Ölçü')} ${bar + 1}: ${[for (var beat = 0; beat < 4; beat++) '${localized(context, 'beat', 'vuruş')} ${beat + 1}: ${localized(context, 'string', 'tel')} ${course.tab[bar * 4 + beat].string}, ${localized(context, 'fret', 'perde')} ${course.tab[bar * 4 + beat].fret} (${_pitch(course.tab[bar * 4 + beat].pitch, context)})'].join('; ')}. ${localized(context, 'Each note one beat. Pitch names are explanatory; compare the string/fret pairs you decoded.', 'Her nota bir vuruş. Ses adları açıklamadır; çözdüğün tel/perde çiftlerini karşılaştır.')}',
                      ),
                    Text(
                      localized(
                        context,
                        'Compare your written reading yourself. Tuning and performance are not checked by this panel.',
                        'Yazılı çözümünü kendin karşılaştır. Bu panel akordu veya çalımı kontrol etmez.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ] else if (id == 'study') ...[
          Text(
            localized(
              context,
              'Eight-bar original study · 4/4',
              'Sekiz ölçülük özgün etüt · 4/4',
            ),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            localized(
              context,
              'Each column is half a beat: 1 & 2 & 3 & 4 &. D down 4→1; U up 1→4; H no new stroke, keep ringing or silence; R stop sound, counted silence. Pan the table horizontally on a narrow screen.',
              'Her sütun yarım vuruş: 1 ve 2 ve 3 ve 4 ve (& = ve). D aşağı 4→1; U yukarı 1→4; H yeni tarama yok, çınlama veya sessizlik sürer; R sesi kes, sayılan sessizlik. Dar ekranda tabloyu yatay kaydır.',
            ),
          ),
          for (var bar = 0; bar < course.study.length; bar++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${localized(context, 'Bar', 'Ölçü')} ${bar + 1} · ${course.chords[course.study[bar].chord]!.title.of(context)}',
                  ),
                  Semantics(
                    label: _studyDescription(course.study[bar], context),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 480,
                        child: Table(
                          border: TableBorder.all(color: Colors.black54),
                          defaultColumnWidth: const FixedColumnWidth(60),
                          children: [
                            TableRow(
                              children: [
                                for (final count in [
                                  '1',
                                  '&',
                                  '2',
                                  '&',
                                  '3',
                                  '&',
                                  '4',
                                  '&',
                                ])
                                  Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Text(
                                      count,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              ],
                            ),
                            TableRow(
                              children: [
                                for (final slot in course.study[bar].slots)
                                  Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Text(
                                      slot,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
    ],
  );
}

String _pitch(String pitch, BuildContext context) {
  const tr = {
    'C': 'Do',
    'C#': 'Do♯',
    'D': 'Re',
    'D#': 'Re♯',
    'E': 'Mi',
    'F': 'Fa',
    'F#': 'Fa♯',
    'G': 'Sol',
    'G#': 'Sol♯',
    'A': 'La',
    'A#': 'La♯',
    'B': 'Si',
  };
  return localized(
    context,
    pitch,
    '${tr[pitch.substring(0, pitch.length - 1)]}${pitch[pitch.length - 1]}',
  );
}

String _chordDescription(UkuleleChord chord, BuildContext context) => [
  for (var i = 0; i < 4; i++)
    '${localized(context, 'string', 'tel')} ${4 - i}: ${chord.frets[i] == 0 ? localized(context, 'open', 'açık') : '${localized(context, 'fret', 'perde')} ${chord.frets[i]}, ${localized(context, 'finger', 'parmak')} ${chord.fingers[i]}'}',
].join('; ');
String _tabDescription(List<UkuleleTabNote> notes, BuildContext context) => [
  for (var i = 0; i < notes.length; i++)
    '${localized(context, 'beat', 'vuruş')} ${i + 1}: ${localized(context, 'string', 'tel')} ${notes[i].string}, ${localized(context, 'fret', 'perde')} ${notes[i].fret}',
].join('; ');
String _studyDescription(UkuleleStudyBar bar, BuildContext context) => [
  for (var i = 0; i < 8; i++)
    '${i ~/ 2 + 1}${i.isOdd ? localized(context, ' and', ' ve') : ''}: ${switch (bar.slots[i]) {
      'D' => localized(context, 'downstroke', 'aşağı tarama'),
      'U' => localized(context, 'upstroke', 'yukarı tarama'),
      'R' => localized(context, 'stop sound', 'sesi kes'),
      _ => localized(context, 'no new stroke', 'yeni tarama yok'),
    }}',
].join('; ');

class _Vector extends StatelessWidget {
  const _Vector({
    required this.kind,
    required this.description,
    this.chord,
    this.notes = const [],
  });
  final String kind, description;
  final UkuleleChord? chord;
  final List<UkuleleTabNote> notes;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Semantics(
      label: description,
      image: true,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: constraints.maxWidth < 340 ? 340 : constraints.maxWidth,
            height: kind == 'chord'
                ? 265
                : kind == 'tab'
                ? 170
                : 220,
            child: CustomPaint(
              key: Key('ukulele-vector-$kind'),
              painter: _UkePainter(kind, chord, notes),
            ),
          ),
        ),
      ),
    ),
  );
}

class _UkePainter extends CustomPainter {
  _UkePainter(this.kind, this.chord, this.notes);
  final String kind;
  final UkuleleChord? chord;
  final List<UkuleleTabNote> notes;
  final ink = Paint()
    ..color = Colors.black
    ..strokeWidth = 1.4;
  void label(
    Canvas c,
    String text,
    double x,
    double y, {
    double size = 16,
    Color color = Colors.black,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Hanken Grotesk',
          fontSize: size,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(c, Offset(x, y));
  }

  @override
  void paint(Canvas c, Size size) {
    c.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    if (kind == 'strings') {
      for (var i = 0; i < 4; i++) {
        final y = 50 + i * 40.0;
        label(c, ['4 G4', '3 C4', '2 E4', '1 A4'][i], 8, y - 11);
        c.drawLine(Offset(80, y), Offset(size.width - 35, y), ink);
      }
      c.drawLine(
        const Offset(80, 40),
        const Offset(80, 180),
        Paint()
          ..color = Colors.black
          ..strokeWidth = 5,
      );
      for (var i = 1; i <= 3; i++) {
        final x = 80 + (size.width - 125) / 3 * i;
        c.drawLine(Offset(x, 40), Offset(x, 180), ink);
        label(c, '$i', x - (size.width - 125) / 6 - 5, 12);
      }
      final x = size.width - 15;
      c.drawLine(Offset(x, 55), Offset(x, 165), ink);
      c.drawLine(Offset(x, 165), Offset(x - 6, 156), ink);
      c.drawLine(Offset(x, 165), Offset(x + 6, 156), ink);
      label(c, 'D', x - 6, 185);
      return;
    }
    if (kind == 'chord') {
      const y = 60.0, step = 48.0;
      final gap = (size.width - 110) / 3;
      for (var i = 0; i < 4; i++) {
        final x = 55 + i * gap;
        label(c, ['4 G', '3 C', '2 E', '1 A'][i], x - 13, 228, size: 14);
        c.drawLine(Offset(x, y), Offset(x, y + 3 * step), ink);
        if (chord!.frets[i] == 0) {
          label(c, 'O', x - 7, 27);
        } else {
          final dotY = y + (chord!.frets[i] - .5) * step;
          c.drawCircle(Offset(x, dotY), 13, ink);
          label(
            c,
            '${chord!.fingers[i]}',
            x - 4.5,
            dotY - 11,
            size: 17,
            color: Colors.white,
          );
        }
      }
      for (var fret = 0; fret <= 3; fret++) {
        c.drawLine(
          Offset(55, y + fret * step),
          Offset(size.width - 55, y + fret * step),
          Paint()
            ..color = Colors.black
            ..strokeWidth = fret == 0 ? 5 : 1.4,
        );
        if (fret > 0) label(c, '$fret', 20, y + (fret - .5) * step - 11);
      }
      return;
    }
    for (var i = 0; i < 4; i++) {
      final y = 35 + i * 30.0;
      label(c, ['1 A', '2 E', '3 C', '4 G'][i], 8, y - 11, size: 14);
      c.drawLine(Offset(65, y), Offset(size.width - 10, y), ink);
    }
    final unit = (size.width - 100) / 4;
    for (var i = 0; i < notes.length; i++) {
      final x = 85 + i * unit, y = 35 + (notes[i].string - 1) * 30.0;
      c.drawRect(
        Rect.fromCenter(center: Offset(x, y), width: 22, height: 23),
        Paint()..color = Colors.white,
      );
      label(c, '${notes[i].fret}', x - 5, y - 12, size: 18);
      label(c, '${i + 1}', x - 5, 145, size: 14);
    }
  }

  @override
  bool shouldRepaint(covariant _UkePainter old) =>
      old.kind != kind || old.chord != chord || old.notes != notes;
}
