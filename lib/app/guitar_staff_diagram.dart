import 'package:flutter/material.dart';

import 'app_locale.dart';
import 'app_theme.dart';
import 'design/ostinato_theme.dart';
import 'design/widgets.dart';
import 'guitar_journey.dart';

int guitarWrittenStaffStep(String written) {
  const letters = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  return int.parse(written.substring(1)) * 7 +
      letters.indexOf(written[0]) -
      (4 * 7 + 2); // E4 is the bottom treble line.
}

/// Original, compiled vector artwork. No recording, notation library or sensor
/// is used. Written guitar pitches sound one octave lower in standard tuning.
final class GuitarStaffNote {
  const GuitarStaffNote(this.written, this.sounding, this.string, this.fret);
  final String written, sounding;
  final int string, fret;

  int get staffStep => guitarWrittenStaffStep(written);

  List<int> get ledgerSteps => [
    if (staffStep < -1)
      for (var step = -2; step >= staffStep; step -= 2) step,
    if (staffStep > 9)
      for (var step = 10; step <= staffStep; step += 2) step,
  ];
}

const guitarOpenStaffNotes = [
  GuitarStaffNote('E3', 'E2', 6, 0),
  GuitarStaffNote('A3', 'A2', 5, 0),
  GuitarStaffNote('D4', 'D3', 4, 0),
  GuitarStaffNote('G4', 'G3', 3, 0),
  GuitarStaffNote('B4', 'B3', 2, 0),
  GuitarStaffNote('E5', 'E4', 1, 0),
];
const guitarFirstStringStaffNotes = [
  GuitarStaffNote('E5', 'E4', 1, 0),
  GuitarStaffNote('F5', 'F4', 1, 1),
  GuitarStaffNote('G5', 'G4', 1, 3),
];

