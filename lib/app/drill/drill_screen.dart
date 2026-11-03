import 'package:flutter/material.dart';

import '../app_locale.dart';
import '../app_theme.dart';
import '../curriculum/v1_lesson.dart';
import '../design/ostinato_theme.dart';
import '../ui_copy.dart';
import 'drill_copy.dart';
import 'drill_generator.dart';
import 'drill_session.dart';

/// F2.6 on-screen drill: one question at a time, immediate feedback, a
/// second try for mixed-up questions, a result with the 80% first-try rule.
/// Pops `true` when a session passed.
class DrillScreen extends StatefulWidget {
  const DrillScreen({
    super.key,
    required this.drill,
    required this.title,
    this.seed,
  });

  final V1Drill drill;
  final String title;

  /// Tests fix the seed; each new set otherwise draws a fresh one.
  final int? seed;

  @override
  State<DrillScreen> createState() => DrillScreenState();
}

class DrillScreenState extends State<DrillScreen> {
  late int _seed = widget.seed ?? DateTime.now().microsecondsSinceEpoch;
  late DrillSession _s = _newSession();
  bool _everPassed = false;

  @visibleForTesting
  DrillSession get session => _s;

  DrillSession _newSession() =>
      DrillSession(generateDrill(widget.drill, seed: _seed));

