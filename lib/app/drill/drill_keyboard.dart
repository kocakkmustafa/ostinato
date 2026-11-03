import 'package:flutter/material.dart';

import '../app_theme.dart';

/// F2.6 keyboard diagram: two octaves of white and black keys from C4, the
/// marked keys filled with the primary colour.
class DrillKeyboardPainter extends CustomPainter {
  DrillKeyboardPainter({
    required this.marked,
    required this.palette,
    this.lowest = 60,
    this.octaves = 2,
  });

  final List<int> marked;
  final OstinatoPalette palette;

  /// MIDI of the leftmost C.
  final int lowest;
  final int octaves;

  static const _whiteOffsets = [0, 2, 4, 5, 7, 9, 11];
  static const _blackAfter = {0: 1, 1: 3, 3: 6, 4: 8, 5: 10};

  @override
  void paint(Canvas canvas, Size size) {
    final whites = 7 * octaves + 1;
    final w = size.width / whites;
    final h = size.height;
    final edge = Paint()
      ..color = palette.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final markFill = Paint()..color = palette.primary;
    for (var i = 0; i < whites; i++) {
      final midi = lowest + 12 * (i ~/ 7) + _whiteOffsets[i % 7];
      final r = Rect.fromLTWH(i * w, 0, w, h);
      canvas.drawRect(
        r,
        Paint()
          ..color = marked.contains(midi) ? palette.primary : palette.surface,
      );
      canvas.drawRect(r, edge);
    }
    for (var i = 0; i < whites - 1; i++) {
      final black = _blackAfter[i % 7];
      if (black == null) continue;
      final midi = lowest + 12 * (i ~/ 7) + black;
      final r = Rect.fromLTWH((i + 0.68) * w, 0, w * 0.64, h * 0.6);
      canvas.drawRect(
        r,
        marked.contains(midi) ? markFill : (Paint()..color = palette.ink),
      );
    }
    // Dots under marked white keys so the mark reads without colour too.
    for (var i = 0; i < whites; i++) {
      final midi = lowest + 12 * (i ~/ 7) + _whiteOffsets[i % 7];
      if (marked.contains(midi)) {
        canvas.drawCircle(
          Offset((i + 0.5) * w, h * 0.85),
          w * 0.16,
          Paint()..color = palette.onPrimary,
        );
      }
    }
  }

  @override
  bool shouldRepaint(DrillKeyboardPainter old) =>
      old.palette != palette || old.marked.join() != marked.join();
}
