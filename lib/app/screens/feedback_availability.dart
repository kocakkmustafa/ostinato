import 'package:flutter/material.dart';

import '../app_locale.dart';
import '../inference_manifest.dart';

/// A failed/incompatible activation root closes feedback while lessons remain
/// usable. The manifest does not turn illustrations into sensor observations.
class FeedbackAvailability extends StatefulWidget {
  const FeedbackAvailability({
    super.key,
    required this.instrumentId,
    this.manifest,
  });
  final String instrumentId;
  final Future<InferenceManifest> Function()? manifest;
  @override
  State<FeedbackAvailability> createState() => _FeedbackAvailabilityState();
}

class _FeedbackAvailabilityState extends State<FeedbackAvailability> {
  late final Future<InferenceManifest> _manifest =
      (widget.manifest ?? InferenceManifest.load)();

  @override
  Widget build(BuildContext context) => FutureBuilder<InferenceManifest>(
    future: _manifest,
    builder: (context, snapshot) {
      final capability = switch (widget.instrumentId) {
        'guitar' => 'guitar.singleNote',
        'piano' => 'piano.fingerKey',
        'voice' || 'vocal' => 'voice.pitch',
        'ukulele' => 'ukulele.singleNote',
        'bass' => 'bass.singleNote',
        _ => '',
      };
      final ready =
          snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError &&
          snapshot.hasData;
      final approximate =
          ready &&
          snapshot.data!.capability(capability) ==
              InferenceCapability.approximate;
      final message = !ready
          ? localized(
              context,
              'Automatic feedback is unavailable. You can still read lessons and keep your own practice record.',
              'Otomatik geri bildirim kullanılamıyor. Dersleri okuyabilir ve kendi çalışma kaydını tutabilirsin.',
            )
          : approximate
          ? localized(
              context,
              'Optional microphone practice can show approximate single-note observations. It does not approve notes, chords, fingering or mastery.',
              'İsteğe bağlı mikrofon çalışması yaklaşık tek nota gözlemi sunabilir. Nota, akor, parmak veya ustalık onayı vermez.',
            )
          : widget.instrumentId == 'piano'
          ? localized(
              context,
              'Finger–key observation is not supported. Hand tracking and keyboard calibration still need acceptance. Notation and practice tasks remain available.',
              'Parmak–tuş gözlemi desteklenmiyor. El takibi ve klavye kalibrasyonu kabulü bekleniyor. Nota ve çalışma görevleri kullanılabilir.',
            )
          : localized(
              context,
              'Automatic sound and technique feedback is not supported for this instrument. Demonstrations and calibration still need acceptance. Follow the lesson tasks and record your own observations.',
              'Bu çalgıda otomatik ses ve teknik geri bildirimi desteklenmiyor. Gösterim ve kalibrasyon kabulü bekleniyor. Ders görevlerini uygula ve kendi gözlemini kaydet.',
            );
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Semantics(
          container: true,
          child: Text(
            message,
            key: Key('feedback-availability-${widget.instrumentId}'),
          ),
        ),
      );
    },
  );
}
