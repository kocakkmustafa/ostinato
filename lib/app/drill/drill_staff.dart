import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'drill_generator.dart';

/// Staff step from the bottom line (treble E4 = 0, bass G2 = 0); the same
/// numbering as `pianoStaffPosition`.
int drillStaffStep(String pitch, String clef) =>
    'CDEFGAB'.indexOf(pitch[0]) +
    int.parse(pitch.substring(1)) * 7 -
    (clef == 'treble' ? 30 : 18);

/// Key-signature steps per clef, in the order they are written.
const Map<String, List<int>> _sharpSteps = {
  'treble': [8, 5, 9, 6, 3, 7, 4], // F5 C5 G5 D5 A4 E5 B4
  'bass': [6, 3, 7, 4, 1, 5, 2], // F3 C3 G3 D3 A2 E3 B2
};
const Map<String, List<int>> _flatSteps = {
  'treble': [4, 7, 3, 6, 2, 5, 1], // B4 E5 A4 D5 G4 C5 F4
  'bass': [2, 5, 1, 4, 0, 3, -1], // B2 E3 A2 D3 G2 C3 F2
};

/// Five lines, a hand-drawn clef (the contours of the piano lessons), the
/// key signature and whole notes with ledger lines.
class DrillStaffPainter extends CustomPainter {
  DrillStaffPainter({required this.staff, required this.palette});

  final DrillStaff staff;
  final OstinatoPalette palette;

  /// Steps shown: three ledger lines below and above the staff.
  static const int _lowStep = -7, _highStep = 15;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height / (_highStep - _lowStep + 2); // half line spacing
    double y(int step) => size.height - (step - _lowStep + 1) * h;
    final ink = Paint()
      ..color = palette.ink
      ..strokeWidth = 1.2;
    final left = 8.0, right = size.width - 8;
    for (var step = 0; step <= 8; step += 2) {
      canvas.drawLine(Offset(left, y(step)), Offset(right, y(step)), ink);
    }
    // Clef contours are drawn for a 10-px line spacing; scale to ours.
    canvas.save();
    canvas.translate(left - 12 * (h / 5), y(0));
    canvas.scale(h / 5);
    _clef(canvas, staff.clef == 'treble');
    canvas.restore();

    var x = left + 14 * h;
    final sig = staff.keySignature;
    final steps = (sig >= 0 ? _sharpSteps : _flatSteps)[staff.clef]!;
    for (var i = 0; i < sig.abs(); i++) {
      if (sig > 0) {
        _sharp(canvas, Offset(x, y(steps[i])), h);
      } else {
        _flat(canvas, Offset(x, y(steps[i])), h);
      }
      x += 2.2 * h;
    }

    final notes = staff.notes;
    if (notes.isEmpty) return;
    final start = x + 4 * h;
    final gap = notes.length == 1
        ? 0.0
        : (right - 4 * h - start) / notes.length;
    for (var i = 0; i < notes.length; i++) {
      final nx = notes.length == 1
          ? (start + right) / 2
          : start + gap * (i + 0.5);
      final step = drillStaffStep(notes[i], staff.clef);
      for (var l = -2; l >= step; l -= 2) {
        canvas.drawLine(
          Offset(nx - 2.4 * h, y(l)),
          Offset(nx + 2.4 * h, y(l)),
          ink,
        );
      }
      for (var l = 10; l <= step; l += 2) {
        canvas.drawLine(
          Offset(nx - 2.4 * h, y(l)),
          Offset(nx + 2.4 * h, y(l)),
          ink,
        );
      }
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(nx, y(step)),
          width: 3.2 * h,
          height: 2 * h,
        ),
        Paint()
          ..color = palette.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.55 * h,
      );
    }
  }

  /// Origin: x of the staff's left edge minus 12, y of the bottom line,
  /// line spacing 10 (as in `piano_notation.dart`).
  void _clef(Canvas c, bool treble) {
    final stroke = Paint()
      ..color = palette.ink
      ..style = PaintingStyle.stroke;
    if (treble) {
      const y = -10.0;
      c.drawPath(
        Path()
          ..moveTo(31, y + 28)
          ..cubicTo(47, y + 39, 48, y + 17, 38, y - 8)
          ..cubicTo(19, y - 44, 31, y - 61, 38, y - 43)
          ..cubicTo(48, y - 25, 12, y - 17, 20, y + 2)
          ..cubicTo(25, y + 16, 49, y + 13, 48, y - 1)
          ..cubicTo(46, y - 16, 27, y - 12, 29, y - 2)
          ..cubicTo(30, y + 4, 37, y + 4, 39, y),
        stroke..strokeWidth = 2.2,
      );
    } else {
      const y = -30.0;
      c.drawPath(
        Path()
          ..moveTo(22, y + 1)
          ..cubicTo(18, y - 12, 43, y - 13, 41, y + 2)
          ..cubicTo(39, y + 14, 26, y + 21, 20, y + 23),
        stroke..strokeWidth = 2.3,
      );
      final dot = Paint()..color = palette.ink;
      c.drawCircle(const Offset(24, y), 3, dot);
      c.drawCircle(const Offset(48, y - 5), 2, dot);
      c.drawCircle(const Offset(48, y + 5), 2, dot);
    }
  }

  void _sharp(Canvas c, Offset at, double h) {
    final p = Paint()
      ..color = palette.ink
      ..strokeWidth = 0.35 * h;
    for (final dx in [-0.45 * h, 0.45 * h]) {
      c.drawLine(at + Offset(dx, -1.6 * h), at + Offset(dx, 1.6 * h), p);
    }
    final thick = Paint()
      ..color = palette.ink
      ..strokeWidth = 0.55 * h;
    for (final dy in [-0.55 * h, 0.55 * h]) {
      c.drawLine(
        at + Offset(-0.9 * h, dy + 0.25 * h),
        at + Offset(0.9 * h, dy - 0.25 * h),
        thick,
      );
    }
  }

  void _flat(Canvas c, Offset at, double h) {
    final p = Paint()
      ..color = palette.ink
      ..strokeWidth = 0.35 * h
      ..style = PaintingStyle.stroke;
    c.drawLine(
      at + Offset(-0.5 * h, -2.4 * h),
      at + Offset(-0.5 * h, 0.9 * h),
      p,
    );
    c.drawPath(
      Path()
        ..moveTo(at.dx - 0.5 * h, at.dy - 0.1 * h)
        ..cubicTo(
          at.dx + 0.9 * h,
          at.dy - 1.0 * h,
          at.dx + 1.2 * h,
          at.dy + 0.2 * h,
          at.dx - 0.5 * h,
          at.dy + 0.9 * h,
        ),
      p,
    );
  }

  @override
  bool shouldRepaint(DrillStaffPainter old) =>
      old.staff != staff || old.palette != palette;
}
