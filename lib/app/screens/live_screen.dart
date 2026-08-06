import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ostinato_posture/ostinato_posture.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;

import '../camera_pose_source.dart';
import '../content.dart';
import '../cue_text.dart';
import '../design/app_scope.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import 'review_screen.dart';

/// Gözlem işareti görünürlük tedavisi — ikisi de gerçek, ikisi de canlı.
///
/// DEĞER (hangisi ÜRETİMDE varsayılan) koordinatörde kalır (§8: "gözlem
/// işaretinin görünürlük DEĞERİ dahil — görsel öneri sende, değer bende").
/// Bu enum'un varlığı bir öneri: A ("nadir, güçlü" — tur-1/2'nin tek panel
/// deseninin doğal devamı) şimdilik varsayılan, B tek satırlık değişiklikle
/// açılabilir.
enum CueTreatment { rare, ambient }

const CueTreatment _defaultCueTreatment = CueTreatment.rare;

/// Canlı ölçüm oturumu — bant + gözlem işareti + "hüküm yok" dürüstlüğü.
///
/// Tur-1/tur-2'nin kanıtlı zinciri (PoseSource → PostureEvaluator →
/// SurfaceState) DEĞİŞMEDİ, yalnız yüzey giydirildi + geri sayım/oturum
/// geçmişi eklendi (Review ekranının ihtiyacı).
class LiveScreenRoute extends StatefulWidget {
  const LiveScreenRoute({
    super.key,
    required this.discipline,
    required this.lesson,
    required this.hue,
    this.source,
    this.skipCountdown = false,
  });
  final Discipline discipline;
  final Lesson lesson;
  final InstrumentHue hue;

  /// Testlerin/harness'ın kendi kaynağını vermesi için — üretimde null
  /// (`CameraPoseSource` kurulur). Gravita `LiveSessionScreen` deseniyle
  /// AYNI: sahte kaynak yalnız test-zerkinde yaşar, üretim yolunda hiç
  /// görünmez (tasarımda "kaynak banner"ı YOK — bu turda kaldırıldı).
  final PoseSource? source;

  /// Testler 3-2-1 geri sayımı beklemeden ölçüme geçer.
  final bool skipCountdown;

  @override
  State<LiveScreenRoute> createState() => _LiveScreenRouteState();
}

class _LiveScreenRouteState extends State<LiveScreenRoute> {
  late final PoseSource _source = widget.source ?? CameraPoseSource();

  // `ContentRepositoryScope.of(context)` initState()'te GÜVENLİ DEĞİL —
  // Flutter'ın kendi kuralı: InheritedWidget bağımlılığı build() ya da
  // didChangeDependencies()'te kurulur, aksi hâlde ikinci rebuild'de
  // "dependOnInheritedElement() was called before initState() completed"
  // fırlatır (widget testinde ölçüldü). Bu yüzden context-bağımlı kurulum
  // didChangeDependencies()'e taşındı, TEK SEFERLİK bayrakla korunuyor.
  late final PostureContract? _contract;
  late final CueTextResolver _cueText;
  PostureEvaluator? _evaluator;
  bool _contextReady = false;

  /// İşaretin YÜKÜ tutulur, METNİ değil — her karede GÜNCEL ölçümle yeniden
  /// çözülür (O-034 dersi: sayı başlıkla senkron kalmalı, aksi hâlde ekranda
  /// çelişen iki sayı belirir). Motor kullanıcı metni ÜRETMEZ — cümle
  /// yalnız burada, golden katalogdan (`CueTextResolver`) doldurulur.
  String? _cueTextFor(double currentTiltDeg) {
    final ObservationCue? c = _cue;
    if (c == null) return null;
    return _cueText.resolve(ObservationCue(
      templateId: c.templateId,
      teacherCount: c.teacherCount,
      sourceClass: c.sourceClass,
      thresholdDeg: c.thresholdDeg,
      measuredDeg: currentTiltDeg,
    ));
  }

