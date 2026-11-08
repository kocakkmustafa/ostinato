import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import '../practice/loop/reference_listen.dart';
import '../ui_copy.dart';
import 'first_minutes_controller.dart';
import 'first_minutes_copy.dart';
import 'rhythm_tap_analysis.dart';

/// OST-P0-05 "first three minutes", behind `ostinatoFirstThreeMinutesOpen`.
///
/// Three starting points; "Tap the rhythm" never asks for the microphone.
/// "Use your voice" asks at the moment of use and falls back, without blame,
/// to tapping. "I have an instrument" leaves for the existing library.
/// Tap times are measured on this device from touch events and kept in
/// memory only; nothing is recorded, saved or sent.
class FirstThreeMinutesScreen extends StatefulWidget {
  const FirstThreeMinutesScreen({
    super.key,
    required this.onOpenLibrary,
    this.portBuilder,
    this.nowUs,
  });

  /// Leaves for the existing library (instrument path, skip, next goal).
  final VoidCallback onOpenLibrary;

  /// The output-only playback path; defaults to the audio root of the route.
  final ReferencePlaybackPort? Function(BuildContext context)? portBuilder;

  /// Test seam for the tap clock (microseconds).
  final int Function()? nowUs;

  @override
  State<FirstThreeMinutesScreen> createState() =>
      _FirstThreeMinutesScreenState();
}

class _FirstThreeMinutesScreenState extends State<FirstThreeMinutesScreen> {
  late final FirstMinutesController _c = FirstMinutesController(
    nowUs: widget.nowUs,
  );

