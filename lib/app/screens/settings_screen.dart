import '../app_appearance_picker.dart';
import '../app_theme.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../app_locale.dart';
import '../app_locale_preferences.dart';
import '../app_translation_catalog.dart' show supportedLanguageTags;
import '../account_connection.dart';
import '../design/app_scope.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import '../practice/display/practice_display_copy.dart';
import '../practice/display/practice_display_preferences.dart';
import '../practice/own_recording/own_recording_copy.dart';
import '../practice/own_recording/own_recording_preference.dart';
import '../ui_copy.dart';

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
  final live = ContentRepositoryScope.of(context).repo.disciplines
      .where((discipline) => discipline.status == 'live')
      .toList();
  final names = live
      .map(
        (discipline) =>
            catalogName(context, discipline.id, discipline.displayName),
      )
      .join(', ');
  return localized(
    context,
    "{v0} instrument previews in the posture catalogue: {v1}. Live camera practice is closed in this release.",
    "Duruş kataloğunda {v0} çalgı ön izlemesi: {v1}. Bu sürümde canlı kamera pratiği kapalıdır.",
    values: {"v0": live.length, "v1": names},
    pluralCount: live.length,
  );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    this.ownRecordingPreference,
    this.practiceDisplay,
  });

  /// FK2 setting store; defaults to the device file.
  final OwnRecordingPreference? ownRecordingPreference;

  /// FK4 settings; defaults to the app's [PracticeDisplayScope].
  final PracticeDisplayController? practiceDisplay;

  @override
  Widget build(BuildContext context) {
    final localeController = AppLocaleScope.maybeOf(context);
    final display = practiceDisplay ?? PracticeDisplayScope.maybeOf(context);
    return Scaffold(
      backgroundColor: OstinatoPalette.of(context).surface,
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
              const AppAppearancePicker(),
              const SizedBox(height: 14),
              if (localeController != null) ...<Widget>[
                _LanguageSettings(controller: localeController),
                const SizedBox(height: 14),
              ],
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
              OwnRecordingSettingCard(
                preference:
                    ownRecordingPreference ??
                    const FileOwnRecordingPreference(),
              ),
              const SizedBox(height: 14),
              if (display != null) ...<Widget>[
                PracticeDisplaySettingCard(controller: display),
                const SizedBox(height: 14),
              ],
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
                  "{v0} Every posture reference is built from teaching footage filmed waist-up, which is why nothing below your hips is read. Nothing here has been verified on real hardware.",
                  "{v0} Tüm duruş referansları belden yukarı çekilmiş eğitim görüntülerine dayanır; bu yüzden kalçanızın altı okunmaz. Buradaki işlevler gerçek cihazda doğrulanmadı.",
                  values: {"v0": _liveSentence(context)},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Stable language identifiers and their own-language names are selector
// metadata, not account or course state. System selection persists null.
class _LanguageSettings extends StatelessWidget {
  const _LanguageSettings({required this.controller});
  final AppLocaleController controller;

  static const _system = 'system';
  static const _names = <String, String>{
    'tr': 'Türkçe',
    'en': 'English',
    'es-419': 'Español (Latinoamérica)',
    'pt-BR': 'Português (Brasil)',
    'de': 'Deutsch',
    'fr': 'Français',
    'ja': '日本語',
    'ar': 'العربية',
    'it': 'Italiano',
    'ko': '한국어',
    'id': 'Bahasa Indonesia',
    'pl': 'Polski',
    'hi': 'हिन्दी',
    'zh-Hans': '简体中文',
  };

  @override
  Widget build(BuildContext context) => GlassCard(
    key: const Key('app-language-settings'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        kicker(localized(context, "Language", "Dil")),
        const SizedBox(height: 10),
        Semantics(
          label: localized(context, "Language", "Dil"),
          child: DropdownButton<String>(
            key: const Key('app-language-select'),
            isExpanded: true,
            itemHeight: null,
            value: controller.languageTag ?? _system,
            items: [
              DropdownMenuItem(
                key: const Key('app-language-option-system'),
                value: _system,
                child: Text(
                  localized(
                    context,
                    "Use device language",
                    "Cihaz dilini kullan",
                  ),
                ),
              ),
              for (final tag in supportedLanguageTags)
                DropdownMenuItem(
                  key: ValueKey('app-language-option-$tag'),
                  value: tag,
                  child: Text(_names[tag] ?? tag),
                ),
            ],
            onChanged: (tag) {
              if (tag == null) return;
              unawaited(controller.select(tag == _system ? null : tag));
            },
          ),
        ),
        if (controller.loading) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              localized(
                context,
                "Reading saved language…",
                "Kayıtlı dil okunuyor…",
              ),
              key: const Key("app-language-loading"),
              style: hankenText(size: 12.5, height: 1.5),
            ),
          ),
        ],
        if (controller.readFailed) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              localized(
                context,
                "The saved language could not be read. Device language is being used. Choose a language to save a new preference.",
                "Kayıtlı dil okunamadı. Cihaz dili kullanılıyor. Yeni tercih kaydetmek için bir dil seçin.",
              ),
              key: const Key("app-language-read-failure"),
              style: hankenText(size: 12.5, height: 1.5),
            ),
          ),
        ],
        if (controller.writeFailed) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              localized(
                context,
                "The language changed for this session but could not be saved. Select it again to retry.",
                "Dil bu oturum için değişti ancak kaydedilemedi. Yeniden denemek için tekrar seçin.",
              ),
              key: const Key("app-language-write-failure"),
              style: hankenText(size: 12.5, height: 1.5),
            ),
          ),
        ],
      ],
    ),
  );
}

