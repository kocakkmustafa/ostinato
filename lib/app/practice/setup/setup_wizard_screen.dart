import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_locale.dart';
import '../../app_theme.dart';
import '../../audio/audio_input_controller.dart';
import '../../design/ostinato_theme.dart';
import '../../design/widgets.dart';
import '../../tuner/tuner_check_memory.dart';
import '../../ui_copy.dart';
import '../../tuner/tuner_screen.dart';
import '../../tuner/tunings.dart';
import '../practice_audio_input.dart';
import 'audio_environment.dart';
import 'latency_calibration.dart';
import 'setup_audio_controller.dart';
import 'setup_profile_store.dart';

/// F4.2 setup wizard (`4-rakip-arayuzleri` §6.1 step 4): placement, room and
/// level, latency (E50, 8 clicks), tuning. Every step can be skipped; results
/// stay on this device ([SetupProfileStore]).
enum SetupStep { placement, room, latency, tuning }

Future<void> openSetupWizard(
  BuildContext context, {
  SetupStep start = SetupStep.placement,
  SetupProfileStore? store,
  TuningPreset preset = TuningPresets.guitarStandard,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    builder: (_) =>
        SetupWizardScreen(start: start, store: store, preset: preset),
  ),
);

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({
    super.key,
    this.start = SetupStep.placement,
    this.store,
    this.preset = TuningPresets.guitarStandard,
    this.audioFactory,
    this.environment = const AudioEnvironmentProbe(),
    this.tune,
    this.estimator,
  });

  final SetupStep start;
  final SetupProfileStore? store;
  final TuningPreset preset;

  /// Tests inject a capture controller on a fake channel.
  final AudioInputController Function()? audioFactory;
  final AudioEnvironmentProbe environment;

  /// Opens the tuner; defaults to [openTuner].
  final Future<TunerCheck?> Function(BuildContext context)? tune;
  final LatencyEstimator? estimator;

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  late final SetupProfileStore _store =
      widget.store ?? FileSetupProfileStore.device;
  late final AudioInputController _audio =
      widget.audioFactory?.call() ?? createPracticeAudioInput();
  late final SetupAudioController _measure = SetupAudioController(
    audio: _audio,
    store: _store,
    environment: widget.environment,
    estimator: widget.estimator,
  );
  late SetupStep? _step = widget.start;
  AudioEnvironment _env = AudioEnvironment.unknown;
  TunerCheck? _tuning;
  bool _tuningAsked = false;

  @override
  void initState() {
    super.initState();
    _measure.addListener(_changed);
    unawaited(
      widget.environment.read().then((env) {
        if (mounted) setState(() => _env = env);
      }),
    );
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _measure.removeListener(_changed);
    unawaited(_measure.cancel());
    _measure.dispose();
    if (widget.audioFactory == null) unawaited(_audio.dispose());
    super.dispose();
  }

  Future<void> _mark(SetupStep step, SetupStepState state) async {
    final record = SetupStepRecord(state, DateTime.now().toUtc());
    try {
      await _store.update(
        (p) => switch (step) {
          SetupStep.placement => p.copyWith(placement: record),
          SetupStep.room => p.copyWith(roomStep: record),
          SetupStep.latency => p.copyWith(latencyStep: record),
          SetupStep.tuning => p.copyWith(tuningStep: record),
        },
      );
    } on Object {
      // Not kept; the wizard still moves on.
    }
  }

  Future<void> _next({required bool skipped}) async {
    final step = _step;
    if (step == null) return;
    await _measure.cancel();
    // Measured steps are written by the measurement itself; a skip or a
    // finished-but-unsaved step is recorded here.
    final measured = switch (step) {
      SetupStep.room => _measure.room != null,
      SetupStep.latency => _measure.latency is LatencyMeasured,
      SetupStep.placement || SetupStep.tuning => false,
    };
    if (!measured) {
      await _mark(step, skipped ? SetupStepState.skipped : SetupStepState.done);
    }
    if (!mounted) return;
    final i = SetupStep.values.indexOf(step);
    setState(() {
      _step = i + 1 < SetupStep.values.length ? SetupStep.values[i + 1] : null;
    });
  }

  Future<void> _tune() async {
    final tune =
        widget.tune ??
        (BuildContext c) => openTuner(
          c,
          preset: widget.preset,
          controller: debugFakeTunerController(widget.preset),
          startOnOpen: true,
        );
    final check = await tune(context);
    if (!mounted) return;
    setState(() {
      _tuning = check;
      _tuningAsked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final step = _step;
    return Scaffold(
      backgroundColor: palette.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GlassIconButton(
                    icon: '‹',
                    semanticLabel: localized(context, 'Back', 'Geri'),
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      localized(context, 'Setup', 'Kurulum'),
                      style: hankenText(size: 20, weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                localized(
                  context,
                  'Four short steps. Each can be skipped; results stay on this phone.',
                  'Dört kısa adım. Her biri atlanabilir; sonuçlar bu telefonda kalır.',
                ),
                style: hankenText(size: 13, height: 1.45),
              ),
              const SizedBox(height: 12),
              _stepBar(context),
              const SizedBox(height: 12),
              if (step == null)
                _summary(context)
              else
                switch (step) {
                  SetupStep.placement => _placement(context),
                  SetupStep.room => _room(context),
                  SetupStep.latency => _latency(context),
                  SetupStep.tuning => _tuningStep(context),
                },
              const SizedBox(height: 12),
              Text(
                localized(
                  context,
                  'Audio stays in memory on this device; nothing is recorded or sent.',
                  'Ses yalnız bu cihazın belleğinde kalır; kaydedilmez, gönderilmez.',
                ),
                style: hankenText(size: 11.5, color: palette.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _stepName(BuildContext context, SetupStep s) => switch (s) {
    SetupStep.placement => localized(context, 'Placement', 'Yerleşim'),
    SetupStep.room => localized(context, 'Room and level', 'Oda ve seviye'),
    SetupStep.latency => localized(context, 'Latency', 'Gecikme'),
    SetupStep.tuning => localized(context, 'Tuning', 'Akort'),
  };

  Widget _stepBar(BuildContext context) {
    final step = _step;
    final index = step == null ? 4 : SetupStep.values.indexOf(step) + 1;
    return Text(
      step == null
          ? localized(context, 'Done', 'Bitti')
          : localized(
              context,
              'Step {v0} of 4 · {v1}',
              'Adım {v0}/4 · {v1}',
              values: {'v0': index, 'v1': _stepName(context, step)},
            ),
      key: const Key('setup-step-label'),
      style: monoText(size: 12, letterSpacing: .3),
    );
  }

  Widget _buttons(
    BuildContext context, {
    required String primary,
    required VoidCallback? onPrimary,
    bool canSkip = true,
    String? secondary,
    VoidCallback? onSecondary,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        FilledButton(
          key: const Key('setup-primary'),
          onPressed: onPrimary,
          child: Text(primary),
        ),
        if (secondary != null)
          OutlinedButton(
            key: const Key('setup-secondary'),
            onPressed: onSecondary,
            child: Text(secondary),
          ),
        if (canSkip)
          TextButton(
            key: const Key('setup-skip'),
            onPressed: _measure.busy ? null : () => _next(skipped: true),
            child: Text(localized(context, 'Skip', 'Atla')),
          ),
      ],
    ),
  );

  Widget _card(BuildContext context, List<Widget> children) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Text _body(String text, {Key? key}) =>
      Text(text, key: key, style: hankenText(size: 13.5, height: 1.45));

  Widget _placement(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final warnings = setupWarnings(_env);
    final ios =
        _env.platform == 'ios' ||
        (!_env.isKnown && Theme.of(context).platform == TargetPlatform.iOS);
    return _card(context, [
      _body(
        localized(
          context,
          'Put the phone in front of you, about 50 cm from the sound hole, microphone towards the guitar. Keep the case off the microphone.',
          'Telefonu önüne koy: ses deliğine yaklaşık 50 cm, mikrofon gitara dönük. Kılıf mikrofonu kapatmasın.',
        ),
      ),
      const SizedBox(height: 6),
      _body(
        localized(
          context,
          'Headphones are recommended, not required. Bluetooth headphones add delay: measure latency again with them on.',
          'Kulaklık önerilir, zorunlu değil. Bluetooth kulaklık gecikme ekler: onunla gecikmeyi ayrıca ölç.',
        ),
      ),
      for (final w in warnings)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            _warning(context, w),
            key: Key('setup-warning-${w.name}'),
            style: hankenText(size: 13, color: palette.warnInk),
          ),
        ),
      if (ios)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            localized(
              context,
              'If Sound Recognition is on (Settings › Accessibility), turn it off while you practise; it can take the microphone.',
              'Ses Tanıma açıksa (Ayarlar › Erişilebilirlik), pratik sırasında kapat; mikrofonu kullanabilir.',
            ),
            key: const Key('setup-sound-recognition'),
            style: hankenText(size: 12.5, color: palette.textMuted),
          ),
        ),
      _buttons(
        context,
        primary: localized(context, 'Ready', 'Hazır'),
        onPrimary: () => _next(skipped: false),
      ),
    ]);
  }

  String _warning(BuildContext context, SetupWarning w) => switch (w) {
    SetupWarning.voiceIsolation => localized(
      context,
      'Mic Mode is Voice Isolation: it filters the guitar out. Control Center › Mic Mode › Standard.',
      'Mikrofon Modu Ses Yalıtımı: gitarı süzüp atar. Denetim Merkezi › Mikrofon Modu › Standart.',
    ),
    SetupWarning.wideSpectrum => localized(
      context,
      'Mic Mode is Wide Spectrum: room sound is boosted. Choose Standard in Control Center.',
      'Mikrofon Modu Geniş Spektrum: oda sesi yükseltilir. Denetim Merkezi’nde Standart seç.',
    ),
    SetupWarning.headsetMic => localized(
      context,
      'The headset microphone is in use. The phone’s own microphone hears the guitar better.',
      'Kulaklığın mikrofonu kullanılıyor. Telefonun kendi mikrofonu gitarı daha iyi duyar.',
    ),
    SetupWarning.bluetoothMic => localized(
      context,
      'A Bluetooth headset microphone is in use; it hears the guitar poorly.',
      'Bluetooth kulaklık mikrofonu kullanılıyor; gitarı zayıf duyar.',
    ),
  };

  Widget _meter(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          key: const Key('setup-level-meter'),
          value: _measure.meter,
          minHeight: 8,
          color: palette.ink,
          backgroundColor: palette.outline,
          semanticsLabel: localized(context, 'Input level', 'Giriş seviyesi'),
        ),
      ),
    );
  }

  Widget _room(BuildContext context) {
    final m = _measure;
    final room = m.room;
    final palette = OstinatoPalette.of(context);
    final running =
        m.phase == SetupAudioPhase.starting ||
        m.phase == SetupAudioPhase.roomQuiet ||
        m.phase == SetupAudioPhase.roomPlay;
    final status = switch (m.phase) {
      SetupAudioPhase.starting => localized(
        context,
        'Opening the microphone…',
        'Mikrofon açılıyor…',
      ),
      SetupAudioPhase.roomQuiet => localized(
        context,
        'Stay quiet for 2 seconds — measuring the room…',
        '2 saniye sessiz kal — oda ölçülüyor…',
      ),
      SetupAudioPhase.roomPlay => localized(
        context,
        'Now play one open string.',
        'Şimdi bir boş tel çal.',
      ),
      SetupAudioPhase.done when room != null && room.heard =>
        switch (roomNoiseFor(room.floorDb)) {
          RoomNoise.quiet => localized(
            context,
            'I hear you ✓ · the room is quiet',
            'Seni duyuyorum ✓ · oda sessiz',
          ),
          RoomNoise.some => localized(
            context,
            'I hear you ✓ · the room is a little noisy',
            'Seni duyuyorum ✓ · oda biraz gürültülü',
          ),
          RoomNoise.loud => localized(
            context,
            'I hear you ✓ · the room is very noisy',
            'Seni duyuyorum ✓ · oda çok gürültülü',
          ),
        },
      SetupAudioPhase.done when room != null => localized(
        context,
        'I couldn’t hear the string. Move the phone closer and play a little stronger.',
        'Teli duyamadım. Telefonu yaklaştır ve biraz daha güçlü çal.',
      ),
      SetupAudioPhase.failed => _failure(context, m.failure),
      _ => '',
    };
    return _card(context, [
      _body(
        localized(
          context,
          'First stay quiet for 2 seconds while I measure the room. Then play one open string.',
          'Önce 2 saniye sessiz kal; odanın sesini ölçüyorum. Sonra bir boş tel çal.',
        ),
      ),
      if (running || room != null) _meter(context),
      if (status.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            status,
            key: const Key('setup-room-status'),
            style: hankenText(size: 13.5, weight: FontWeight.w600),
          ),
        ),
      if (room != null && m.roomNoisy)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            localized(
              context,
              'The room is loud; a quieter place makes notes clearer.',
              'Oda gürültülü; daha sessiz bir yer notaları netleştirir.',
            ),
            style: hankenText(size: 12.5, color: palette.warnInk),
          ),
        ),
      if (room == null)
        _buttons(
          context,
          primary: localized(context, 'Measure', 'Ölç'),
          onPrimary: running
              ? null
              : () => unawaited(
                  m.measureRoom(
                    captureAction: practiceCaptureActionFor(context),
                  ),
                ),
        )
      else
        _buttons(
          context,
          primary: localized(context, 'Continue', 'Devam'),
          onPrimary: () => _next(skipped: false),
          secondary: localized(context, 'Measure again', 'Tekrar ölç'),
          onSecondary: () => unawaited(
            m.measureRoom(captureAction: practiceCaptureActionFor(context)),
          ),
          canSkip: false,
        ),
    ]);
  }

  String _routeName(BuildContext context, CalibrationRoute? r) => switch (r) {
    CalibrationRoute.speaker => localized(context, 'speaker', 'hoparlör'),
    CalibrationRoute.wiredHeadset => localized(
      context,
      'wired headphones',
      'kablolu kulaklık',
    ),
    CalibrationRoute.bluetooth => localized(context, 'Bluetooth', 'Bluetooth'),
    null => '—',
  };

  String _failure(BuildContext context, String? code) => switch (code) {
    'permission' => localized(
      context,
      'Microphone access is off. You can allow it in Settings.',
      'Mikrofon erişimi kapalı. Ayarlar’dan izin verebilirsin.',
    ),
    'no_clicks' => localized(
      context,
      'The clicks could not be played. Try again.',
      'Klikler çalınamadı. Tekrar dene.',
    ),
    'route_unknown' => localized(
      context,
      'I couldn’t tell which output this is, so the latency was not kept.',
      'Bu çıkışı tanıyamadım; gecikme kaydedilmedi.',
    ),
    _ => localized(
      context,
      'The microphone stopped (the input changed or another app took it). Start again.',
      'Mikrofon durdu (giriş değişti ya da başka bir uygulama aldı). Yeniden başlat.',
    ),
  };

  Widget _latency(BuildContext context) {
    final m = _measure;
    final running =
        m.phase == SetupAudioPhase.starting ||
        m.phase == SetupAudioPhase.clicking ||
        m.phase == SetupAudioPhase.analysing;
    final result = m.latency;
    final measured =
        result is LatencyMeasured && m.phase == SetupAudioPhase.done;
    final status = switch (m.phase) {
      SetupAudioPhase.starting || SetupAudioPhase.clicking => localized(
        context,
        'Playing 8 clicks — stay quiet…',
        '8 klik çalıyor — sessiz kal…',
      ),
      SetupAudioPhase.analysing => localized(
        context,
        'Calculating…',
        'Hesaplanıyor…',
      ),
      SetupAudioPhase.failed => _failure(context, m.failure),
      SetupAudioPhase.done => switch (result) {
        LatencyMeasured(:final latency) => localized(
          context,
          'Latency {v0} ms ({v1}). Timing is now shown on this output.',
          'Gecikme {v0} ms ({v1}). Zamanlama artık bu çıkışta gösterilir.',
          values: {
            'v0': (latency.roundTripUs / 1000).round(),
            'v1': _routeName(context, m.route),
          },
        ),
        LatencyNotHeard(:final heardClicks) => localized(
          context,
          'I heard {v0} of 8 clicks. Turn the volume up and try again.',
          '8 klikten {v0} tanesini duydum. Sesi aç ve tekrar dene.',
          values: {'v0': heardClicks},
        ),
        LatencyUnsteady() => localized(
          context,
          'The clicks arrived at different delays (echo or movement). Keep the phone still and try again.',
          'Klikler farklı gecikmelerle geldi (yankı ya da hareket). Telefonu sabit bırakıp tekrar dene.',
        ),
        null => '',
      },
      _ => '',
    };
    return _card(context, [
      _body(
        localized(
          context,
          'Leave the phone where it is. I play 8 clicks and measure when the microphone hears them. Stay quiet; no tapping or clapping needed.',
          'Telefonu yerinde bırak. 8 klik çalıp mikrofonun onları ne zaman duyduğunu ölçeceğim. Sessiz kal; dokunman ya da alkışlaman gerekmez.',
        ),
      ),
      const SizedBox(height: 6),
      _body(
        localized(
          context,
          'Volume up. If you will practise with headphones, put them on now: each output is measured on its own.',
          'Ses açık olsun. Kulaklıkla çalışacaksan şimdi tak: her çıkış ayrı ölçülür.',
        ),
      ),
      if (running) _meter(context),
      if (status.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            status,
            key: const Key('setup-latency-status'),
            style: hankenText(size: 13.5, weight: FontWeight.w600),
          ),
        ),
      if (measured)
        _buttons(
          context,
          primary: localized(context, 'Continue', 'Devam'),
          onPrimary: () => _next(skipped: false),
          secondary: localized(context, 'Measure again', 'Tekrar ölç'),
          onSecondary: () => unawaited(
            m.calibrateLatency(
              captureAction: practiceCaptureActionFor(context),
            ),
          ),
          canSkip: false,
        )
      else
        _buttons(
          context,
          primary: localized(context, 'Measure', 'Ölç'),
          onPrimary: running
              ? null
              : () => unawaited(
                  m.calibrateLatency(
                    captureAction: practiceCaptureActionFor(context),
                  ),
                ),
        ),
    ]);
  }

  Widget _tuningStep(BuildContext context) {
    final check = _tuning;
    final status = !_tuningAsked
        ? ''
        : check == null
        ? localized(context, 'No tuning measured.', 'Akort ölçülmedi.')
        : localized(
            context,
            'In tune: {v0} of {v1} strings',
            'Akortlu tel: {v1} telden {v0}',
            values: {'v0': check.inTune, 'v1': check.total},
          );
    return _card(context, [
      _body(
        localized(
          context,
          'Tune the strings ({v0}). The tuner marks each string once it is in tune.',
          'Telleri akort et ({v0}). Akort ekranı her teli akortlu olunca işaretler.',
          values: {'v0': uiText(context, widget.preset.name)},
        ),
      ),
      if (status.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            status,
            key: const Key('setup-tuning-status'),
            style: hankenText(size: 13.5, weight: FontWeight.w600),
          ),
        ),
      if (check == null)
        _buttons(
          context,
          primary: localized(context, 'Tune', 'Akort et'),
          onPrimary: () => unawaited(_tune()),
        )
      else
        _buttons(
          context,
          primary: localized(context, 'Continue', 'Devam'),
          onPrimary: () => _next(skipped: false),
          secondary: localized(context, 'Tune again', 'Yeniden akort et'),
          onSecondary: () => unawaited(_tune()),
          canSkip: false,
        ),
    ]);
  }

  Widget _summary(BuildContext context) => FutureBuilder<SetupProfile>(
    future: _store.load(),
    builder: (context, snap) {
      final p = snap.data ?? SetupProfile.empty;
      String state(SetupStepRecord? r) => r == null
          ? '—'
          : r.state == SetupStepState.done
          ? localized(context, 'done', 'yapıldı')
          : localized(context, 'skipped', 'atlandı');
      final routes = [
        for (final r in CalibrationRoute.values)
          if (p.latency[r] != null)
            '${_routeName(context, r)} ${(p.latency[r]!.roundTripUs / 1000).round()} ms',
      ];
      return _card(context, [
        for (final s in SetupStep.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '${_stepName(context, s)}: ${state(switch (s) {
                SetupStep.placement => p.placement,
                SetupStep.room => p.roomStep,
                SetupStep.latency => p.latencyStep,
                SetupStep.tuning => p.tuningStep,
              })}',
              style: hankenText(size: 13.5),
            ),
          ),
        if (routes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              localized(
                context,
                'Measured latency: {v0}',
                'Ölçülen gecikme: {v0}',
                values: {'v0': routes.join(' · ')},
              ),
              key: const Key('setup-summary-latency'),
              style: hankenText(size: 13),
            ),
          ),
        _buttons(
          context,
          primary: localized(context, 'Done', 'Bitti'),
          onPrimary: () => Navigator.of(context).maybePop(),
          canSkip: false,
        ),
      ]);
    },
  );
}