  @override
  void initState() {
    super.initState();
    _c.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_rebuild);
    _c.dispose();
    super.dispose();
  }

  ReferencePlaybackPort? get _port => widget.portBuilder != null
      ? widget.portBuilder!(context)
      : ReferenceRoutePort.of(context);

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    return Scaffold(
      backgroundColor: palette.shell,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: switch (_c.stage) {
                FirstMinutesStage.choose => _choose(context),
                FirstMinutesStage.voice => _voice(context),
                FirstMinutesStage.rhythm => _rhythm(context),
                FirstMinutesStage.variation => _variation(context),
                FirstMinutesStage.summary => _summary(context),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(BuildContext context, UiCopy copy, Key key) => Text(
    uiText(context, copy),
    key: key,
    style: hankenText(size: 28, weight: FontWeight.w600, height: 1.12),
  );

  Widget _body(BuildContext context, UiCopy copy, {Key? key}) => Text(
    uiText(context, copy),
    key: key,
    style: hankenText(
      size: 15,
      height: 1.55,
      color: OstinatoPalette.of(context).textBody,
    ),
  );

  Widget _gap([double h = 14]) => SizedBox(height: h);

  Widget _backButton(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TextButton.icon(
      key: const Key('first-minutes-back'),
      onPressed: _c.backToChoice,
      icon: const Icon(Icons.arrow_back, size: 18),
      label: Text(uiText(context, FirstMinutesCopy.back)),
    ),
  );

  // ── choose ────────────────────────────────────────────────────────────
  Widget _choose(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      _title(
        context,
        FirstMinutesCopy.choiceTitle,
        const Key('fm-choice-title'),
      ),
      _gap(8),
      _body(context, FirstMinutesCopy.choiceHint),
      _gap(18),
      _ChoiceCard(
        key: const Key('fm-choice-tap'),
        icon: Icons.touch_app_outlined,
        title: uiText(context, FirstMinutesCopy.tapTitle),
        body: uiText(context, FirstMinutesCopy.tapBody),
        onTap: _c.chooseTap,
      ),
      _gap(12),
      _ChoiceCard(
        key: const Key('fm-choice-voice'),
        icon: Icons.mic_none,
        title: uiText(context, FirstMinutesCopy.voiceTitle),
        body: uiText(context, FirstMinutesCopy.voiceBody),
        onTap: _c.chooseVoice,
      ),
      _gap(12),
      _ChoiceCard(
        key: const Key('fm-choice-instrument'),
        icon: Icons.library_music_outlined,
        title: uiText(context, FirstMinutesCopy.instrumentTitle),
        body: uiText(context, FirstMinutesCopy.instrumentBody),
        onTap: widget.onOpenLibrary,
      ),
      _gap(8),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          key: const Key('fm-skip'),
          onPressed: widget.onOpenLibrary,
          child: Text(uiText(context, FirstMinutesCopy.skip)),
        ),
      ),
    ],
  );

  // ── voice ─────────────────────────────────────────────────────────────
  Widget _voice(BuildContext context) {
    final outcome = _c.voiceOutcome;
    final message = switch (outcome) {
      VoiceOutcome.none => null,
      VoiceOutcome.granted => FirstMinutesCopy.voiceGranted,
      VoiceOutcome.denied => FirstMinutesCopy.voiceDenied,
      VoiceOutcome.permanent => FirstMinutesCopy.voicePermanent,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _backButton(context),
        _title(
          context,
          FirstMinutesCopy.voiceTitle,
          const Key('fm-voice-title'),
        ),
        _gap(),
        _body(context, FirstMinutesCopy.voiceExplain),
        _gap(18),
        if (message != null) ...<Widget>[
          Semantics(
            liveRegion: true,
            child: _body(context, message, key: const Key('fm-voice-result')),
          ),
          _gap(18),
        ],
        if (outcome == VoiceOutcome.none)
          PrimaryButton(
            key: const Key('fm-voice-allow'),
            label: uiText(context, FirstMinutesCopy.voiceAllow),
            onPressed: _c.voiceBusy ? null : _c.requestVoice,
          )
        else if (outcome == VoiceOutcome.granted)
          PrimaryButton(
            key: const Key('fm-voice-library'),
            label: uiText(context, FirstMinutesCopy.openLibrary),
            onPressed: widget.onOpenLibrary,
          )
        else
          PrimaryButton(
            key: const Key('fm-voice-fallback'),
            label: uiText(context, FirstMinutesCopy.continueTapping),
            onPressed: _c.chooseTap,
          ),
      ],
    );
  }

  // ── rhythm ────────────────────────────────────────────────────────────
  Widget _rhythm(BuildContext context) {
    final tapping = _c.roundActive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _backButton(context),
        _title(
          context,
          _c.round == 0
              ? FirstMinutesCopy.rhythmTitle
              : FirstMinutesCopy.variationTitle,
          const Key('fm-rhythm-title'),
        ),
        _gap(),
        _body(
          context,
          _c.round == 0
              ? FirstMinutesCopy.rhythmIntro
              : FirstMinutesCopy.variationBody,
        ),
        _gap(18),
        _BeatGrid(
          deviations: _c.liveDeviations,
          expectedBeats: kRoundBeats[_c.round],
        ),
        _gap(6),
        Text(
          uiText(context, FirstMinutesCopy.gridLegend),
          style: hankenText(
            size: 12.5,
            color: OstinatoPalette.of(context).textMuted,
          ),
        ),
        _gap(18),
        if (_c.beatUnavailable) ...<Widget>[
          Semantics(
            liveRegion: true,
            child: _body(
              context,
              FirstMinutesCopy.beatUnavailable,
              key: const Key('fm-beat-unavailable'),
            ),
          ),
          _gap(14),
          PrimaryButton(
            key: const Key('fm-retry'),
            label: uiText(context, FirstMinutesCopy.tryAgain),
            onPressed: () => _c.startRound(_port),
          ),
          _gap(8),
          TextButton(
            key: const Key('fm-unavailable-library'),
            onPressed: widget.onOpenLibrary,
            child: Text(uiText(context, FirstMinutesCopy.openLibrary)),
          ),
        ] else if (!tapping)
          PrimaryButton(
            key: const Key('fm-start-beat'),
            label: uiText(context, FirstMinutesCopy.startBeat),
            onPressed: () => _c.startRound(_port),
          )
        else ...<Widget>[
          _TapPad(onTap: _c.tap),
          _gap(10),
          Text(
            uiText(
              context,
              FirstMinutesCopy.tapCount,
              values: {'v0': _c.tapCount, 'v1': _c.expectedTaps},
            ),
            key: const Key('fm-tap-count'),
            style: hankenText(
              size: 13.5,
              color: OstinatoPalette.of(context).textMuted,
            ),
          ),
          _gap(6),
          _body(context, FirstMinutesCopy.humanNote),
        ],
      ],
    );
  }

  // ── variation ─────────────────────────────────────────────────────────
  Widget _variation(BuildContext context) {
    final m = _c.results[0]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _title(
          context,
          FirstMinutesCopy.variationTitle,
          const Key('fm-variation-title'),
        ),
        _gap(),
        _BeatGrid(deviations: m.deviationsMs, expectedBeats: kRoundBeats[0]),
        _gap(10),
        _body(context, summaryFor(m), key: const Key('fm-variation-try1')),
        _gap(10),
        _body(context, FirstMinutesCopy.variationBody),
        _gap(18),
        PrimaryButton(
          key: const Key('fm-variation-go'),
          label: uiText(context, FirstMinutesCopy.variationGo),
          onPressed: _c.startVariation,
        ),
      ],
    );
  }

  // ── summary ───────────────────────────────────────────────────────────
  Widget _summary(BuildContext context) {
    final a = _c.results[0]!;
    final b = _c.results[1]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _title(
          context,
          FirstMinutesCopy.summaryTitle,
          const Key('fm-summary-title'),
        ),
        _gap(),
        _body(context, summaryFor(b), key: const Key('fm-summary-line')),
        _gap(8),
        _body(
          context,
          comparisonFor(a, b),
          key: const Key('fm-summary-compare'),
        ),
        _gap(16),
        _TakeRow(
          index: 0,
          measurement: a,
          beats: kRoundBeats[0],
          playing: _c.playingTag == 'take0',
          label: FirstMinutesCopy.listenTry1,
          onPlay: () => _c.playTake(0, _port),
          onStop: _c.stopPlayback,
        ),
        _gap(12),
        _TakeRow(
          index: 1,
          measurement: b,
          beats: kRoundBeats[1],
          playing: _c.playingTag == 'take1',
          label: FirstMinutesCopy.listenTry2,
          onPlay: () => _c.playTake(1, _port),
          onStop: _c.stopPlayback,
        ),
        _gap(6),
        Text(
          uiText(context, FirstMinutesCopy.playbackNote),
          style: hankenText(
            size: 12.5,
            color: OstinatoPalette.of(context).textMuted,
          ),
        ),
        _gap(18),
        GlassCard(
          borderRadius: 18,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              kicker(uiText(context, FirstMinutesCopy.nextTitle)),
              _gap(8),
              _body(context, FirstMinutesCopy.nextBody),
            ],
          ),
        ),
        _gap(14),
        PrimaryButton(
          key: const Key('fm-summary-library'),
          label: uiText(context, FirstMinutesCopy.openLibrary),
          onPressed: widget.onOpenLibrary,
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = OstinatoPalette.of(context);
    return Semantics(
      button: true,
      label: '$title. $body',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.controlSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.glassBorder),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: <Widget>[
                  Icon(icon, size: 28, color: p.ink),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: hankenText(size: 17, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          body,
                          style: hankenText(
                            size: 13.5,
                            height: 1.45,
                            color: p.textBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A large tap area. Touch-down is used, not touch-up, so the time is the
/// moment of the touch.
class _TapPad extends StatelessWidget {
  const _TapPad({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = OstinatoPalette.of(context);
    return Semantics(
      button: true,
      label: uiText(context, FirstMinutesCopy.tapPadLabel),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        key: const Key('fm-tap-pad'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onTap(),
        child: Container(
          height: 180,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.primary,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Text(
            uiText(context, FirstMinutesCopy.tapPad),
            style: hankenText(
              size: 26,
              weight: FontWeight.w600,
              color: p.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Four slots, one per beat of the tapped bar. A dot is the beat; a ring is
/// the tap, shifted by how far it landed from the beat. Colors are neutral:
/// being off the beat is never drawn as an error. A beat the variation
/// leaves out is a faint hollow dot.
class _BeatGrid extends StatelessWidget {
  const _BeatGrid({required this.deviations, required this.expectedBeats});
  final List<double?> deviations;
  final List<int> expectedBeats;

  @override
  Widget build(BuildContext context) {
    final p = OstinatoPalette.of(context);
    final halfBeatMs = 60000 / kFirstMinutesBpm / 2;
    return Semantics(
      label: uiText(context, FirstMinutesCopy.gridLabel),
      child: ExcludeSemantics(
        child: SizedBox(
          key: const Key('fm-beat-grid'),
          height: 56,
          child: LayoutBuilder(
            builder: (context, c) {
              final slot = c.maxWidth / kListenBeats;
              return Stack(
                children: <Widget>[
                  for (var i = 0; i < kListenBeats; i++)
                    ..._slot(p, i, slot, halfBeatMs),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _slot(OstinatoPalette p, int i, double slot, double halfBeatMs) {
    final k = expectedBeats.indexOf(kListenBeats + i);
    final active = k >= 0;
    final dev = active ? deviations[k] : null;
    final center = slot * i + slot / 2;
    final reach = slot / 2 - 14;
    return <Widget>[
      Positioned(
        left: center - 7,
        top: 21,
        child: Container(
          key: Key('fm-beat-dot-$i'),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? p.ink : Colors.transparent,
            border: Border.all(color: active ? p.ink : p.divider, width: 1.5),
          ),
        ),
      ),
      if (dev != null)
        Positioned(
          left: center - 11 + (dev / halfBeatMs).clamp(-1.0, 1.0) * reach,
          top: 17,
          child: Container(
            key: Key('fm-tap-mark-$i'),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: p.primary, width: 3),
            ),
          ),
        ),
    ];
  }
}

class _TakeRow extends StatelessWidget {
  const _TakeRow({
    required this.index,
    required this.measurement,
    required this.beats,
    required this.playing,
    required this.label,
    required this.onPlay,
    required this.onStop,
  });
  final int index;
  final TapMeasurement measurement;
  final List<int> beats;
  final bool playing;
  final UiCopy label;
  final VoidCallback onPlay;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      _BeatGrid(deviations: measurement.deviationsMs, expectedBeats: beats),
      const SizedBox(height: 6),
      OutlinedButton.icon(
        key: Key('fm-listen-$index'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: playing ? onStop : onPlay,
        icon: Icon(playing ? Icons.stop : Icons.play_arrow),
        label: Text(
          uiText(context, playing ? FirstMinutesCopy.stopListen : label),
        ),
      ),
    ],
  );
}
