import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../account_connection.dart';
import '../app_locale.dart';
import '../app_theme.dart';
import '../audio/practice_audio_root.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import '../device_accuracy_copy.dart';
import '../ui_copy.dart';
import 'tuner_check_memory.dart';
import 'tuner_controller.dart';
import 'tuner_copy.dart';
import 'tuner_guidance.dart';
import 'tunings.dart';

/// Opens the tuner. The setup wizard (F4.2) and the session tuning gate use
/// this entry point; it resolves to today's tuner result when the screen
/// closes (null if nothing was measured). The screen never closes itself
/// when strings are in tune (anti-pattern 9).
///
/// [startOnOpen]: the caller's own button already said "tune now" (the setup
/// wizard), so the microphone starts with the screen instead of asking for a
/// second tap. The OS permission prompt still appears on first use.
Future<TunerCheck?> openTuner(
  BuildContext context, {
  TuningPreset preset = TuningPresets.guitarStandard,
  TunerController? controller,
  bool startOnOpen = false,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => TunerScreen(
        initialPreset: preset,
        controller: controller,
        startOnOpen: startOnOpen,
      ),
    ),
  );
  return TunerCheckMemory.instance.today;
}

class TunerScreen extends StatefulWidget {
  const TunerScreen({
    super.key,
    this.initialPreset = TuningPresets.guitarStandard,
    this.controller,
    this.startOnOpen = false,
  });

