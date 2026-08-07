import 'package:flutter/material.dart';

import '../content.dart';
import '../design/app_scope.dart';
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
/// Canlı çalgı cümlesi — SAYI ve ADLAR `library.json`dan TÜRER.
/// Elle yazılmış bir "üç çalgı" cümlesi, dördüncüsü eklendiği gün sessizce
/// yanlış olur ve hiçbir test kırılmaz (O-068).
String _liveSentence(BuildContext context) {
  final List<Discipline> live = ContentRepositoryScope.of(context)
      .repo
      .disciplines
      .where((Discipline d) => d.status == 'live')
      .toList();
  const Map<int, String> words = <int, String>{
    1: 'One', 2: 'Two', 3: 'Three', 4: 'Four', 5: 'Five', 6: 'Six',
  };
  final String n = words[live.length] ?? '${live.length}';
  final String names =
      live.map((Discipline d) => d.displayName.toLowerCase()).join(', ');
  final String verb = live.length == 1 ? 'instrument is' : 'instruments are';
  return '$n $verb live: $names.';
}

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
              // DÜZELTME (2026-08-07): tek kart "Camera and microphone"
              // deyip "the microphone reads level and pitch" diyordu — bu
              // build'de mikrofon giriş yolu YOK (`NSMicrophoneUsageDescription`
              // ve `RECORD_AUDIO` ikisi de yok, tek bir yakalama çağrısı da
              // yok). "Neither stream is uploaded" cümlesi VAR OLMAYAN bir
              // akış için güvence veriyordu; var olmayan bir riski güvenceye
              // almak, riski var gibi göstermenin sessiz hâli.
              //
              // İKİYE AYRILDI: yokluk, var olanın kartındaki bir yan cümle
              // değil KENDİ kartıdır (dürüst hâller birinci sınıf ekran).
              // Yan cümle hâlinde `validate_surface_honesty.py` de onu
              // göremiyordu — başlık "mikrofon" diyor, gerekçe gövdedeydi.
              const _SettingsCard(
                title: 'Camera',
                // DÜZELTME (2026-08-07, O-054 — yayın envanteri): önceki
                // cümle "only the body angles we measure are kept" diyordu.
                // Ölçüldü: `lib/` içinde TEK dosya yazımı karşılama
                // işaretidir; HİÇBİR ölçüm saklanmıyor. Sonuç DOĞRUYDU
                // (video cihazdan çıkmıyor), GEREKÇE uydurmaydı — ve doğru
                // sonucu yanlış gerekçeyle söylemek en zor yakalanan hata,
                // çünkü kimse sonucu sorgulamıyor. Üstelik cümle bir
                // gizlilik İMTİYAZI kılığındaydı ("yalnız şunu tutuyoruz"),
                // yani kullanıcıya cihazında bir KAYIT olduğunu düşündürüyordu.
                body: 'It runs on your phone and reads nine upper-body '
                    'points, and only inside a lesson. Nothing is uploaded '
                    'and nothing is stored: the angles exist while the '
                    'lesson is running and are gone when you leave it. '
                    'There is no history here to browse, and none to delete.',
              ),
              const SizedBox(height: 14),
              const _SettingsCard(
                title: 'Microphone — not wired in this build',
                body: 'No audio permission is requested and nothing you play '
                    'is captured. The chord and note-attack work the lessons '
                    'describe was measured on recordings, not in your room. '
                    'Until an input is wired, every judgement this app makes '
                    'comes from the camera.',
              ),
              const SizedBox(height: 14),
              const _SettingsCard(
                title: 'Sharing',
                body: 'Raw video never leaves this device. There is no '
                    'setting that changes that.',
              ),
              const SizedBox(height: 14),
              _SettingsCard(
                title: 'About this build',
                // DÜZELTME (koordinatör, 2026-08-07, M-F-186): "yet"
                // çıkarıldı — bir zaman taahhüdüydü, üstelik bu cümlenin
                // gerekçesi bile yoktu (en çıplak örnek). Kalan cümle
                // bugünün OLGUSUNU söylüyor.
                // TÜRETİLDİ (O-068, JabLab J-151): burada "Three instruments
                // are live: guitar, voice, piano" ELLE yazılıydı. Aynı sayıyı
                // karşılama ekranında `library.json`dan TÜRETMİŞTİM (O-039) ve
                // BU yüzeyi taramamıştım — *bir kusuru bulduğun yüzeyde
                // düzeltmek, onu ürünün geri kalanında düzeltmek değildir.*
                // Dördüncü çalgı canlıya geçtiği gün burası sessizce "Three"
                // demeye devam ederdi.
                body: '${_liveSentence(context)} '
                    'Every posture reference is built from teaching footage '
                    'filmed waist-up, which is why nothing below your hips '
                    'is read. Nothing here has been verified on real '
                    'hardware.',
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
