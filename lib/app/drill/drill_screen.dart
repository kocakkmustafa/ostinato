import 'dart:async';
import 'dart:isolate';

import 'package:flutter/material.dart';

import '../app_locale.dart';
import '../app_theme.dart';
import '../curriculum/v1_lesson.dart';
import '../design/ostinato_theme.dart';
import '../ui_copy.dart';
import 'drill_copy.dart';
import 'drill_dictation.dart';
import 'drill_hand.dart';
import 'drill_keyboard.dart';
import 'drill_theory.dart';
import 'drill_generator.dart';
import '../practice/loop/reference_copy.dart';
import '../practice/loop/reference_listen.dart';
import 'drill_session.dart';
import 'drill_sound.dart';
import 'drill_staff.dart';

/// F2.6 on-screen drill: one question at a time, immediate feedback, a
/// second try for mixed-up questions, a result with the 80% first-try rule.
/// Pops `true` when a session passed.
class DrillScreen extends StatefulWidget {
  const DrillScreen({
    super.key,
    required this.drill,
    required this.title,
    this.seed,
    this.port,
  });

  final V1Drill drill;
  final String title;

  /// Tests fix the seed; each new set otherwise draws a fresh one.
  final int? seed;

  /// Where heard drills play; defaults to the route's reference output.
  final ReferencePlaybackPort? Function(BuildContext context)? port;

  @override
  State<DrillScreen> createState() => DrillScreenState();
}

class DrillScreenState extends State<DrillScreen> {
  late int _seed = widget.seed ?? DateTime.now().microsecondsSinceEpoch;
  late DrillSession _s = _newSession();
  bool _everPassed = false;

  @visibleForTesting
  DrillSession get session => _s;

  /// F2.6b: heard questions play through the FK1 reference output.
  final ReferenceListenController _listen = ReferenceListenController();

  @override
  void dispose() {
    _listen.dispose();
    super.dispose();
  }

  void _play(DrillSound sound, String tag) => unawaited(
    _listen.playClip(
      (widget.port ?? ReferenceRoutePort.of)(context),
      () async => (
        samples: await Isolate.run(
          () => renderDrillSound(sound, sampleRate: kReferenceSampleRate),
        ),
        sampleRate: kReferenceSampleRate,
      ),
      tag: tag,
    ),
  );