class GuitarStaffDiagram extends StatelessWidget {
  const GuitarStaffDiagram({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        key: const Key('guitar-staff-diagram'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localized(context, 'Read the staff', 'Porteyi oku'),
              style: hankenText(size: 17, weight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              localized(
                context,
                'Treble clef: the second line from the bottom is G4. Guitar sounds one octave below the written pitch.',
                'Sol anahtarı: aşağıdan ikinci çizgi G4. Gitar, yazılandan bir oktav pes seslenir.',
              ),
              style: hankenText(size: 13, height: 1.5),
            ),
            _staff(context, guitarOpenStaffNotes),
            for (final note in guitarOpenStaffNotes)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  localized(context, "Open string {v0}: written {v1} → sounding {v2}", "{v0}. açık tel: yazılı {v1} → seslenen {v2}", values: {"v0": note.string, "v1": note.written, "v2": note.sounding}),
                  style: hankenText(size: 13, height: 1.4),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              localized(
                context,
                'Three quarter notes on string 1',
                'İlk telde üç dörtlük nota',
              ),
              style: hankenText(size: 15, weight: FontWeight.w600),
            ),
            _staff(context, guitarFirstStringStaffNotes),
            Text(
              localized(
                context,
                'Written E5 – F5 – G5; sounding E4 – F4 – G4. String 1 frets: 0 – 1 – 3. A filled head and stem show a quarter note.',
                'Yazılı E5 – F5 – G5; seslenen E4 – F4 – G4. İlk tel perdeleri: 0 – 1 – 3. Dolu baş ve sap bir dörtlük notayı gösterir.',
              ),
              style: hankenText(size: 13, height: 1.5),
            ),
            const SizedBox(height: 10),
            Text(
              localized(
                context,
                'Original teaching schematic; not an audio measurement or skill test. Short ledger lines show pitches outside the staff.',
                'Özgün öğretim şeması; ses ölçümü veya başarı testi değildir. Kısa ek çizgiler porte dışındaki notaları gösterir.',
              ),
              style: hankenText(size: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _staff(BuildContext context, List<GuitarStaffNote> notes) => ExcludeSemantics(
    // All visual information is repeated in scalable, readable text above/below.
    child: SizedBox(
      height: 180,
      width: double.infinity,
      child: CustomPaint(
        painter: _StaffPainter(
          notes,
          inkColor: OstinatoPalette.of(context).notationInk,
          paperColor: OstinatoPalette.of(context).notationPaper,
        ),
      ),
    ),
  );
}

class _StaffPainter extends CustomPainter {
  const _StaffPainter(
    this.notes, {
    required this.inkColor,
    required this.paperColor,
  });
  final Color inkColor, paperColor;
  final List<GuitarStaffNote> notes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = paperColor);
    canvas.save();
    canvas.scale(size.width / 300, size.height / 180);
    final ink = Paint()
      ..color = inkColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    double y(int step) => 112 - step * 6;
    for (var step = 0; step <= 8; step += 2) {
      canvas.drawLine(Offset(8, y(step)), Offset(290, y(step)), ink);
    }
    // Hand-drawn G-clef contour, with its coil centred on the G4 line (step2).
    final clef = Path()
      ..moveTo(28, 100)
      ..cubicTo(43, 82, 48, 115, 28, 116)
      ..cubicTo(5, 116, 9, 93, 26, 83)
      ..cubicTo(44, 71, 42, 45, 31, 43)
      ..cubicTo(17, 60, 29, 108, 33, 131)
      ..cubicTo(38, 149, 20, 151, 21, 138);
    canvas.drawPath(clef, ink..strokeWidth = 2.5);
    for (var i = 0; i < notes.length; i++) {
      final note = notes[i];
      final x = 68 + i * (208 / (notes.length - 1));
      for (final step in note.ledgerSteps) {
        canvas.drawLine(Offset(x - 12, y(step)), Offset(x + 12, y(step)), ink);
      }
      canvas.save();
      canvas.translate(x, y(note.staffStep));
      canvas.rotate(-0.25);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 14, height: 9),
        Paint()..color = inkColor,
      );
      canvas.restore();
      final down = note.staffStep >= 4;
      canvas.drawLine(
        Offset(x + (down ? -6 : 6), y(note.staffStep)),
        Offset(x + (down ? -6 : 6), y(note.staffStep) + (down ? 32 : -32)),
        ink,
      );
      // Circled numbers are string numbers, never fingers or pitch readings.
      canvas.drawCircle(Offset(x, 20), 11, ink);
      final label = TextPainter(
        text: TextSpan(
          text: '${note.string}',
          style: monoText(size: 13, color: inkColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(x - label.width / 2, 20 - label.height / 2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StaffPainter oldDelegate) => oldDelegate.notes != notes ||
      oldDelegate.inkColor != inkColor ||
      oldDelegate.paperColor != paperColor;
}

/// Four original 4/4 bars for the final reading task. This is a drawing and a
/// readable transcription, never a microphone result or sight-reading grade.
class GuitarFirstReadScore extends StatelessWidget {
  const GuitarFirstReadScore({super.key, required this.score});

  final GuitarJourneyFirstReadScore score;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      key: const Key('guitar-first-read-score'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localized(
              context,
              'Original four-bar staff',
              'Özgün dört ölçülük porte',
            ),
            style: hankenText(size: 17, weight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            localized(
              context,
              'Treble clef, 4/4. Written guitar notes are one octave above their sounding pitches. Use the staff or the scalable note-and-duration text below; the text also works with a screen reader, and both describe the same four bars.',
              'Sol anahtarı, 4/4. Gitarın yazılı notaları duyulandan bir oktav yukarıdadır. Porteyi veya aşağıdaki büyütülebilir nota ve süre metnini kullan; metin ekran okuyucuyla da okunur ve ikisi aynı dört ölçüyü anlatır.',
            ),
            style: hankenText(size: 13, height: 1.5),
          ),
          for (var barIndex = 0; barIndex < score.bars.length; barIndex++) ...[
            const SizedBox(height: 12),
            Text(
              localized(context, "Bar {v0}", "{v0}. ölçü", values: {"v0": barIndex + 1}),
              style: hankenText(size: 14, weight: FontWeight.w600),
            ),
            ExcludeSemantics(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 340,
                  height: 150,
                  child: CustomPaint(
                    painter: _FirstReadBarPainter(
                      score.bars[barIndex],
                      inkColor: OstinatoPalette.of(context).notationInk,
                      paperColor: OstinatoPalette.of(context).notationPaper,
                      showMeter: barIndex == 0,
                      finalBar: barIndex == score.bars.length - 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            localized(
              context,
              'Readable notes and durations',
              'Nota ve sürelerin okunabilir karşılığı',
            ),
            style: hankenText(size: 14, weight: FontWeight.w600),
          ),
          for (var barIndex = 0; barIndex < score.bars.length; barIndex++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SelectableText(
                _barDescription(context, score.bars[barIndex], barIndex),
                style: hankenText(size: 12.5, height: 1.5),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            localized(
              context,
              'This card is self-guided practice; it is not an audio measurement or graded sight-reading exam.',
              'Bu kart öz denetimli çalışmadır; ses ölçümü veya puanlı deşifre sınavı değildir.',
            ),
            style: hankenText(size: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  String _barDescription(
    BuildContext context,
    List<GuitarJourneyScoreEvent> events,
    int index,
  ) {
    final parts = <String>[];
    for (final event in events) {
      if (event.isRest) {
        parts.add(localized(context, 'one-beat rest', 'bir vuruş sus'));
      } else {
        final duration = event.ticks == 2
            ? localized(context, 'quarter note', 'dörtlük')
            : localized(context, 'eighth note', 'sekizlik');
        parts.add(localized(context,
          'written {v0} (sounds {v1}), {v2}',
          'yazılı {v0} (duyulan {v1}), {v2}',
          values: {'v0': musicPitch(context, event.written!),
            'v1': musicPitch(context, event.sounding!), 'v2': duration}));
      }
    }
    return localized(context, 'Bar {v0}: {v1}.', '{v0}. ölçü: {v1}.',
      values: {'v0': index + 1, 'v1': parts.join('; ')});
  }
}

class _FirstReadBarPainter extends CustomPainter {
  const _FirstReadBarPainter(
    this.events, {
    required this.inkColor,
    required this.paperColor,
    required this.showMeter,
    required this.finalBar,
  });

  final List<GuitarJourneyScoreEvent> events;
  final Color inkColor, paperColor;
  final bool showMeter;
  final bool finalBar;

  static const _firstX = 100.0;
  static const _tickWidth = 25.0;
  static double _y(int staffStep) => 108 - staffStep * 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = paperColor);
    canvas.save();
    canvas.scale(size.width / 340, size.height / 150);
    final ink = Paint()
      ..color = inkColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (var step = 0; step <= 8; step += 2) {
      canvas.drawLine(Offset(8, _y(step)), Offset(320, _y(step)), ink);
    }
    // The same original treble-clef contour used by the earlier staff lesson.
    final clef = Path()
      ..moveTo(28, 96)
      ..cubicTo(43, 78, 48, 111, 28, 112)
      ..cubicTo(5, 112, 9, 89, 26, 79)
      ..cubicTo(44, 67, 42, 41, 31, 39)
      ..cubicTo(17, 56, 29, 104, 33, 127)
      ..cubicTo(38, 145, 20, 147, 21, 134);
    canvas.drawPath(clef, ink..strokeWidth = 2.5);
    if (showMeter) {
      _text(canvas, '4', const Offset(61, 60), 21);
      _text(canvas, '4', const Offset(61, 84), 21);
    }

    final starts = <int>[];
    var tick = 0;
    for (final event in events) {
      starts.add(tick);
      tick += event.ticks;
    }
    final beamed = <int>{};
    for (var i = 0; i < events.length - 1; i++) {
      if (events[i].ticks == 1 &&
          events[i + 1].ticks == 1 &&
          !events[i].isRest &&
          !events[i + 1].isRest &&
          starts[i].isEven) {
        beamed.add(i);
        beamed.add(i + 1);
        final leftX = _firstX + starts[i] * _tickWidth;
        final rightX = _firstX + starts[i + 1] * _tickWidth;
        final leftY = _y(guitarWrittenStaffStep(events[i].written!));
        final rightY = _y(guitarWrittenStaffStep(events[i + 1].written!));
        final beamY = (leftY > rightY ? leftY : rightY) + 33;
        canvas.drawLine(
          Offset(leftX - 6, leftY),
          Offset(leftX - 6, beamY),
          ink,
        );
        canvas.drawLine(
          Offset(rightX - 6, rightY),
          Offset(rightX - 6, beamY),
          ink,
        );
        canvas.drawRect(
          Rect.fromLTWH(leftX - 6, beamY - 2, rightX - leftX, 5),
          Paint()..color = inkColor,
        );
        i++;
      }
    }
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      final x = _firstX + starts[i] * _tickWidth;
      if (event.isRest) {
        _quarterRest(canvas, x, ink);
        continue;
      }
      final step = guitarWrittenStaffStep(event.written!);
      final y = _y(step);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(-0.25);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 14, height: 9),
        Paint()..color = inkColor,
      );
      canvas.restore();
      if (!beamed.contains(i)) {
        final down = step >= 4;
        canvas.drawLine(
          Offset(x + (down ? -6 : 6), y),
          Offset(x + (down ? -6 : 6), y + (down ? 33 : -33)),
          ink,
        );
      }
    }
    canvas.drawLine(const Offset(312, 60), const Offset(312, 108), ink);
    if (finalBar) {
      canvas.drawLine(
        const Offset(318, 60),
        const Offset(318, 108),
        ink..strokeWidth = 3,
      );
    }
    canvas.restore();
  }

  void _quarterRest(Canvas canvas, double x, Paint ink) {
    // An original vector quarter-rest contour; no platform music glyph needed.
    final rest = Path()
      ..moveTo(x - 3, 66)
      ..lineTo(x + 3, 74)
      ..lineTo(x - 2, 82)
      ..lineTo(x + 5, 91)
      ..quadraticBezierTo(x - 8, 89, x - 3, 100)
      ..quadraticBezierTo(x + 2, 107, x + 5, 100);
    canvas.drawPath(
      rest,
      Paint()
        ..color = ink.color
        ..strokeWidth = 2.7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _text(Canvas canvas, String value, Offset at, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: monoText(size: size, color: inkColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_FirstReadBarPainter oldDelegate) =>
      oldDelegate.inkColor != inkColor ||
      oldDelegate.paperColor != paperColor ||
      oldDelegate.events != events ||
      oldDelegate.showMeter != showMeter ||
      oldDelegate.finalBar != finalBar;
}