  final TuningPreset initialPreset;
  final TunerController? controller;
  final bool startOnOpen;

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> {
  late final TunerController _controller =
      widget.controller ?? TunerController(preset: widget.initialPreset);
  bool _accountInitialized = false;
  String? _accountId;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller.setPreset(widget.initialPreset);
    }
    _controller.addListener(_changed);
    if (widget.startOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _controller.isActive || !_controller.canStart) return;
        unawaited(
          _controller.start(
            captureAction: PracticeAudioCaptureScope.actionFor(context),
          ),
        );
      });
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = AccountScope.maybeOf(context)?.currentUserId;
    if (_accountInitialized && id != _accountId) {
      unawaited(_controller.stop());
    }
    _accountInitialized = true;
    _accountId = id;
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    unawaited(_controller.stop());
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  String _t(UiCopy copy, [Map<String, Object?> values = const {}]) =>
      uiText(context, copy, values: values);

  String _note(int midi, {bool flats = false}) =>
      musicPitch(context, midiNoteName(midi, flats: flats));

  String _phaseMessage() => switch (_controller.phase) {
    TunerPhase.idle => _t(TunerCopy.phaseIdle),
    TunerPhase.starting => _t(TunerCopy.phaseStarting),
    TunerPhase.calibrating => _t(TunerCopy.phaseCalibrating),
    TunerPhase.listening => _t(TunerCopy.listening),
    TunerPhase.permissionDenied => _t(TunerCopy.phaseDenied),
    TunerPhase.permissionDeniedPermanent => _t(TunerCopy.phaseDeniedPermanent),
    TunerPhase.unsupportedInput => _t(TunerCopy.phaseUnsupported),
    TunerPhase.unavailable => _t(TunerCopy.phaseUnavailable),
  };

  /// Headline and hint for the current readout. Never says "wrong".
  (String, String?) _readoutText(TunerReadout r) {
    final chromatic = _controller.mode == TunerMode.chromatic;
    return switch (r.kind) {
      TunerReadoutKind.listening => (_t(TunerCopy.listening), null),
      TunerReadoutKind.couldNotMeasure => (
        _t(TunerCopy.couldNotMeasure),
        _t(
          r.reason == CouldNotMeasureReason.tooQuiet
              ? TunerCopy.tooQuiet
              : TunerCopy.unclear,
        ),
      ),
      TunerReadoutKind.playAgain => (
        _t(TunerCopy.playAgain),
        _t(TunerCopy.playAgainHint),
      ),
      TunerReadoutKind.octaveUnclear => (
        _t(TunerCopy.octaveUnclear),
        _t(TunerCopy.octaveUnclearHint),
      ),
      TunerReadoutKind.chooseString => _controller.mode == TunerMode.manual
          ? (_t(TunerCopy.chooseString), _t(TunerCopy.farFromSelected))
          : (_t(TunerCopy.chooseString), _t(TunerCopy.chooseStringHint)),
      TunerReadoutKind.tooHigh => (
        _t(TunerCopy.tooHigh),
        _t(TunerCopy.tooHighHint),
      ),
      TunerReadoutKind.inTune => (_t(TunerCopy.inTune), null),
      TunerReadoutKind.measured => (
        chromatic
            ? _t(
                r.direction == TuneDirection.loosen
                    ? TunerCopy.above
                    : TunerCopy.below,
              )
            : _t(
                r.direction == TuneDirection.loosen
                    ? TunerCopy.loosen
                    : TunerCopy.tighten,
              ),
        null,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final p = OstinatoPalette.of(context);
    final hue = p.guitar;
    final r = c.readout;
    final (headline, hint) = _readoutText(r);
    final preset = c.preset;
    return Scaffold(
      backgroundColor: p.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassIconButton(
                key: const Key('tuner-back'),
                icon: '‹',
                semanticLabel: _t(TunerCopy.back),
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 16),
              Text(
                _t(TunerCopy.title),
                style: hankenText(size: 27, weight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _instrumentPicker(),
              const SizedBox(height: 8),
              _presetPicker(),
              const SizedBox(height: 12),
              _modePicker(),
              const SizedBox(height: 6),
              Text(
                _t(switch (c.mode) {
                  TunerMode.auto => TunerCopy.modeAutoHint,
                  TunerMode.manual => TunerCopy.modeManualHint,
                  TunerMode.chromatic => TunerCopy.modeChromaticHint,
                }),
                style: hankenText(size: 12.5, height: 1.4),
              ),
              if (c.mode != TunerMode.chromatic) ...[
                const SizedBox(height: 12),
                _strings(preset),
              ],
              const SizedBox(height: 14),
              GlassCard(
                key: const Key('tuner-readout'),
                gradientColors: hue.grad,
                child: Column(
                  children: [
                    SizedBox(
                      height: 120,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _NeedlePainter(
                          cents: r.showsNumber ? r.cents : null,
                          tolerance: c.toleranceCents,
                          ink: hue.ink,
                          band: p.success,
                          muted: p.textFaint,
                        ),
                      ),
                    ),
                    Text(
                      r.showsNumber
                          ? '${r.cents! >= 0.5 ? '+' : r.cents! <= -0.5 ? '−' : ''}'
                                '${appInteger(context, r.cents!.abs().round())}'
                          : '—',
                      key: const Key('tuner-cents'),
                      style: hankenText(size: 56, weight: FontWeight.w600),
                    ),
                    Text(
                      _t(TunerCopy.centsUnit),
                      style: monoText(color: hue.ink),
                    ),
                    const SizedBox(height: 8),
                    if (r.targetMidi != null && r.showsNumber)
                      Text(
                        _t(
                          c.mode == TunerMode.chromatic
                              ? TunerCopy.nearest
                              : TunerCopy.target,
                          {
                            'v0': _note(
                              r.targetMidi!,
                              flats: preset.preferFlats,
                            ),
                          },
                        ),
                        style: hankenText(size: 13),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      c.phase == TunerPhase.listening
                          ? headline
                          : _phaseMessage(),
                      key: const Key('tuner-headline'),
                      textAlign: TextAlign.center,
                      style: hankenText(size: 18, weight: FontWeight.w600),
                    ),
                    if (c.phase == TunerPhase.listening && hint != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        hint,
                        key: const Key('tuner-hint'),
                        textAlign: TextAlign.center,
                        style: hankenText(size: 13, height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: kicker(_t(TunerCopy.trace), color: hue.ink),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _TracePainter(
                          points: c.trace,
                          nowUs: c.latestUs,
                          tolerance: c.toleranceCents,
                          ink: hue.ink,
                          band: p.success,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t(TunerCopy.band, {
                        'v0': appInteger(context, c.toleranceCents.round()),
                        'v1': appInteger(context, c.a4Hz.round()),
                      }),
                      style: hankenText(size: 12, color: p.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (c.mode != TunerMode.chromatic)
                Text(
                  c.session.allInTune
                      ? _t(TunerCopy.allInTune)
                      : _t(TunerCopy.progressCount, {
                          'v0': appInteger(context, c.session.inTuneCount),
                          'v1': appInteger(context, preset.stringCount),
                        }),
                  key: const Key('tuner-progress'),
                  style: hankenText(size: 14, weight: FontWeight.w500),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const Key('tuner-start-stop'),
                    onPressed: c.isActive
                        ? () => unawaited(c.stop())
                        : !c.canStart
                        ? null
                        : () {
                            final action = PracticeAudioCaptureScope.actionFor(
                              context,
                            );
                            unawaited(c.start(captureAction: action));
                          },
                    icon: Icon(c.isActive ? Icons.stop : Icons.mic_none),
                    label: Text(
                      _t(c.isActive ? TunerCopy.stop : TunerCopy.start),
                    ),
                  ),
                  if (c.phase == TunerPhase.permissionDeniedPermanent)
                    TextButton(
                      onPressed: openAppSettings,
                      child: Text(_t(TunerCopy.openSettings)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _t(TunerCopy.privacy),
                style: hankenText(size: 12.5, height: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                joinSentences(
                  context,
                  _t(DeviceAccuracyCopy.note),
                  _t(TunerCopy.newString),
                ),
                style: hankenText(size: 12.5, height: 1.5, color: p.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _instrumentPicker() => SegmentedButton<TunerInstrument>(
    key: const Key('tuner-instrument'),
    showSelectedIcon: false,
    segments: [
      for (final i in TunerInstrument.values)
        ButtonSegment(value: i, label: Text(_t(i.name))),
    ],
    selected: {_controller.preset.instrument},
    onSelectionChanged: (s) =>
        _controller.setPreset(TuningPresets.forInstrument(s.first).first),
  );

  Widget _presetPicker() => Wrap(
    spacing: 8,
    runSpacing: 6,
    children: [
      for (final preset in TuningPresets.forInstrument(
        _controller.preset.instrument,
      ))
        ChoiceChip(
          key: Key('tuner-preset-${preset.id}'),
          label: Text(_t(preset.name)),
          selected: preset.id == _controller.preset.id,
          onSelected: (_) => _controller.setPreset(preset),
        ),
    ],
  );

  Widget _modePicker() => SegmentedButton<TunerMode>(
    key: const Key('tuner-mode'),
    showSelectedIcon: false,
    segments: [
      ButtonSegment(value: TunerMode.auto, label: Text(_t(TunerCopy.modeAuto))),
      ButtonSegment(
        value: TunerMode.manual,
        label: Text(_t(TunerCopy.modeManual)),
      ),
      ButtonSegment(
        value: TunerMode.chromatic,
        label: Text(_t(TunerCopy.modeChromatic)),
      ),
    ],
    selected: {_controller.mode},
    onSelectionChanged: (s) => _controller.setMode(s.first),
  );

  Widget _strings(TuningPreset preset) {
    final states = _controller.session.states;
    final focus = _controller.session.focus;
    final p = OstinatoPalette.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < preset.stringCount; i++)
          Semantics(
            button: true,
            selected: i == focus,
            label: _t(TunerCopy.stringLabel, {
              'v0': appInteger(context, preset.stringNumber(i)),
              'v1': _note(preset.midis[i], flats: preset.preferFlats),
            }),
            value: _t(switch (states[i]) {
              StringTuneState.pending => TunerCopy.stringWaiting,
              StringTuneState.low => TunerCopy.stringLow,
              StringTuneState.high => TunerCopy.stringHigh,
              StringTuneState.inTune => TunerCopy.stringInTune,
            }),
            excludeSemantics: true,
            child: OutlinedButton(
              key: Key('tuner-string-$i'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(52, 48),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                side: BorderSide(
                  color: i == focus ? p.focus : p.outline,
                  width: i == focus ? 2.5 : 1,
                ),
              ),
              onPressed: () => _controller.selectString(i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    midiNoteName(preset.midis[i], flats: preset.preferFlats),
                    style: hankenText(size: 15, weight: FontWeight.w600),
                  ),
                  Text(
                    switch (states[i]) {
                      StringTuneState.pending => '●',
                      StringTuneState.low => '↑',
                      StringTuneState.high => '↓',
                      StringTuneState.inTune => '✓',
                    },
                    style: hankenText(
                      size: 13,
                      color: states[i] == StringTuneState.inTune
                          ? p.success
                          : p.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Arc gauge, −50…+50 cents. Grey with no needle when nothing is shown.
class _NeedlePainter extends CustomPainter {
  _NeedlePainter({
    required this.cents,
    required this.tolerance,
    required this.ink,
    required this.band,
    required this.muted,
  });

  final double? cents;
  final double tolerance;
  final Color ink, band, muted;

  static const double range = 50;
  static const double sweep = math.pi * 0.8;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height - 6);
    final radius = math.min(size.width / 2 - 8, size.height - 14);
    final rect = Rect.fromCircle(center: centre, radius: radius);
    const start = -math.pi / 2 - sweep / 2;
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = muted.withValues(alpha: 0.35),
    );
    final bandSweep = sweep * (2 * tolerance / (2 * range));
    canvas.drawArc(
      rect,
      -math.pi / 2 - bandSweep / 2,
      bandSweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = band.withValues(alpha: cents == null ? 0.35 : 0.9),
    );
    final value = cents;
    if (value == null) return;
    final angle = -math.pi / 2 + sweep / 2 * (value.clamp(-range, range) / range);
    canvas.drawLine(
      centre,
      centre + Offset(math.cos(angle), math.sin(angle)) * (radius - 4),
      Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = ink,
    );
    canvas.drawCircle(centre, 5, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(_NeedlePainter old) =>
      old.cents != cents || old.tolerance != tolerance || old.ink != ink;
}

/// Last three seconds of shown cents values; centre line is the target.
class _TracePainter extends CustomPainter {
  _TracePainter({
    required this.points,
    required this.nowUs,
    required this.tolerance,
    required this.ink,
    required this.band,
  });

  final List<TracePoint> points;
  final int? nowUs;
  final double tolerance;
  final Color ink, band;

  static const double range = 50;

  @override
  void paint(Canvas canvas, Size size) {
    double y(double cents) =>
        size.height / 2 - cents.clamp(-range, range) / range * size.height / 2;
    canvas.drawRect(
      Rect.fromLTRB(0, y(tolerance), size.width, y(-tolerance)),
      Paint()..color = band.withValues(alpha: 0.25),
    );
    final now = nowUs;
    if (now == null || points.isEmpty) return;
    final dot = Paint()..color = ink;
    Offset? previous;
    for (final p in points) {
      final age = (now - p.tUs) / (TunerController.traceMs * 1000);
      if (age > 1) continue;
      final at = Offset(size.width * (1 - age.clamp(0.0, 1.0)), y(p.cents));
      if (previous != null) {
        canvas.drawLine(
          previous,
          at,
          Paint()
            ..strokeWidth = 1.5
            ..color = ink.withValues(alpha: 0.6),
        );
      }
      canvas.drawCircle(at, 2.5, dot);
      previous = at;
    }
  }

  @override
  bool shouldRepaint(_TracePainter old) => true;
}
