import 'package:flutter/material.dart';
import '../app_locale.dart';
import '../bass_beginner.dart';

/// Original instruction diagrams, never captured or judged performance.
class BassDiagrams extends StatelessWidget {
  const BassDiagrams({super.key, required this.course, required this.lesson});
  final BassCourse course;
  final BassLesson lesson;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final id in lesson.diagrams)
        if (id == 'strings' || id == 'frets') ...[
          Text(
            localized(
              context,
              'Held neck map: top nearest your face, bottom nearest floor. Nut left; body right. Fret spaces count 1, 2, 3 toward the body. Labels name sounding pitches.',
              'Tutulan sap: üst yüzüne, alt zemine yakın. Üst eşik solda, gövde sağda. Perde boşlukları gövdeye doğru 1, 2, 3 sayılır. Etiketler gerçek sesleri adlandırır.',
            ),
          ),
          _Vector(
            kind: id,
            description: localized(
              context,
              'Top to bottom: string 4 E1, 3 A1, 2 D2, 1 G2. Nut at left, frets 1 to 3 right. String 4 fret 1 F1, fret 3 G1; string 3 fret 2 B1; string 2 fret 2 E2.',
              'Üstten alta: tel 4 Mi1, 3 La1, 2 Re2, 1 Sol2. Eşik solda, perdeler 1–3 sağda. Tel 4 perde 1 Fa1, perde 3 Sol1; tel 3 perde 2 Si1; tel 2 perde 2 Mi2.',
            ),
          ),
        ] else if (id == 'pairs') ...[
          Text(
            localized(
              context,
              'Original pair map · sounding pitches',
              'Özgün çift haritası · gerçek sesler',
            ),
          ),
          for (final row in [
            [
              'E1 → B1',
              '4/0 → 3/2',
              localized(
                context,
                'perfect fifth, 7 semitones',
                'tam beşli, 7 yarım ses',
              ),
            ],
            [
              'A1 → E2',
              '3/0 → 2/2',
              localized(
                context,
                'perfect fifth, 7 semitones',
                'tam beşli, 7 yarım ses',
              ),
            ],
            [
              'E1 → E2',
              '4/0 → 2/2',
              localized(context, 'octave, 12 semitones', 'oktav, 12 yarım ses'),
            ],
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '${_pitchPhrase(row[0], context)}\n${localized(context, 'string/fret', 'tel/perde')}: ${row[1]}\n${row[2]}',
              ),
            ),
        ] else if (id == 'staff') ...[
          Text(
            localized(
              context,
              'Four OPEN-string notation examples (not a melody)',
              'Dört AÇIK tel yazım örneği (melodi değil)',
            ),
          ),
          Text(
            localized(
              context,
              'Bass clef: written pitch is one octave ABOVE sound. Staff lines are not strings. Each separate example is a quarter note.',
              'Fa anahtarı: yazılı ses gerçek sesten bir oktav TİZ. Porte çizgileri tel değildir. Her ayrı örnek dörtlük notadır.',
            ),
          ),
          _Vector(
            kind: 'staff',
            description: localized(
              context,
              'Five-line bass clef. Written E2 on one ledger below sounds E1, open string4; A2 bottom space sounds A1, string3; D3 middle line sounds D2, string2; G3 top space sounds G2, string1.',
              'Beş çizgili Fa anahtarı. Yazılı Mi2 altta bir ek çizgide Mi1 sesi verir, açık tel4; La2 alt boşlukta La1 sesi, tel3; Re3 orta çizgide Re2 sesi, tel2; Sol3 üst boşlukta Sol2 sesi, tel1.',
            ),
          ),
          for (final pair in [
            ('E2', 'E1', 4),
            ('A2', 'A1', 3),
            ('D3', 'D2', 2),
            ('G3', 'G2', 1),
          ])
            Text(
              '${localized(context, 'written', 'yazılı')} ${_pitch(pair.$1, context)} → ${localized(context, 'sounds', 'gerçek ses')} ${_pitch(pair.$2, context)} · ${localized(context, 'open string', 'açık tel')} ${pair.$3}',
            ),
        ] else if (id == 'tab') ...[
          Text(
            localized(
              context,
              'New two-bar reading task · one quarter beat per column',
              'Yeni iki ölçülük okuma görevi · sütunda bir dörtlük vuruş',
            ),
          ),
          for (var bar = 0; bar < 2; bar++) ...[
            Text('${localized(context, 'Bar', 'Ölçü')} ${bar + 1}'),
            _Vector(
              kind: 'tab',
              notes: course.tab.sublist(bar * 4, bar * 4 + 4),
              description: [
                for (var i = 0; i < 4; i++)
                  '${localized(context, 'beat', 'vuruş')} ${i + 1}: ${localized(context, 'string', 'tel')} ${course.tab[bar * 4 + i].string}, ${localized(context, 'fret', 'perde')} ${course.tab[bar * 4 + i].fret}',
              ].join('; '),
            ),
          ],
          ExpansionTile(
            key: const Key('bass-tab-answers'),
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
                        '${localized(context, 'Bar', 'Ölçü')} ${bar + 1}: ${[for (var beat = 0; beat < 4; beat++) '${localized(context, 'beat', 'vuruş')} ${beat + 1}: ${localized(context, 'string', 'tel')} ${course.tab[bar * 4 + beat].string}, ${localized(context, 'fret', 'perde')} ${course.tab[bar * 4 + beat].fret} (${_pitch(course.tab[bar * 4 + beat].pitch, context)})'].join('; ')}. ${localized(context, 'Each note one beat; pitch labels are SOUNDING information.', 'Her nota bir vuruş; ses etiketleri GERÇEK ses bilgisidir.')}',
                      ),
                    Text(
                      localized(
                        context,
                        'Compare your written reading yourself. This panel checks neither tuning nor playing.',
                        'Yazılı çözümünü kendin karşılaştır. Bu panel ne akordu ne çalımı kontrol eder.',
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
              'Eight-bar original bass study · 4/4',
              'Sekiz ölçülük özgün bas etüdü · 4/4',
            ),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            localized(
              context,
              'Each column is half a beat: 1 & 2 & 3 & 4 &. N = pluck the string/fret shown (one note), H = no new attack, keep current sound or silence; R = stop sound, count silence. N replaces the old note; mute its old string. H is not hammer-on. Pan each table horizontally to read every cell.',
              'Her sütun yarım vuruş: 1 ve 2 ve 3 ve 4 ve (& = ve). N = gösterilen tel/perdeyi çek (tek nota), H = yeni çekiş yok, mevcut ses/sessizlik sürer; R = sesi kes, sessizlik say. N eski notanın yerini alır; eski teli sustur. H hammer-on değildir. Her hücreyi okumak için tabloyu yatay kaydır.',
            ),
          ),
          for (var bar = 0; bar < 8; bar++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${localized(context, 'Bar', 'Ölçü')} ${bar + 1}'),
                  Semantics(
                    label: [
                      for (var i = 0; i < 8; i++)
                        '${i ~/ 2 + 1}${i.isOdd ? ' &' : ''}: ${_event(course.study[bar].events[i], context)}',
                    ].join('; '),
                    child: SingleChildScrollView(
                      key: Key('bass-study-${bar + 1}'),
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 800,
                        child: Table(
                          border: TableBorder.all(color: Colors.black54),
                          defaultColumnWidth: const FixedColumnWidth(100),
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
                                for (final event in course.study[bar].events)
                                  Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Text(
                                      event.kind == 'note'
                                          ? 'N\n${event.string}/${event.fret}'
                                          : event.kind == 'hold'
                                          ? 'H'
                                          : 'R',
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

String _event(BassEvent event, BuildContext context) => event.kind == 'note'
    ? '${localized(context, 'pluck string', 'tel çek')} ${event.string}, ${localized(context, 'fret', 'perde')} ${event.fret} (${_pitch(event.pitch!, context)})'
    : event.kind == 'hold'
    ? localized(
        context,
        'no new attack, maintain sound or silence',
        'yeni çekiş yok, ses veya sessizlik sürer',
      )
    : localized(context, 'stop, counted silence', 'sustur, sayılan sessizlik');
String _pitch(String pitch, BuildContext context) {
  if (Localizations.localeOf(context).languageCode != 'tr') {
    return pitch;
  }
  const names = {
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
  return '${names[pitch.substring(0, pitch.length - 1)]}${pitch[pitch.length - 1]}';
}

String _pitchPhrase(String pair, BuildContext context) =>
    pair.split(' → ').map((p) => _pitch(p, context)).join(' → ');

class _Vector extends StatelessWidget {
  const _Vector({
    required this.kind,
    required this.description,
    this.notes = const [],
  });
  final String kind, description;
  final List<BassTabNote> notes;
  @override
  Widget build(BuildContext context) => Semantics(
    label: description,
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: constraints.maxWidth < 380 ? 380 : constraints.maxWidth,
          height: kind == 'tab'
              ? 170
              : kind == 'staff'
              ? 170
              : 230,
          child: CustomPaint(
            key: Key('bass-vector-$kind'),
            painter: _BassPainter(kind, notes),
          ),
        ),
      ),
    ),
  );
}

int bassWrittenStaffPosition(String pitch) =>
    'CDEFGAB'.indexOf(pitch[0]) + int.parse(pitch.substring(1)) * 7 - 18;

class _BassPainter extends CustomPainter {
  _BassPainter(this.kind, this.notes);
  final String kind;
  final List<BassTabNote> notes;
  final ink = Paint()
    ..color = Colors.black
    ..strokeWidth = 1.4;
  void label(Canvas c, String text, double x, double y, {double size = 16}) {
    final p = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black,
          fontSize: size,
          fontFamily: 'Hanken Grotesk',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(c, Offset(x, y));
  }

  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = Colors.white);
    if (kind == 'strings' || kind == 'frets') {
      final step = (s.width - 110) / 3;
      for (var i = 0; i < 4; i++) {
        final y = 50 + i * 43.0;
        label(c, ['4 E1', '3 A1', '2 D2', '1 G2'][i], 5, y - 10, size: 14);
        c.drawLine(Offset(75, y), Offset(s.width - 10, y), ink);
      }
      for (var f = 0; f <= 3; f++) {
        final x = 75 + f * step;
        c.drawLine(
          Offset(x, 35),
          Offset(x, 195),
          Paint()
            ..color = Colors.black
            ..strokeWidth = f == 0 ? 5 : 1.4,
        );
        if (f > 0) {
          label(c, '$f', x - step / 2 - 5, 5);
        }
      }
      if (kind == 'frets') {
        for (final n in [
          (4, 1, 'F1'),
          (4, 3, 'G1'),
          (3, 2, 'B1'),
          (2, 2, 'E2'),
        ]) {
          final x = 75 + (n.$2 - .5) * step, y = 50 + (4 - n.$1) * 43.0;
          c.drawRect(
            Rect.fromCenter(center: Offset(x, y), width: 34, height: 24),
            Paint()..color = Colors.white,
          );
          label(c, n.$3, x - 12, y - 10, size: 14);
        }
      }
      return;
    }
    if (kind == 'staff') {
      const bottom = 100.0;
      for (var i = 0; i < 5; i++) {
        c.drawLine(
          Offset(10, bottom - i * 12),
          Offset(s.width - 10, bottom - i * 12),
          ink,
        );
      }
      final curve = Path()
        ..moveTo(17, bottom - 35)
        ..cubicTo(18, bottom - 54, 49, bottom - 45, 39, bottom - 29)
        ..quadraticBezierTo(33, bottom - 15, 17, bottom - 8);
      c.drawPath(
        curve,
        Paint()
          ..color = Colors.black
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );
      c.drawCircle(const Offset(23, bottom - 36), 3.5, ink);
      c.drawCircle(const Offset(47, bottom - 42), 2, ink);
      c.drawCircle(const Offset(47, bottom - 30), 2, ink);
      for (var i = 0; i < 4; i++) {
        final x = 85 + i * (s.width - 110) / 4;
        final pitch = ['E2', 'A2', 'D3', 'G3'][i];
        final pos = bassWrittenStaffPosition(pitch), y = bottom - pos * 6;
        if (pos == -2) {
          c.drawLine(Offset(x - 13, y), Offset(x + 13, y), ink);
        }
        c.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 13, height: 8),
          ink,
        );
        // Separate single-voice quarter examples use conventional stem direction.
        if (pos >= 4) {
          c.drawLine(Offset(x - 6, y), Offset(x - 6, y + 28), ink);
        } else {
          c.drawLine(Offset(x + 6, y), Offset(x + 6, y - 28), ink);
        }
        label(c, pitch, x - 10, 130, size: 14);
      }
      return;
    }
    for (var i = 0; i < 4; i++) {
      final y = 35 + i * 30.0;
      label(c, ['1 G', '2 D', '3 A', '4 E'][i], 8, y - 11, size: 14);
      c.drawLine(Offset(65, y), Offset(s.width - 10, y), ink);
    }
    final unit = (s.width - 100) / 4;
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
  bool shouldRepaint(covariant _BassPainter old) =>
      old.kind != kind || old.notes != notes;
}