/// FK2: "listen to my own recording", off until the learner turns it on.
class OwnRecordingSettingCard extends StatefulWidget {
  const OwnRecordingSettingCard({super.key, required this.preference});
  final OwnRecordingPreference preference;

  @override
  State<OwnRecordingSettingCard> createState() =>
      OwnRecordingSettingCardState();
}

class OwnRecordingSettingCardState extends State<OwnRecordingSettingCard> {
  bool _on = false;
  bool _loaded = false;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final on = await widget.preference.read();
    if (mounted) {
      setState(() {
        _on = on;
        _loaded = true;
      });
    }
  }

  Future<void> _set(bool on) async {
    setState(() {
      _on = on;
      _saveFailed = false;
    });
    try {
      await widget.preference.write(on);
    } on Object {
      if (mounted) {
        setState(() {
          _on = !on;
          _saveFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    return Container(
      key: const Key('settings-own-recording'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.controlSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: [
              Expanded(
                child: kicker(uiText(context, OwnRecordingCopy.settingTitle)),
              ),
              Switch(
                key: const Key('settings-own-recording-switch'),
                value: _on,
                onChanged: _loaded ? _set : null,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            uiText(context, OwnRecordingCopy.settingBody),
            style: hankenText(
              size: 13.5,
              height: 1.55,
              color: palette.textBody,
            ),
          ),
          if (_saveFailed) ...[
            const SizedBox(height: 8),
            Text(
              uiText(context, OwnRecordingCopy.settingSaveFailed),
              style: hankenText(size: 12, color: palette.warnInk),
            ),
          ],
        ],
      ),
    );
  }
}

/// FK4 (F2.7): left-handed strip and colour-blind-safe colours, both off
/// until the learner turns them on. Changes apply to practice screens at once.
class PracticeDisplaySettingCard extends StatelessWidget {
  const PracticeDisplaySettingCard({super.key, required this.controller});
  final PracticeDisplayController controller;

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final settings = controller.settings;
        Widget toggle({
          required Key key,
          required UiCopy title,
          required UiCopy body,
          required bool value,
          required Future<void> Function(bool) onChanged,
        }) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MergeSemantics(
              child: Row(
                children: [
                  Expanded(child: kicker(uiText(context, title))),
                  Switch(
                    key: key,
                    value: value,
                    onChanged: (v) => unawaited(onChanged(v)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              uiText(context, body),
              style: hankenText(
                size: 13.5,
                height: 1.55,
                color: palette.textBody,
              ),
            ),
          ],
        );
        return Container(
          key: const Key('settings-practice-display'),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: palette.controlSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              toggle(
                key: const Key('settings-left-handed-switch'),
                title: PracticeDisplayCopy.leftHandedTitle,
                body: PracticeDisplayCopy.leftHandedBody,
                value: settings.leftHanded,
                onChanged: controller.setLeftHanded,
              ),
              const SizedBox(height: 14),
              toggle(
                key: const Key('settings-color-blind-switch'),
                title: PracticeDisplayCopy.colorBlindTitle,
                body: PracticeDisplayCopy.colorBlindBody,
                value: settings.colorBlindSafe,
                onChanged: controller.setColorBlindSafe,
              ),
              if (controller.saveFailed) ...[
                const SizedBox(height: 8),
                Text(
                  uiText(context, OwnRecordingCopy.settingSaveFailed),
                  key: const Key('settings-practice-display-save-failed'),
                  style: hankenText(size: 12, color: palette.warnInk),
                ),
              ],
            ],
          ),
        );
      },
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
      color: OstinatoPalette.of(context).controlSurface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: OstinatoPalette.of(context).glassBorder),
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
            color: OstinatoPalette.of(context).textBody,
          ),
        ),
      ],
    ),
  );
}
