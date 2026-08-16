# Mağaza Liste Metni — TASLAK (D6, 2026-08-16, O-156)

**Makine-okur kaynak:** `docs/store/listing.json` — `test/`e bağlı bir kapı YOK (koordinatör
sınırı: bu genişletme JabLab'da var, Ostinato'da bilerek yazılmadı). Bu dosya insan-okur
bağlam; metnin kendisi `listing.json`da.

**Gönderim KURUCU kalemi (B7).** Bu yalnız taslak — ASC/Play'e hiçbir şey yüklenmedi,
yüklenmeyecek. Orkestratör `PASS`ı olmadan submit yok.

## Neden bu kadar dar

`docs/PRD.md`nin W1 kabul kriterleri (§7) çok daha zengin bir yetenek seti listeliyor —
perde doğruluğu, vibrato, akor-sınıfı, MIDI modu, tempo. **Bunların hiçbiri bugünkü build'de
CANLI değil** (`lib/` tarandı: mikrofon izni yok, ses-yakalama çağrısı sıfır —
`settings_screen.dart`ın kendi kartı bunu adıyla söylüyor). PRD bir **hedef**, bugünkü kodun
**envanteri** değil. Mağaza metni PRD'yi değil `lib/`i baz aldı — JabLab'ın `$claimAuditWhy`
denetiminin yakaladığı üç sınıf hatadan (saklama-yalanı · ölçülüyor-ama-gösterilmiyor ·
"graded" aşırı-iddiası) ders alınarak, **yazmadan önce** önlendi.

## Kontrol listesi (her cümle bir kaynağa bağlı)

| İddia | Kaynak |
|---|---|
| Kamera-temelli, mikrofon yok | `lib/app/screens/settings_screen.dart` kartı + `grep NSMicrophoneUsageDescription` sıfır |
| Tek ölçüm: gövde eğimi | `settings_screen.dart` "it measures one thing" + `docs/g1/w1-hasat-nihai.md` (trunk_tilt = W1 omurgası) |
| İskelet canlı çizilir | `grep SkeletonFigurePainter` → `live_screen.dart`/`setup_check_screen.dart`/`lesson_scored_screen.dart` |
| Video hiç saklanmaz, özet saklanır | `PrivacyInfo.xcprivacy` (H-34/D14) + `session_store.dart` (bugün, D14) |
| Tıbbi değil | CLAUDE.md kuralı + `onboarding_screen.dart` "does not diagnose anything" + medikal-dil taraması sıfır |
| 3 çalgı canlı, 39 yakında | `settings_screen.dart:_liveSentence()` (library.json'dan türer) + gate çıktısı |
| Web/UGC yok | `grep webview\|url_launcher` sıfır |

## Ne YAZILMADI (bilerek)

- **"Watched but not scored" katmanı** (JabLab'ın dirsek/omuz emsali): ruleset'lerde
  `coached_only` sınıflandırması VAR ama serbest-metin alanında yaşıyor (`_noiseBand_why`),
  boolean değil — bu oturumda eklem-eklem doğrulanmadı. Eksik bırakıldı, uydurulmadı.
- **Ses/perde/ritim hiçbir biçimde** — config'te metrik TANIMLI olsa da `lib/`de sıfır
  yakalama yolu var; PRD'nin hedefi, bugünün gerçeği değil.
- **Cihaz-kanıtlı hiçbir cümle** — kamera köprüsü turu (`KAMERA-KÖPRÜSÜ-CANLILIK.md` emsali,
  JabLab'da) Ostinato'da henüz yapılmadı.

## Sıradaki

Ekran görüntüleri (kendi simülatörümde, `H-46`: attach/detach çağrılmadan, `xcrun simctl io
screenshot` doğrudan) → sonra `D8` (ikon) → `D20` (Android imza kablolaması).
