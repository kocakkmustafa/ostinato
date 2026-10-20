import 'package:flutter/material.dart';

import '../app_locale.dart';
import '../piano/hand_source.dart';

class PianoHandSupportNotice extends StatelessWidget {
  const PianoHandSupportNotice({super.key});
  @override
  Widget build(BuildContext context) {
    // The shipping source has no native capture or replay selection path.
    final available =
        createProductionHandSource().identity.mode !=
        HandEvidenceMode.unavailable;
    return Text(
      available
          ? localized(context, "Hand observation requires an accepted keyboard and audio clock calibration. A contact candidate does not verify physical touch or mastery.", "El gözlemi için kabul edilmiş klavye ve ses saati kalibrasyonu gerekir. Temas adayı fiziksel temas veya ustalık onayı değildir.")
          : localized(context, "Hand tracking is unavailable. Follow the C4–G4 task yourself; the app does not verify finger–key contact. Keyboard and audio timing calibration need separate acceptance.", "El takibi kullanılamıyor. Do4–Sol4 görevini kendin uygula; uygulama parmak–tuş temasını doğrulamaz. Klavye ve ses zamanı kalibrasyonu ayrı kabul gerektirir."),
      key: const Key('piano-05-hand-support'),
    );
  }
}