  SurfaceState _state = const Starting();
  ObservationCue? _cue;
  DateTime? _cueAt;
  Timer? _cueClearTimer;
  static const Duration _cueHold = Duration(seconds: 4);

  int _countdown = 3;
  Timer? _countdownTimer;
  late bool _counting = !widget.skipCountdown;

  final List<double> _hist = <double>[];
  int _outCount = 0;
  int _sampleCount = 0;
  final Stopwatch _elapsed = Stopwatch();

  @override
  void initState() {
    super.initState();
    // Yalnız context-BAĞIMSIZ kurulum burada. Kaynak dinleyicileri +
    // evaluator, `_contract`/`_cueText` context'ten geldiği için
    // didChangeDependencies()'e taşındı.
    if (widget.skipCountdown) {
      _elapsed.start();
    } else {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
        if (!mounted) return;
        setState(() {
          _countdown--;
          if (_countdown <= 0) {
            _counting = false;
            _elapsed.start();
            t.cancel();
          }
        });
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_contextReady) return;
    _contextReady = true;

    final ContentRepositoryScope scope = ContentRepositoryScope.of(context);
    _contract = scope.contractOrNull(widget.discipline.id);
    _cueText = scope.cueText;
    _evaluator =
        _contract == null ? null : PostureEvaluator(contract: _contract);

    _source.status.listen((SurfaceState s) {
      if (!mounted) return;
      setState(() {
        _state = s;
        _cue = null;
      });
    });
    _source.frames.listen((PoseFrame f) {
      final PostureEvaluator? ev = _evaluator;
      if (ev == null) return;
      final SurfaceState s = ev.evaluate(f);
      if (!mounted) return;
      setState(() {
        _state = s;
        if (s is Measuring) {
          _sampleCount++;
          if (!s.inBand) _outCount++;
          _hist.add(s.trunkTiltDeg);
          if (_hist.length > 240) _hist.removeAt(0);
          if (s.cue != null) {
            _cue = s.cue;
            _cueAt = DateTime.now();
            _cueClearTimer?.cancel();
            _cueClearTimer = Timer(_cueHold, () {
              if (mounted) setState(() {});
            });
          } else if (s.inBand) {
            _cue = null;
          }
        } else {
          _cue = null;
        }
      });
    });
    _source.start();
  }

  bool get _cueVisible {
    if (_cue == null || _cueAt == null) return false;
    return DateTime.now().difference(_cueAt!) < _cueHold;
  }

