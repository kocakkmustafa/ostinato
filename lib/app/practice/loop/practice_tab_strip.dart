import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_locale.dart';
import '../../app_theme.dart';
import '../../ui_copy.dart';
import '../display/practice_display_copy.dart';
import 'practice_marks.dart';
import 'practice_score.dart';
import 'practice_visual_theme.dart';

/// What the strip shows for one played note.
final class StripMark {
  const StripMark(this.mark, {this.observedMidi});
  final PracticeMark mark;

  /// "Heard" pitch for a different note: drawn as a ghost on its own string.
  final int? observedMidi;
}

/// F2.3 flowing notation: a fixed NOW line, notes move towards it.
/// Guitar: six TAB lines (string 1 on top, as written TAB); other lessons:
/// one rhythm line with degree/onset heads (base for voice/piano rolls).
class PracticeTabStrip extends StatelessWidget {
  const PracticeTabStrip({
    super.key,
    required this.score,
    required this.displayBeat,
    this.marks = const {},
    this.heldEvent,
    this.loop,
    this.pixelsPerBeat = 88,
    this.nowFraction = .28,
    this.guitar = true,
  });

  final PracticeScore score;

  /// Lesson beat under the NOW line (negative during the count-in).
  final double displayBeat;
  final Map<int, StripMark> marks;
  final int? heldEvent;
  final ({double start, double end})? loop;
  final double pixelsPerBeat;
  final double nowFraction;
  final bool guitar;

  PracticeEvent? _upcoming() {
    for (final e in score.events) {
      if (e.endBeat > displayBeat && !marks.containsKey(e.index)) return e;
    }
    return null;
  }

  String _nowLabel(BuildContext context) {
    final e = _upcoming();
    if (e == null) return localized(context, 'End of the line', 'Dizinin sonu');
    if (e.kind == PracticeEventKind.pitch && e.midi != null) {
      final tab = guitar ? guitarTabPosition(e.midi!) : null;
      final name = musicPitch(context, e.pitchName ?? midiName(e.midi!));
      if (tab != null) {
        return localized(
          context,
          'Now: {v0}, fret {v1}, string {v2}',
          'Şimdi: {v0}, {v1}. perde, {v2}. tel',
          values: {'v0': name, 'v1': tab.fret, 'v2': tab.string},
        );
      }
      return localized(
        context,
        'Now: {v0}',
        'Şimdi: {v0}',
        values: {'v0': name},
      );
    }
    if (e.degree != null) {
      return localized(
        context,
        'Now: degree {v0}',
        'Şimdi: {v0}. derece',
        values: {'v0': e.degree},
      );
    }
    return localized(context, 'Now: a beat', 'Şimdi: bir vuruş');
  }

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final theme = PracticeVisualThemeScope.of(context);
    final last = lastMarkedEvent(marks);
    final strip = Semantics(
      label: _nowLabel(context),
      container: true,
      child: ExcludeSemantics(
        child: ClipRect(
          child: CustomPaint(
            key: const Key('practice-tab-strip'),
            size: Size.infinite,
            painter: TabStripPainter(
              score: score,
              displayBeat: displayBeat,
              marks: marks,
              heldEvent: heldEvent,
              loop: loop,
              pixelsPerBeat: pixelsPerBeat,
              nowFraction: nowFraction,
              guitar: guitar,
              theme: theme,
              ink: palette.notationInk,
              paper: palette.notationPaper,
              muted: palette.textMuted,
              now: palette.guitar.ink,
            ),
          ),
        ),
      ),
    );
    // FK4: the newest mark is spoken as a state ("Correct", "Different
    // note", "Couldn't hear"), never "wrong". A live region of its own so the
    // NOW label is not re-read on every note. One stable tree shape.
    return Stack(
      fit: StackFit.expand,
      children: [
        strip,
        if (last != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 24,
            child: Semantics(
              key: const Key('practice-tab-strip-last-mark'),
              container: true,
              liveRegion: true,
              label: uiText(
                context,
                PracticeDisplayCopy.lastNote,
                values: {'v0': practiceMarkLabel(context, marks[last]!.mark)},
              ),
              child: const SizedBox.expand(),
            ),
          ),
      ],
    );
  }
}

/// Index of the most recently judged note (the highest marked index).
int? lastMarkedEvent(Map<int, StripMark> marks) {
  int? last;
  for (final entry in marks.entries) {
    if (entry.value.mark == PracticeMark.pending) continue;
    if (last == null || entry.key > last) last = entry.key;
  }
  return last;
}

class TabStripPainter extends CustomPainter {
  TabStripPainter({
    required this.score,
    required this.displayBeat,
    required this.marks,
    required this.heldEvent,
    required this.loop,
    required this.pixelsPerBeat,
    required this.nowFraction,
    required this.guitar,
    required this.theme,
    required this.ink,
    required this.paper,
    required this.muted,
    required this.now,
  });

  final PracticeScore score;
  final double displayBeat;
  final Map<int, StripMark> marks;
  final int? heldEvent;
  final ({double start, double end})? loop;
  final double pixelsPerBeat, nowFraction;
  final bool guitar;
  final PracticeVisualTheme theme;
  final Color ink, paper, muted, now;

  StripGeometry geometry(double width) => StripGeometry(
    width: width,
    displayBeat: displayBeat,
    pixelsPerBeat: pixelsPerBeat,
    nowFraction: nowFraction,
    leftHanded: theme.leftHanded,
  );

  /// X of lesson beat [beat] for a strip of [width] (mirrored when left-handed).
  double xOf(double beat, double width) => geometry(width).xOf(beat);