  void _newSet() => setState(() {
    _seed++;
    _s = _newSession();
  });

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_everPassed);
      },
      child: Scaffold(
        backgroundColor: palette.surface,
        appBar: AppBar(
          title: Text(widget.title),
          leading: BackButton(
            onPressed: () => Navigator.of(context).pop(_everPassed),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: _s.finished ? _result(context) : _question(context),
          ),
        ),
      ),
    );
  }

  Widget _question(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final q = _s.current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _s.isReview
              ? uiText(context, DrillCopy.review)
              : uiText(
                  context,
                  DrillCopy.progress,
                  values: {'v0': _s.number, 'v1': _s.total},
                ),
          key: const Key('drill-progress'),
          style: monoText(size: 11, color: palette.textMono),
        ),
        const SizedBox(height: 12),
        Text(
          uiText(context, _promptCopy(q.kind), values: _values(context, q)),
          key: const Key('drill-prompt'),
          style: hankenText(size: 18, weight: FontWeight.w600, height: 1.35),
        ),
        if (q.fretWindow case final window?) ...[
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 2.6,
            child: CustomPaint(
              key: const Key('drill-fretboard'),
              painter: FretboardPainter(
                window: window,
                marks: q.marks,
                palette: palette,
                labelStyle: monoText(size: 10, color: palette.textMuted),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        for (var i = 0; i < q.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _option(context, q, i),
          ),
        if (_s.answered) ...[
          const SizedBox(height: 4),
          Text(
            _s.matchedCurrent
                ? uiText(context, DrillCopy.matches)
                : uiText(
                    context,
                    DrillCopy.differs,
                    values: {
                      'v0': _label(context, q, q.options[_s.chosen!]),
                      'v1': _label(context, q, q.expected),
                    },
                  ),
            key: const Key('drill-feedback'),
            style: hankenText(size: 14, height: 1.4),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('drill-next'),
            onPressed: () => setState(_s.next),
            child: Text(
              uiText(context, _s.onLast ? DrillCopy.seeResult : DrillCopy.next),
            ),
          ),
        ],
      ],
    );
  }

  Widget _option(BuildContext context, DrillQuestion q, int i) {
    final palette = OstinatoPalette.of(context);
    final answered = _s.answered;
    final isExpected = i == q.answer;
    final isChosen = i == _s.chosen;
    final Color? border = !answered
        ? null
        : isExpected
        ? palette.success
        : isChosen
        ? palette.warnInk
        : null;
    return OutlinedButton(
      key: Key('drill-option-$i'),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        side: border == null ? null : BorderSide(color: border, width: 2),
        // Answered options stay readable: the result is shown on them.
        disabledForegroundColor: palette.textBody,
      ),
      onPressed: answered ? null : () => setState(() => _s.choose(i)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _label(context, q, q.options[i]),
              style: hankenText(
                size: 15,
                color: answered && !isExpected && !isChosen
                    ? palette.textMuted
                    : palette.textBody,
              ),
            ),
          ),
          if (answered && isExpected)
            Icon(Icons.check_circle, color: palette.success, size: 18)
          else if (answered && isChosen)
            Icon(Icons.change_history, color: palette.warnInk, size: 18),
        ],
      ),
    );
  }

  Widget _result(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final passed = _s.passed;
    if (passed) _everPassed = true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          uiText(context, DrillCopy.resultTitle),
          style: hankenText(size: 20, weight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Text(
          uiText(
            context,
            DrillCopy.resultScore,
            values: {'v0': _s.matched, 'v1': _s.total, 'v2': _s.needed},
          ),
          key: const Key('drill-score'),
          style: hankenText(size: 15, height: 1.4),
        ),
        const SizedBox(height: 8),
        Text(
          uiText(context, passed ? DrillCopy.passed : DrillCopy.notYet),
          key: const Key('drill-verdict'),
          style: hankenText(
            size: 14,
            height: 1.4,
            color: passed ? palette.success : palette.textBody,
          ),
        ),
        const SizedBox(height: 16),
        if (!passed)
          FilledButton(
            key: const Key('drill-new-set'),
            onPressed: _newSet,
            child: Text(uiText(context, DrillCopy.newSet)),
          ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('drill-back'),
          onPressed: () => Navigator.of(context).pop(_everPassed),
          child: Text(uiText(context, DrillCopy.backToLesson)),
        ),
      ],
    );
  }

  UiCopy _promptCopy(DrillPromptKind k) => switch (k) {
    DrillPromptKind.noteAtFret => DrillCopy.noteAtFret,
    DrillPromptKind.fretOfNote => DrillCopy.fretOfNote,
    DrillPromptKind.enharmonic => DrillCopy.enharmonic,
    DrillPromptKind.scaleStep => DrillCopy.scaleStep,
    DrillPromptKind.pentatonicNote => DrillCopy.pentatonicNote,
    DrillPromptKind.chordTones => DrillCopy.chordTones,
    DrillPromptKind.romanNumeral => DrillCopy.romanNumeral,
    DrillPromptKind.bluesLine => DrillCopy.bluesLine,
    DrillPromptKind.bluesBar => DrillCopy.bluesBar,
  };

  /// Note names in values get the local name in Turkish (`C# (Do#)`).
  Map<String, Object> _values(BuildContext context, DrillQuestion q) => {
    for (final e in q.values.entries)
      e.key: switch ((q.kind, e.key)) {
        (DrillPromptKind.fretOfNote, 'v0') ||
        (DrillPromptKind.enharmonic, 'v0') ||
        (DrillPromptKind.scaleStep, 'v0') ||
        (DrillPromptKind.pentatonicNote, 'v0') ||
        (
          DrillPromptKind.romanNumeral,
          'v0',
        ) => drillNoteName(context, e.value as String),
        _ => e.value,
      },
  };

  String _label(BuildContext context, DrillQuestion q, String option) =>
      switch (q.kind) {
        DrillPromptKind.fretOfNote => uiText(
          context,
          DrillCopy.fretOption,
          values: {'v0': option},
        ),
        DrillPromptKind.scaleStep => uiText(
          context,
          DrillCopy.stepOption,
          values: {'v0': option},
        ),
        DrillPromptKind.noteAtFret ||
        DrillPromptKind.enharmonic ||
        DrillPromptKind.pentatonicNote => drillNoteName(context, option),
        DrillPromptKind.chordTones =>
          option.split(' ').map((n) => drillNoteName(context, n)).join(' · '),
        // Chord symbols (A7, Dmaj7) stay international.
        DrillPromptKind.romanNumeral ||
        DrillPromptKind.bluesLine ||
        DrillPromptKind.bluesBar => option,
      };
}