  Widget _sounds(BuildContext context, DrillQuestion q) => ListenableBuilder(
    listenable: _listen,
    builder: (context, _) {
      final sounds = q.optionSounds;
      final differs = _s.answered && !_s.matchedCurrent;
      final entry = q.entry, written = _s.written;
      final DrillSound? mine = !differs
          ? null
          : entry != null && written != null
          ? entry.kind == DrillEntryKind.rhythm
                ? rhythmSound(written, bpm: entry.bpm)
                : melodyAnswerSound(entry, written)
          : sounds?[_s.chosen!];
      final DrillSound? expected = entry != null ? q.sound : sounds?[q.answer];
      Widget button(String tag, UiCopy copy, DrillSound sound) =>
          OutlinedButton.icon(
            key: Key('drill-play-$tag'),
            onPressed: () => _listen.busy && _listen.tag == tag
                ? unawaited(_listen.stop())
                : _play(sound, tag),
            icon: Icon(
              _listen.busy && _listen.tag == tag
                  ? Icons.stop
                  : Icons.volume_up_outlined,
            ),
            label: Text(uiText(context, copy)),
          );
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          button(
            'question',
            _s.answered ? DrillCopy.playAgain : DrillCopy.play,
            q.sound!,
          ),
          if (mine != null) button('mine', DrillCopy.playMine, mine),
          if (mine != null && expected != null)
            button('expected', DrillCopy.playExpected, expected),
          if (_listen.state == ReferenceListenState.unavailable)
            Text(
              uiText(context, ReferenceCopy.unavailable),
              key: const Key('drill-audio-unavailable'),
            ),
        ],
      );
    },
  );

  DrillSession _newSession() =>
      DrillSession(generateDrill(widget.drill, seed: _seed));

  void _newSet() => setState(() {
    unawaited(_listen.stop());
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
        if (q.sound != null) ...[
          const SizedBox(height: 14),
          _sounds(context, q),
        ],
        if (q.staff case final staff?) ...[
          const SizedBox(height: 14),
          Semantics(
            label: uiText(
              context,
              staff.clef == 'treble'
                  ? DrillCopy.trebleClef
                  : DrillCopy.bassClef,
            ),
            child: AspectRatio(
              aspectRatio: 2.4,
              child: CustomPaint(
                key: const Key('drill-staff'),
                painter: DrillStaffPainter(staff: staff, palette: palette),
              ),
            ),
          ),
        ],
        for (var i = 0; i < q.staves.length; i++) ...[
          const SizedBox(height: 12),
          Text(
            uiText(context, DrillCopy.staffLabel, values: {'v0': q.options[i]}),
            style: monoText(size: 11, color: palette.textMono),
          ),
          AspectRatio(
            aspectRatio: 2.8,
            child: CustomPaint(
              key: Key('drill-staff-${q.options[i]}'),
              painter: DrillStaffPainter(staff: q.staves[i], palette: palette),
            ),
          ),
        ],
        if (q.finger case final finger?) ...[
          const SizedBox(height: 14),
          Center(
            child: SizedBox(
              width: 200,
              height: 220,
              child: CustomPaint(
                key: const Key('drill-hand'),
                painter: DrillHandPainter(marked: finger, palette: palette),
              ),
            ),
          ),
        ],
        if (q.keys.isNotEmpty) ...[
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 3.4,
            child: CustomPaint(
              key: const Key('drill-keyboard'),
              painter: DrillKeyboardPainter(marked: q.keys, palette: palette),
            ),
          ),
        ],
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
        if (q.entry case final entry?)
          DictationInput(
            key: ValueKey(identityHashCode(q)),
            entry: entry,
            enabled: !_s.answered,
            onSubmit: (entered) => setState(() => _s.submit(entered)),
          )
        else
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
                      'v0': q.entry != null
                          ? writtenLabel(context, q.entry!, _s.written!)
                          : _label(context, q, q.options[_s.chosen!]),
                      'v1': q.entry != null
                          ? writtenLabel(context, q.entry!, q.entry!.answer)
                          : _label(context, q, q.expected),
                    },
                  ),
            key: const Key('drill-feedback'),
            style: hankenText(size: 14, height: 1.4),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('drill-next'),
            onPressed: () {
              unawaited(_listen.stop());
              setState(_s.next);
            },
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
    DrillPromptKind.tempoCompare => DrillCopy.tempoCompare,
    DrillPromptKind.pitchDirection => DrillCopy.pitchDirection,
    DrillPromptKind.pitchContour => DrillCopy.pitchContour,
    DrillPromptKind.sameDifferent => DrillCopy.sameDifferent,
    DrillPromptKind.intervalName =>
      _s.current.values['v0'] == 'descending'
          ? DrillCopy.intervalDown
          : DrillCopy.intervalUp,
    DrillPromptKind.chordQuality => DrillCopy.chordQuality,
    DrillPromptKind.staffNote => DrillCopy.staffNote,
    DrillPromptKind.keySignature => DrillCopy.keySignature,
    DrillPromptKind.staffInterval => DrillCopy.staffInterval,
    DrillPromptKind.tonicOrNot => DrillCopy.tonicOrNot,
    DrillPromptKind.rhythmDictation => DrillCopy.rhythmDictation,
    DrillPromptKind.stepSize => DrillCopy.stepSize,
    DrillPromptKind.staffPlace => DrillCopy.staffPlace,
    DrillPromptKind.staffSymbol => DrillCopy.staffSymbol,
    DrillPromptKind.beatsInBar => DrillCopy.beatsInBar,
    DrillPromptKind.halfStepPlace => DrillCopy.halfStepPlace,
    DrillPromptKind.degreeOverDrone => DrillCopy.degreeOverDrone,
    DrillPromptKind.staffMatch => DrillCopy.staffMatch,
    DrillPromptKind.fingerNumber => DrillCopy.fingerNumber,
    DrillPromptKind.melodicDictation =>
      (_s.current.entry?.given.isNotEmpty ?? false)
          ? DrillCopy.melodicDictationGiven
          : DrillCopy.melodicDictation,
  };

  /// Note names in values get the local name in Turkish (`C# (Do#)`).
  Map<String, Object> _values(BuildContext context, DrillQuestion q) => {
    for (final e in q.values.entries)
      e.key: switch ((q.kind, e.key)) {
        (DrillPromptKind.fretOfNote, 'v0') ||
        (DrillPromptKind.enharmonic, 'v0') ||
        (DrillPromptKind.scaleStep, 'v0') ||
        (DrillPromptKind.pentatonicNote, 'v0') ||
        (DrillPromptKind.tonicOrNot, 'v0') ||
        (DrillPromptKind.melodicDictation, 'v1') ||
        (DrillPromptKind.stepSize, 'v0') ||
        (DrillPromptKind.halfStepPlace, 'v0') ||
        (DrillPromptKind.degreeOverDrone, 'v0') ||
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
        DrillPromptKind.tempoCompare ||
        DrillPromptKind.pitchDirection ||
        DrillPromptKind.sameDifferent ||
        DrillPromptKind.intervalName ||
        DrillPromptKind.chordQuality => uiText(context, _heardWord(option)),
        DrillPromptKind.staffNote => drillNoteName(context, option),
        DrillPromptKind.keySignature => uiText(
          context,
          DrillCopy.keyOption,
          values: {'v0': drillNoteName(context, option)},
        ),
        DrillPromptKind.staffInterval => uiText(context, switch (option) {
          '2' => DrillCopy.number2,
          '3' => DrillCopy.number3,
          '4' => DrillCopy.number4,
          '5' => DrillCopy.number5,
          '6' => DrillCopy.number6,
          '7' => DrillCopy.number7,
          _ => DrillCopy.number8,
        }),
        DrillPromptKind.rhythmDictation ||
        DrillPromptKind.melodicDictation => option,
        DrillPromptKind.stepSize => uiText(
          context,
          option == 'whole' ? DrillCopy.wholeStep : DrillCopy.halfStep,
        ),
        DrillPromptKind.staffPlace => uiText(
          context,
          option.startsWith('line') ? DrillCopy.lineN : DrillCopy.spaceN,
          values: {'v0': option.split('_').last},
        ),
        DrillPromptKind.staffSymbol => uiText(context, switch (option) {
          'bar_line' => DrillCopy.barLine,
          'double_bar_line' => DrillCopy.doubleBarLine,
          _ => DrillCopy.timeSignature44,
        }),
        DrillPromptKind.halfStepPlace =>
          option == 'none'
              ? uiText(context, DrillCopy.noHalfStep)
              : uiText(
                  context,
                  DrillCopy.betweenNotes,
                  values: {
                    'v0': option.split('-').first,
                    'v1': option.split('-').last,
                  },
                ),
        DrillPromptKind.degreeOverDrone => uiText(
          context,
          DrillCopy.stepOption,
          values: {'v0': option},
        ),
        DrillPromptKind.staffMatch => uiText(
          context,
          DrillCopy.staffLabel,
          values: {'v0': option},
        ),
        DrillPromptKind.fingerNumber => option,
        DrillPromptKind.beatsInBar => uiText(
          context,
          DrillCopy.beatsOption,
          values: {'v0': option},
        ),
        DrillPromptKind.tonicOrNot => uiText(
          context,
          option == 'tonic' ? DrillCopy.tonicYes : DrillCopy.tonicNo,
        ),
        DrillPromptKind.pitchContour =>
          option
              .split('-')
              .map((w) => uiText(context, _heardWord(w)))
              .join(' → '),
      };

  static UiCopy _heardWord(String key) => switch (key) {
    'faster' => DrillCopy.faster,
    'slower' => DrillCopy.slower,
    'same' => DrillCopy.same,
    'higher' => DrillCopy.higher,
    'lower' => DrillCopy.lower,
    'different' => DrillCopy.different,
    'up' => DrillCopy.moveUp,
    'down' => DrillCopy.moveDown,
    'm2' => DrillCopy.minor2,
    'M2' => DrillCopy.major2,
    'm3' => DrillCopy.minor3,
    'M3' => DrillCopy.major3,
    'P4' => DrillCopy.perfect4,
    'TT' => DrillCopy.tritone,
    'P5' => DrillCopy.perfect5,
    'm6' => DrillCopy.minor6,
    'M6' => DrillCopy.major6,
    'm7' => DrillCopy.minor7,
    'M7' => DrillCopy.major7,
    'P8' => DrillCopy.octave,
    'major' => DrillCopy.qualityMajor,
    'minor' => DrillCopy.qualityMinor,
    'dominant7' => DrillCopy.qualityDominant7,
    _ => throw ArgumentError.value(key, 'key'),
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

UiCopy _valueCopy(String v) => switch (v) {
  'whole' => DrillCopy.valueWhole,
  'half' => DrillCopy.valueHalf,
  'dottedQuarter' => DrillCopy.valueDottedQuarter,
  'quarter' => DrillCopy.valueQuarter,
  'eighthPair' => DrillCopy.valueEighthPair,
  'eighth' => DrillCopy.valueEighth,
  'quarterRest' => DrillCopy.valueQuarterRest,
  'halfRest' => DrillCopy.valueHalfRest,
  kTie => DrillCopy.valueTie,
  _ => throw ArgumentError.value(v, 'value'),
};

/// A degree's button label: `3 · E (Mi)`.
String _degreeLabel(BuildContext context, DrillEntry e, String degree) {
  final note = majorScale(e.key!)[int.parse(degree) - 1].name;
  return '$degree · ${drillNoteName(context, note)}';
}

/// What a written answer reads as, for "your answer · expected".
String writtenLabel(BuildContext context, DrillEntry e, List<String> written) =>
    e.kind == DrillEntryKind.rhythm
    ? written.map((v) => uiText(context, _valueCopy(v))).join(' · ')
    : written
          .map(
            (d) => drillNoteName(
              context,
              majorScale(e.key!)[int.parse(d) - 1].name,
            ),
          )
          .join(' – ');

/// F2.6d entry: rhythm values or melody degrees, with Undo / Clear / Check.
/// The given first note of a melody cannot be removed.
class DictationInput extends StatefulWidget {
  const DictationInput({
    super.key,
    required this.entry,
    required this.enabled,
    required this.onSubmit,
  });

  final DrillEntry entry;
  final bool enabled;
  final ValueChanged<List<String>> onSubmit;

  @override
  State<DictationInput> createState() => _DictationInputState();
}

class _DictationInputState extends State<DictationInput> {
  late final List<String> _entered = List.of(widget.entry.given);

  DrillEntry get _e => widget.entry;
  bool get _rhythm => _e.kind == DrillEntryKind.rhythm;

  bool _canAdd(String v) => _rhythm
      ? rhythmFits(_entered, v, bars: _e.bars)
      : _entered.length < _e.length;

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final muted = hankenText(size: 13, color: palette.textMuted);
    final complete = _e.complete(_entered);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_rhythm)
          Wrap(
            key: const Key('drill-written'),
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final v in _entered)
                Chip(label: Text(uiText(context, _valueCopy(v)))),
            ],
          )
        else
          AspectRatio(
            aspectRatio: 2.4,
            child: CustomPaint(
              key: const Key('drill-written'),
              painter: DrillStaffPainter(
                staff: DrillStaff(
                  clef: 'treble',
                  notes: [
                    for (final d in _entered) _e.pitches[int.parse(d) - 1],
                  ],
                  keySignature: _e.keySignature,
                ),
                palette: palette,
              ),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          _rhythm
              ? uiText(
                  context,
                  DrillCopy.beatsWritten,
                  values: {
                    'v0': appDecimal(
                      context,
                      rhythmLength(_entered),
                      rhythmLength(_entered) % 1 == 0 ? 0 : 1,
                    ),
                    'v1': _e.bars * 4,
                  },
                )
              : uiText(
                  context,
                  DrillCopy.notesWritten,
                  values: {'v0': _entered.length, 'v1': _e.length},
                ),
          key: const Key('drill-written-count'),
          style: muted,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in [..._e.palette, if (_e.ties) kTie])
              OutlinedButton(
                key: Key(v == kTie ? 'drill-add-tie' : 'drill-add-$v'),
                onPressed: widget.enabled && _canAdd(v)
                    ? () => setState(() => _entered.add(v))
                    : null,
                child: Text(
                  _rhythm
                      ? uiText(context, _valueCopy(v))
                      : _degreeLabel(context, _e, v),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            TextButton(
              key: const Key('drill-undo'),
              onPressed: widget.enabled && _entered.length > _e.given.length
                  ? () => setState(_entered.removeLast)
                  : null,
              child: Text(uiText(context, DrillCopy.undo)),
            ),
            TextButton(
              key: const Key('drill-clear'),
              onPressed: widget.enabled && _entered.length > _e.given.length
                  ? () => setState(() {
                      _entered
                        ..clear()
                        ..addAll(_e.given);
                    })
                  : null,
              child: Text(uiText(context, DrillCopy.clear)),
            ),
            const Spacer(),
            FilledButton(
              key: const Key('drill-check'),
              onPressed: widget.enabled && complete
                  ? () => widget.onSubmit(List.of(_entered))
                  : null,
              child: Text(uiText(context, DrillCopy.check)),
            ),
          ],
        ),
      ],
    );
  }
}
