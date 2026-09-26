import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../account_connection.dart';
import '../app_locale.dart';
import '../audio/guitar_note_observation_controller.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';

/// Optional practice instrument; no target prompt, assessment or progress write.
class GuitarNoteObservationScreen extends StatefulWidget {
  const GuitarNoteObservationScreen({super.key, this.controller});
  final GuitarNoteObservationController? controller;
  @override
  State<GuitarNoteObservationScreen> createState() =>
      _GuitarNoteObservationScreenState();
}

class _GuitarNoteObservationScreenState
    extends State<GuitarNoteObservationScreen> {
  GuitarNoteObservationController? _controller;
  bool _loadingFailed = false, _accountInitialized = false;
  String? _accountId;
  @override
  void initState() {
    super.initState();
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
    if (mounted) setState(() {});
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = AccountScope.maybeOf(context)?.currentUserId;
    if (_accountInitialized && id != _accountId) unawaited(_controller?.stop());
    _accountInitialized = true;
    _accountId = id;
  }

  @override
  void dispose() {
    _controller?.removeListener(_changed);
    unawaited(_controller?.stop());
    if (widget.controller == null) _controller?.dispose();
    super.dispose();
  }

  String _message(
    BuildContext context,
    NoteObservationPhase phase,
  ) => switch (phase) {
    NoteObservationPhase.idle => localized(
      context,
      'Microphone is off. Start only when you want to observe.',
      'Mikrofon kapalı. Yalnız gözlem yapmak istediğinde başlat.',
    ),
    NoteObservationPhase.starting => localized(
      context,
      'Waiting for microphone permission and input…',
      'Mikrofon izni ve giriş bekleniyor…',
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
      'The microphone stopped or could not open. Return to the foreground and start again if you choose.',
      'Mikrofon durdu veya açılamadı. Ön plana döndüğünde istersen yeniden başlat.',
    ),
  };
  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final value = controller?.observation;
    final hue = InstrumentHues.guitar;
    final names = Localizations.localeOf(context).languageCode == 'tr'
        ? [
            'Do',
            'Do♯',
            'Re',
            'Re♯',
            'Mi',
            'Fa',
            'Fa♯',
            'Sol',
            'Sol♯',
            'La',
            'La♯',
            'Si',
          ]
        : ['C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B'];
    return Scaffold(
      backgroundColor: OstinatoColors.surface,
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
                  'Optional · one guitar string · a quiet room. Evaluated on isolated studio notes; real phone accuracy has not been verified. This is not a tuning or playing success decision.',
                  'İsteğe bağlı · tek gitar teli · sessiz oda. Ayrı stüdyo notalarında ölçüldü; gerçek telefon doğruluğu doğrulanmadı. Akort veya çalma başarısına karar vermez.',
                ),
                style: hankenText(size: 13, height: 1.5),
              ),
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
                          : '${names[value.midi % 12]}${value.midi ~/ 12 - 1}',
                      key: const Key('observed-note'),
                      style: hankenText(size: 42, weight: FontWeight.w600),
                    ),
                    if (value != null) ...[
                      Text(
                        '${value.hz.toStringAsFixed(1)} Hz',
                        style: monoText(color: hue.ink),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        localized(
                          context,
                          '${value.centsFromCenter >= 0 ? '+' : ''}${value.centsFromCenter.toStringAsFixed(0)} cents from nearest note center (A4 = 440 Hz)',
                          '${value.centsFromCenter >= 0 ? '+' : ''}${value.centsFromCenter.toStringAsFixed(0)} cent: en yakın nota merkezine göre (La4 = 440 Hz)',
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
                          : _message(context, controller.phase),
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
                            onPressed: () {
                              if (controller.isActive) {
                                unawaited(controller.stop());
                              } else {
                                unawaited(controller.start());
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
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                localized(
                  context,
                  'Audio stays in temporary memory on this device. It is never recorded or uploaded. Leaving this screen, changing account or losing the foreground closes capture; resuming does not restart it.',
                  'Ses bu cihazda geçici bellekte kalır; kaydedilmez veya yüklenmez. Ekrandan çıkış, hesap değişimi ve ön plandan ayrılma yakalamayı kapatır; geri dönüşte kendiliğinden başlamaz.',
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
                  color: OstinatoColors.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