  void _stop() {
    _source.stop();
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => ReviewScreenRoute(
        discipline: widget.discipline,
        lesson: widget.lesson,
        hue: widget.hue,
        summary: SessionSummary(
          elapsedSeconds: _elapsed.elapsed.inSeconds,
          sampleCount: _sampleCount,
          outCount: _outCount,
          history: List<double>.of(_hist),
        ),
      ),
    ));
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cueClearTimer?.cancel();
    _source.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OstinatoColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  GlassIconButton(
                      icon: '✕',
                      semanticLabel: 'Stop session',
                      onTap: _stop),
                  Column(children: <Widget>[
                    Text(widget.lesson.displayName,
                        style: hankenText(size: 13.5, weight: FontWeight.w500)),
                    const SizedBox(height: 3),
                    Text(_clock(), style: monoText()),
                  ]),
                  const SizedBox(width: 38, height: 38),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: _body(context)),
            ],
          ),
        ),
      ),
    );
  }

  String _clock() {
    final int s = _elapsed.elapsed.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:'
        '${(s % 60).toString().padLeft(2, '0')}';
  }

  Widget _body(BuildContext context) {
    if (_state is PermissionDeniedRetriable ||
        _state is PermissionDeniedPermanent ||
        _state is SetupFailed ||
        _state is CameraUnavailable ||
        _state is Starting) {
      return _NoticeCard(state: _state, onRetry: () => _source.start());
    }
    if (_contract == null) {
      return _NoticeCard(
          state: const SetupFailed('no-contract-for-discipline'),
          onRetry: () {});
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFFF9F7FB), Color(0xFFF1ECF6)],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  if (_counting)
                    Text('$_countdown',
                        key: const Key('live-countdown'),
                        style: hankenText(size: 96, weight: FontWeight.w500))
                  else if (_state is NoPersonVisible)
                    const _BlindNotice()
                  else if (_state is Measuring)
                    KeyedSubtree(
                      key: const Key('live-measuring'),
                      child: _MeasuringFigure(
                          state: _state as Measuring,
                          contract: _contract,
                          hue: widget.hue),
                    ),
                  if (!_counting &&
                      _cueVisible &&
                      _defaultCueTreatment == CueTreatment.rare &&
                      _state is Measuring)
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 16,
                      child: _CueAPanel(
                        text: _cueTextFor((_state as Measuring).trunkTiltDeg)!,
                        hue: widget.hue,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (!_counting &&
            _defaultCueTreatment == CueTreatment.ambient &&
            _state is Measuring)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CueBLine(
              inBand: (_state as Measuring).inBand,
              // B: kesintisiz, cooldown'suz (tasarımın kendi şartı — "no
              // cooldown, no entrance"). Cümle YİNE golden katalogdan.
              text: (_state as Measuring).inBand
                  ? null
                  : _cueText.resolve(ObservationCue(
                      templateId: _contract.cueTemplateId,
                      teacherCount: _contract.teacherCount,
                      sourceClass: _contract.sourceClass,
                      thresholdDeg: _contract.cueThresholdDeg,
                      measuredDeg: (_state as Measuring).trunkTiltDeg.abs(),
                    )),
              hue: widget.hue,
            ),
          ),
        if (!_counting)
          OutlinedButton(
            onPressed: _stop,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: Color(0x282A2533)),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
            child: Text('Stop and see the summary',
                style: hankenText(size: 15, weight: FontWeight.w500)),
          ),
      ],
    );
  }
}

class _MeasuringFigure extends StatelessWidget {
  const _MeasuringFigure(
      {required this.state, required this.contract, required this.hue});
  final Measuring state;
  final PostureContract contract;
  final InstrumentHue hue;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 220,
          height: 236,
          child: CustomPaint(
            painter: SkeletonFigurePainter(
              tiltDeg: state.trunkTiltDeg.clamp(-30, 30),
              bandLowDeg: contract.bandLowDeg,
              bandHighDeg: contract.bandHighDeg,
              bandColor: hue.band,
              markerDeg: contract.cueThresholdDeg,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                      'TEACHERS ${contract.bandLowDeg.toStringAsFixed(1)}–'
                      '${contract.bandHighDeg.toStringAsFixed(1)}° · '
                      'N=${contract.teacherCount}',
                      style: monoText(size: 9.5, letterSpacing: .09)),
                  Text('${state.trunkTiltDeg.abs().toStringAsFixed(1)}°',
                      key: const Key('live-tilt-label'),
                      style: monoText(size: 15, color: OstinatoColors.ink)),
                ],
              ),
              const SizedBox(height: 8),
              HorizontalBandTrack(
                lowDeg: contract.bandLowDeg,
                highDeg: contract.bandHighDeg,
                maxDeg: 24,
                youDeg: state.trunkTiltDeg.abs(),
                color: hue.ink,
              ),
              const SizedBox(height: 8),
              Text('No score, and none is coming. The bar is the range; '
                  'the mark is you.',
                  style: hankenText(size: 11.5, color: OstinatoColors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _BlindNotice extends StatelessWidget {
  const _BlindNotice();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          key: const Key('live-blind'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: const Color(0x4D2A2533), width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text('?', style: hankenText(size: 20, color: OstinatoColors.textFaint)),
            ),
            const SizedBox(height: 16),
            Text('I can’t see you right now.',
                style: hankenText(size: 21, weight: FontWeight.w500)),
            const SizedBox(height: 10),
            Text(
              'Landmark confidence is below the bar. I’m not judging this '
              'stretch — and I’m telling you rather than going quiet, '
              'because silence would read as "you’re doing fine".',
              textAlign: TextAlign.center,
              style: hankenText(size: 14.5, height: 1.55, color: const Color(0xFF5C5569)),
            ),
          ],
        ),
      );
}

