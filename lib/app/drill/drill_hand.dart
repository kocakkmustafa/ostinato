import 'package:flutter/material.dart';

import '../app_theme.dart';

/// K8 fretting-hand diagram: a palm with the thumb and four fingers, one
/// finger filled with the primary colour and dotted (the mark reads without
/// colour too). No numbers are drawn: the number is the question.
class DrillHandPainter extends CustomPainter {
  DrillHandPainter({required this.marked, required this.palette});

  /// 1 index … 4 little.
  final int marked;
  final OstinatoPalette palette;

  // Finger centre x (share of width) and length (share of height), index to
  // little; the thumb sits on the right, as a left hand seen from the front.
  static const _x = [0.62, 0.48, 0.34, 0.22];
  static const _len = [0.50, 0.56, 0.52, 0.40];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..color = palette.controlSurface;
    final edge = Paint()
      ..color = palette.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final mark = Paint()..color = palette.primary;
    final fingerW = w * 0.11;
    final palmTop = h * 0.52;

    // The thumb goes first so the palm covers its base; it leans out to
    // the right from the lower palm.
    final thumbBase = Offset(w * 0.64, h * 0.86);
    final thumb = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        thumbBase.dx - fingerW / 2,
        thumbBase.dy - h * 0.40,
        fingerW,
        h * 0.40,
      ),
      Radius.circular(fingerW / 2),
    );
    canvas
      ..save()
      ..translate(thumbBase.dx, thumbBase.dy)
      ..rotate(0.75)
      ..translate(-thumbBase.dx, -thumbBase.dy)
      ..drawRRect(thumb, fill)
      ..drawRRect(thumb, edge)
      ..restore();

    final palm = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.15, palmTop, w * 0.70, h * 0.96),
      Radius.circular(w * 0.08),
    );
    canvas
      ..drawRRect(palm, fill)
      ..drawRRect(palm, edge);

    for (var i = 0; i < 4; i++) {
      final top = palmTop - h * _len[i] + h * 0.08;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * _x[i] - fingerW / 2, top, fingerW, palmTop - top + 8),
        Radius.circular(fingerW / 2),
      );
      final isMarked = marked == i + 1;
      canvas
        ..drawRRect(r, isMarked ? mark : fill)
        ..drawRRect(r, edge);
      if (isMarked) {
        canvas.drawCircle(
          Offset(w * _x[i], top + fingerW * 0.7),
          fingerW * 0.22,
          Paint()..color = palette.onPrimary,
        );
      }
    }
  }

  @override
  bool shouldRepaint(DrillHandPainter old) =>
      old.marked != marked || old.palette != palette;
}
