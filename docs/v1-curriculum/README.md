# Ostinato v1 müfredat planı

**Tarih:** 2026-10-31 · **Durum:** kurucu kararları işlendi (1 Kas); müzik öğretmeni incelemesi ve Türk halk ezgileri için hukuk onayı bekliyor
**Dayanak:** Kurucu kararları (31 Eki 2026): tek uygulama odağı Ostinato; v1 kapsamı ~690 ders; birinci taraf kayıt yok; kamera yalnız S1 duruş; pratik ekranda, nota başına mikrofon geri bildirimi (doğru / farklı nota / duyamadım).
**Kaynak araştırma:** `scratch/2026-10-31-ostinato-derin/` (0 ürün önerisi, 1 talep ve müfredat §2–§5, 3 teknoloji §4). Mevcut dersler: `assets/content/*.v1.json`, `assets/content/library.json`.

Bu klasör yalnız **plan ve sözleşme** içerir: ders gövde metni, uygulama kodu ve içerik JSON'u yok.

---

## Sayılar

| Kurs | Seviye | Hedef | Yazılan ders | Öğrenci yolu | Mevcut içerikten | Yeni |
|---|---|---|---|---|---|---|
| Gitar | S1–S4 (S4'te Akustik/Fingerstyle ve Elektro/Lead kolları) | ~240 | **240** (40 · 60 · 60 · 80) | 221 (S4: 42 ortak + 19 kol) | 68 | 172 |
| Ses / Şan | S1–S4 | ~240 | **240** (40 · 60 · 60 · 80) | 240 | 24 | 216 |
| Piyano / Klavye | S1–S3 (mikrofonla ölçülebilir) | ~160 | **160** (40 · 60 · 60) | 160 | 28 | 132 |
| Kulak & Müzisyenlik | S1–S2 (ücretsiz giriş, ortak) | ~50 | **50** (25 · 25) | 50 | 0 | 50 |
| **Toplam** | | **~690** | **690** | **671** | **120** | **570** |

- Sayılar hedefle **birebir** aynı. Tek sapma kavramsal: gitarda "yazılan" (240) ile "öğrencinin gördüğü" (221) farklı, çünkü S4'te iki kol ayrı yazıldı. Gerekçe `10-gitar.md` başında.
- 15 seviye testi ders sayısına dahil (gitar 5, ses 4, piyano 3, kulak 2). Yerleştirme testi dahil değil.
- Mevcut 107 yazılı dersin 76'sı yeniden kullanıldı, 28'i revize edildi, 3'ü emekli. Kamera kurslarının 28 dersinin 20'si S1 kurulum derslerine birleşti, 8'i emekli.

## Ölçüm dağılımı

| Ölçüm | Gitar | Ses | Piyano | Kulak | Toplam |
|---|---|---|---|---|---|
| `M` mikrofon (Ö'ye düşebilir) | 209 | 200 | 122 | 24 | 555 |
| `M!` mikrofon, zorunlu (geçiş, test, kalibrasyon) | 27 | 24 | 16 | 7 | 74 |
| `M~` deneysel (piyano çok sesli; MIDI ile kesin) | — | — | 14 | — | 14 |
| `D` ekranda yanıt | 1 | 12 | 4 | 19 | 36 |
| `Ö` öz-kontrol | 1 | 3 | 2 | — | 6 |
| `K` kamera (yalnız S1) | 2 | 1 | 2 | — | 5 |

Mikrofonla ölçülen ders oranı **%93** (643/690). Motor adımlarına göre döküm: `70-motor-bagimliligi.md`.

## Dosyalar

| Dosya | İçerik |
|---|---|
| [00-ders-format-sozlesmesi.md](00-ders-format-sozlesmesi.md) | Ders format sözleşmesi: alanlar, ölçüm türleri, motor adımları, üç sonuç, geçiş ölçütleri, referans ses, güvenlik kodları, ön koşul, gizlilik |
| [10-gitar.md](10-gitar.md) | Gitar S1–S4, 240 ders |
| [20-ses.md](20-ses.md) | Ses S1–S4, 240 ders |
| [30-piyano.md](30-piyano.md) | Piyano S1–S3, 160 ders, "tek yeni nota" kuralı |
| [40-kulak-muzisyenlik.md](40-kulak-muzisyenlik.md) | Kulak & Müzisyenlik S1–S2, 50 ders, çalgı kurslarına bağlantılar |
| [50-seviye-ve-yerlestirme-testleri.md](50-seviye-ve-yerlestirme-testleri.md) | 15 seviye testi ve yerleştirme testi |
| [60-kamu-mali-repertuvar.md](60-kamu-mali-repertuvar.md) | Kamu malı eser listesi, besteci yaşam yılları, edisyon uyarıları |
| [70-motor-bagimliligi.md](70-motor-bagimliligi.md) | Motor adımı başına ders sayısı, gecikme senaryoları, motor gereksinimleri |
| [80-mevcut-ders-eslemesi.md](80-mevcut-ders-eslemesi.md) | Mevcut 135 dersin (107 yazılı + 28 kamera) R/V/X eşlemesi |
| [90-ders-yazim-kilavuzu.md](90-ders-yazim-kilavuzu.md) | Plan satırından ders dosyasına: JSON alanları, yazım kuralları, D alıştırma türleri, iş akışı |
| [counts.v1.json](counts.v1.json) | `tool/curriculum_lint.py`'nin plandan ürettiği sayılar (70-… ile aynı); `--check` CI'da |

## Araçlar ve ders kaynakları

- **`content/v1/<kurs>/<id>.json`:** ders gövdeleri (EN + TR). Henüz uygulamaya paketlenmez. Model: `lib/app/curriculum/v1_lesson.dart`; biçim testi: `test/v1_lesson_content_test.dart`.
- **`tool/curriculum_lint.py --check`:** plan tablolarını denetler. Kontrol edilenler: kimlik, başlık sayıları, kod sözlükleri, A0 kuralı. Sayıları `counts.v1.json` ile karşılaştırır. Her ders dosyasını plan satırına bağlar: başlık, ölçüm, motor, yedek davranış, güvenlik, referans ve "yanlış" yasağı.
- **`tool/build_message_ids.py`:** `(en, tr)` → `sha256[:16]` mesaj kimliği tablosunu (`lib/app/app_message_ids.dart`) bayt bayt yeniden üretir (`--check`). `--pending content/v1`: yeni kimlikleri ve 12 dilin eksiklerini listeler. `--add`: tabloya ekler.

## Bu planda alınan tasarım kararları

1. **Ders kimliği** `<kurs>-s<seviye>-m<modül>-<sıra>`; mevcut kimlikler (`guitar.journey.*`, `piano-NN`, `vocal-NN`) ilerleme göçü için `legacy` alanında tutulur.
2. **`D` (ekranda yanıt) ölçüm türü eklendi.** Kulak/teori sorularını Ö'den ayırmak için (`00-…` §3).
3. **`M!` / `M` ayrımı** her derste motor gecikmesinde ne olacağını belirler: modül geçişleri, seviye testleri ve kalibrasyon dersleri bekletilir, diğerleri öz-kontrolle gönderilebilir.
4. **Göreli dinamik A3'e, gitar bend/vibrato A5'e bağlandı** (aynı sinyal işleme altyapısı).
5. **Piyanoda "tek yeni nota" kuralı:** mikrofonla ölçülen her pratikte aynı anda yalnız bir yeni atak. Çok sesli pratikler `M~` (kilitlemez) + MIDI.
6. **Ses kursunda kişisel ton:** diziler derece olarak yazılır, kullanıcının rahat menziline taşınır, oktav katlanmış ölçülür. Ses tipi sınıflandırması yok.
7. **Kayıt yok:** Ö dersleri kayıt dinlemeye dayanmaz; mevcut "kendi kaydını dinle" adımları tekrar-ölç adımına çevrildi.
8. **Kulak kursu çalgı kurslarında kopyalanmadı;** bağlantıyla gömüldü. Çalgıya özgü kulak dersleri (kulaktan telde bulmak, akor rengini çalmak) çalgı kursunda kaldı.

## Açık sorular

1. ~~**Motor sırası**~~ **Kararlaştı (kurucu, 31 Eki; Yönetim iletti):** A3 → A5 → A4.
2. **Ücretsiz kapsam:** ~~Kulak S1–S2'nin tamamı mı, yalnız S1 mi?~~ **Kararlaştı (kurucu, 31 Eki; Yönetim iletti):** kulak S1 ücretsiz, S2 premium; kulak ayrı satılmaz. Açık kalan: çalgı kurslarında ücretsiz çekirdek (ör. her kursun S1 M01–M02).
3. ~~**Amfisiz elektro gitar**~~ **Kararlaştı (kurucu, 1 Kas; Yönetim iletti):** elektro kol (`m19b`, 19 ders) v1'de.
4. ~~**Piyano alt frekans sınırı**~~ **Kapandı (kurucu, 1 Kas):** motorun alt sınırı 28 Hz'e indi (PR #7); C2 (65,4 Hz) dersleri plandaki yerinde açık kalır.
5. ~~**Geçiş eşikleri**~~ **Kararlaştı (kurucu, 1 Kas):** varsayılan %80 kalır, ders dosyalarındaki `expertPending` işareti durur. Müzik öğretmeni incelemesi sonraya bırakıldı.
6. ~~**Hukuk**~~ **Kararlaştı (kurucu, 1 Kas):** kamu malı eserler (`60-…`) v1'de. **Türk halk ezgileri hukuk onayına kadar kilitli**; bu satırlar yazılabilir ama paketlenmez.
7. ~~**Ses M18 armoni**~~ **Kararlaştı (kurucu, 1 Kas):** M18 (16 ders) v1'de; her dersin başında kulaklık uyarısı gösterilir.
8. ~~**Kamera el/bilek uyarısı**~~ **Kararlaştı (kurucu, 1 Kas):** el/bilek duruşu uyarısı v1'de. Kamera izni yalnız `K` derslerinde istenir; görüntü cihazda işlenir, kaydedilmez ve gönderilmez.
9. ~~**Sayım konvansiyonu**~~ **Kararlaştı (kurucu, 1 Kas):** mağaza metninde **690 ders** yazılır.

Diğer kurucu kararları (1 Kas): atıflar ayrı ekranda değil, Ayarlar > Hakkında'daki tek lisans metninde ya da mağaza açıklamasında; 12 dil için anadili incelemesi şimdilik yok.

## Sonraki adımlar (bu PR'ın kapsamı dışında)

- ~~Sözleşmeyi içerik JSON şemasına çevirmek~~ → `v1_lesson.dart` + `90-ders-yazim-kilavuzu.md` (2026-10-31).
- Ders gövde metinleri (EN + TR), sonra 12 dil katalog çevirisi. Örnek 3 ders `content/v1/`'de.
- Özgün egzersiz havuzu (seviye testi başına bileşen başına ≥6 varyant).
- Müzik öğretmeni incelemesi: sıra, tempo hedefleri, ses sağlığı notları.