/// Treatment A — nadir, güçlü: tam panel, [text] `CueTextResolver`den
/// GELMİŞ olmak ZORUNDA (motor kullanıcı metni üretmez, M-F-232 şart 2).
class _CueAPanel extends StatelessWidget {
  const _CueAPanel({required this.text, required this.hue});
  final String text;
  final InstrumentHue hue;

  @override
  Widget build(BuildContext context) => GlassCard(
        key: const Key('observation-cue'),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            kicker('Observation', color: hue.ink),
            const SizedBox(height: 8),
            Text(text,
                style: hankenText(size: 17, weight: FontWeight.w500, height: 1.35)),
            const SizedBox(height: 7),
            Text(
              'Not a correction — we have no teacher data on what you '
              'should do about it. Just what we measured.',
              style: hankenText(size: 12.5, color: OstinatoColors.textMuted),
            ),
          ],
        ),
      );
}

/// Treatment B — daima orada, sessiz: [text] null ise bant-içi DURUM
/// cümlesi gösterilir (bu bir `ObservationCue` DEĞİL, mevcut `posture_
/// screen.dart`'ın "Within the range" durum metniyle aynı sınıf — motor
/// metni değil, UI durum metni). [text] doluysa YİNE `CueTextResolver`den
/// gelir; tasarımın kendi şartı gereği (§ "no cooldown, no entrance")
/// evaluator'ın cooldown'lu `cue` alanını BEKLEMEZ, ama cümle yine golden
/// katalogdan doldurulur.
class _CueBLine extends StatelessWidget {
  const _CueBLine({required this.inBand, required this.text, required this.hue});
  final bool inBand;
  final String? text;
  final InstrumentHue hue;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('observation-cue'),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .78)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: inBand ? const Color(0x282A2533) : hue.ink,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text ??
                  'You are inside the range the teachers occupy. Nothing '
                      'to report.',
              style: hankenText(size: 13, color: OstinatoColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.state, required this.onRetry});
  final SurfaceState state;

  /// `PermissionDeniedRetriable` için — kaynağı yeniden `start()` eder.
  /// Kalıcı redde bu düğme hiç GÖSTERİLMEZ (sistem bir daha sormaz,
  /// "tekrar dene" işlevsiz bir düğme olurdu — var olan aile kuralı).
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (String key, String title, String body, String? action, VoidCallback? onAction) =
        switch (state) {
      Starting() => ('live-starting', 'Getting the camera ready',
          'This takes a moment. Nothing is being recorded.', null, null),
      PermissionDeniedRetriable() => (
          'live-permission-retriable',
          'Camera access is off',
          'Ostinato needs the camera to see how you sit. Video never '
              'leaves your phone.',
          'Try again',
          onRetry,
        ),
      PermissionDeniedPermanent() => (
          'live-permission-permanent',
          'Camera access is off',
          'The system will not ask again. Open Settings to change it. '
              'Video never leaves your phone.',
          'Open Settings',
          openAppSettings,
        ),
      SetupFailed(:final String reason) => ('live-setup-failed',
          'This lesson opened, but nothing is being measured',
          'The camera did not start ($reason). We are simply not '
              'analysing anything right now.', null, null),
      CameraUnavailable(:final String reason) => ('live-camera-unavailable',
          'The camera did not open',
          'We could not start a camera session ($reason).', null, null),
      _ => ('live-unknown', 'Nothing to show', '', null, null),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          key: Key(key),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(title, style: hankenText(size: 19, weight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: hankenText(size: 14, color: OstinatoColors.textBody)),
            if (action != null) ...<Widget>[
              const SizedBox(height: 18),
              FilledButton(
                key: const Key('notice-action'),
                onPressed: onAction,
                style: FilledButton.styleFrom(backgroundColor: OstinatoColors.ink),
                child: Text(action),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
