# Güncel mağaza metni girişi · 17 Ekim 2026

Yayıma hazırlanacak TR/EN metinlerin kaynağı [listing.json](listing.json) ve
[listing.tr-TR.json](listing.tr-TR.json) dosyalarıdır. Güncel dar kurs kapsamı
**60 ders / 10 modül gitar**; kurs varlık kimliği ve hashleri JSON içindeki `$` kaynak notlarındadır.
İsteğe bağlı mikrofonla cihaz üstü yaklaşık tek nota gözlemi vardır; doğruluk/akor puanı, kamera koçluğu veya abonelik satışı vaadi yoktur.

Kurs ilerlemesi kullanıcının kendi çalışma kaydıdır; ustalık veya fiziksel öğretim
kabulü değildir. Hesap ve destek/gizlilik metinleri güncel JSON'dan alınır.
Yerel metin, eski ekran görüntüsü veya kaynak testi mağazada kaydedildiği, güncel
imzalı pakette bulunduğu ya da fiziksel cihazda kabul edildiği anlamına gelmez.
Bu bakımda mağaza paneline yazılmadı ve yükleme yapılmadı.

## Tarihsel araştırma · aşağıdaki metni yayın metni olarak kullanmayın

Aşağıdaki eski katalog/kamera incelemesi kendi tarihinin kanıtıdır. Eski “bugün”,
“sıradaki” ve simge onayı ifadeleri güncel yayın durumu değildir; yukarıdaki iki
JSON ve kaynaklarına bağlı güncel kabul kullanılır.

# Mağaza Liste Metni — TASLAK (D6, 2026-08-16, O-156)

**Makine-okur kaynaklar:** `docs/store/listing.json` (EN) ve
`docs/store/listing.tr-TR.json` (TR). `python3 -B tools/validate_store_listing_limits.py`
iki dosyanın mekanik kısıtlarını denetler; keyword sınırı virgüller dahil 100 UTF-8
byte'tır. `tools/test_validate_store_listing_limits.py` 100 byte kabul / 102 byte ret
ve iki locale'ın denetlenmesini sınar; `tools/run_gates.sh` bu regresyonları çağırır
(2026-10-15). Bu yerel kontrol mağaza formu, gerçek cihaz veya yayın kabulü değildir.
Bu dosya insan-okur bağlamdır; metinler JSON dosyalarındadır.

**Gönderim KURUCU kalemi (B7).** Bu yalnız taslak — ASC/Play'e hiçbir şey yüklenmedi,
yüklenmeyecek. Orkestratör `PASS`ı olmadan submit yok.

## Güncel ürün sınırı — 2026-09-26

Gitar öğrenme yolunda10 modül/60 özgün TR-EN metin dersi ve yerel, hesap
kapsamlı öz beyan ilerlemesi vardır. Model/demonstrasyon görselleri üretilmedi.
İsteğe bağlı tek gitar nota gözlemi, kullanıcı Başlat'a bastığında mikrofon
izni ister. Ham PCM yalnız geçici cihaz belleğinde işlenir; kaydedilmez ve
aktarılmaz. Yaklaşık nota, Hz ve en yakın nota merkezinden cent gösterilir;
doğru nota, akort başarısı, akor, zamanlama, mutlak dB(A) veya ustalık puanı yoktur.
Gitar kursu mikrofonsuz tamamlanabilir.

Native izin/kanal kaynakları ve derleme kanıtı, gerçek telefonda mikrofon
kabulü sayılmaz. Stüdyo ölçümü ve gerçek telefon doğrulaması sınırı ekranda
belirtilir. Eski duruş rotaları mikrofon başlatmaz; kamera/abonelik/puan
kapıları bu çalışmada açılmadı. Mağaza gönderimi yapılmadı.

## Tarihsel kamera kontrol listesi (2026-08-16; yeni kurs kapısı ayrı)

| İddia | Kaynak |
|---|---|
| İsteğe bağlı cihaz üstü tek gitar nota gözlemi; eski duruş dersleri ses başlatmaz | `guitar_note_observation_screen.dart`, `guitar_note_observation_controller.dart`, native izin/kanal kayıtları; gerçek telefon kabulü açık |
| Tek ölçüm: gövde eğimi | `settings_screen.dart` "it measures one thing" + `docs/g1/w1-hasat-nihai.md` (trunk_tilt = W1 omurgası) |
| İskelet canlı çizilir | `grep SkeletonFigurePainter` → `live_screen.dart`/`setup_check_screen.dart`/`lesson_scored_screen.dart` |
| Video hiç saklanmaz, özet saklanır | `PrivacyInfo.xcprivacy` (H-34/D14) + `session_store.dart` (bugün, D14) |
| Tıbbi değil | CLAUDE.md kuralı + `onboarding_screen.dart` "does not diagnose anything" + medikal-dil taraması sıfır |
| 3 çalgı canlı, 39 yakında | `settings_screen.dart:_liveSentence()` (library.json'dan türer) + gate çıktısı |
| Serbest web gezintisi/UGC yok | Ortak hesap ekranı gizlilik bağlantısını dış tarayıcıda açabilir; uygulama içinde serbest web gezintisi veya kullanıcı içeriği paylaşımı yok |

## Ne YAZILMADI (bilerek)

- **"Watched but not scored" katmanı** (JabLab'ın dirsek/omuz emsali): ruleset'lerde
  `coached_only` sınıflandırması VAR ama serbest-metin alanında yaşıyor (`_noiseBand_why`),
  boolean değil — bu oturumda eklem-eklem doğrulanmadı. Eksik bırakıldı, uydurulmadı.
- **Doğruluk/akor/ritim puanı** — yeni tek nota gözlemi bir hedef veya ders
  başarısı kararı üretmez; stüdyo ölçümü fiziksel telefon doğruluğu sayılmaz.
- **Cihaz-kanıtlı hiçbir cümle** — kamera köprüsü turu (`KAMERA-KÖPRÜSÜ-CANLILIK.md` emsali,
  JabLab'da) Ostinato'da henüz yapılmadı.

## Sıradaki

Ekran görüntüleri (kendi simülatörümde, `H-46`: attach/detach çağrılmadan, `xcrun simctl io
screenshot` doğrudan) → sonra `D8` (ikon) → `D20` (Android imza kablolaması).
