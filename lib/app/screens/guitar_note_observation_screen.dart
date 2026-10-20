import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../account_connection.dart';
import '../app_locale.dart';
import '../app_theme.dart';
import '../audio/audio_capture_channel.dart';
import '../audio/guitar_note_observation_controller.dart';
import '../audio/practice_audio_root.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import '../guitar_session_preparation.dart';

/// Optional practice instrument; no target prompt, assessment or progress write.
class GuitarNoteObservationScreen extends StatefulWidget {
  const GuitarNoteObservationScreen({
    super.key,
    this.controller,
    this.preparation,
  });
  final GuitarNoteObservationController? controller;
  final GuitarSessionPreparation? preparation;
  @override
  State<GuitarNoteObservationScreen> createState() =>
      _GuitarNoteObservationScreenState();
}

class _GuitarNoteObservationScreenState
    extends State<GuitarNoteObservationScreen> {
  late final GuitarSessionPreparation _preparation =
      widget.preparation ?? GuitarSessionPreparation();
  GuitarNoteObservationController? _controller;
  bool _loadingFailed = false, _accountInitialized = false;
  String? _accountId;
  @override
  void initState() {
    super.initState();
    _preparation.addListener(_preparationChanged);
    if (widget.controller != null) {
      _attach(widget.controller!);
    } else {
      GuitarObservationConfig.load().then(
        (config) {
          if (mounted) _attach(GuitarNoteObservationController(config: config));
        },
        onError: (Object _) {
          if (mounted) setState(() => _loadingFailed = true);
        },
      );
    }
  }

  void _attach(GuitarNoteObservationController controller) {
    _controller = controller;
    controller.addListener(_changed);
    if (!_preparation.isAcknowledged && controller.isActive) {
      unawaited(controller.stop());
    }
    if (mounted) setState(() {});
  }

  void _preparationChanged() {
    if (!_preparation.isAcknowledged && (_controller?.isActive ?? false)) {
      unawaited(_controller!.stop());
    }
    if (mounted) setState(() {});
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = AccountScope.maybeOf(context)?.currentUserId;
    if (_accountInitialized && id != _accountId) {
      unawaited(_controller?.stop());
      _preparation.afterBreak();
    }
    _accountInitialized = true;
    _accountId = id;
  }

  @override
  void dispose() {
    _preparation.removeListener(_preparationChanged);
    if (widget.preparation == null) _preparation.dispose();
    _controller?.removeListener(_changed);
    unawaited(_controller?.stop());
    if (widget.controller == null) _controller?.dispose();
    super.dispose();
  }

  String _message(
    BuildContext context,
    GuitarNoteObservationController controller,
  ) {
    if (!controller.isActive &&
        (controller.captureClosePending ||
            controller.captureClosePhase == AudioCaptureClosePhase.closing ||
            controller.captureClosePhase ==
                AudioCaptureClosePhase.unconfirmedInFlight)) {
      return localized(
        context,
        'Microphone close is still in progress or has no final receipt. Capture stays disabled. Refresh status without starting a new recording.',
        'Mikrofon kapatma işlemi sürüyor veya son makbuz gelmedi. Yakalama kapalı kalır. Yeni kayıt başlatmadan durumu yenile.',
      );
    }
    if (!controller.isActive &&
        controller.captureClosePhase == AudioCaptureClosePhase.running) {
      return controller.canRetryCaptureClose
          ? localized(
              context,
              'A previous microphone attempt still reports running. Request its closure before choosing a new start.',
              'Önceki mikrofon denemesi hâlâ çalışıyor görünüyor. Yeni başlatmayı seçmeden önce kapatılmasını iste.',
            )
          : localized(
              context,
              'Another microphone attempt still reports running. Wait or refresh its status; this screen cannot close that active attempt. If the device microphone indicator remains on, close the app.',
              'Başka bir mikrofon denemesi hâlâ çalışıyor görünüyor. Bekle veya durumunu yenile; bu ekran o etkin denemeyi kapatamaz. Cihazın mikrofon göstergesi açık kalırsa uygulamayı kapat.',
            );
    }
    if (!controller.isActive && controller.canRetryCaptureClose) {
      return localized(
        context,
        'Microphone closure needs an explicit retry. This action only requests closure; starting again is a separate choice after confirmation.',
        'Mikrofonu kapatmak için açık bir yeniden deneme gerekiyor. Bu işlem yalnız kapatmayı ister; doğrulama sonrası başlatma ayrı bir seçimdir.',
      );
    }
    if (!controller.isActive && !controller.captureGateReady) {
      return localized(
        context,
        'Microphone close status is unknown. Capture remains disabled until a native close readback is available.',
        'Mikrofonun kapanma durumu bilinmiyor. Native kapanma durumu doğrulanana kadar yakalama kapalı kalır.',
      );
    }
    if (controller.captureStopFailed) {
      return localized(
        context,
        'Microphone closure could not be confirmed. Observation cannot restart from this screen. Check the device microphone indicator; if it remains on, close the app. You can continue the course without audio.',
        'Mikrofonun kapatıldığı doğrulanamadı. Bu ekranda gözlem yeniden başlatılamaz. Cihazın mikrofon göstergesini denetle; açık kalırsa uygulamayı kapat. Kursa sessiz devam edebilirsin.',
      );
    }
    if (controller.isCaptureStopping) {
      return switch (controller.phase) {
        NoteObservationPhase.analysisTimedOut => localized(
          context,
          'Audio analysis did not finish in time. Stopping the microphone; closure has not been confirmed. This is a processing issue, not a playing result. You can continue the course while observation is unavailable.',
          'Ses analizi zamanında tamamlanmadı. Mikrofon durduruluyor; kapatıldığı doğrulanmadı. Bu bir işlem sorunu, çalma sonucu değil. Gözlem kullanılamazken kursa devam edebilirsin.',
        ),
        NoteObservationPhase.analysisSettling => localized(
          context,
          'Stopping the microphone while earlier audio analysis finishes; closure has not been confirmed. No playing result was produced. You can continue the course.',
          'Önceki ses analizi tamamlanırken mikrofon durduruluyor; kapatıldığı doğrulanmadı. Çalma sonucu üretilmedi. Kursa devam edebilirsin.',
        ),
        _ => localized(
          context,
          'Requesting microphone stop; closure has not been confirmed. Observation cannot restart while the stop request is pending.',
          'Mikrofonun durdurulması isteniyor; kapatıldığı doğrulanmadı. Durdurma isteği beklerken gözlem yeniden başlatılamaz.',
        ),
      };
    }
    return switch (controller.phase) {
      NoteObservationPhase.idle => localized(
        context,
        'Note observation is stopped. Start only when you want to observe.',
        'Nota gözlemi durdu. Yalnız gözlem yapmak istediğinde başlat.',
      ),
      NoteObservationPhase.starting => localized(
        context,
        'Waiting for microphone permission and input…',
        'Mikrofon izni ve giriş bekleniyor…',
      ),
      NoteObservationPhase.checkingInput => localized(
        context,
        'Checking the microphone input. If the built-in microphone cannot be identified, capture will stop.',
        'Mikrofon girişi denetleniyor. Dahili mikrofon belirlenemezse kayıt duracak.',
      ),
      NoteObservationPhase.calibrating => localized(
        context,
        'Keep the room quiet for two seconds; leave the strings silent.',
        'İki saniye odayı sessiz tut; telleri sessiz bırak.',
      ),
      NoteObservationPhase.listening => localized(
        context,
        'Play one string, let it settle, then damp it before the next note.',
        'Tek tel çal, sesin yerleşmesini bekle ve sonraki notadan önce sustur.',
      ),
      NoteObservationPhase.noResult => localized(
        context,
        'No clear single note. Damp other strings, stop accompaniment and try a steady tone.',
        'Belirgin tek nota yok. Diğer telleri sustur, eşliği kapat ve kararlı bir ses dene.',
      ),
      NoteObservationPhase.analysisTimedOut => localized(
        context,
        'Audio analysis did not finish in time. Note observation stopped and the app’s microphone stop request finished. If the device microphone indicator stays on, close the app. This is a processing issue, not a playing result. You can continue the course and retry when the control enables.',
        'Ses analizi zamanında tamamlanmadı. Nota gözlemi durdu ve uygulamanın mikrofon durdurma isteği tamamlandı. Cihazın mikrofon göstergesi açık kalırsa uygulamayı kapat. Bu bir işlem sorunu, çalma sonucu değil. Kursa devam edebilir, düğme kullanılabilir olduğunda yeniden deneyebilirsin.',
      ),
      NoteObservationPhase.analysisSettling => localized(
        context,
        'Note observation stopped and the app’s microphone stop request finished while earlier analysis settles. If the device microphone indicator stays on, close the app. No playing result was produced; you can continue the course.',
        'Önceki analiz tamamlanırken nota gözlemi durdu ve uygulamanın mikrofon durdurma isteği tamamlandı. Cihazın mikrofon göstergesi açık kalırsa uygulamayı kapat. Çalma sonucu üretilmedi; kursa devam edebilirsin.',
      ),
      NoteObservationPhase.permissionDenied => localized(
        context,
        'Microphone permission was declined. The course works without it; retry only if you choose.',
        'Mikrofon izni verilmedi. Kurs mikrofonsuz çalışır; istersen yeniden deneyebilirsin.',
      ),
      NoteObservationPhase.permissionDeniedPermanent => localized(
        context,
        'Microphone access is disabled in Settings. You can continue the course without it.',
        'Mikrofon erişimi Ayarlar’da kapalı. Kursa mikrofonsuz devam edebilirsin.',
      ),
      NoteObservationPhase.unsupportedInput => localized(
        context,
        'This observation supports the built-in microphone only. Change the input, stop and start again.',
        'Bu gözlem yalnız dahili mikrofonu destekler. Girişi değiştir, durdur ve yeniden başlat.',
      ),
      NoteObservationPhase.unavailable => localized(
        context,
        'Note observation stopped or could not open. Return to the foreground and retry if the control enables.',
        'Nota gözlemi durdu veya açılamadı. Ön plana döndüğünde düğme kullanılabiliyorsa yeniden dene.',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final value = controller?.observation;
    final p = OstinatoPalette.of(context);
    final hue = p.guitar;
    const names = [
      'C',
      'C♯',
      'D',
      'D♯',
      'E',
      'F',
      'F♯',
      'G',
      'G♯',
      'A',
      'A♯',
      'B',
    ];
    return Scaffold(
      backgroundColor: OstinatoPalette.of(context).surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassIconButton(
                icon: '‹',
                semanticLabel: localized(context, 'Back', 'Geri'),
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 20),
              Text(
                localized(
                  context,
                  'Approximate note observation',
                  'Yaklaşık nota gözlemi',
                ),
                style: hankenText(size: 27, weight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                localized(
                  context,
                  'Optional · one guitar string · a quiet room. Overlapping sounds can show a plausible but misleading note. Evaluated on isolated studio notes; real phone accuracy has not been verified. This does not decide tuning or playing success.',
                  'İsteğe bağlı · tek gitar teli · sessiz oda. Üst üste binen sesler inandırıcı ama yanıltıcı bir nota gösterebilir. Ayrı stüdyo notalarında ölçüldü; gerçek telefon doğruluğu doğrulanmadı. Akort veya çalma başarısına karar vermez.',
                ),
                style: hankenText(size: 13, height: 1.5),
              ),
              const SizedBox(height: 18),
              _sessionPreparationCard(context),
              const SizedBox(height: 18),
              GlassCard(
                gradientColors: hue.grad,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    kicker(
                      localized(
                        context,
                        'OBSERVED · APPROXIMATE',
                        'GÖZLENEN · YAKLAŞIK',
                      ),
                      color: hue.ink,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      value == null
                          ? '—'
                          : musicPitch(
                              context,
                              '${names[value.midi % 12]}${value.midi ~/ 12 - 1}',
                            ),
                      key: const Key('observed-note'),
                      style: hankenText(size: 42, weight: FontWeight.w600),
                    ),
                    if (value != null) ...[
                      Text(
                        '${appDecimal(context, value.hz, 1)} Hz',
                        style: monoText(color: hue.ink),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        localized(
                          context,
                          '{v0}{v1} cents from nearest note center (A4 = 440 Hz)',
                          '{v0}{v1} cent: en yakın nota merkezine göre (La4 = 440 Hz)',
                          values: {
                            'v0': value.centsFromCenter >= 0 ? '+' : '',
                            'v1': AppDecimal(value.centsFromCenter, 0),
                          },
                        ),
                        style: hankenText(size: 12.5, height: 1.5),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      _loadingFailed
                          ? localized(
                              context,
                              'Observation could not load. The course is still available.',
                              'Gözlem yüklenemedi. Kurs kullanılabilir.',
                            )
                          : controller == null
                          ? localized(context, 'Loading…', 'Yükleniyor…')
                          : _message(context, controller),
                      key: const Key('observation-status'),
                      style: hankenText(size: 13, height: 1.5),
                    ),
                    const SizedBox(height: 18),
                    if (controller != null)
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            key: const Key('observation-start-stop'),
                            onPressed: controller.isActive
                                ? () => unawaited(controller.stop())
                                : !_preparation.isAcknowledged ||
                                      !controller.canStart
                                ? null
                                : () {
                                    if (_preparation.isAcknowledged &&
                                        controller.canStart) {
                                      // Capture the top-route/account/native
                                      // context before permission can suspend.
                                      final action =
                                          PracticeAudioCaptureScope.actionFor(
                                            context,
                                          );
                                      unawaited(
                                        controller.start(captureAction: action),
                                      );
                                    }
                                  },
                            icon: Icon(
                              controller.isActive ? Icons.stop : Icons.mic_none,
                            ),
                            label: Text(
                              controller.isActive
                                  ? localized(
                                      context,
                                      'Stop microphone',
                                      'Mikrofonu durdur',
                                    )
                                  : localized(
                                      context,
                                      'Start with permission',
                                      'İzinle başlat',
                                    ),
                            ),
                          ),
                          if (controller.phase ==
                              NoteObservationPhase.permissionDeniedPermanent)
                            TextButton(
                              onPressed: openAppSettings,
                              child: Text(
                                localized(
                                  context,
                                  'Open Settings',
                                  'Ayarları aç',
                                ),
                              ),
                            ),
                          if (!controller.isActive &&
                              !controller.captureGateReady &&
                              !controller.canRetryCaptureClose)
                            TextButton(
                              key: const Key('observation-close-refresh'),
                              onPressed: () =>
                                  unawaited(controller.refreshCaptureStatus()),
                              child: Text(
                                localized(
                                  context,
                                  'Refresh microphone status',
                                  'Mikrofon durumunu yenile',
                                ),
                              ),
                            ),
                          if (!controller.isActive &&
                              controller.canRetryCaptureClose)
                            TextButton(
                              key: const Key('observation-close-retry'),
                              onPressed: () =>
                                  unawaited(controller.retryCaptureClose()),
                              child: Text(
                                controller.captureClosePhase ==
                                        AudioCaptureClosePhase.running
                                    ? localized(
                                        context,
                                        'Close previous microphone',
                                        'Önceki mikrofonu kapat',
                                      )
                                    : localized(
                                        context,
                                        'Retry microphone close',
                                        'Mikrofonu kapatmayı yeniden dene',
                                      ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                localized(
                  context,
                  'Audio stays in temporary memory on this device. It is never recorded or uploaded. Leaving this screen, changing account or losing the foreground stops observation and requests microphone closure; resuming does not restart it. If the device microphone indicator stays on, close the app.',
                  'Ses bu cihazda geçici bellekte kalır; kaydedilmez veya yüklenmez. Ekrandan çıkış, hesap değişimi ve ön plandan ayrılma gözlemi durdurur ve mikrofonun kapatılmasını ister; geri dönüşte kendiliğinden başlamaz. Cihazın mikrofon göstergesi açık kalırsa uygulamayı kapat.',
                ),
                style: hankenText(size: 12.5, height: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                localized(
                  context,
                  'No chord, timing, loudness, correctness or mastery score is produced. Overlapping notes can still resemble one harmonic family; do not use this display to judge a chord. The course can be completed without the microphone.',
                  'Akor, zamanlama, ses yüksekliği, doğruluk veya ustalık puanı üretilmez. Üst üste notalar bazen tek armonik aileye benzeyebilir; bu gösterimle akor değerlendirme. Kurs mikrofonsuz tamamlanabilir.',
                ),
                style: hankenText(
                  size: 12.5,
                  color: OstinatoPalette.of(context).textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sessionPreparationCard(BuildContext context) => GlassCard(
    key: const Key('note-session-preparation'),
    gradientColors: OstinatoPalette.of(context).guitar.grad,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        kicker(
          localized(context, 'BEFORE PLAYING TODAY', 'BUGÜN ÇALMADAN ÖNCE'),
          color: OstinatoPalette.of(context).guitar.ink,
        ),
        const SizedBox(height: 9),
        Text(
          localized(
            context,
            'Support the guitar so both hands can release. If tuning is needed, check string letters and octaves with an external tuner; do not force a peg. Begin with a few easy open-string plucks and full hand release.',
            'Gitarı iki elin de gevşeyebileceği şekilde destekle. Akort gerekiyorsa tel adlarını ve oktavları harici akort cihazıyla denetle; burguyu zorlama. Birkaç kolay açık tel sesi ve tam el gevşetmesiyle başla.',
          ),
          style: hankenText(size: 13, height: 1.5),
        ),
        const SizedBox(height: 8),
        Text(
          localized(
            context,
            'Pause for hand, neck, shoulder or hearing discomfort or tingling. This is your own check, not an app verdict about safety, posture or tuning. You can read this screen without starting the microphone.',
            'El, boyun, omuz veya işitme rahatsızlığı ya da karıncalanmada ara ver. Bu senin denetimin; uygulamanın güvenlik, duruş veya akort hükmü değil. Mikrofonu açmadan bu ekranı okuyabilirsin.',
          ),
          style: hankenText(size: 12.5, height: 1.5),
        ),
        const SizedBox(height: 10),
        if (!_preparation.isAcknowledged)
          FilledButton(
            key: const Key('note-session-acknowledge'),
            onPressed: _preparation.acknowledge,
            child: Text(
              localized(
                context,
                'I checked this and may practise',
                'Denetledim, çalışabilirim',
              ),
            ),
          )
        else
          TextButton(
            key: const Key('note-session-after-break'),
            onPressed: _preparation.afterBreak,
            child: Text(
              localized(
                context,
                'After a break: prepare again',
                'Aradan sonra: yeniden hazırlan',
              ),
            ),
          ),
      ],
    ),
  );
}
