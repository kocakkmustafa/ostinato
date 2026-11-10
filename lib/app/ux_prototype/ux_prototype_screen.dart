import 'dart:async';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../design/ostinato_theme.dart';
import '../practice/loop/practice_marks.dart';
import '../practice/loop/v1_course_catalog.dart';
import '../ui_copy.dart';
import 'ux_glass_layer.dart';
import 'ux_prototype_copy.dart';
import 'ux_prototype_model.dart';

/// OST-UX-04: the "one stage" prototype (ADR-UX-001, K1), all seven core
/// journeys in one place. Sample data only (labelled "Prototype"); no
/// microphone, no camera, no storage, no network. Reachable only through
/// [UxPrototypeEntryButton], which exists only while
/// `ostinatoUxPrototypeOpen` is true.
///
/// Journeys: (1) Play on the stage, (2) "Another practice" > ear without an
/// instrument, (3) "My path" > Path, (4) the result layer, (5) Try again /
/// Loop this bar, (6) "My path" > History, (7) microphone denied.
class UxPrototypeScreen extends StatefulWidget {
  const UxPrototypeScreen({
    super.key,
    this.catalog,
    this.seedHistory = true,
    this.initialMic = UxMic.ready,
    this.stepDuration = const Duration(milliseconds: 400),
  });

  /// The real guitar course catalog (journey 3); null shows labelled sample
  /// rows instead.
  final Future<V1CourseCatalog>? catalog;

  /// Show the sample "yesterday" run in History.
  final bool seedHistory;

  final UxMic initialMic;

  /// Time between two sample notes while "playing".
  final Duration stepDuration;

  @override
  State<UxPrototypeScreen> createState() => _UxPrototypeScreenState();
}

enum _Layer { other, path, setup, result }

class _PathRow {
  const _PathRow(this.level, this.module, this.lessons);
  final int level;
  final String module;
  final int lessons;
}

class _UxPrototypeScreenState extends State<UxPrototypeScreen> {
  _Layer? _layer;
  bool _ear = false;
  bool _playing = false;
  bool _loop = false;
  bool _pathTab = true;
  int _step = 0;
  int _section = 2;
  int _unit = 1;
  late UxMic _mic = widget.initialMic;
  List<PracticeMark> _marks = List.filled(uxRunLength, PracticeMark.pending);
  UxRunKind? _lastKind;
  final List<UxHistoryRun> _session = <UxHistoryRun>[];
  V1CourseCatalog? _course;
  Timer? _timer;
  bool _earListened = false;
  bool? _earChoseHigher;