  int get _lines => guitar ? 6 : 1;

  double yOfString(int string, Size size) {
    final top = size.height * .16, bottom = size.height * .84;
    if (_lines == 1) return size.height / 2;
    return top + (string - 1) * (bottom - top) / (_lines - 1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    final line = Paint()
      ..color = ink.withValues(alpha: .45)
      ..strokeWidth = 1;
    final l = loop;
    if (l != null) {
      final a = xOf(l.start, size.width), b = xOf(l.end, size.width);
      canvas.drawRect(
        Rect.fromLTRB(math.min(a, b), 0, math.max(a, b), size.height),
        Paint()..color = now.withValues(alpha: .07),
      );
    }
    for (var s = 1; s <= _lines; s++) {
      final y = yOfString(s, size);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final bar = Paint()
      ..color = ink.withValues(alpha: .35)
      ..strokeWidth = 1.2;
    for (var b = 0; b <= score.barCount; b++) {
      final x = xOf(b * score.beatsPerBar.toDouble(), size.width);
      if (x < -2 || x > size.width + 2) continue;
      canvas.drawLine(
        Offset(x, yOfString(1, size)),
        Offset(x, yOfString(_lines, size)),
        bar,
      );
    }
    final radius = math.min(13.0, size.height / (_lines * 2.4));
    for (final e in score.events) {
      final x = xOf(e.startBeat, size.width);
      if (x < -radius * 2 || x > size.width + radius * 2) continue;
      final tab = guitar && e.midi != null ? guitarTabPosition(e.midi!) : null;
      final y = tab != null
          ? yOfString(tab.string, size)
          : yOfString(guitar ? 6 : 1, size);
      // Duration tail.
      final tailEnd = xOf(e.endBeat, size.width);
      canvas.drawLine(
        Offset(x, y),
        Offset(tailEnd, y),
        Paint()
          ..color = ink.withValues(alpha: .18)
          ..strokeWidth = radius * .9
          ..strokeCap = StrokeCap.round,
      );
      final m = marks[e.index];
      final label = tab != null
          ? '${tab.fret}'
          : e.degree != null
          ? '${e.degree}'
          : '';
      if (m == null) {
        _drawPending(canvas, Offset(x, y), radius, label, e.index == heldEvent);
      } else {
        _drawMark(canvas, Offset(x, y), radius, m.mark, label);
        final heard = m.observedMidi;
        if (m.mark == PracticeMark.differentNote && heard != null && guitar) {
          final ghost = guitarTabPosition(heard);
          if (ghost != null) {
            _drawGhost(
              canvas,
              // Just after the note in reading direction (mirrored too).
              Offset(
                x + geometry(size.width).forward * radius * .6,
                yOfString(ghost.string, size),
              ),
              radius * .8,
              '${ghost.fret}',
            );
          }
        }
      }
    }
    final nowX = geometry(size.width).nowX;
    canvas.drawLine(
      Offset(nowX, 0),
      Offset(nowX, size.height),
      Paint()
        ..color = now
        ..strokeWidth = 2.5,
    );
  }

  void _text(Canvas canvas, Offset c, String text, Color color, double size) {
    if (text.isEmpty) return;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'IBM Plex Mono',
          fontSize: size,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawPending(
    Canvas canvas,
    Offset c,
    double r,
    String label,
    bool held,
  ) {
    canvas.drawCircle(c, r, Paint()..color = paper);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = held ? 3 : 1.6
        ..color = held ? now : ink,
    );
    _text(canvas, c, label, ink, r * 1.05);
  }

  void _drawGhost(Canvas canvas, Offset c, double r, String label) {
    final color = theme.style(PracticeMark.differentNote).color;
    _diamond(
      canvas,
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = color.withValues(alpha: .7),
    );
    _text(canvas, c, label, color.withValues(alpha: .8), r);
  }

  void _diamond(Canvas canvas, Offset c, double r, Paint paint) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - r * 1.15)
        ..lineTo(c.dx + r * 1.15, c.dy)
        ..lineTo(c.dx, c.dy + r * 1.15)
        ..lineTo(c.dx - r * 1.15, c.dy)
        ..close(),
      paint,
    );
  }

  void _drawMark(
    Canvas canvas,
    Offset c,
    double r,
    PracticeMark mark,
    String label,
  ) {
    final style = theme.style(mark);
    switch (style.shape) {
      case MarkShape.filledCircle:
        canvas.drawCircle(c, r, Paint()..color = style.color);
        _text(canvas, c, label, paper, r * 1.05);
      case MarkShape.diamond:
        _diamond(canvas, c, r, Paint()..color = style.color);
        _text(canvas, c, label, paper, r * .95);
      case MarkShape.dashedCircle:
        canvas.drawCircle(c, r, Paint()..color = paper);
        final dash = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = style.color;
        const segments = 10;
        for (var i = 0; i < segments; i++) {
          final a = i * 2 * math.pi / segments;
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r),
            a,
            math.pi / segments,
            false,
            dash,
          );
        }
        _text(canvas, c, style.symbol, style.color, r * 1.05);
      case MarkShape.outlineCircle:
        _drawPending(canvas, c, r, label, false);
    }
  }

  @override
  bool shouldRepaint(TabStripPainter old) =>
      old.displayBeat != displayBeat ||
      !identical(old.marks, marks) ||
      old.heldEvent != heldEvent ||
      old.loop != loop ||
      old.theme != theme ||
      old.pixelsPerBeat != pixelsPerBeat;
}
