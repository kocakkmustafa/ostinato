import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ostinato_posture/ostinato_posture.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;

import '../camera_pose_source.dart';
import '../camera_session.dart';
import '../account_connection.dart';
import '../app_locale.dart';
import '../app_theme.dart';
import '../content.dart';
import '../cue_text.dart';
import '../design/app_scope.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import '../session_store.dart';
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
  String? _accountUserId;
  PostureEvaluator? _evaluator;
  bool _contextReady = false;
  bool _routeRetired = false;
  StreamSubscription<SurfaceState>? _statusSubscription;
  StreamSubscription<PoseFrame>? _frameSubscription;
  Future<void>? _closeFuture;

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
    _accountUserId = AccountScope.maybeOf(context)?.currentUserId;

    final ContentRepositoryScope scope = ContentRepositoryScope.of(context);
    _contract = scope.contractOrNull(widget.discipline.id);
    _cueText = scope.cueText;
    _evaluator =
        _contract == null ? null : PostureEvaluator(contract: _contract);

    _statusSubscription = _source.status.listen((SurfaceState s) {
      if (!mounted || _routeRetired) return;
      final PoseSource source = _source;
      if (source is CameraPoseSource && !source.canObserveStatus) return;
      setState(() {
        _state = s;
        _cue = null;
      });
    });
    _frameSubscription = _source.frames.listen((PoseFrame f) {
      if (!mounted || _routeRetired) return;
      final PoseSource source = _source;
      if (source is CameraPoseSource && !source.canObserveFrames) return;
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
    observeCameraWork(_source.start());
  }

  bool get _cueVisible {
    if (_cue == null || _cueAt == null) return false;
    return DateTime.now().difference(_cueAt!) < _cueHold;
  }

  /// H-45 DÜZELTMESİ (2026-08-16, O-154 — `full_flow_test.dart` sabotajı
  /// yakaladı): navigasyon ÖNCE depo OKUMASINI bekliyordu — gerçek cihazda
  /// `getApplicationSupportDirectory()` hızlı döner ama `flutter test`te
  /// platform kanalı YOK, bu yüzden SONUÇ yüzeyi hiç doğmadı (widget testi
  /// "ReviewScreenRoute bulunamadı" diye çöktü — kod savunmasızdı, yalnız
  /// üretimde şanslıydı). Şimdi navigasyon SENKRON ve depo I/O'suna hiç
  /// bağlı değil; okuma+yazma arka planda sürer, sonucu `previousSession`
  /// Future'ı taşır — Review kendi `FutureBuilder`ıyla çözer.
  void _stop() {
    if (_routeRetired) return;
    observeCameraWork(_retireSource());
    final SessionSummary summary = SessionSummary(
      elapsedSeconds: _elapsed.elapsed.inSeconds,
      sampleCount: _sampleCount,
      outCount: _outCount,
      history: List<double>.of(_hist),
    );
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => ReviewScreenRoute(
        discipline: widget.discipline,
        lesson: widget.lesson,
        hue: widget.hue,
        summary: summary,
        previousSession: _readPreviousThenSave(summary),
      ),
    ));
  }

  /// D14 (2026-08-16, O-153): ÖNCE önceki kaydı OKU, SONRA bugünküyü YAZ —
  /// sıra kasıtlı, aksi hâlde "önceki oturum" bugünküyle YARIŞIR (yazma
  /// önce inerse Review kendi oturumunu "önceki" diye gösterebilirdi).
  /// Yazma kendisi kasıtlı unawaited: bu Future'ın çözülmesi yazmayı
  /// BEKLEMEZ, ama `.ignore()` yalnız "beklemiyorum" der, hatayı GİZLEMEZ —
  /// bir disk arızası burada sessiz kalır (kabul edilen sınır: sonuç yüzeyi
  /// zaten ÖLÇÜLEN kareden türer, yazma başarısız olsa bile kullanıcı
  /// SONUCU görür, yalnız GEÇMİŞE eklenmez). Bu Future'ın kendisi de
  /// hatayla biterse (ör. okuma çöker) `FutureBuilder` onu yakalar — geçmiş
  /// kartı çizilmez, uygulama çökmez.
  Future<PersistedSession?> _readPreviousThenSave(
      SessionSummary summary) async {
    final SessionStore store = SessionStore(accountUserId: _accountUserId);
    final PersistedSession? previous = await store.lastSession();
    store.save(PersistedSession.fromSummary(
      disciplineId: widget.discipline.id,
      lessonId: widget.lesson.id,
      summary: summary,
      completedAt: DateTime.now(),
    )).ignore();
    return previous;
  }

  @override
  void dispose() {
    observeCameraWork(_retireSource());
    _countdownTimer?.cancel();
    _cueClearTimer?.cancel();
    super.dispose();
  }

  Future<void> _retireSource() {
    if (_closeFuture != null) return _closeFuture!;
    _routeRetired = true;
    // CameraPoseSource.stop retires its real lease synchronously. Only then
    // cancel the two retained route listeners, before queued evaluation/UI work.
    final Future<void> sourceClose = _source.stop();
    final StreamSubscription<SurfaceState>? status = _statusSubscription;
    final StreamSubscription<PoseFrame>? frames = _frameSubscription;
    _statusSubscription = null;
    _frameSubscription = null;
    final Future<void> closing = Future.wait<void>(<Future<void>>[
      sourceClose,
      if (status != null) status.cancel(),
      if (frames != null) frames.cancel(),
    ]).then<void>((_) {});
    _closeFuture = closing;
    return closing;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OstinatoPalette.of(context).surface,
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
                  // `lesson.displayName` GERÇEK içerikte 34 karaktere kadar
                  // çıkıyor ("How much teachers actually differ") — Expanded
                  // olmadan sabit-genişlikli iki komşusu arasında RenderFlex
                  // taştı (375pt'te ölçüldü, test/real_content_overflow_test.dart).
                  Expanded(
                    child: Column(children: <Widget>[
                      Text(catalogName(context, widget.lesson.id, widget.lesson.displayName),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: hankenText(size: 13.5, weight: FontWeight.w500)),
                      const SizedBox(height: 3),
                      Text(_clock(), style: monoText()),
                    ]),
                  ),
                  const SizedBox(width: 48, height: 48),
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
    final p = OstinatoPalette.of(context);
    final hue = p.instrument(widget.discipline.id);
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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[p.surface, p.controlSurface],
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
                          hue: hue),
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
                        hue: hue,
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
              hue: hue,
            ),
          ),
        if (!_counting)
          OutlinedButton(
            onPressed: _stop,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              side: BorderSide(color: p.controlBorder),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
            child: Text(localized(context, 'Stop and see the summary', 'Durdur ve özeti gör'),
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
              color: OstinatoPalette.of(context).ink,
              markerColor: OstinatoPalette.of(context).outline,
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
                      '${localized(context, 'TEACHERS', 'EĞİTMENLER')} ${appDecimal(context, contract.bandLowDeg, 1)}–'
                      '${appDecimal(context, contract.bandHighDeg, 1)}° · '
                      'N=${contract.teacherCount}',
                      style: monoText(size: 9.5, letterSpacing: .09)),
                  Text('${appDecimal(context, state.trunkTiltDeg.abs(), 1)}°',
                      key: const Key('live-tilt-label'),
                      style: monoText(size: 15, color: OstinatoPalette.of(context).ink)),
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
              Text(localized(context, 'No score, and none is coming. The bar is the range; the mark is you.',
                  'Puan yok. Çubuk eğitmen aralığını, işaret seni gösterir.'),
                  style: hankenText(size: 11.5, color: OstinatoPalette.of(context).textMuted)),
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
                    Border.all(color: OstinatoPalette.of(context).outline, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text('?', style: hankenText(size: 20, color: OstinatoPalette.of(context).textFaint)),
            ),
            const SizedBox(height: 16),
            Text(localized(context, 'I can’t see you right now.', 'Şu anda seni göremiyoruz.'),
                style: hankenText(size: 21, weight: FontWeight.w500)),
            const SizedBox(height: 10),
            Text(
              localized(context,
                  'Landmark confidence is below the bar. I’m not judging this stretch — and I’m telling you rather than going quiet, because silence would read as "you’re doing fine".',
                  'Vücut noktaları yeterli güvenle okunmuyor. Bu bölümü değerlendirmiyoruz; sessiz kalmak yanlış bir güven verebilirdi.'),
              textAlign: TextAlign.center,
              style: hankenText(
                        size: 14.5, height: 1.55,
                        color: OstinatoPalette.of(context).textBody),
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
            kicker(localized(context, 'Observation', 'Gözlem'), color: hue.ink),
            const SizedBox(height: 8),
            Text(text,
                style: hankenText(size: 17, weight: FontWeight.w500, height: 1.35)),
            const SizedBox(height: 7),
            Text(
              localized(context,
                  'Not a correction — we have no teacher data on what you should do about it. Just what we measured.',
                  'Bu bir düzeltme önerisi değil. Ne yapman gerektiğine dair eğitmen verimiz yok; yalnızca ölçtüğümüzü gösteriyoruz.'),
              style: hankenText(size: 12.5, color: OstinatoPalette.of(context).textMuted),
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
        color: OstinatoPalette.of(context).controlSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OstinatoPalette.of(context).controlBorder),
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
                color: inBand ? OstinatoPalette.of(context).textMuted : hue.ink,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text ??
                  'You are inside the range the teachers occupy. Nothing '
                      'to report.',
              style: hankenText(size: 13, color: OstinatoPalette.of(context).inkSoft),
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
      Starting() => ("live-starting", localized(context, "Getting the camera ready", "Kamera hazırlanıyor"), localized(context, "This takes a moment. Nothing is being recorded.", "Bu kısa sürebilir. Hiçbir şey kaydedilmiyor."), null, null),
      PermissionDeniedRetriable() => ("live-permission-retriable", localized(context, "Camera access is off", "Kamera erişimi kapalı"), localized(context, "Ostinato needs the camera to see how you sit. Video never leaves your phone.", "Oturma duruşunu görebilmek için kamera erişimi gerekli. Video telefonundan çıkmaz."), localized(context, "Try again", "Tekrar dene"), onRetry),
      PermissionDeniedPermanent() => ("live-permission-permanent", localized(context, "Camera access is off", "Kamera erişimi kapalı"), localized(context, "The system will not ask again. Open Settings to change it. Video never leaves your phone.", "Sistem tekrar izin istemeyecek. Erişimi Ayarlar’dan açabilirsin. Video telefonundan çıkmaz."), localized(context, "Open Settings", "Ayarları aç"), openAppSettings),
      SetupFailed() => ("live-setup-failed", localized(context, "This lesson opened, but nothing is being measured", "Ders açıldı ancak ölçüm başlamadı"), localized(context, "The camera did not start. We are simply not analysing anything right now.", "Kamera açılamadı. Şu anda hiçbir şey analiz edilmiyor."), null, null),
      CameraUnavailable() => ("live-camera-unavailable", localized(context, "The camera did not open", "Kamera açılamadı"), localized(context, "We could not start a camera session.", "Kamera oturumu başlatılamadı."), null, null),
      _ => ("live-unknown", localized(context, "Nothing to show", "Gösterilecek bir şey yok"), '', null, null),
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
            Text(body, textAlign: TextAlign.center,
                style: hankenText(size: 14, color: OstinatoPalette.of(context).textBody)),
            if (action != null) ...<Widget>[
              const SizedBox(height: 18),
              FilledButton(
                key: const Key('notice-action'),
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: OstinatoPalette.of(context).primary,
                  foregroundColor: OstinatoPalette.of(context).onPrimary,
                ),
                child: Text(action),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