/// A note letter with accidental and no octave, localized like
/// [musicPitch]: `C#` stays `C#` in English and reads `C# (Do#)` in Turkish.
String drillNoteName(BuildContext context, String note) {
  final m = RegExp(r'^([A-G])(#{0,2}|b{0,2})$').firstMatch(note);
  if (m == null) return note;
  final local = switch (m.group(1)) {
    'C' => localized(context, 'C', 'Do'),
    'D' => localized(context, 'D', 'Re'),
    'E' => localized(context, 'E', 'Mi'),
    'F' => localized(context, 'F', 'Fa'),
    'G' => localized(context, 'G', 'Sol'),
    'A' => localized(context, 'A', 'La'),
    'B' => localized(context, 'B', 'Si'),
    _ => m.group(1)!,
  };
  final shown = note.replaceAll('#', '♯').replaceAll('b', '♭');
  if (local == m.group(1)) return shown;
  return '$shown ($local${shown.substring(1)})';
}

/// Six strings across (string 1 on top, as in tab), the fret window along,
/// inlay dots at 3 5 7 9 12, fret numbers below, marks as filled circles.
class FretboardPainter extends CustomPainter {
  FretboardPainter({
    required this.window,
    required this.marks,
    required this.palette,
    required this.labelStyle,
  });

  final (int, int) window;
  final List<FretMark> marks;
  final OstinatoPalette palette;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final (first, last) = window;
    // An open-string column (fret 0) sits left of the nut.
    final columns = last - first + 1;
    const labelBand = 16.0;
    final top = 8.0, bottom = size.height - labelBand;
    final left = 18.0, right = size.width - 8;
    final colW = (right - left) / columns;
    final rowH = (bottom - top) / 5;
    final line = Paint()
      ..color = palette.outline
      ..strokeWidth = 1.2;
    final board = Paint()..color = palette.glassStart;
    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), board);
    // Frets: vertical lines; the nut is thick when fret 0 is shown.
    for (var i = 0; i <= columns; i++) {
      final x = left + i * colW;
      final nut = first == 0 && i == 1;
      canvas.drawLine(
        Offset(x, top),
        Offset(x, bottom),
        nut
            ? (Paint()
                ..color = palette.ink
                ..strokeWidth = 3.5)
            : line,
      );
    }
    // Strings: 1 (thin, top) … 6 (thick, bottom).
    for (var s = 1; s <= 6; s++) {
      final y = top + (s - 1) * rowH;
      canvas.drawLine(
        Offset(left, y),
        Offset(right, y),
        Paint()
          ..color = palette.inkSoft
          ..strokeWidth = 0.8 + (s - 1) * 0.35,
      );
    }
    double cx(int fret) => left + (fret - first + 0.5) * colW;
    final inlay = Paint()..color = palette.divider;
    for (final f in const [3, 5, 7, 9, 15]) {
      if (f >= first && f <= last && f > 0) {
        canvas.drawCircle(Offset(cx(f), (top + bottom) / 2), 4, inlay);
      }
    }
    if (12 >= first && 12 <= last) {
      canvas.drawCircle(Offset(cx(12), top + rowH * 1.5), 4, inlay);
      canvas.drawCircle(Offset(cx(12), top + rowH * 3.5), 4, inlay);
    }
    for (var f = first; f <= last; f++) {
      final tp = TextPainter(
        text: TextSpan(text: '$f', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx(f) - tp.width / 2, bottom + 3));
    }
    final dot = Paint()..color = palette.primary;
    for (final m in marks) {
      canvas.drawCircle(
        Offset(cx(m.fret), top + (m.string - 1) * rowH),
        rowH * 0.42,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(FretboardPainter old) =>
      old.window != window ||
      old.palette != palette ||
      old.marks.length != marks.length ||
      [
        for (var i = 0; i < marks.length; i++) old.marks[i] != marks[i],
      ].any((x) => x);
}
