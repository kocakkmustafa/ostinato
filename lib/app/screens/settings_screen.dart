import 'package:flutter/material.dart';

import '../app_locale.dart';
import '../account_connection.dart';
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
// source-only: ekranda çocuk rejimine dair kullanıcı cümlesi YOK ve
// olmamalı — olmayan bir rejimi anlatmak onu varmış gibi gösterirdi.
// closedPaths: none-known
/// Canlı çalgı cümlesi — SAYI ve ADLAR `library.json`dan TÜRER.
/// Elle yazılmış bir "üç çalgı" cümlesi, dördüncüsü eklendiği gün sessizce
/// yanlış olur ve hiçbir test kırılmaz (O-068).
String _liveSentence(BuildContext context) {
  final List<Discipline> live = ContentRepositoryScope.of(
    context,
  ).repo.disciplines.where((Discipline d) => d.status == 'live').toList();
  if (Localizations.localeOf(context).languageCode == 'tr') {
    const names = <String, String>{
      'guitar': 'gitar',
      'voice': 'şan',
      'piano': 'piyano',
    };
    return 'Duruş kataloğunda ${live.length} çalgı ön izlemesi: '
        '${live.map((d) => names[d.id] ?? d.displayName).join(', ')}. '
        'Bu sürümde canlı kamera pratiği kapalıdır.';
  }
  const Map<int, String> words = <int, String>{
    1: 'One',
    2: 'Two',
    3: 'Three',
    4: 'Four',
    5: 'Five',
    6: 'Six',
  };
  final String n = words[live.length] ?? '${live.length}';
  final String names = live
      .map((Discipline d) => d.displayName.toLowerCase())
      .join(', ');
  final String noun = live.length == 1
      ? 'instrument preview'
      : 'instrument previews';
  return '$n $noun in the posture catalogue: $names. '
      'Live camera practice is closed in this release.';
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
                semanticLabel: localized(
                  context,
                  'Back to library',
                  'Kütüphaneye dön',
                ),
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 20),
              Text(
                localized(context, 'Settings', 'Ayarlar'),
                style: hankenText(
                  size: 28,
                  weight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 22),
              if (AccountScope.maybeOf(context)?.connection
                  case final AccountConnection account) ...<Widget>[
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: account.pageBuilder),
                  ),
                  icon: const Icon(Icons.person_outline),
                  label: Text(localized(context, 'Account', 'Hesap')),
                ),
                const SizedBox(height: 14),
              ],
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
              _SettingsCard(
                title: localized(context, 'Camera', 'Kamera'),
                // DÜZELTME (2026-08-07, O-054 — yayın envanteri): önceki
                // cümle "only the body angles we measure are kept" diyordu.
                // Ölçüldü: `lib/` içinde TEK dosya yazımı karşılama
                // işaretidir; HİÇBİR ölçüm saklanmıyor. Sonuç DOĞRUYDU
                // (video cihazdan çıkmıyor), GEREKÇE uydurmaydı — ve doğru
                // sonucu yanlış gerekçeyle söylemek en zor yakalanan hata,
                // çünkü kimse sonucu sorgulamıyor. Üstelik cümle bir
                // gizlilik İMTİYAZI kılığındaydı ("yalnız şunu tutuyoruz"),
                // yani kullanıcıya cihazında bir KAYIT olduğunu düşündürüyordu.
                // DÜZELTME-2 (O-099, 2026-08-12): 08-07'de bu cümlenin
                // SAKLAMA iddiası düzeltildi, ama yanındaki SAYI kaldı —
                // "nine upper-body points". Ölçüldü: canlı zincir
                // `specs:[trunkTilt]` = TEK açı, `required:LmRegion.torso`
                // = DÖRT landmark. Dokuz, `SkeletonFigurePainter`ın düğüm
                // sayısıydı: sayı gerçek, BİRİMİ yanlış. Aynı kartta iki
                // tur — bir iddiayı düzeltirken YANINDAKİNE bakılmamış.
                // D14 (2026-08-16, O-153): "nothing is stored"/"no history
                // here" DÜZELTİLDİ — artık bir özet-geçmiş var (Review
                // ekranı gösterir). Ham açı hâlâ saklanmıyor (korundu, doğru
                // kaldı); "silecek bir şey yok" yerine GERÇEK silme yolu
                // adıyla yazıldı (uygulamayı kaldırmak) — var olmayan bir
                // "sil" DÜĞMESİ İCAT EDİLMEDİ, iOS'un kendi mekanizması
                // anlatıldı.
                body: localized(
                  context,
                  'Live camera posture practice is closed in this release. '
                      'The guitar course works without a camera and keeps your '
                      'lesson progress and self-checks on this device. Existing '
                      'posture-session summaries also remain local. Uninstalling '
                      'the app removes its local records.',
                  'Bu sürümde canlı kamera duruş pratiği kapalıdır. Gitar kursu '
                      'kamera olmadan çalışır; ders ilerlemeniz ve öz denetimleriniz '
                      'bu cihazda kalır. Önceki duruş seansı özetleri de yereldir. '
                      'Uygulamayı kaldırmak yerel kayıtlarını siler.',
                ),
              ),
              const SizedBox(height: 14),
              _SettingsCard(
                title: localized(
                  context,
                  'Microphone — optional single-note observation',
                  'Mikrofon — isteğe bağlı tek nota gözlemi',
                ),
                body: localized(
                  context,
                  'The guitar learning path offers optional on-device single-note observation. '
                      'Permission is requested only after you press Start. Audio stays in temporary memory; '
                      'it is never recorded or uploaded. Stop, leaving the screen, changing account or '
                      'losing foreground closes capture. No chord, accuracy or mastery score is produced. '
                      'Physical phone accuracy has not been verified.',
                  'Gitar öğrenme yolunda isteğe bağlı cihaz üstü tek nota gözlemi vardır. '
                      'İzin yalnız Başlat düğmesine bastığınızda istenir. Ses geçici bellekte kalır; '
                      'kaydedilmez veya yüklenmez. Durdurma, ekrandan çıkış, hesap değişimi veya '
                      'ön plandan ayrılma yakalamayı kapatır. Akor, doğruluk veya ustalık puanı üretilmez. '
                      'Gerçek telefon doğruluğu doğrulanmadı.',
                ),
              ),
              const SizedBox(height: 14),
              _SettingsCard(
                title: localized(context, 'Sharing', 'Paylaşım'),
                body: localized(
                  context,
                  'Raw video is never stored on this device. It never leaves '
                      'this device. There is no setting that changes that.',
                  'Ham video bu cihazda saklanmaz ve cihazdan çıkmaz. '
                      'Bunu değiştiren bir ayar yoktur.',
                ),
              ),
              const SizedBox(height: 14),
              _SettingsCard(
                title: localized(
                  context,
                  'About this build',
                  'Bu sürüm hakkında',
                ),
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
                body: localized(
                  context,
                  '${_liveSentence(context)} '
                      'Every posture reference is built from teaching footage '
                      'filmed waist-up, which is why nothing below your hips '
                      'is read. Nothing here has been verified on real '
                      'hardware.',
                  '${_liveSentence(context)} Tüm duruş referansları belden '
                      'yukarı çekilmiş eğitim görüntülerine dayanır; bu yüzden '
                      'kalçanızın altı okunmaz. Buradaki işlevler gerçek '
                      'cihazda doğrulanmadı.',
                ),
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
        Text(
          body,
          style: hankenText(
            size: 13.5,
            height: 1.55,
            color: OstinatoColors.textBody,
          ),
        ),
      ],
    ),
  );
}