  @override
  void initState() {
    super.initState();
    widget.catalog?.then((c) {
      if (mounted) setState(() => _course = c);
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------- actions

  void _resetMarks() => _marks = List.filled(uxRunLength, PracticeMark.pending);

  void _open(_Layer layer) {
    if (_playing) return; // no layer while playing
    setState(() => _layer = layer);
  }

  void _closeLayer() => setState(() => _layer = null);

  void _start() {
    final script = uxScriptFor(_mic);
    setState(() {
      _layer = null;
      _ear = false;
      _playing = true;
      _step = 0;
      _resetMarks();
    });
    _timer?.cancel();
    _timer = Timer.periodic(widget.stepDuration, (t) {
      if (_step >= uxRunLength) {
        _finish(finished: true);
        return;
      }
      setState(() {
        _marks = List<PracticeMark>.of(_marks)..[_step] = script[_step];
        _step++;
      });
    });
  }

  void _finish({required bool finished}) {
    _timer?.cancel();
    final kind = uxClassifyRun(
      mic: _mic,
      finished: finished,
      loopUsed: _loop,
      waitUsed: false,
      marks: _marks,
    );
    setState(() {
      _playing = false;
      _lastKind = kind;
      _session.add(
        UxHistoryRun(dayIsToday: true, kind: kind, marks: List.of(_marks)),
      );
      final firstDifferent = _marks.indexOf(PracticeMark.differentNote);
      if (firstDifferent >= 0) _section = firstDifferent ~/ 2 + 1;
      _layer = _Layer.result;
    });
  }

  void _tryAgain() => setState(() {
    _layer = null;
    _resetMarks();
  });

  void _next() => setState(() {
    _layer = null;
    _unit += 1;
    _loop = false;
    _resetMarks();
  });

  void _loopBar() => setState(() {
    _loop = true;
    _layer = null;
    _resetMarks();
  });

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final layerOpen = _layer != null;
    return PopScope(
      canPop: !layerOpen && !_ear,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() {
          if (_layer != null) {
            _layer = null;
          } else {
            _ear = false;
          }
        });
      },
      child: Scaffold(
        backgroundColor: palette.surface,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => Stack(
              children: <Widget>[
                Positioned.fill(
                  child: ExcludeSemantics(
                    excluding: layerOpen,
                    child: _scene(context),
                  ),
                ),
                if (layerOpen) ...<Widget>[
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: box.maxHeight * 0.4,
                    child: Semantics(
                      button: true,
                      label: uiText(context, UxPrototypeCopy.close),
                      child: GestureDetector(
                        key: const Key('ux-layer-scrim'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _closeLayer,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: box.maxHeight * 0.6,
                    child: UxGlassLayer(
                      key: const Key('ux-glass-layer'),
                      child: _layerBody(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- scene

  Widget _scene(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final units = _pathUnits();
    final (level, module) = _continueTarget(units);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _prototypeHeader(context),
          const SizedBox(height: 16),
          if (_ear)
            _earPanel(context)
          else ...<Widget>[
            Text(
              uiText(context, UxPrototypeCopy.stageHeading),
              style: hankenText(
                size: 26,
                weight: FontWeight.w600,
                height: 1.15,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              uiText(
                context,
                UxPrototypeCopy.continueLine,
                values: {'v0': level, 'v1': module},
              ),
              style: hankenText(size: 15, color: palette.textBody),
            ),
            Text(
              uiText(
                context,
                UxPrototypeCopy.sectionLine,
                values: {'v0': _section},
              ),
              style: hankenText(size: 15, color: palette.textBody),
            ),
            const SizedBox(height: 14),
            _strip(context),
            const SizedBox(height: 10),
            _counterRow(context, _marks),
            const SizedBox(height: 10),
            _statusRow(context),
            if (_loop)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  uiText(context, UxPrototypeCopy.loopNotice),
                  key: const Key('ux-loop-notice'),
                  style: hankenText(size: 14, color: palette.textBody),
                ),
              ),
            if (_mic == UxMic.denied && !_playing) _micOffCard(context),
            const SizedBox(height: 18),
            _playButton(context),
            if (!_playing) ...<Widget>[
              const SizedBox(height: 18),
              _handles(context),
            ],
          ],
        ],
      ),
    );
  }

  Widget _prototypeHeader(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          key: const Key('ux-prototype-badge'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: palette.controlSurface,
            border: Border.all(color: palette.controlBorder),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            uiText(context, UxPrototypeCopy.protoBadge),
            style: hankenText(
              size: 13,
              weight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            uiText(context, UxPrototypeCopy.protoNote),
            style: hankenText(size: 13, color: palette.textBody),
          ),
        ),
      ],
    );
  }

  Widget _strip(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    return Semantics(
      container: true,
      label: _counterLabel(context, _marks),
      child: ExcludeSemantics(
        child: Container(
          key: const Key('ux-stage-strip'),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
          decoration: BoxDecoration(
            color: palette.controlSurface,
            border: Border.all(color: palette.controlBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              for (var i = 0; i < uxRunLength; i++)
                _stripCell(context, i, current: _playing && i == _step),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stripCell(BuildContext context, int i, {required bool current}) {
    final palette = OstinatoPalette.of(context);
    return Container(
      width: 34,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: current ? palette.ink : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        children: <Widget>[
          Text(
            '${i + 1}',
            style: monoText(
              size: 11,
              color: palette.textMono,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          UxMarkGlyph(mark: _marks[i], color: palette.ink),
        ],
      ),
    );
  }

  String _counterLabel(BuildContext context, List<PracticeMark> marks) =>
      uiText(
        context,
        UxPrototypeCopy.counterLabel,
        values: {
          'v0': uxCount(marks, PracticeMark.correct),
          'v1': uxCount(marks, PracticeMark.differentNote),
          'v2': uxCount(marks, PracticeMark.couldNotHear),
        },
      );

  /// Neutral counter: shape plus a count; no verdict words (04-design §A).
  Widget _counterRow(BuildContext context, List<PracticeMark> marks) {
    final palette = OstinatoPalette.of(context);
    Widget item(PracticeMark m, UiCopy label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        UxMarkGlyph(mark: m, color: palette.ink, size: 16),
        const SizedBox(width: 5),
        Text(
          '${uxCount(marks, m)}',
          style: hankenText(
            size: 15,
            weight: FontWeight.w600,
            color: palette.ink,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            uiText(context, label),
            style: hankenText(size: 13, color: palette.textBody),
          ),
        ),
      ],
    );
    return Semantics(
      container: true,
      label: _counterLabel(context, marks),
      child: ExcludeSemantics(
        child: Wrap(
          key: const Key('ux-counter'),
          spacing: 14,
          runSpacing: 4,
          children: <Widget>[
            item(PracticeMark.correct, UxPrototypeCopy.markCorrect),
            item(PracticeMark.differentNote, UxPrototypeCopy.markDifferent),
            item(PracticeMark.couldNotHear, UxPrototypeCopy.markCouldNot),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final text = _mic == UxMic.denied
        ? uiText(context, UxPrototypeCopy.micOff)
        : _playing
        ? uiText(context, UxPrototypeCopy.micListening)
        : uiText(context, UxPrototypeCopy.micReady);
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: <Widget>[
        Text(
          text,
          key: const Key('ux-mic-status'),
          style: hankenText(size: 14, color: palette.textBody),
        ),
        Text(
          uiText(context, UxPrototypeCopy.tempoLine, values: {'v0': 50}),
          style: hankenText(size: 14, color: palette.textBody),
        ),
      ],
    );
  }

  Widget _micOffCard(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    return Container(
      key: const Key('ux-mic-off'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.controlSurface,
        border: Border.all(color: palette.controlBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            uiText(context, UxPrototypeCopy.micOffBody),
            style: hankenText(size: 15, color: palette.textBody),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton(
                key: const Key('ux-ear-first'),
                style: _bigOutlined,
                onPressed: () => setState(() => _ear = true),
                child: Text(uiText(context, UxPrototypeCopy.earFirst)),
              ),
              OutlinedButton(
                key: const Key('ux-go-setup'),
                style: _bigOutlined,
                onPressed: () => _open(_Layer.setup),
                child: Text(uiText(context, UxPrototypeCopy.goSetup)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ButtonStyle get _bigOutlined => OutlinedButton.styleFrom(
    minimumSize: const Size(48, 48),
    foregroundColor: OstinatoPalette.of(context).ink,
  );

  Widget _playButton(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final label = _playing
        ? UxPrototypeCopy.stop
        : _mic == UxMic.denied
        ? UxPrototypeCopy.playSelf
        : UxPrototypeCopy.play;
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: FilledButton(
        key: Key(_playing ? 'ux-stop' : 'ux-play'),
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: _playing ? () => _finish(finished: false) : _start,
        child: Text(
          uiText(context, label),
          style: hankenText(
            size: 20,
            weight: FontWeight.w600,
            color: palette.onPrimary,
          ),
        ),
      ),
    );
  }

  Widget _handles(BuildContext context) {
    Widget handle(String key, UiCopy label, _Layer layer) => Expanded(
      child: OutlinedButton(
        key: Key(key),
        style: _bigOutlined,
        onPressed: () => _open(layer),
        child: Text(
          uiText(context, label),
          textAlign: TextAlign.center,
          style: hankenText(size: 14, weight: FontWeight.w500),
        ),
      ),
    );
    return Row(
      key: const Key('ux-handles'),
      children: <Widget>[
        handle('ux-handle-other', UxPrototypeCopy.handleOther, _Layer.other),
        const SizedBox(width: 8),
        handle('ux-handle-path', UxPrototypeCopy.handlePath, _Layer.path),
        const SizedBox(width: 8),
        handle('ux-handle-setup', UxPrototypeCopy.handleSetup, _Layer.setup),
      ],
    );
  }

  // ----------------------------------------------------------------- ear

  Widget _earPanel(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    Widget bar(double h) => Container(
      width: 44,
      height: h,
      decoration: BoxDecoration(
        color: palette.ink,
        borderRadius: BorderRadius.circular(8),
      ),
    );
    return Column(
      key: const Key('ux-ear-panel'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          uiText(context, UxPrototypeCopy.earTitle),
          style: hankenText(
            size: 24,
            weight: FontWeight.w600,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          uiText(context, UxPrototypeCopy.earFormat),
          key: const Key('ux-ear-format'),
          style: monoText(
            size: 12,
            color: palette.textMono,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          uiText(context, UxPrototypeCopy.earPrompt),
          style: hankenText(size: 16, color: palette.textBody),
        ),
        const SizedBox(height: 12),
        Container(
          height: 110,
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: palette.controlSurface,
            border: Border.all(color: palette.controlBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: _earListened
              ? Row(
                  key: const Key('ux-ear-notes'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    bar(40),
                    const SizedBox(width: 24),
                    bar(80),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 6),
        Text(
          uiText(context, UxPrototypeCopy.earDrawn),
          style: hankenText(size: 13, color: palette.textBody),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            key: const Key('ux-ear-listen'),
            onPressed: () => setState(() => _earListened = true),
            child: Text(uiText(context, UxPrototypeCopy.earListen)),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                key: const Key('ux-ear-higher'),
                style: _bigOutlined,
                onPressed: _earListened
                    ? () => setState(() => _earChoseHigher = true)
                    : null,
                child: Text(uiText(context, UxPrototypeCopy.earHigher)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                key: const Key('ux-ear-lower'),
                style: _bigOutlined,
                onPressed: _earListened
                    ? () => setState(() => _earChoseHigher = false)
                    : null,
                child: Text(uiText(context, UxPrototypeCopy.earLower)),
              ),
            ),
          ],
        ),
        if (_earChoseHigher != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              uiText(context, UxPrototypeCopy.earWas),
              key: const Key('ux-ear-reveal'),
              style: hankenText(
                size: 16,
                weight: FontWeight.w600,
                color: palette.ink,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          uiText(context, UxPrototypeCopy.earNotCounted),
          key: const Key('ux-ear-not-counted'),
          style: hankenText(size: 14, color: palette.textBody),
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          key: const Key('ux-ear-back'),
          style: _bigOutlined,
          onPressed: () => setState(() => _ear = false),
          child: Text(uiText(context, UxPrototypeCopy.backToStage)),
        ),
      ],
    );
  }

  // -------------------------------------------------------------- layers

  Widget _layerBody(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final layer = _layer!;
    final title = switch (layer) {
      _Layer.other => UxPrototypeCopy.handleOther,
      _Layer.path => UxPrototypeCopy.handlePath,
      _Layer.setup => UxPrototypeCopy.deviceTitle,
      _Layer.result => UxPrototypeCopy.resultTitle,
    };
    final content = switch (layer) {
      _Layer.other => _otherBody(context),
      _Layer.path => _pathBody(context),
      _Layer.setup => _setupBody(context),
      _Layer.result => _resultBody(context),
    };
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: uiText(context, title),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    uiText(context, title),
                    style: hankenText(
                      size: 22,
                      weight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('ux-layer-close'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: palette.ink,
                  ),
                  onPressed: _closeLayer,
                  child: Text(uiText(context, UxPrototypeCopy.close)),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle get _body =>
      hankenText(size: 15, color: OstinatoPalette.of(context).textBody);

  Widget _otherBody(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final measured = _session.where((r) => r.measured).toList();
    final firstDifferent = measured.isEmpty
        ? -1
        : measured.last.marks.indexOf(PracticeMark.differentNote);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Rule-based suggestion; hidden when there is no run to base it on.
        if (firstDifferent >= 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              uiText(
                context,
                UxPrototypeCopy.otherSuggestion,
                values: {'v0': firstDifferent ~/ 2 + 1},
              ),
              key: const Key('ux-suggestion'),
              style: _body,
            ),
          ),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: <Widget>[
            FilledButton(
              key: const Key('ux-other-same'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _tryAgain,
              child: Text(uiText(context, UxPrototypeCopy.sameExercise)),
            ),
            OutlinedButton(
              key: const Key('ux-other-ear'),
              style: _bigOutlined,
              onPressed: () => setState(() {
                _layer = null;
                _ear = true;
              }),
              child: Text(uiText(context, UxPrototypeCopy.earNoInstrument)),
            ),
          ],
        ),
        if (measured.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            uiText(context, UxPrototypeCopy.latestRun),
            style: hankenText(
              size: 14,
              weight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 4),
          _counterRow(context, measured.last.marks),
        ],
      ],
    );
  }

  List<_PathRow> _pathUnits() {
    final course = _course;
    if (course == null) {
      return const <_PathRow>[
        _PathRow(1, '1', 5),
        _PathRow(1, '2', 5),
        _PathRow(1, '3', 6),
        _PathRow(2, '4', 5),
      ];
    }
    return <_PathRow>[
      for (final u in course.units)
        if (!u.isTest)
          _PathRow(u.level, '${u.module}${u.track ?? ''}', u.lessons.length),
    ];
  }

  (int, String) _continueTarget(List<_PathRow> units) {
    final i = _unit.clamp(0, units.length - 1);
    return (units[i].level, units[i].module);
  }

  Widget _pathBody(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    Widget tab(String key, UiCopy label, bool selected, VoidCallback tap) =>
        Expanded(
          child: Semantics(
            selected: selected,
            button: true,
            child: TextButton(
              key: Key(key),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: palette.ink,
                backgroundColor: selected ? palette.controlSurface : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: selected ? palette.ink : palette.controlBorder,
                    width: selected ? 2 : 1,
                  ),
                ),
              ),
              onPressed: tap,
              child: Text(uiText(context, label)),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            tab(
              'ux-tab-path',
              UxPrototypeCopy.tabPath,
              _pathTab,
              () => setState(() => _pathTab = true),
            ),
            const SizedBox(width: 8),
            tab(
              'ux-tab-history',
              UxPrototypeCopy.tabHistory,
              !_pathTab,
              () => setState(() => _pathTab = false),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_pathTab) _pathList(context) else _historyList(context),
      ],
    );
  }

  Widget _pathList(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final rows = _pathUnits();
    final next = _unit.clamp(0, rows.length - 1);
    final children = <Widget>[];
    if (_course == null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(uiText(context, UxPrototypeCopy.protoNote), style: _body),
        ),
      );
    }
    int? lastLevel;
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      if (r.level != lastLevel) {
        lastLevel = r.level;
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              uiText(
                context,
                UxPrototypeCopy.levelLabel,
                values: {'v0': r.level},
              ),
              style: hankenText(
                size: 16,
                weight: FontWeight.w600,
                color: palette.ink,
              ),
            ),
          ),
        );
      }
      children.add(
        Container(
          key: Key(i == next ? 'ux-next-module' : 'ux-module-$i'),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: i == next ? palette.controlSurface : null,
            border: Border.all(
              color: i == next ? palette.ink : palette.controlBorder,
              width: i == next ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                uiText(
                  context,
                  UxPrototypeCopy.moduleRow,
                  values: {'v0': r.module, 'v1': r.lessons},
                ),
                style: _body,
              ),
              if (i == next) ...<Widget>[
                Text(
                  uiText(context, UxPrototypeCopy.nextBadge),
                  style: hankenText(
                    size: 13,
                    weight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
                Text(
                  uiText(context, UxPrototypeCopy.nextWhy),
                  key: const Key('ux-next-why'),
                  style: hankenText(size: 13, color: palette.textBody),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      key: const Key('ux-path-list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _historyList(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final runs = <UxHistoryRun>[
      ..._session.reversed,
      if (widget.seedHistory) uxSampleYesterday,
    ];
    return Column(
      key: const Key('ux-history'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (runs.isEmpty)
          Text(
            uiText(context, UxPrototypeCopy.historyEmpty),
            key: const Key('ux-history-empty'),
            style: _body,
          )
        else ...<Widget>[
          Text(
            uiText(context, UxPrototypeCopy.historyHead),
            style: hankenText(
              size: 14,
              weight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
          for (final r in runs)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: palette.controlBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    uiText(
                      context,
                      r.dayIsToday
                          ? UxPrototypeCopy.dayToday
                          : UxPrototypeCopy.dayYesterday,
                    ),
                    style: hankenText(
                      size: 14,
                      weight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                  if (r.measured) ...<Widget>[
                    _counterRow(context, r.marks),
                    // "Heard" is its own line, apart from accuracy.
                    Text(
                      uiText(
                        context,
                        UxPrototypeCopy.heardPct,
                        values: {'v0': uxHeardPercent(r.marks)},
                      ),
                      style: _body,
                    ),
                  ] else
                    Text(
                      uiText(context, UxPrototypeCopy.notMeasured),
                      style: _body,
                    ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 12),
        Text(uiText(context, UxPrototypeCopy.earListedApart), style: _body),
      ],
    );
  }

  Widget _setupBody(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    Widget chip(String key, UiCopy label, UxMic value) {
      final selected = _mic == value;
      return Semantics(
        selected: selected,
        button: true,
        child: OutlinedButton(
          key: Key(key),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: palette.ink,
            backgroundColor: selected ? palette.controlSurface : null,
            side: BorderSide(
              color: selected ? palette.ink : palette.controlBorder,
              width: selected ? 2 : 1,
            ),
          ),
          onPressed: () => setState(() => _mic = value),
          child: Text(uiText(context, label)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(uiText(context, UxPrototypeCopy.protoMicState), style: _body),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            chip('ux-mic-ready', UxPrototypeCopy.stateReady, UxMic.ready),
            chip('ux-mic-denied', UxPrototypeCopy.stateDenied, UxMic.denied),
            chip('ux-mic-unclear', UxPrototypeCopy.stateUnclear, UxMic.unclear),
          ],
        ),
      ],
    );
  }

  Widget _resultBody(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final kind = _lastKind ?? UxRunKind.measured;
    final marks = _session.isEmpty ? _marks : _session.last.marks;
    final different = marks.indexOf(PracticeMark.differentNote);
    final bar = different >= 0 ? different ~/ 2 + 1 : _section;
    final couldNot = uxCount(marks, PracticeMark.couldNotHear);
    final children = <Widget>[];
    if (kind == UxRunKind.measured) {
      children
        ..add(_counterRow(context, marks))
        ..add(const SizedBox(height: 8))
        ..add(
          Text(
            uiText(
              context,
              UxPrototypeCopy.heardPct,
              values: {'v0': uxHeardPercent(marks)},
            ),
            key: const Key('ux-result-heard'),
            style: _body,
          ),
        );
      final accuracy = uxAccuracyPercent(marks);
      if (accuracy != null) {
        children.add(
          Text(
            uiText(
              context,
              UxPrototypeCopy.accuracyLine,
              values: {'v0': accuracy},
            ),
            key: const Key('ux-result-accuracy'),
            style: _body,
          ),
        );
      }
      if (different >= 0) {
        children.add(
          Text(
            uiText(context, UxPrototypeCopy.whereLine, values: {'v0': bar}),
            key: const Key('ux-result-where'),
            style: _body,
          ),
        );
      }
      if (couldNot > 0) {
        children.add(
          Text(
            uiText(
              context,
              UxPrototypeCopy.couldNotLine,
              values: {
                'v0': couldNot,
                'v1': uiText(context, UxPrototypeCopy.reasonQuiet),
              },
            ),
            key: const Key('ux-result-could-not'),
            style: _body,
          ),
        );
      }
      children
        ..add(const SizedBox(height: 8))
        ..add(
          Text(
            uiText(
              context,
              UxPrototypeCopy.correctionLine,
              values: {'v0': bar},
            ),
            key: const Key('ux-result-correction'),
            style: hankenText(
              size: 15,
              weight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
        );
    } else {
      children
        ..add(
          Text(
            uiText(context, UxPrototypeCopy.notMeasured),
            key: const Key('ux-result-not-measured'),
            style: hankenText(
              size: 17,
              weight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
        )
        ..add(const SizedBox(height: 6))
        ..add(
          Text(
            uiText(context, switch (kind) {
              UxRunKind.unmeasuredPartial => UxPrototypeCopy.unmeasuredBody,
              UxRunKind.unmeasuredNotListened => UxPrototypeCopy.selfCheckBody,
              _ => UxPrototypeCopy.unreliableBody,
            }),
            key: const Key('ux-result-body'),
            style: _body,
          ),
        );
    }
    children
      ..add(const SizedBox(height: 14))
      ..add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton(
              key: const Key('ux-try-again'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _tryAgain,
              child: Text(uiText(context, UxPrototypeCopy.tryAgain)),
            ),
            OutlinedButton(
              key: const Key('ux-next'),
              style: _bigOutlined,
              onPressed: _next,
              child: Text(uiText(context, UxPrototypeCopy.nextButton)),
            ),
            OutlinedButton(
              key: const Key('ux-loop-bar'),
              style: _bigOutlined,
              onPressed: _loopBar,
              child: Text(uiText(context, UxPrototypeCopy.loopBar)),
            ),
          ],
        ),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// A note mark drawn as a shape, never by colour alone: check (correct),
/// diamond (different note), ring (could not hear), dot (pending).
class UxMarkGlyph extends StatelessWidget {
  const UxMarkGlyph({
    super.key,
    required this.mark,
    required this.color,
    this.size = 22,
  });

  final PracticeMark mark;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _MarkPainter(mark, color));
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.mark, this.color);
  final PracticeMark mark;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    switch (mark) {
      case PracticeMark.correct:
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.15, s * 0.55)
            ..lineTo(s * 0.4, s * 0.8)
            ..lineTo(s * 0.85, s * 0.2),
          stroke,
        );
      case PracticeMark.differentNote:
        canvas.drawPath(
          Path()
            ..moveTo(s * 0.5, s * 0.1)
            ..lineTo(s * 0.9, s * 0.5)
            ..lineTo(s * 0.5, s * 0.9)
            ..lineTo(s * 0.1, s * 0.5)
            ..close(),
          fill,
        );
      case PracticeMark.couldNotHear:
        canvas.drawCircle(Offset(s / 2, s / 2), s * 0.36, stroke);
      case PracticeMark.pending:
        canvas.drawCircle(Offset(s / 2, s / 2), s * 0.07, fill);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.mark != mark || old.color != color;
}
