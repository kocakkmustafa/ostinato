import 'package:flutter/material.dart';

import '../design/ostinato_theme.dart';
import '../design/widgets.dart';

/// Ayarlar — statik dürüstlük beyanları. Çocuk rejimi BİLEREK YOK:
/// kurucu kararı gelmedi, tasarım paneli de bunu KASITLI kapsam-dışı
/// bıraktı (§17 "sorulursa koordinatöre gelir" — burada icat edilmedi).
// PLACEHOLDER(flow): çocuk rejimi (ayrı akış/izin/UI) bu ekranda YOK —
// unblocked by: kurucu ürün kararı (tasarlanıp tasarlanmayacağı bile
// henüz KARARLAŞTIRILMADI, bu yüzden burada bir toggle/iskele de YOK —
// var olmayan bir karara sahte bir yer tutucu inşa etmek kendisi bir
// taklit olurdu).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OstinatoColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              GlassIconButton(
                  icon: '‹',
                  semanticLabel: 'Back to library',
                  onTap: () => Navigator.of(context).pop()),
              const SizedBox(height: 20),
              Text('Settings',
                  style: hankenText(
                      size: 28, weight: FontWeight.w600, height: 1.1)),
              const SizedBox(height: 22),
              const _SettingsCard(
                title: 'Camera and microphone',
                body: 'Both run on your phone. The camera reads nine '
                    'upper-body points; the microphone reads level and '
                    'pitch. Neither stream is uploaded, and neither runs '
                    'outside a lesson.',
              ),
              const SizedBox(height: 14),
              const _SettingsCard(
                title: 'Sharing',
                body: 'Raw video never leaves this device. There is no '
                    'setting that changes that.',
              ),
              const SizedBox(height: 14),
              const _SettingsCard(
                title: 'About this build',
                body: 'Three instruments are live: guitar, voice, piano. '
                    'Every posture reference is built from teaching footage '
                    'filmed waist-up, which is why nothing below your hips '
                    'is read. Nothing here has been verified on real '
                    'hardware yet.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .62),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: .75)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            kicker(title),
            const SizedBox(height: 10),
            Text(body,
                style: hankenText(size: 13.5, height: 1.55, color: OstinatoColors.textBody)),
          ],
        ),
      );
}
